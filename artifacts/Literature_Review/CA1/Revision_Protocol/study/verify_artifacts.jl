# Post-run consistency audit, not a new scientific analysis or experiment.
include("common.jl")
cg,cgdir=scopecheck();sealcheck()
manifest=TOML.parsefile(joinpath(HERE,"Manifest.toml"));verify_manifest(manifest)
catalogue=TOML.parsefile(joinpath(HERE,"Catalogue.toml"))["plans"]
trace=TOML.parsefile(joinpath(ROOT,manifest["reference_trace"]))["trace"]
include(joinpath(HISTORICAL,"source_fidelity/detector.jl"))
include(joinpath(ROOT,"handover.jl"));include(joinpath(ROOT,"lifecycle.jl"));include(joinpath(ROOT,"controllers.jl"));include("Study.jl")
checks=Ref(0)
function audit(condition,label)
    checks[]+=1;condition || error("ARTIFACT AUDIT: "*label)
end
jobs=Any[]
for dir in readdir(joinpath(HERE,"runs");join=true)
    isfile(joinpath(dir,"job.toml")) || continue
    meta=TOML.parsefile(joinpath(dir,"job.toml"))
    audit(readchomp(joinpath(dir,"exit_code"))=="0","final exit")
    audit(readchomp(joinpath(dir,"process_exit_code"))=="0","process exit")
    meta["mode"]=="freeze" && continue
    data=TOML.parsefile(joinpath(dir,"result.toml"))["data"]
    audit(data["status"]=="PASS","result status")
    audit(0<meta["supervised_elapsed_nanoseconds"]<=120_000_000_000,"120-second job ceiling")
    resource=data["resources"]
    audit(resource["memory_max_bytes"]==2^31 && resource["swap_max_bytes"]==0,"hard memory/zero swap")
    audit(resource["cpu_max"]=="200000 100000","two-core quota")
    audit(resource["memory_peak_at_checkpoint_bytes"]<=2^31,"checkpoint memory")
    haskey(resource,"affinity") && audit(resource["affinity"]==[0,1],"Python affinity")
    push!(jobs,(;dir,meta,data))
end
sensitivity=filter(j->j.data["mode"]=="sensitivity",jobs)
benchmarks=filter(j->j.data["mode"]=="benchmark",jobs)
primary=filter(j->j.data["mode"]=="primary",jobs)
audit(length(sensitivity)==18 && length(benchmarks)==48 && length(primary)==12,"job coverage")
for job in sensitivity
    audit(sort([r["seed"] for r in job.data["rows"]])==manifest["sensitivity_seeds"],"fixed sensitivity labels")
    for row in job.data["rows"]
        cache=Dict(s=>Set(String.(ns)) for (s,ns) in row["cache"])
        audit(Study.fingerprint(cache)==row["cache_sha256"],"cache fingerprints across implementations")
    end
end
for condition in 0:3,implementation in ("python_numpy","julia"),measurement in ("cold","warm")
    selected=filter(j->j.data["condition"]==condition && j.data["implementation"]==implementation && j.data["measurement"]==measurement,benchmarks)
    audit(length(selected)==(measurement=="cold" ? 5 : 1),"benchmark process count")
    if measurement=="cold"
        audit(sort([j.meta["detail"] for j in selected])==["cold-$i" for i in 1:5],"no duplicate/missing cold repetition")
    end
    descriptor=manifest["benchmark_conditions"][condition+1]
    reference=only(filter(c->c["fixture"]==descriptor["fixture"] && c["k"]==descriptor["k"] && !c["noop"],trace["cases"]))
    for job in selected
        audit(length(job.data["elapsed_seconds"])==(measurement=="cold" ? 1 : 20),"timed sample count")
        audit(all(x->isfinite(x) && x>=0,job.data["elapsed_seconds"]),"finite timings")
        audit(job.data["states_checked"]==reference["states_checked"] && job.data["alarms"]==reference["violations_found"],"matched benchmark semantic output")
    end
end
sort!(primary;by=j->j.data["index"])
audit([j.data["index"] for j in primary]==collect(0:11),"primary identity")
audit(length(readdir(joinpath(HERE,"attempts")))==12,"one attempt receipt per cell")
for job in primary
    cell=manifest["primary_cells"][job.data["index"]+1]
    audit(job.data["cell"]==cell,"canonical cell specification")
    audit(readchomp(joinpath(HERE,"attempts","primary-$(job.data["index"])","run"))==job.dir,"attempt points to actual run")
    audit(length(job.data["rows"])==(cell["include_seed_independent_controls"] ? 11 : 6),"primary rows")
    audit(sort([c["seed"] for c in job.data["caches"]])==manifest["primary_seeds"],"primary cache seed coverage")
    for cache in job.data["caches"]
        audit(Study.fingerprint(Dict(s=>Set(String.(v)) for (s,v) in cache["cache"]))==cache["cache_sha256"],"primary cache fingerprint")
    end
    for row in job.data["rows"]
        key=string(cell["fixture"],"|",cell["extra_rows"],"|",row["plan_fingerprint"])
        audit(haskey(catalogue,key) && row["independent_evidence"]==catalogue[key],"exact independent plan proof")
        audit(row["qualified"]==(catalogue[key]["verdict"]=="PASS" && catalogue[key]["coverage_complete"]),"eligibility before cost")
        audit(row["control_costs"]["peak_extra_rows"]<=cell["extra_rows"],"capacity")
        if row["plan_status"]=="RESOURCE_BLOCKED"
            audit(row["control_costs"]["switch_batches"]==0 && !row["qualified"],"upfront refusal not PASS")
        end
    end
end
audit(sum(length(j.data["rows"]) for j in primary)==92,"92 raw rows, not fabricated repeats")
audit(length(readlines(joinpath(HERE,"Primary_Results.csv")))==93,"CSV row count")
analysis=only(filter(j->j.data["mode"]=="analyze",jobs))
audit(analysis.data["summary"]["primary_rows"]==92 && analysis.data["summary"]["sensitivity_trials"]==576,"analysis coverage")
verify_manifest(manifest);sealcheck()
report=Dict("status"=>"PASS","checks"=>checks[],"source_sha256"=>hashfile(@__FILE__),
    "primary_cells"=>12,"primary_rows"=>92,"sensitivity_trials"=>576,"benchmark_jobs"=>48,
    "historical_sealed_files"=>194,"historical_external_snapshots"=>2,
    "frozen_manifest_sha256"=>hashfile(joinpath(HERE,"Manifest.toml")),
    "scope"=>cg,"memory_peak_at_checkpoint_bytes"=>parse(Int,readchomp(joinpath(cgdir,"memory.peak"))))
open(joinpath(HERE,"Artifact_Verification.toml"),"w") do io;TOML.print(io,report);end
println("ARTIFACT AUDIT PASS checks=",checks[])
