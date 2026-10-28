# Implementation of the predeclared exhaustive-baseline coverage summary on retained caches.
# Post-run derived analysis only: no new random draws, controller tuning or primary attempts.
include("common.jl")
cg,cgdir=scopecheck();sealcheck()
manifest=TOML.parsefile(joinpath(HERE,"Manifest.toml"));verify_manifest(manifest)
include(joinpath(HISTORICAL,"source_fidelity/detector.jl"))
include(joinpath(ROOT,"handover.jl"));include(joinpath(ROOT,"lifecycle.jl"));include(joinpath(ROOT,"controllers.jl"))
bases=Dict{String,Any}();scenarios=Dict{String,Any}()
for kind in ("cisco","fat4")
    g=kind=="cisco" ? SourceDetector.cisco() : SourceDetector.fattree()
    sc=SourceDetector.scenario(g,kind);base=SourceDetector.baseline(sc)
    allhosts=Dict(s=>Set(sc.hosts) for s in g.names if !startswith(s,"H"))
    actual=Controllers.detector(sc,allhosts)
    Set(actual.events)==Set(base.events) || error("exhaustive snapshot engines disagree")
    bases[kind]=base;scenarios[kind]=sc
end
rows=Dict{String,Any}[]
for dir in readdir(joinpath(HERE,"runs");join=true)
    isfile(joinpath(dir,"result.toml")) || continue
    data=TOML.parsefile(joinpath(dir,"result.toml"))["data"]
    data["mode"]=="sensitivity" || continue
    readchomp(joinpath(dir,"exit_code"))=="0" && data["status"]=="PASS" || error("partial sensitivity")
    for row in data["rows"]
        kind=row["fixture"];sc=scenarios[kind];base=bases[kind]
        cache=Dict(s=>Set(String.(ns)) for (s,ns) in row["cache"])
        cov=SourceDetector.coverage(sc,base,cache)
        length(cov.found)==row["alarms"] && cov.pair_checks==row["pair_checks"] || error("offline coverage disagrees with executed detector")
        push!(rows,Dict("fixture"=>kind,"configuration"=>row["configuration"],"implementation"=>data["implementation"],
            "seed"=>row["seed"],"alarms"=>length(cov.found),"exhaustive_alarms"=>length(base.events),
            "full_alarm_coverage"=>length(cov.found)==length(base.events),
            "alarm_keys"=>[string(mask,"|",a,"|",b) for (mask,a,b) in cov.found]))
    end
end
length(rows)==576 || error("coverage trial count")
summary=Dict{String,Any}[]
for kind in ("cisco","fat4"),config in ("k3","k20","k3_adjacent"),implementation in ("python_numpy","julia_weighted","julia_neighbors")
    selected=filter(r->r["fixture"]==kind && r["configuration"]==config && r["implementation"]==implementation,rows)
    sort([r["seed"] for r in selected])==manifest["sensitivity_seeds"] || error("coverage labels")
    alarms=length(bases[kind].events);found=sum(r["alarms"] for r in selected)
    push!(summary,Dict("fixture"=>kind,"configuration"=>config,"implementation"=>implementation,"trials"=>32,
        "exhaustive_alarms_per_trial"=>alarms,"zero_alarm_trials"=>count(r->r["alarms"]==0,selected),
        "full_alarm_coverage_trials"=>count(r->r["full_alarm_coverage"],selected),
        "found_alarm_occurrences"=>found,"exhaustive_alarm_occurrences"=>32*alarms,
        "pooled_fixed_trial_alarm_coverage"=>found/(32*alarms)))
end
verify_manifest(manifest);sealcheck()
report=Dict("status"=>"PASS","analysis"=>"predeclared descriptive coverage, derived after execution",
    "source_sha256"=>hashfile(@__FILE__),"trials"=>rows,"summary"=>summary,
    "baseline"=>"Julia exhaustive full snapshot; event-set equality of two traversals sharing graph/shortest helpers, not independent engines; not temporal packet obligations",
    "new_primary_attempts"=>0,"new_random_draws"=>0)
open(joinpath(HERE,"Coverage_Results.toml"),"w") do io;TOML.print(io,report);end
open(joinpath(HERE,"Coverage_Results.md"),"w") do io
    println(io,"# Exhaustive snapshot-alarm coverage\n\nDerived from the retained fixed sensitivity caches; no new seeds, primary attempts or tuning. The Julia exhaustive snapshot baseline has two Cisco and four fat-tree alarm events; two snapshot traversals agree on its event set (they share graph/shortest-path helpers, so this is not an independent-engine proof). Offline coverage equals every executed Python/Julia alarm and pair-check count. This is not temporal packet safety or a population detection rate.\n")
    println(io,"| Fixture | Cache | Implementation | No alarms /32 | All baseline alarms /32 | Found / exhaustive alarm occurrences |\n|---|---|---|---:|---:|---:|")
    for row in summary
        println(io,"| ",row["fixture"]," | ",row["configuration"]," | ",row["implementation"]," | ",row["zero_alarm_trials"]," | ",row["full_alarm_coverage_trials"]," | ",row["found_alarm_occurrences"]," / ",row["exhaustive_alarm_occurrences"]," |")
    end
    println(io,"\nAlarm occurrences repeat fixed fixture events over seed labels; they are not independent vulnerabilities or networks. The event keys and per-label records are retained in Coverage_Results.toml. This post-run implementation completes the coverage summary declared in Three_Stage_Execution_Plan.md; the original experimental sources and primary grid remain unchanged.\n")
end
println("COVERAGE ANALYSIS PASS trials=",length(rows)," groups=",length(summary))
