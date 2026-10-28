using JSON, TOML, SHA
const HERE=@__DIR__
const RUN=ENV["COS738_OVS_RUN_DIR"]
@assert occursin("cos738-ovs-",read("/proc/self/cgroup",String))
@assert readlink("/proc/self/ns/net")!=ENV["HOST_NETNS"]
const import_start=time_ns()
using PythonCall, CondaPkg
const import_seconds=(time_ns()-import_start)/1e9
include("../Step2/CiscoAdapter.jl")
using .CiscoAdapter
include("Wire.jl")

untagged(hex)=begin
    b=hex2bytes(hex)
    b[13:14]==UInt8[0x81,0] ? [b[1:12];b[17:end]] : b
end
function main()
    sources=["timing.jl","Wire.jl","wire.py","run.sh","Timing_Plan.md"]
    hashes=Dict(f=>bytes2hex(sha256(read(joinpath(HERE,f)))) for f in sources)
    result=Dict{String,Any}("status"=>"RUNNING","validation_only"=>true,"primary_data"=>false,
        "source_sha256"=>hashes,"import_seconds"=>import_seconds,"cases"=>Any[],"checks"=>0)
    a=nothing
    check(c,label)=(result["checks"]+=1;c || error("TIMING GATE FAILED: "*label);true)
    function packetcase(record::Dict{String,Any};strict=true)
        id=record["id"]
        if !haskey(record,"send")
            record["send"]=emit!(a,record["source"],id,record["sent_hex"])
        end
        deadline=UInt64(record["send"]["after_ns"])+UInt64(1500000000)
        received=Any[]
        pollstart=time_ns()
        while time_ns()-pollstart<150000000
            reply=CiscoAdapter.rpc(a,"wire",Dict("op"=>"drain"))
            append!(received,reply["events"])
            any(e["id"]==id && e["kind"]=="receive" for e in received) && break
            sleep(.002)
        end
        marker=time_ns()
        observation=collectat!(a,deadline)
        append!(received,[e for e in observation["records"] if e["node"]=="wire"])
        record["marker_ns"]=marker;record["marker_type"]=record["source"]=="H5" ? "resident-workload-marker" : "post-commit-observation-marker"
        record["relay_events"]=received;record["observation"]=observation
        record["strict"]=strict
        push!(result["cases"],record)
        rx=[e for e in received if e["id"]==id && e["kind"]=="receive"]
        tx=[e for e in received if e["id"]==id && e["kind"]=="release"]
        check(length(rx)==length(tx)==1,"one wire receive/release")
        check(rx[1]["input_side"]==0 && tx[1]["output_side"]==1,"fixed transparent direction")
        check(rx[1]["hex"]==tx[1]["hex"],"wire preserves full canonical Ethernet bytes")
        check(untagged(rx[1]["hex"])==untagged(record["sent_hex"]),"wire cannot rewrite payload/MAC")
        check(tx[1]["before_ns"]>=rx[1]["due_ns"]==rx[1]["received_ns"]+250000000,"minimum declared residence")
        check(tx[1]["after_ns"]-rx[1]["received_ns"]<=1000000000,"bounded observed residence")
        if strict && record["source"]=="H5"
            check(record["send"]["before_ns"]<=rx[1]["received_ns"]<=marker<tx[1]["before_ns"],"real admitted frame resident at request marker")
        end
        hosts=[e for e in observation["records"] if startswith(e["node"],"H")]
        expected=[e for e in hosts if e["id"]==id]
        check(length(hosts)==length(expected)==1,"all-host identity and duplication check")
        event=only(expected)
        check(event["node"]==record["expected_host"] && event["vlan"]==record["expected_vlan"],"actual expected host/version")
        check(event["received_ns"]<=deadline && event["received_ns"]>=tx[1]["before_ns"],"application observation deadline/order")
        check(event["ipv4_checksum_valid"] && untagged(event["hex"])==untagged(record["sent_hex"]),"actual host bytes/checksum")
        record["residence_ns"]=tx[1]["before_ns"]-rx[1]["received_ns"]
        println("TIMING CONTROL PASS ",id," residence_ns=",record["residence_ns"])
    end
    try
        check(CondaPkg.backend()==:Null,"offline embedded Python")
        a=Adapter(fixture(),RUN);start!(a)
        addwire!(a;delay_ms=250)
        configure!(a,rows(a.f,"old");label="timing-old")
        packetcase(Dict{String,Any}("id"=>6900,"source"=>"H5","sent_hex"=>frame(6900;label="wire-warmup"),"expected_host"=>"H9","expected_vlan"=>nothing);strict=false)
        for id in 7001:7003
            packetcase(Dict{String,Any}("id"=>id,"source"=>"H5","sent_hex"=>frame(id;label="old-wire-case"),"expected_host"=>"H9","expected_vlan"=>nothing))
        end
        check(stage!(a;allowance=0)==:RESOURCE_BLOCKED,"V zero-row preflight refusal")
        check(stage!(a;allowance=1)==:STAGED,"version staging unchanged")
        slot=Slot();r=Request(7011,"H6",frame(7011;label="pending-wire-case"),time_ns());offer!(slot,r)
        check(admit!(slot,a.newopen,_ -> error("closed request emitted"))===nothing,"real pending remains pre-admission")
        commit!(a)
        sent=admit!(slot,a.newopen,x->emit!(a,x.source,x.id,x.hex))
        check(slotvalid(slot) && slot.original[r.id]===r && slot.pending===nothing,"pending identity/arrival conserved")
        packetcase(Dict{String,Any}("id"=>r.id,"source"=>"H6","send"=>sent,"sent_hex"=>r.hex,"arrival_ns"=>r.arrival_ns,"expected_host"=>"H10","expected_vlan"=>101))
        for id in 7012:7013
            packetcase(Dict{String,Any}("id"=>id,"source"=>"H6","sent_hex"=>frame(id;label="new-wire-case"),"expected_host"=>"H10","expected_vlan"=>101))
        end
        clean!(a)
        check(pyconvert(Int,pyimport("os").getpid())==getpid(),"resident embedded interpreter")
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
        for (f,h) in hashes
            bytes2hex(sha256(read(joinpath(HERE,f))))==h || (result["status"]="FAIL";result["source_drift"]=true)
        end
        write(joinpath(RUN,"timing_validation.json"),JSON.json(result)*"\n")
    end
    result["status"]=="PASS" || error("timing cleanup/source failure")
    println("TIMING GATE PASS")
end
main()
