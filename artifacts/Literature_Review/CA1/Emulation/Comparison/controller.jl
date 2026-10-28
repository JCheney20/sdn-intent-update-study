using JSON, TOML, SHA
const HERE=@__DIR__
const RUN=ENV["COS738_OVS_RUN_DIR"]
const LAUNCH=parse(UInt64,ENV["COS738_LAUNCH_NS"])
const IMPORT_START=time_ns()
using PythonCall, CondaPkg
const IMPORT_SECONDS=(time_ns()-IMPORT_START)/1e9
include("../Step2/CiscoAdapter.jl")
using .CiscoAdapter
include("../Step3/Wire.jl")
include("../../Revision_Protocol/handover.jl")
const PARAMS=JSON.parsefile(joinpath(HERE,"Manifest.json"))["parameters"]
const MODE,CELL=ARGS
const METHOD,SCENARIO=split(CELL,"-")
const FIXTURE=TOML.parsefile(joinpath(HERE,"../../Revision_Protocol/Handover_Bounds.toml"))["fixtures"][1]
const DOMAIN=Handover.Domain(FIXTURE)
const MODEL_PLANS=Dict(m=>Handover.plan(DOMAIN,Symbol(m)) for m in PARAMS["procedures"])

function journal(kind,data)
    open(joinpath(RUN,"progress.jsonl"),"a") do io
        println(io,JSON.json(Dict("kind"=>kind,"at_ns"=>time_ns(),"data"=>data)))
    end
end
function waituntil(deadline)
    while time_ns()<deadline
        remaining=max(0,(Int128(deadline)-Int128(time_ns()))/1e9)
        remaining>0 && sleep(Float64(remaining))
    end
end
untagged(hex)=begin
    b=hex2bytes(hex)
    b[13:14]==UInt8[0x81,0] ? [b[1:12];b[17:end]] : b
end
function resident!(a,id)
    events=Any[];started=time_ns()
    while time_ns()-started<PARAMS["resident_poll_timeout_ns"]
        response=CiscoAdapter.rpc(a,"wire",Dict("op"=>"drain"))
        append!(events,response["events"])
        any(e["id"]==id && e["kind"]=="receive" for e in events) && return events
        sleep(.002)
    end
    error("declared resident initial condition not established")
end

# Controller boundary: no captures, worker drains, wire occupancy or delivery inputs here.
function execute!(a,method,slot,t0)
    phases=Any[];admission=nothing
    function operation(kind,s,fn)
        before=time_ns();fn();after=time_ns()
        event=Dict("kind"=>kind,"switch"=>s,"before_ns"=>before,"after_ns"=>after,"snapshot_end"=>length(a.evidence["snapshots"]))
        push!(phases,event);journal("operation",event)
        if kind in ("replace_activate","open","commit")
            admission=admit!(slot,a.newopen,r->emit!(a,r.source,r.id,r.hex))
        end
    end
    function pause(kind,duration)
        before=time_ns();waituntil(before+UInt64(duration));after=time_ns()
        push!(phases,Dict("kind"=>kind,"switch"=>nothing,"before_ns"=>before,"after_ns"=>after,"snapshot_end"=>length(a.evidence["snapshots"])))
    end
    target=rows(a.f,"new")
    if method=="ordinary"
        for cmd in MODEL_PLANS[method][1]
            s=DOMAIN.names[cmd.switch];rs=filter(r->r[1]==s,target)
            if cmd.kind==:replace_activate
                operation("replace_activate",s,()->install!(a,s,rs;oldopen=false,newopen=true,newtag=0,label="ordinary-activate"))
            else
                operation("replace",s,()->install!(a,s,rs;label="ordinary-replace"))
            end
        end
    elseif method=="Q"
        operation("close","C2",()->install!(a,"C2",a.tables["C2"];oldopen=false,newopen=false,label="Q-close"))
        pause("drain_wait",PARAMS["drain_wait_ns"])
        for cmd in MODEL_PLANS[method][DOMAIN.H+2]
            s=DOMAIN.names[cmd.switch]
            operation("replace",s,()->install!(a,s,filter(r->r[1]==s,target);label="Q-replace"))
        end
        operation("open","C2",()->install!(a,"C2",a.tables["C2"];newopen=true,label="Q-open"))
    elseif method=="V"
        operation("stage","all",()->(@assert stage!(a;allowance=1)==:STAGED))
        operation("commit","C2",()->commit!(a))
        pause("retirement_wait",PARAMS["retirement_wait_ns"])
        operation("clean","all",()->clean!(a))
    else
        error("unsupported frozen procedure")
    end
    completion=time_ns()
    @assert slotvalid(slot) && slot.pending===nothing && admission!==nothing
    expected=rows(a.f,"new";tag=method=="V" ? 1 : 0)
    @assert CiscoAdapter.stateis(a,expected) && !a.oldopen && a.newopen && a.newtag==(method=="V" ? 1 : 0)
    waits=sum((p["after_ns"]-p["before_ns"] for p in phases if p["kind"] in ("drain_wait","retirement_wait"));init=UInt64(0))
    Dict("phases"=>phases,"completion_ns"=>completion,"admission"=>admission,"controller_wall_ns"=>completion-t0,
        "intentional_wait_ns"=>waits,"nonwait_wall_ns"=>completion-t0-waits)
end

function outcomes(record)
    events=record["observation"]["records"];deadline=record["observation"]["deadline_ns"]
    answer=Any[]
    for spec in record["requests"]
        found=[e for e in events if startswith(e["node"],"H") && e["id"]==spec["id"]]
        for event in found
            @assert event["ipv4_checksum_valid"] && untagged(event["hex"])==untagged(spec["hex"])
        end
        ontime=[e for e in found if e["received_ns"]<=deadline]
        wrong=any(e["node"]!=spec["expected_host"] || e["vlan"]!=spec["expected_vlan"] for e in found)
        status=wrong ? "WRONG_DESTINATION_OR_VERSION" : length(found)>1 ? "DUPLICATE" : isempty(found) ? "UNOBSERVED" : isempty(ontime) ? "LATE" : "PASS"
        latency=isempty(ontime) ? nothing : minimum(e["received_ns"] for e in ontime)-spec["arrival_ns"]
        push!(answer,Dict("id"=>spec["id"],"role"=>spec["role"],"status"=>status,"receipts"=>found,"service_age_ns"=>latency))
    end
    known=Set(r["id"] for r in record["requests"])
    @assert all(e["id"] in known for e in events if startswith(e["node"],"H"))
    answer
end
function episode!(a,method,scenario,base;phase="measured")
    configure!(a,rows(a.f,"old");label="reset")
    oldid,newid=base,base+1
    oldhex=frame(oldid;label="old-request");newhex=frame(newid;label="new-request")
    requests=Any[];pre=Any[];oldsend=nothing
    if scenario=="inflight"
        oldsend=emit!(a,"H5",oldid,oldhex)
        pre=resident!(a,oldid)
    end
    slot=Slot();t0=time_ns()
    if scenario=="inflight"
        rx=only(e for e in pre if e["id"]==oldid && e["kind"]=="receive")
        @assert oldsend["before_ns"]<=rx["received_ns"]<=t0<rx["due_ns"]
        push!(requests,Dict("id"=>oldid,"role"=>"old","source"=>"H5","arrival_ns"=>oldsend["before_ns"],"hex"=>oldhex,"send"=>oldsend,"expected_host"=>"H9","expected_vlan"=>nothing))
    end
    req=Request(newid,"H6",newhex,t0);@assert offer!(slot,req)==:PENDING
    push!(requests,Dict("id"=>newid,"role"=>"new","source"=>"H6","arrival_ns"=>t0,"hex"=>newhex,"expected_host"=>"H10","expected_vlan"=>(method=="V" ? 101 : nothing)))
    journal("request",Dict("id"=>base,"method"=>method,"scenario"=>scenario,"phase"=>phase,"request_ns"=>t0,"requests"=>requests,"pre"=>pre))
    first_snapshot=length(a.evidence["snapshots"])+1
    control=execute!(a,method,slot,t0)
    requests[end]["send"]=control["admission"]
    @assert slot.original[newid]===req && control["admission"]["before_ns"]>=t0
    observation=collectat!(a,t0+UInt64(PARAMS["observation_window_ns"]))
    sleep(PARAMS["tail_settle_ns"]/1e9)
    tail=collectat!(a,time_ns())
    append!(observation["records"],tail["records"])
    append!(observation["collection_intervals"],tail["collection_intervals"])
    for event in pre;event["node"]="wire";push!(observation["records"],event);end
    wire=CiscoAdapter.rpc(a,"wire",Dict("op"=>"drain"))
    @assert isempty(wire["pending_ids"]) && isempty(wire["events"])
    record=Dict{String,Any}("phase"=>phase,"method"=>method,"scenario"=>scenario,"id"=>base,"request_ns"=>t0,"requests"=>requests,
        "control"=>control,"observation"=>observation,"snapshot_first"=>first_snapshot,"snapshot_last"=>length(a.evidence["snapshots"]),
        "resident_pid"=>getpid(),"embedded_pid"=>pyconvert(Int,pyimport("os").getpid()))
    record["outcomes"]=outcomes(record)
    open(joinpath(RUN,"episodes.jsonl"),"a") do io;println(io,JSON.json(record));end
    if method in ("Q","V")
        all(o["status"]=="PASS" for o in record["outcomes"]) || error("MODEL_IMPLEMENTATION_DISAGREEMENT: "*JSON.json(record["outcomes"]))
    end
    println("EPISODE ",phase," ",method," ",scenario," ",base," ",JSON.json([o["status"] for o in record["outcomes"]]))
    record
end
function main()
    @assert MODE in ("validation","primary") && CELL in PARAMS["cell_order"]
    @assert occursin("cos738-ovs-",read("/proc/self/cgroup",String)) && CondaPkg.backend()==:Null
    @assert all(Handover.validate_plan(DOMAIN,p) for p in values(MODEL_PLANS))
    result=Dict{String,Any}("status"=>"RUNNING","mode"=>MODE,"cell"=>CELL,"primary_data"=>MODE=="primary",
        "manifest_sha256"=>bytes2hex(sha256(read(joinpath(HERE,"Manifest.json")))),"import_seconds"=>IMPORT_SECONDS,"warmup"=>Any[],"episodes"=>Any[])
    a=nothing
    try
        a=Adapter(fixture(),RUN);start!(a);addwire!(a;delay_ms=PARAMS["delay_ms"])
        configure!(a,rows(a.f,"old");label="reset")
        @assert stage!(a;allowance=0)==:RESOURCE_BLOCKED
        index=findfirst(==(CELL),PARAMS["cell_order"]);base=index*100000
        primeid=base+1;primehex=frame(primeid;label="cold-path-prime")
        sent=emit!(a,"H5",primeid,primehex);pre=resident!(a,primeid)
        prime=collectat!(a,UInt64(sent["after_ns"])+UInt64(PARAMS["observation_window_ns"]))
        hosts=[e for e in prime["records"] if startswith(e["node"],"H")]
        @assert length(hosts)==1 && hosts[1]["id"]==primeid && hosts[1]["node"]=="H9"
        result["priming"]=Dict("send"=>sent,"pre"=>pre,"observation"=>prime)
        for (i,cell) in enumerate(PARAMS["warm_order"])
            m,s=split(cell,"-")
            push!(result["warmup"],episode!(a,m,s,base+100+i*10;phase="warmup"))
        end
        configure!(a,rows(a.f,"old");label="ready-reset")
        ready=time_ns();result["ready_ns"]=ready;result["launch_to_ready_ns"]=ready-LAUNCH
        result["ready_pid"]=getpid();result["ready_embedded_pid"]=pyconvert(Int,pyimport("os").getpid())
        println("READY ",CELL," pid=",getpid()," warmup=",length(result["warmup"]))
        write(joinpath(RUN,"readiness.json"),JSON.json(Dict(k=>result[k] for k in ("cell","ready_ns","launch_to_ready_ns","ready_pid","ready_embedded_pid")))*"\n")
        for i in 1:PARAMS["repetitions"]
            push!(result["episodes"],episode!(a,METHOD,SCENARIO,base+10000+i*10;phase=MODE=="primary" ? "primary" : "validation"))
        end
        @assert all(e["resident_pid"]==e["embedded_pid"]==result["ready_pid"] for e in result["episodes"])
        result["status"]="PASS"
    catch error
        result["status"]="FAIL";result["error"]=sprint(showerror,error,catch_backtrace());rethrow()
    finally
        if a!==nothing
            try
                result["cleanup"]=stop!(a)
                all(values(result["cleanup"])) || (result["status"]="FAIL")
            catch error
                result["cleanup_error"]=sprint(showerror,error,catch_backtrace());result["status"]="FAIL"
            end
            result["adapter_evidence"]=a.evidence
        end
        write(joinpath(RUN,"comparison.json"),JSON.json(result)*"\n")
    end
    result["status"]=="PASS" || error("cleanup acceptance failed")
    println("COMPARISON JOB PASS ",MODE," ",CELL)
end
main()
