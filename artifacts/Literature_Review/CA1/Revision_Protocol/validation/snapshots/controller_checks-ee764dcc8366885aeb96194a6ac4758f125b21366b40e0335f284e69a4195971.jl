include(joinpath(@__DIR__,"comparison_map.jl"))
const CCHECKS=Ref(0)
function same(a,b,label)
    CCHECKS[]+=1
    if a!=b
        open(joinpath(outdir,"controller_failure.toml"),"w") do io
            TOML.print(io,Dict("label"=>label,"expected"=>repr(a),"observed"=>repr(b)))
        end
        error("CONTROLLER MISMATCH: "*label)
    end
end
const C=Controllers
kind=split(mode,'-')[2]
declared=input["fixtures"][kind=="cisco" ? 1 : 2]
f=raw_fixture(kind,generator,detector);d=Handover.Domain(declared)
g=kind=="cisco" ? SourceDetector.cisco() : SourceDetector.fattree()
sc=SourceDetector.scenario(g,kind)
settings=TOML.parsefile(joinpath(HERE,"Controller_Inputs.toml"))
tracepath=joinpath(ROOT,settings["reference_trace"])
same(settings["reference_trace_sha256"],bytes2hex(sha256(read(tracepath))),"frozen executed-reference caches")
trace=TOML.parsefile(tracepath)["trace"]

function independent_validate(plan,extra,label)
    os=Dict(r=>[(c.kind,d.names[c.switch]) for c in commands] for (r,commands) in plan.schedule)
    if plan.status==:RESOURCE_BLOCKED
        same(true,isempty(os),"$label refuses before network actions")
        same(0,extra,"$label version staging refuses insufficient extra rows")
        return Dict("verdict"=>"RESOURCE_BLOCKED","coverage_complete"=>false,"probes"=>0,"peak_extra_rows"=>0)
    end
    same(:COMPLETE,plan.status,"$label supported controller completes")
    # Independent structural action/rank checks, not a controller completion flag.
    completion_round=0;used=Set{Tuple{Symbol,String}}();gates=0
    for r in sort!(collect(keys(os)))
        same(true,1<=r && r-completion_round<=f.H+1,"$label progress interval")
        same(length(os[r]),length(Set(s for (_,s) in os[r])),"$label local independent batches")
        for (action,s) in os[r]
            slot=(action==:replace_activate ? :replace : action,s)
            same(false,slot in used,"$label no repeated action slots")
            push!(used,slot)
            if action in (:close,:open,:commit,:replace_activate)
                gates+=1;same(f.old[2],s,"$label physical ingress gate")
            end
        end
        completion_round=r
    end
    same(true,gates<=2 && completion_round<=declared["common_controller_bound"],"$label common controller envelope")
    probes=[inflight(f,i) for i in 1:length(f.old)-3]
    append!(probes,[request(f,0,a) for a in 0:3])
    append!(probes,[request(f,1,a) for a in 0:declared["common_controller_bound"]])
    numeric,_,T=C.probes(d)
    same(encoded.(probes,Ref(d)),numeric,"$label complete raw-derived representative domain")
    peak=0;covered=0;completeold=true;allpass=true;witness=""
    for original in probes
        ov=initial(f);front=Set([original])
        function observe(r,before,commands,edges,after,states)
            same(concrete(ov),concrete(before,d),"$label start table round $r")
            views,nextov=round_views(ov,get(os,r,Tuple{Symbol,String}[]),f)
            expected=Set((p,z) for p in front for view in views for z in service(p,view,f,r))
            observed=Set((decoded(a,d),decoded(b,d)) for (a,b) in edges)
            same(expected,observed,"$label complete packet transitions round $r")
            next=Set(last(e) for e in expected)
            same(next,Set(decoded(p,d) for (p,_) in states),"$label complete packet boundaries round $r")
            same(concrete(nextov),concrete(after,d),"$label acknowledged rule/gate frame round $r")
            for (_,slot) in states
                newrequest=original.status==:waiting && original.node==f.new[2] && original.incoming==first(f.new)
                same(newrequest && r>original.arrival,slot!==nothing,"$label buffer allocated at request arrival, not before")
                if slot!==nothing
                    same(true,Lifecycle.slot_valid(slot),"$label integrated source-slot conservation")
                    same(encoded(original,d),slot.originals[1],"$label source identity/arrival retained")
                    same(true,isempty(slot.outside_domain),"$label no hidden overflow service")
                end
            end
            for view in views,s in f.switches
                baseline=max(count(x->x[1]==s,f.ro),count(x->x[1]==s,f.rn))
                peak=max(peak,count(k->k[1]==s,keys(view.rows))-baseline)
            end
            if r==completion_round
                completeold &= !any(p->p.epoch==0 && p.status==:live,next)
            end
            ov=nextov;front=next
        end
        result=C.runprobe(d,plan.schedule,encoded(original,d);horizon=T,cap=settings["max_states"],observe)
        covered+=1
        same(true,result.complete,"$label no truncated safe claim")
        verdict=qualified((complete=true,controller_settled=true,packets=front,view=ov),f,plan.encoding)
        same(verdict,Handover.target(result.tables,d,plan.encoding) && all(p->
            (p.status==:delivered && p.age<=d.H) || (p.status==:rejected && p.epoch==0 && p.admitted==-999 && p.arrival>=0),result.packets),
            "$label numeric/oracle final qualification")
        allpass &= verdict
        if !verdict || !completeold
            witness=repr(original)*" => "*repr(collect(front));break
        end
    end
    same(true,peak<=extra,"$label actual row capacity")
    if !isempty(plan.history)
        history=Dict{Tuple{String,String,String},Int}();view=initial(f)
        for action in get(os,1,Tuple{Symbol,String}[]);view=apply_batch(view,action,f);end
        for audit in plan.history
            r=audit.round
            filter!(pair->r<=pair.second+f.H,history)
            observed=Dict((d.names[s],d.names[i],d.names[z])=>at for ((s,i,z),at) in audit.removed)
            same(history,observed,"$label scheduler history used at opening $r")
            before=view
            for action in get(os,r,Tuple{Symbol,String}[]);view=apply_batch(view,action,f);end
            old=Set((s,i,z) for ((s,i,t),z) in before.rows if t==0)
            new=Set((s,i,z) for ((s,i,t),z) in view.rows if t==0)
            for edge in setdiff(old,new);history[edge]=r;end
        end
    end
    Dict("verdict"=>allpass && completeold ? "PASS" : "FAIL","coverage_complete"=>covered==length(probes),
        "probes"=>covered,"total_probe_domain"=>length(probes),"peak_extra_rows"=>peak,
        "old_drained_at_claimed_completion"=>completeold,"witness"=>witness,
        "completion_round"=>completion_round)
end

# Reuse identical, fully normalized plan evidence instead of fabricating repeated workloads.
validated=Dict{Any,Any}();rows=Dict{String,Any}[]
function record(policy,extra,condition,caches)
    plan=C.build(d,policy,extra;sc,caches)
    key=(extra,plan.status,plan.encoding,!isempty(plan.history),Tuple((r,Tuple((a.kind,a.switch) for a in plan.schedule[r])) for r in sort!(collect(keys(plan.schedule)))))
    result=get!(validated,key) do
        independent_validate(plan,extra,"$kind $policy $condition rows=$extra")
    end
    push!(rows,Dict("method"=>string(policy),"extra_rows"=>extra,"cache_condition"=>condition,
        "plan_status"=>string(plan.status),"branch"=>plan.branch,"independent"=>result,"work"=>copy(plan.work)))
    result,plan
end
for extra in settings["extra_rows"],policy in (:ordinary,:Q,:V,:CCG,:guard)
    verdict,selected_plan=record(policy,extra,"seed_independent",nothing)
    expected=policy==:ordinary ? "FAIL" : extra==0 && policy in (:V,:guard) ? "RESOURCE_BLOCKED" : "PASS"
    same(expected,verdict["verdict"],"$kind $policy declared independent control")
end
for case in trace["cases"]
    case["fixture"]==kind && !case["noop"] || continue
    caches=Dict(q["source"]=>Set(String.(q["cache_order"])) for q in case["queries"])
    work=C.freshwork();result=C.detector(sc,caches;work)
    same(case["states_checked"],work["detector_pairs"],"$kind full detector pair-count parity")
    expected=[(sum(1<<(findfirst(==(s),sc.updated)-1) for s in m["subset"]),m["source"],m["destination"])
        for m in case["packet_matches"] if m["matches"]]
    same(expected,result.events,"$kind full detector alarm/witness order parity")
    for extra in settings["extra_rows"],policy in (:detector,:guarded_detector)
        record(policy,extra,"captured_k$(case["k"])",caches)
    end
end
for (condition,caches) in [("empty_branch_control",Dict(s=>Set{String}() for s in sc.switches)),
    ("all_hosts_branch_control",Dict(s=>Set(sc.hosts) for s in sc.switches))]
    for extra in settings["extra_rows"],policy in (:detector,:guarded_detector)
        result,selected_plan=record(policy,extra,condition,caches)
        expected=condition=="empty_branch_control" && policy==:detector ? "FAIL" : extra==0 ? "RESOURCE_BLOCKED" : "PASS"
        same(expected,result["verdict"],"$kind $policy $condition branch correctness")
    end
end
# Explicit progress-blocked and incomplete-guard controls never manufacture PASS.
broken=deepcopy(d);broken.newtable[d.new[end-1],d.new[end-2],1]=0
same(:PROGRESS_BLOCKED,C.scheduled(broken).status,"lost target row produces explicit bounded blocked outcome")
emptycache=Dict(s=>Set{String}() for s in sc.switches)
limited=C.build(d,:guarded_detector,1;sc,caches=emptycache,guard_cap=0)
same("guard_incomplete",limited.branch,"incomplete guard selects fallback rather than release")
same(:V,limited.encoding,"incomplete guard fallback is counted V")
println("CONTROLLER PASS ",kind," assertions=",CCHECKS[]," rows=",length(rows)," unique_plans=",length(validated))
Dict("status"=>"PASS","fixture"=>kind,"checks"=>CCHECKS[],"rows"=>rows,"unique_plan_evaluations"=>length(validated),
    "integrated_source_slot_validated"=>true,"scheduler_history_and_progress_validated"=>true,
    "primary_data"=>false,"benchmarks_or_primary_executed"=>false)
