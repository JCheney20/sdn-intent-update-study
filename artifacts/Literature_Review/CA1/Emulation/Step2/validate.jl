using JSON, TOML, SHA
const HERE=@__DIR__
const RUN=ENV["COS738_OVS_RUN_DIR"]
@assert occursin("cos738-ovs-",read("/proc/self/cgroup",String))
@assert readlink("/proc/self/ns/net")!=ENV["HOST_NETNS"]
const import_started=time_ns()
using PythonCall, CondaPkg
const import_seconds=(time_ns()-import_started)/1e9
include("CiscoAdapter.jl")
using .CiscoAdapter

function main()
    mode=only(ARGS);mode in ("static","queue","version") || error("unsupported adapter validation mode")
    sourcefiles=["CiscoAdapter.jl","packet_worker.py","validate.jl","run.sh","Validation_Plan.md"]
    hashes=Dict(f=>bytes2hex(sha256(read(joinpath(HERE,f)))) for f in sourcefiles)
    result=Dict{String,Any}("status"=>"RUNNING","mode"=>mode,"validation_only"=>true,"primary_data"=>false,
        "source_sha256"=>hashes,"import_seconds"=>import_seconds,"cases"=>Any[],"checks"=>0)
    a=nothing
    check(c,label)=(result["checks"]+=1;c || error("CHECK FAILED: "*label);true)
    function rejected(fn)
        try;fn();false;catch e;e isa ArgumentError;end
    end
    function probe(id,label,source,expected;vlan=nothing,expected_vlan=nothing,sourceip=0x0a000000,destip=0x0a000000,neighbor=nothing,payload=label)
        earlier=observe!(a;window=.01)
        check(isempty(filter(e->startswith(e["node"],"H"),earlier)),"no late host packets")
        bytes=frame(id;label=payload,vlan=vlan,source=sourceip,destination=destip)
        send=neighbor===nothing ? emit!(a,source,id,bytes) : emit!(a,source,id,bytes;neighbor)
        observed=observe!(a)
        hosts=filter(e->startswith(e["node"],"H"),observed)
        push!(result["cases"],Dict("id"=>id,"label"=>label,"source"=>source,"expected_host"=>expected,
            "expected_vlan"=>expected_vlan,"sent_hex"=>bytes,"send"=>send,"observed"=>observed))
        check(all(e->e["id"]==id,hosts),"packet identity/observation separation")
        check([e["node"] for e in hosts]==(expected===nothing ? String[] : [expected]),label*" delivery")
        for event in hosts
            check(event["ipv4_checksum_valid"],"valid IPv4 bytes")
            check(event["vlan"]==expected_vlan,label*" version")
        end
        println("ADAPTER CONTROL PASS ",label)
    end
    try
        check(CondaPkg.backend()==:Null,"no managed Python")
        f=fixture();check(length(f["hosts"])==12 && length(f["switches"])==10,"original node counts")
        check(length(f["adjacency"]["H2"])==2 && length(f["adjacency"]["H7"])==2,"dual-home preservation")
        a=Adapter(f,RUN)
        start!(a;internal_worker=mode=="version")
        result["fixture"]=f
        result["resident_pid"]=getpid()
        if mode=="static"
            configure!(a,rows(f,"old");label="old-static")
            probe(101,"old path","H5","H9")
            probe(102,"new physical gate closed","H6",nothing)
            ident=110
            for host in filter(h->!(h in ("H5","H6")),f["hosts"]),neighbor in f["adjacency"][host]
                ident+=1;probe(ident,"other physical ingress $host/$neighbor",host,nothing;neighbor)
            end
            probe(150,"source prefix mismatch","H5",nothing;sourceip=0x0b000001)
            probe(151,"destination prefix mismatch","H5",nothing;destip=0x0b000001)
            probe(152,"payload authorization is not a gate","H5","H9";payload="monitor-says-authorized-for-H10")
            configure!(a,rows(f,"new");oldopen=false,newopen=true,label="new-static")
            probe(160,"new path","H6","H10")
            probe(161,"old physical gate closed","H5",nothing)
        elseif mode=="queue"
            configure!(a,rows(f,"new");oldopen=false,newopen=false,label="queue-closed")
            slot=Slot();req=Request(301,"H6",frame(301;label="queued-new"),time_ns())
            check(offer!(slot,req)==:PENDING && slotvalid(slot),"initial source offer")
            second=Request(302,"H6",frame(302),time_ns())
            check(offer!(slot,second)==:OUTSIDE_DOMAIN && slot.pending===req,"overflow visible/no overwrite")
            check(rejected(()->offer!(slot,req)),"duplicate rejected")
            check(rejected(()->offer!(Slot(),Request(303,"H5",frame(303),time_ns()))),"wrong physical source rejected")
            calls=Ref(0)
            sender(r)=(calls[]+=1;emit!(a,r.source,r.id,r.hex))
            check(admit!(slot,a.newopen,sender)===nothing && calls[]==0 && slot.pending===req,"closed gate does not emit")
            check(isempty(filter(e->startswith(e["node"],"H"),observe!(a))),"pending request absent from network")
            install!(a,"C2",a.tables["C2"];newopen=true,label="queue-open")
            send=admit!(slot,a.newopen,sender)
            check(calls[]==1 && slot.pending===nothing && slotvalid(slot),"once-only admission/conservation")
            check(slot.original[301]===req && send["before_ns"]>=req.arrival_ns,"original arrival/identity preserved")
            observed=observe!(a);hosts=filter(e->startswith(e["node"],"H"),observed)
            push!(result["cases"],Dict("id"=>301,"label"=>"buffered request delivery","source"=>"H6","expected_host"=>"H10",
                "expected_vlan"=>nothing,"sent_hex"=>req.hex,"send"=>send,"arrival_ns"=>req.arrival_ns,"observed"=>observed))
            check(length(hosts)==1 && hosts[1]["id"]==301 && hosts[1]["node"]=="H10","queued request physically delivered")
            check(admit!(slot,a.newopen,sender)===nothing && calls[]==1,"repeat admit no duplicate")
            check(isempty(filter(e->startswith(e["node"],"H"),observe!(a))),"no overflow/duplicate emission")
            failed=Slot();offer!(failed,Request(304,"H6",frame(304),time_ns()))
            try;admit!(failed,true,_ -> error("expected send failure"));catch;end
            check(failed.disposition[304]==:EMISSION_INCOMPLETE && slotvalid(failed),"send failure visible")
            check(admit!(failed,true,sender)===nothing && calls[]==1,"failed send not retried")
            lost=Slot();offer!(lost,req);lost.pending=nothing
            check(!slotvalid(lost),"pending-loss defect rejected")
            reset=Slot();offer!(reset,req);reset.pending=Request(req.id,req.source,req.hex,req.arrival_ns+1)
            check(!slotvalid(reset),"arrival-reset defect rejected")
            altered=Slot();offer!(altered,req);altered.pending=Request(req.id,req.source,frame(req.id;label="changed"),req.arrival_ns)
            check(!slotvalid(altered),"pending-byte mutation rejected")
            result["queue"]=Dict("arrival_ns"=>req.arrival_ns,"emission_before_ns"=>send["before_ns"],
                "emission_after_ns"=>send["after_ns"],"pending_wait_ns"=>send["before_ns"]-req.arrival_ns,
                "admitted_ids"=>collect(keys(slot.emitted)),"overflow_disposition"=>string(slot.disposition[302]),"emission_calls"=>calls[])
        else
            configure!(a,rows(f,"old");label="old-static")
            before=length(a.evidence["snapshots"])
            check(rejected(()->commit!(a)) && rejected(()->clean!(a)) && length(a.evidence["snapshots"])==before,"premature commit/cleanup rejected before work")
            check(stage!(a;allowance=0)==:RESOURCE_BLOCKED && length(a.evidence["snapshots"])==before,"capacity refusal before work")
            check(stage!(a;allowance=1)==:STAGED,"version staging")
            check(rejected(()->stage!(a)) && rejected(()->clean!(a)),"restaging and precommit cleanup rejected")
            peak=Dict(s=>max(0,length(a.tables[s])-max(count(r->r[1]==s,f["old_rows"]),count(r->r[1]==s,f["new_rows"]))) for s in f["switches"])
            check(maximum(values(peak))==1,"one extra logical row peak")
            result["staged_extra_forwarding_rows"]=peak
            probe(401,"old endpoint cannot choose new tag","H5","H9";vlan=101)
            probe(402,"new source closed before commit","H6",nothing)
            probe(403,"synthetic old internal version before commit","C10","H9";neighbor="C4")
            probe(404,"synthetic staged new internal version","C10","H10";neighbor="C4",vlan=101,expected_vlan=101)
            pending=Slot();request=Request(405,"H6",frame(405;label="pending-through-version-commit"),time_ns())
            offer!(pending,request);sent=Ref(0)
            pending_sender(r)=(sent[]+=1;emit!(a,r.source,r.id,r.hex))
            check(admit!(pending,a.newopen,pending_sender)===nothing && sent[]==0,"staged request remains pre-admission")
            check(isempty(filter(e->startswith(e["node"],"H"),observe!(a))),"staged pending absent on wire")
            tables=deepcopy(a.tables);commit!(a)
            check(a.tables==tables && !a.oldopen && a.newopen && a.newtag==1,"commit is local gates/tag only")
            check(rejected(()->commit!(a)),"repeated commit rejected")
            admission=admit!(pending,a.newopen,pending_sender);delivery=observe!(a)
            hostdelivery=filter(e->startswith(e["node"],"H"),delivery)
            check(sent[]==1 && slotvalid(pending) && pending.original[405]===request,"versioned pending request conserved")
            check(length(hostdelivery)==1 && hostdelivery[1]["id"]==405 && hostdelivery[1]["node"]=="H10" && hostdelivery[1]["vlan"]==101,"pending gets actual committed version")
            push!(result["cases"],Dict("id"=>405,"label"=>"pending through version commit","source"=>"H6","expected_host"=>"H10","expected_vlan"=>101,"sent_hex"=>request.hex,"send"=>admission,"arrival_ns"=>request.arrival_ns,"observed"=>delivery))
            check(admit!(pending,a.newopen,pending_sender)===nothing && sent[]==1,"version commit cannot duplicate request")
            probe(410,"new endpoint gets assigned new version","H6","H10";vlan=100,expected_vlan=101)
            probe(411,"old endpoint closed after commit","H5",nothing)
            probe(412,"synthetic old internal version survives commit","C10","H9";neighbor="C4")
            probe(413,"invalid internal version drops","C10",nothing;neighbor="C4",vlan=102)
            clean!(a)
            check(all(all(r[4]==1 for r in rs) for rs in values(a.tables)),"old logical rows removed")
            check(rejected(()->clean!(a)),"repeated cleanup rejected")
            probe(420,"synthetic old version drops after cleanup","C10",nothing;neighbor="C4")
            probe(421,"new version survives cleanup","C10","H10";neighbor="C4",vlan=101,expected_vlan=101)
            probe(422,"new source remains usable","H6","H10";expected_vlan=101)
        end
        check(pyconvert(Int,pyimport("os").getpid())==getpid()==result["resident_pid"],"resident Julia and embedded Python")
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
        write(joinpath(RUN,"adapter_validation.json"),JSON.json(result)*"\n")
    end
    check(result["status"]=="PASS","final cleanup/source acceptance")
    println("CISCO ADAPTER VALIDATION PASS ",mode)
end
main()
