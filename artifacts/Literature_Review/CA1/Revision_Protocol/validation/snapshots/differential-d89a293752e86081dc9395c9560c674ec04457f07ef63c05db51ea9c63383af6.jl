# Comparison map only. Neither engine imports this file or calls the other engine.
const DIFFERENTIAL_CHECKS=Ref(0)
function agree(a,b,label)
    DIFFERENTIAL_CHECKS[]+=1
    if a!=b
        open(joinpath(outdir,"differential_failure.toml"),"w") do io
            TOML.print(io,Dict("label"=>label,"oracle"=>repr(a),"adapter"=>repr(b)))
        end
        error("DIFFERENTIAL MISMATCH: "*label)
    end
end
function encoded(p,d)
    Handover.Packet(d.ids[p.node],d.ids[p.incoming],p.tag,p.epoch,p.age,p.status,
        p.arrival,p.admitted,p.ended,p.sourceip,p.destip)
end
function decoded(p,d)
    (node=d.names[p.node],incoming=d.names[p.input],tag=p.tag,epoch=p.epoch,age=p.age,status=p.status,
        arrival=p.arrival,admitted=p.admitted,ended=p.ended,sourceip=p.sourceip,destip=p.destip)
end
function concrete(t,d)
    rows=Dict{Tuple{String,String,Int},String}()
    for tag in 0:1,i in eachindex(d.names),s in eachindex(d.names)
        z=t.rows[s,i,tag+1]
        z==0 || (rows[(d.names[s],d.names[i],tag)]=d.names[z])
    end
    (rows=rows,oldopen=t.oldopen,newopen=t.newopen,newtag=t.tag)
end
concrete(v::View)=(rows=v.rows,oldopen=v.oldopen,newopen=v.newopen,newtag=v.newtag)
function compare_probe(f,d,oschedule,dschedule,probe,T,label;fault=:none)
    ov=initial(f);dv=Handover.initial(d);ofront=Set([probe]);dfront=Set([encoded(probe,d)])
    visits=1;edges=0
    for r in 1:T
        oa=get(oschedule,r,Tuple{Symbol,String}[])
        da=get(dschedule,r,Handover.Command[])
        views,nextov=round_views(ov,oa,f)
        oe=Set((p,z) for p in ofront for v in views for z in service(p,v,f,r))
        de=Set{Tuple{typeof(probe),typeof(probe)}}()
        nextdf=empty(dfront);nextdv=Handover.finish(dv,da,d)
        for p in dfront
            zs,final=Handover.successors(p,dv,da,d,r;fault)
            agree(concrete(nextdv,d),concrete(final,d),"$label final table at round $r")
            for z in zs
                push!(de,(decoded(p,d),decoded(z,d)));push!(nextdf,z)
            end
        end
        agree(oe,de,"$label legal packet edges at round $r")
        ofront=Set(last(e) for e in oe);dfront=nextdf
        agree(ofront,Set(decoded(p,d) for p in dfront),"$label reachable boundary at round $r")
        agree(concrete(nextov),concrete(nextdv,d),"$label acknowledged table/gates at round $r")
        edges+=length(oe);visits+=length(ofront);ov=nextov;dv=nextdv
    end
    (packets=ofront,view=ov,adapterview=dv,states=visits,edges=edges)
end

reports=Dict{String,Any}[]
for (kind,declared) in zip(["cisco","fat4"],input["fixtures"])
    before=DIFFERENTIAL_CHECKS[]
    f=raw_fixture(kind,generator,detector);d=Handover.Domain(declared)
    agree(d.H,f.H,"$kind independently derived packet rank")
    C=declared["common_controller_bound"];T=declared["common_observation_horizon"]
    cases=0;visits=0;edges=0
    for policy in [:Q,:V]
        os=plan(f,policy);ds=Handover.plan(d,policy)
        agree(Set((r,k,s) for (r,acts) in os for (k,s) in acts),
            Set((r,c.kind,d.names[c.switch]) for (r,cs) in ds for c in cs),"$kind $policy independent action schedule")
        agree(true,Handover.validate_plan(d,ds),"$kind $policy action discipline")
        probes=[inflight(f,i) for i in 1:length(f.old)-3]
        append!(probes,[request(f,0,a) for a in 0:3])
        append!(probes,[request(f,1,a) for a in 0:C])
        for (i,p) in enumerate(probes)
            result=compare_probe(f,d,os,ds,p,T,"$kind $policy probe $i")
            cases+=1;visits+=result.states;edges+=result.edges
            agree(true,Handover.target(result.adapterview,d,policy),"$kind $policy adapter exact final target")
            agree(true,qualified((complete=true,controller_settled=true,packets=result.packets,view=result.view),f,policy),
                "$kind $policy independent packet qualification")
        end
        # Progress envelope mutation checks are adapter preconditions, not packet verdicts.
        repeated=deepcopy(ds);first_round=minimum(keys(ds));command=first(ds[first_round])
        repeated[first_round+1]=[command]
        agree(true,rejects(()->Handover.validate_plan(d,repeated)),"$kind repeated action rejected")
        stalled=Dict(d.H+2=>[Handover.Command(:close,d.old[2])])
        agree(true,rejects(()->Handover.validate_plan(d,stalled)),"$kind excessive progress wait rejected")
        nonlocalgate=Dict(1=>[Handover.Command(:close,d.old[3])])
        agree(true,rejects(()->Handover.validate_plan(d,nonlocalgate)),"$kind nonlocal gate rejected")
    end
    # Overlapping unsafe domain: original ordinary schedule, retaining old history.
    ordinary=Dict(1=>[(:replace,s) for s in f.changed])
    numeric=Dict(1=>[Handover.Command(:replace,d.ids[s]) for s in f.changed])
    p=inflight(f,Int(declared["ordinary_negative"]["initial_age"]))
    unsafe=compare_probe(f,d,ordinary,numeric,p,f.H+1,"$kind ordinary negative")
    agree(true,any(p->p.status==:wrong_delivery,unsafe.packets),"$kind independent ordinary negative retained")
    # Seed a defect in the adapter only; compare the actual first faulty transition.
    staged=Handover.finish(Handover.initial(d),Handover.plan(d,:V)[1],d)
    fresh=request(f,1,0)
    tagged=Handover.apply(staged,Handover.Command(:commit,d.old[2]),d)
    correct=Handover.serve(encoded(fresh,d),tagged,d,2)
    defective=Handover.serve(encoded(fresh,d),tagged,d,2;fault=:ignore_tag)
    agree(true,decoded(correct,d)!=decoded(defective,d),"$kind adapter tag fault changes physical transition")
    # Frame comparison must reject the mutant, not merely agree on a final PASS bit.
    ov=initial(f)
    for action in plan(f,:V)[1];ov=apply_batch(ov,action,f);end
    ov=apply_batch(ov,(:commit,f.old[2]),f)
    expected=Set(service(fresh,ov,f,2))
    agree(expected,Set([decoded(correct,d)]),"$kind independent correct commit transition")
    agree(false,expected==Set([decoded(defective,d)]),"$kind independent comparison detects seeded tag fault")
    push!(reports,Dict("fixture"=>kind,"checks"=>DIFFERENTIAL_CHECKS[]-before,"probe_cases"=>cases,
        "boundary_state_visits"=>visits,"packet_transition_edges"=>edges,
        "ordinary_witness_agrees"=>true,"seeded_adapter_tag_fault_detected"=>true))
    println("DIFFERENTIAL_FIXTURE ",kind," checks=",DIFFERENTIAL_CHECKS[]-before," cases=",cases,
        " states=",visits," edges=",edges)
end
Dict("status"=>"PASS","scope"=>"candidate Q/V adapter versus standalone oracle; all single-probe boundary and packet-edge sets on two tiny fixtures",
    "checks"=>DIFFERENTIAL_CHECKS[],"fixtures"=>reports,"candidate_Q_V_transition_agreement"=>true,
    "historical_production_engine_validated"=>false,"all_method_gate_D_complete"=>false,
    "python_reference_replay_validated"=>false)
