module Study
using Random, SHA, Serialization
using ..Handover, ..Controllers, ..SourceDetector
const H=Handover
const C=Controllers
const SD=SourceDetector

fingerprint(cache)=bytes2hex(sha256(join([s*":"*join(sort!(collect(cache[s])),",")*"\n" for s in sort!(collect(keys(cache)))])))
function pick(probabilities,u)
    0<=u<1 || throw(ArgumentError("uniform outside [0,1)"))
    cdf=cumsum(probabilities);cdf./=cdf[end]
    searchsortedlast(cdf,u)+1
end
function native_cache(g,k,seed;sampler=:weighted)
    sampler in (:weighted,:neighbors) || throw(ArgumentError("unknown sampler"))
    rng=MersenneTwister(seed);n=length(g.names);R=SD.sample_count(g,4)
    cache=Dict{String,Set{String}}();orders=Dict{String,Vector{String}}();counts=Dict{String,Vector{Int}}()
    for (source,name) in enumerate(g.names)
        startswith(name,"H") && continue
        # Original helper also rebuilds the full probability matrix per query.
        probabilities=sampler==:weighted ? zeros(Float64,n,n) : nothing
        for s in 1:n
            isempty(g.out[s]) && throw(ArgumentError("isolated nodes outside reference domain"))
            if sampler==:weighted
                for z in g.out[s];probabilities[s,z]=1/length(g.out[s]);end
            end
        end
        walks=Vector{Int}[]
        for _ in 1:R
            at=rand(rng,1:n);path=[at]
            for _ in 1:4
                at=sampler==:weighted ? pick(view(probabilities,at,:),rand(rng)) : rand(rng,g.out[at])
                push!(path,at)
            end
            push!(walks,path)
        end
        scores=SD.score_walks(walks,source,n);top,_=SD.rank_cache(scores,source,k)
        cache[name]=Set(g.names[top]);orders[name]=g.names[top];counts[name]=scores
    end
    buffer=IOBuffer();serialize(buffer,rng)
    (;cache,orders,counts,R,rng_final_sha256=bytes2hex(sha256(take!(buffer))))
end
function augment(g,cache)
    Dict(s=>union(values,Set(g.names[z] for z in g.out[g.ids[s]] if startswith(g.names[z],"H"))) for (s,values) in cache)
end
function configuration(config)
    config in ("k3","k20","k3_adjacent") || throw(ArgumentError("unknown cache condition"))
    config=="k20" ? 20 : 3,config=="k3_adjacent"
end
function build_cache(g,config,seed;sampler=:weighted)
    k,adjacent=configuration(config)
    timing=@timed native_cache(g,k,seed;sampler)
    augmentation=@timed(adjacent ? augment(g,timing.value.cache) : timing.value.cache)
    cache=augmentation.value
    payload=Dict{String,Any}("seed"=>seed,"sampler"=>string(sampler),"k"=>k,"adjacent_hosts"=>adjacent,
        "sample_paths_per_query"=>timing.value.R,"cache"=>Dict(s=>sort!(collect(v)) for (s,v) in cache),
        "cache_order_before_augmentation"=>timing.value.orders,"cooccurrence_counts"=>timing.value.counts,
        "cache_sha256"=>fingerprint(cache),"rng_final_sha256"=>timing.value.rng_final_sha256,
        "cache_build_seconds"=>timing.time,"cache_build_allocated_bytes"=>timing.bytes,
        "augmentation_seconds"=>augmentation.time,"augmentation_allocated_bytes"=>augmentation.bytes,
        "cache_entries"=>sum(length,values(cache)),"unaugmented_entries"=>sum(length,values(timing.value.cache)),
        "integer_start_API_calls"=>length(cache)*timing.value.R,
        "hop_API_calls"=>length(cache)*timing.value.R*4,
        "API_calls_are_not_raw_entropy_draw_counts"=>true)
    cache,payload
end
function control_costs(d,plan)
    t=H.initial(d);insertions=removals=batches=gates=tags=0;oldclose=opening=0
    switches=findall(.!d.hosts);peak=Dict(s=>count(!=(0),t.rows[s,:,:]) for s in switches)
    function rows(t)
        Set((s,i,tag,z) for s in axes(t.rows,1),i in axes(t.rows,2),tag in 1:2 for z in (t.rows[s,i,tag],) if z!=0)
    end
    for r in sort!(collect(keys(plan.schedule))),action in plan.schedule[r]
        after=H.apply(t,action,d);batches+=1
        insertions+=length(setdiff(rows(after),rows(t)));removals+=length(setdiff(rows(t),rows(after)))
        gates+=(t.oldopen!=after.oldopen)+(t.newopen!=after.newopen);tags+=t.tag!=after.tag
        t.oldopen && !after.oldopen && (oldclose=r)
        !t.newopen && after.newopen && (opening=r)
        for s in switches;peak[s]=max(peak[s],count(!=(0),after.rows[s,:,:]));end
        t=after
    end
    extra=maximum(peak[s]-max(count(!=(0),d.oldtable[s,:,:]),count(!=(0),d.newtable[s,:,:])) for s in switches)
    Dict("switch_batches"=>batches,"row_insertions"=>insertions,"row_removals"=>removals,
        "gate_mutations"=>gates,"tag_mutations"=>tags,"peak_extra_rows"=>extra,
        "peak_rows"=>Dict(d.names[s]=>peak[s] for s in switches),
        "completion_round"=>isempty(plan.schedule) ? 0 : maximum(keys(plan.schedule)),
        "old_closure_ack_round"=>oldclose,"new_opening_ack_round"=>opening,
        "boundary0_pending_wait_bound"=>opening==0 ? -1 : opening+1,
        "boundary0_request_delivery_bound"=>opening==0 ? -1 : opening+1+d.H,
        "request_bounds_are_conservative_not_measured_latency"=>true)
end
function row(d,sc,policy,extra,cache,catalogue,fixture)
    measured=@timed C.build(d,policy,extra;sc,caches=cache)
    plan=measured.value;fingerprint=C.fingerprint(plan,d)
    key=string(fixture,"|",extra,"|",fingerprint)
    haskey(catalogue,key) || error("Unvalidated plan family: "*key)
    proof=catalogue[key]
    qualified=proof["verdict"]=="PASS" && proof["coverage_complete"]
    costs=control_costs(d,plan)
    costs["peak_extra_rows"]<=extra || error("capacity contradiction")
    Dict{String,Any}("method"=>string(policy),"extra_rows"=>extra,"branch"=>plan.branch,
        "plan_status"=>string(plan.status),"plan_fingerprint"=>fingerprint,"qualified"=>qualified,
        "independent_verdict"=>proof["verdict"],"proof_reuse"=>"exact validated plan family with unchanged kernel/fixture",
        "independent_evidence"=>proof,"control_costs"=>costs,"work"=>copy(plan.work),
        "decision_seconds"=>measured.time,"decision_allocated_bytes"=>measured.bytes)
end
end
