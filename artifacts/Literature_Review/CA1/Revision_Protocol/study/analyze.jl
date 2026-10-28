function analyze(manifest,catalogue,fixtures;sensitivity_only=false)
    jobs=Any[]
    for dir in readdir(joinpath(HERE,"runs");join=true)
        isfile(joinpath(dir,"result.toml")) || continue
        meta=TOML.parsefile(joinpath(dir,"job.toml"))
        meta["mode"]=="analyze" && continue
        readchomp(joinpath(dir,"exit_code"))=="0" || error("failed study job retained: "*dir)
        data=TOML.parsefile(joinpath(dir,"result.toml"))["data"]
        data["status"]=="PASS" || error("partial study output: "*dir)
        push!(jobs,(;dir,meta,data))
    end
    sensitivity=filter(j->j.data["mode"]=="sensitivity",jobs)
    primary=filter(j->j.data["mode"]=="primary",jobs)
    benchmarks=filter(j->j.data["mode"]=="benchmark",jobs)
    length(sensitivity)==18 && (sensitivity_only || (length(primary)==12 && length(benchmarks)==48)) || error("study job coverage incomplete")
    all(j->sort([r["seed"] for r in j.data["rows"]])==manifest["sensitivity_seeds"],sensitivity) || error("sensitivity seed coverage")
    rows=Dict{String,Any}[]
    for job in sensitivity,row in job.data["rows"]
        push!(rows,merge(row,Dict("implementation"=>job.data["implementation"])))
    end
    comparisons=Dict{String,Any}[]
    for kind in ("cisco","fat4"),config in ("k3","k20","k3_adjacent")
        d=Handover.Domain(fixtures[kind=="cisco" ? 1 : 2])
        g=kind=="cisco" ? SourceDetector.cisco() : SourceDetector.fattree();sc=SourceDetector.scenario(g,kind)
        reference=filter(r->r["fixture"]==kind && r["configuration"]==config && r["implementation"]=="python_numpy",rows)
        length(reference)==32 || error("reference sensitivity coverage")
        refproof=Dict{Int,Any}()
        for row in reference
            caches=Dict(s=>Set(String.(ns)) for (s,ns) in row["cache"])
            work=Controllers.freshwork();actual=Controllers.detector(sc,caches;work)
            length(actual.events)==row["alarms"] && work["detector_pairs"]==row["pair_checks"] || error("new native reference detector replay mismatch")
            refproof[row["seed"]]=Dict(string(policy,"_",extra)=>Study.row(d,sc,policy,extra,caches,catalogue,kind)
                for extra in (0,1) for policy in (:detector,:guarded_detector))
        end
        for implementation in ("julia_weighted","julia_neighbors")
            candidate=filter(r->r["fixture"]==kind && r["configuration"]==config && r["implementation"]==implementation,rows)
            length(candidate)==32 || error("Julia sensitivity coverage")
            changed_caches=changed_alerts=changed_qualification=changed_unsafe_release=0
            for row in candidate
                ref=only(filter(r->r["seed"]==row["seed"],reference))
                changed_caches+=row["cache_sha256"]!=ref["cache_sha256"]
                changed_alerts+=row["alert"]!=ref["alert"]
                changed_qualification+=row["qualification"]["detector_1"]["qualified"]!=refproof[row["seed"]]["detector_1"]["qualified"]
                changed_unsafe_release+=(row["qualification"]["detector_1"]["independent_verdict"]=="FAIL") !=
                    (refproof[row["seed"]]["detector_1"]["independent_verdict"]=="FAIL")
            end
            push!(comparisons,Dict("fixture"=>kind,"configuration"=>config,"implementation"=>implementation,
                "seed_labels"=>32,"cache_membership_differences"=>changed_caches,"alert_decision_differences"=>changed_alerts,
                "qualification_differences_extra1"=>changed_qualification,"unsafe_release_outcome_differences"=>changed_unsafe_release,
                "reference_alerts"=>count(r->r["alert"],reference),"candidate_alerts"=>count(r->r["alert"],candidate)))
        end
    end
    open(joinpath(HERE,"Sensitivity_Results.toml"),"w") do io;TOML.print(io,Dict("comparisons"=>comparisons,"descriptive_only"=>true));end
    if sensitivity_only
        return Dict("status"=>"PASS","sensitivity_trials"=>length(rows),"comparisons"=>comparisons,
            "new_native_reference_detector_parity_passed"=>true,"population_equivalence_claim"=>false)
    end
    benchmark_summary=Dict{String,Any}[]
    for condition in 0:3,implementation in ("python_numpy","julia"),measurement in ("cold","warm")
        selected=filter(j->j.data["condition"]==condition && j.data["implementation"]==implementation && j.data["measurement"]==measurement,benchmarks)
        length(selected)==(measurement=="cold" ? 5 : 1) || error("benchmark repetition coverage")
        samples=vcat([Float64.(j.data["elapsed_seconds"]) for j in selected]...)
        length(samples)==(measurement=="cold" ? 5 : 20) || error("benchmark samples")
        process=[j.meta["supervised_elapsed_nanoseconds"]/1e9 for j in selected]
        peaks=[j.data["resources"]["memory_peak_at_checkpoint_bytes"] for j in selected]
        push!(benchmark_summary,Dict("condition"=>condition,"implementation"=>implementation,"measurement"=>measurement,
            "samples"=>length(samples),"inner_search_median_seconds"=>median(samples),
            "inner_search_IQR_seconds"=>quantile(samples,.75)-quantile(samples,.25),
            "inner_search_min_seconds"=>minimum(samples),"inner_search_max_seconds"=>maximum(samples),
            "supervised_process_median_seconds"=>median(process),"job_peak_checkpoint_median_bytes"=>median(peaks)))
    end
    open(joinpath(HERE,"Benchmark_Results.toml"),"w") do io;TOML.print(io,Dict("conditions"=>benchmark_summary,"pure_language_speedup_claim"=>false));end
    sort!(primary;by=j->j.data["index"])
    [j.data["index"] for j in primary]==collect(0:11) || error("primary cell identity")
    sum(length(j.data["rows"]) for j in primary)==92 || error("primary method-row coverage")
    csvquote(x)="\""*replace(string(x),"\""=>"\"\"")*"\""
    open(joinpath(HERE,"Primary_Results.csv"),"w") do io
        println(io,"cell,fixture,extra_rows,configuration,method,seed,branch,qualified,independent_verdict,batches,row_insertions,row_removals,peak_extra_rows,opening_round,completion_round,decision_seconds")
        for job in primary,row in job.data["rows"]
            cell=job.data["cell"];cost=row["control_costs"]
            values=[job.data["index"],cell["fixture"],cell["extra_rows"],cell["configuration"],row["method"],get(row,"seed","seed-independent"),row["branch"],row["qualified"],row["independent_verdict"],cost["switch_batches"],cost["row_insertions"],cost["row_removals"],cost["peak_extra_rows"],cost["new_opening_ack_round"],cost["completion_round"],row["decision_seconds"]]
            println(io,join(csvquote.(values),","))
        end
    end
    open(joinpath(HERE,"Results.md"),"w") do io
        println(io,"# Revised bounded study results\n\nAll declared jobs completed; no population equivalence or pure-language speedup is established. Two network fixtures, not 92 independent workloads.\n")
        println(io,"## Native sensitivity\n\n| Fixture | Cache | Julia implementation | Cache membership differences /32 | Alert differences /32 | Qualification differences at extra=1 /32 |\n|---|---|---|---:|---:|---:|")
        for r in comparisons
            println(io,"| ",r["fixture"]," | ",r["configuration"]," | ",r["implementation"]," | ",r["cache_membership_differences"]," | ",r["alert_decision_differences"]," | ",r["qualification_differences_extra1"]," |")
        end
        println(io,"\nDifferences compare identical seed labels, not common random numbers. Any qualification/unsafe-release difference is case-material. Absence of such a difference is bounded observation only. Conditions on the same graph/seed are correlated.\n")
        println(io,"## Primary qualification\n\n| Cell | Fixture | Extra rows | Cache | Q | V | CCG-inspired | Guard-only | Detector qualified /3 | Guarded detector qualified /3 |\n|---:|---|---:|---|---|---|---|---|---:|---:|")
        for job in primary
            cell=job.data["cell"];controls=primary[cell["control_cell_index"]+1].data["rows"]
            control(method)=only(filter(r->r["method"]==method && get(r,"seed_independent",false),controls))["independent_verdict"]
            qualify(method)=count(r->r["method"]==method && r["qualified"],job.data["rows"])
            println(io,"| ",job.data["index"]," | ",cell["fixture"]," | ",cell["extra_rows"]," | ",cell["configuration"]," | ",control("Q")," | ",control("V")," | ",control("CCG")," | ",control("guard")," | ",qualify("detector")," | ",qualify("guarded_detector")," |")
        end
        println(io,"\nOrdinary is an independently witnessed failure on both fixtures. Seed-independent controls are referenced once per fixture/row allowance. Proof reuse requires the exact validated plan and unchanged sources; it is not new packet-coverage evidence per seed. Detailed costs are in Primary_Results.csv and per-job TOML.\n")
        println(io,"## Matched full snapshot search\n\n| Condition | Implementation | Process state | Inner search median (s) | IQR (s) | Supervised process median (s) |\n|---:|---|---|---:|---:|---:|")
        for r in benchmark_summary
            println(io,"| ",r["condition"]," | ",r["implementation"]," | ",r["measurement"]," | ",r["inner_search_median_seconds"]," | ",r["inner_search_IQR_seconds"]," | ",r["supervised_process_median_seconds"]," |")
        end
        println(io,"\nConditions are Cisco k3/k20 then fat-tree k3/k20. Warm process totals include warm-up and all 20 calls; they are not per-call latency. Cold means new process, not cold OS caches. Timings include implementation/representation/predicate/dependency differences, not an isolated language effect. Memory is job checkpoint peak including setup. No Python temporal-controller baseline is claimed. See Protocol.md and raw jobs for all measurement boundaries.\n")
    end
    Dict("status"=>"PASS","sensitivity_trials"=>length(rows),"primary_cells"=>12,"primary_rows"=>92,
        "benchmark_jobs"=>48,"population_equivalence_claim"=>false,"pure_language_speedup_claim"=>false)
end
