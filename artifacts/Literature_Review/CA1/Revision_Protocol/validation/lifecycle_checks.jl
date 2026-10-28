# Independent expectations use raw oracle rows/packets, never lifecycle helpers.
const LIFECYCLE_CHECKS=Ref(0)
function lifecycle_agree(a,b,label)
    LIFECYCLE_CHECKS[]+=1
    if a!=b
        open(joinpath(outdir,"lifecycle_failure.toml"),"w") do io
            TOML.print(io,Dict("label"=>label,"expected"=>repr(a),"observed"=>repr(b)))
        end
        error("LIFECYCLE MISMATCH: "*label)
    end
end
function compare_joint(f,d,os,ds,p,q,T,label)
    ov=initial(f);dv=Handover.initial(d)
    ofront=Set([(p,q)]);dfront=Set([(encoded(p,d),encoded(q,d))]);visits=1;edges=0
    for r in 1:T
        oa=get(os,r,Tuple{Symbol,String}[]);da=get(ds,r,Handover.Command[])
        views,nextov=round_views(ov,oa,f)
        oe=Set((pair,(x,y)) for pair in ofront for (i,j) in nested_views(length(oa))
            for x in service(pair[1],views[i+1],f,r) for y in service(pair[2],views[j+1],f,r))
        de=Set{eltype(oe)}();nextdf=empty(dfront);nextdv=Handover.finish(dv,da,d)
        for pair in dfront
            zs,final=Lifecycle.joint_successors(pair,dv,da,d,r)
            lifecycle_agree(concrete(nextdv,d),concrete(final,d),"$label joint final table round $r")
            for z in zs
                push!(de,((decoded(pair[1],d),decoded(pair[2],d)),(decoded(z[1],d),decoded(z[2],d))))
                push!(nextdf,z)
            end
        end
        lifecycle_agree(oe,de,"$label joint packet-edge set round $r")
        ofront=Set(last(e) for e in oe);dfront=nextdf
        lifecycle_agree(ofront,Set((decoded(a,d),decoded(b,d)) for (a,b) in dfront),"$label joint boundary round $r")
        lifecycle_agree(concrete(nextov),concrete(nextdv,d),"$label acknowledged joint table round $r")
        edges+=length(oe);visits+=length(ofront);ov=nextov;dv=nextdv
    end
    (pairs=ofront,view=ov,adapterview=dv,states=visits,edges=edges)
end

lifecycle_reports=Dict{String,Any}[]
for (kind,declared) in zip(["cisco","fat4"],input["fixtures"])
    before=LIFECYCLE_CHECKS[];f=raw_fixture(kind,generator,detector);d=Handover.Domain(declared)
    C=declared["common_controller_bound"];T=declared["common_observation_horizon"]
    cases=0;visits=0;edges=0
    for policy in [:Q,:V]
        os=plan(f,policy);ds=Handover.plan(d,policy);opening=policy==:Q ? f.H+3 : 2
        oldprobes=[inflight(f,i) for i in 1:length(f.old)-3]
        append!(oldprobes,[request(f,0,a) for a in 0:3])
        for (index,p) in enumerate(oldprobes),arrival in unique([0,opening-1,opening,C])
            q=request(f,1,arrival)
            result=compare_joint(f,d,os,ds,p,q,T,"$kind $policy old $index new $arrival")
            cases+=1;visits+=result.states;edges+=result.edges
            lifecycle_agree(true,Handover.target(result.adapterview,d,policy),"$kind $policy joint exact target")
            for index in 1:2
                projection=Set(pair[index] for pair in result.pairs)
                lifecycle_agree(true,qualified((complete=true,controller_settled=true,packets=projection,view=result.view),f,policy),
                    "$kind $policy joint packet obligations")
            end
        end
        # Explicit one-slot lifecycle: no overwrite, no lost/reset arrival and no silent second admission.
        slot=Lifecycle.SourceSlot();p=request(f,1,0);numeric=encoded(p,d)
        lifecycle_agree(:pending,Lifecycle.offer!(slot,1,numeric,d),"$kind $policy source offer")
        lifecycle_agree(:outside_domain,Lifecycle.offer!(slot,2,encoded(request(f,1,1),d),d),"$kind $policy overflow explicit")
        lifecycle_agree(p,decoded(slot.pending.packet,d),"$kind $policy overflow preserves first request")
        for r in 1:opening-1
            q=Lifecycle.admit!(slot,Handover.initial(d),d,r)
            lifecycle_agree(p,decoded(q,d),"$kind $policy closed source retains arrival at round $r")
            lifecycle_agree(true,Lifecycle.slot_valid(slot),"$kind $policy source conservation")
        end
        lost=deepcopy(slot);lost.pending=nothing
        lifecycle_agree(false,Lifecycle.slot_valid(lost),"$kind $policy lost pending request detected")
        reset=deepcopy(slot);reset.pending=Lifecycle.Pending(1,encoded(merge(p,(arrival=opening,)),d))
        lifecycle_agree(false,Lifecycle.slot_valid(reset),"$kind $policy reset pending arrival detected")
        forged=merge(p,(epoch=0,));gates=Handover.finish(Handover.initial(d),reduce(vcat,[ds[r] for r in sort!(collect(keys(ds)))]),d)
        exact=initial(f)
        for r in sort!(collect(keys(os))),a in os[r];exact=apply_batch(exact,a,f);end
        result=Lifecycle.admit!(slot,gates,d,opening)
        lifecycle_agree(Set(service(p,exact,f,opening)),Set([decoded(result,d)]),"$kind $policy independent source admission transition")
        lifecycle_agree(true,Lifecycle.slot_valid(slot),"$kind $policy admitted identity and arrival conserved")
        lifecycle_agree(nothing,Lifecycle.admit!(slot,gates,d,opening+1),"$kind $policy no duplicate admission")
        lifecycle_agree([2],slot.outside_domain,"$kind $policy second request remains outside service claim")
        # A hidden intended-destination/authorization filter would withhold this physically identical request.
        physical=Handover.serve(encoded(forged,d),gates,d,opening)
        expected=only(service(forged,exact,f,opening))
        lifecycle_agree(expected,decoded(physical,d),"$kind $policy gate ignores monitor-only destination epoch")
        mutant=forged.epoch==1 ? expected : forged
        lifecycle_agree(false,mutant==decoded(physical,d),"$kind $policy destination-aware withholding defect distinguished")
        lifecycle_agree(true,rejects(()->Lifecycle.offer!(slot,1,numeric,d)),"$kind $policy duplicate request ID rejected")
        lifecycle_agree(true,rejects(()->Lifecycle.offer!(Lifecycle.SourceSlot(),3,encoded(request(f,0,0),d),d)),
            "$kind $policy wrong physical source rejected")
        # Complete history lifecycle over the actual plan, including a removal at the opening boundary.
        history=Lifecycle.RemovedHistory();ov=initial(f);dv=Handover.initial(d)
        expectedhistory=Dict{Tuple{String,String,String},Int}()
        last_round=maximum(keys(os))+f.H+1
        for r in 1:last_round
            # Expected expiry is computed directly from the independent specification.
            filter!(pair->r<=pair.second+f.H,expectedhistory)
            Lifecycle.expire!(history,r,d.H)
            beforetable=ov;beforecandidate=dv
            for action in get(os,r,Tuple{Symbol,String}[]);ov=apply_batch(ov,action,f);end
            dv=Handover.finish(dv,get(ds,r,Handover.Command[]),d)
            oldrows=Set((s,i,z) for ((s,i,t),z) in beforetable.rows if t==0)
            nowrows=Set((s,i,z) for ((s,i,t),z) in ov.rows if t==0)
            for edge in setdiff(oldrows,nowrows);expectedhistory[edge]=r;end
            Lifecycle.acknowledge!(history,beforecandidate,dv,r)
            observed=Dict((d.names[s],d.names[i],d.names[z])=>removed for ((s,i,z),removed) in history.removed)
            lifecycle_agree(expectedhistory,observed,"$kind $policy removed-edge lifecycle round $r")
            for (edge,removed) in observed
                # A one-round-early mutation must differ at the last legal retained boundary.
                if r==removed+f.H
                    mutant=filter(pair->r<pair.second+f.H,observed)
                    lifecycle_agree(false,mutant==expectedhistory,"$kind $policy premature history expiry distinguished")
                end
            end
        end
        lifecycle_agree(true,isempty(history.removed),"$kind $policy history fully expired")
    end
    ordinary=Dict(1=>[(:replace,s) for s in f.changed])
    numeric=Dict(1=>[Handover.Command(:replace,d.ids[s]) for s in f.changed])
    bad=compare_joint(f,d,ordinary,numeric,inflight(f,Int(declared["ordinary_negative"]["initial_age"])),request(f,1,0),f.H+1,
        "$kind ordinary joint negative")
    lifecycle_agree(true,any(pair->pair[1].status==:wrong_delivery,bad.pairs),"$kind independent joint ordinary witness")
    push!(lifecycle_reports,Dict("fixture"=>kind,"checks"=>LIFECYCLE_CHECKS[]-before,
        "joint_cases"=>cases,"joint_state_visits"=>visits,"joint_packet_edges"=>edges,
        "source_slot_and_history_controls_passed"=>true))
    println("LIFECYCLE_FIXTURE ",kind," checks=",LIFECYCLE_CHECKS[]-before," joint_cases=",cases," states=",visits," edges=",edges)
end
Dict("status"=>"PASS","checks"=>LIFECYCLE_CHECKS[],"fixtures"=>lifecycle_reports,
    "scope"=>"targeted Q/V joint engine correspondence and explicit source-slot/removed-edge component validation",
    "all_method_gate_D_complete"=>false,"general_controller_and_CCG_scheduler_validated"=>false,
    "reference_replay_validated"=>false)
