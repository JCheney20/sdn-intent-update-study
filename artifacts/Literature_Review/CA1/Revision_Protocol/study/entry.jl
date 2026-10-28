include("common.jl")
cg,cgdir=scopecheck();sealcheck()
length(ARGS)>=3 || error("mode, index and output required")
mode,index,output=ARGS[1],parse(Int,ARGS[2]),abspath(ARGS[3])
manifest=TOML.parsefile(joinpath(HERE,"Manifest.toml"));verify_manifest(manifest)
include(joinpath(HISTORICAL,"source_fidelity/detector.jl"))
include(joinpath(ROOT,"handover.jl"));include(joinpath(ROOT,"lifecycle.jl"));include(joinpath(ROOT,"controllers.jl"))
include("Study.jl")
catalogue=TOML.parsefile(joinpath(HERE,"Catalogue.toml"))["plans"]
fixtures=TOML.parsefile(joinpath(ROOT,"Handover_Bounds.toml"))["fixtures"]
function domain(kind)
    f=fixtures[kind=="cisco" ? 1 : 2]
    g=kind=="cisco" ? SourceDetector.cisco() : SourceDetector.fattree()
    Handover.Domain(f),g,SourceDetector.scenario(g,kind)
end
result=Dict{String,Any}("status"=>"RUNNING","mode"=>mode,"index"=>index,"rows"=>Any[],"primary_data"=>mode=="primary")
try
    if mode in ("sensitivity-weighted","sensitivity-neighbors")
        cell=manifest["sensitivity_cells"][index+1];kind=cell["fixture"];config=cell["configuration"]
        d,g,sc=domain(kind);sampler=mode=="sensitivity-weighted" ? :weighted : :neighbors
        result["mode"]="sensitivity";result["implementation"]=sampler==:weighted ? "julia_weighted" : "julia_neighbors"
        for seed in manifest["sensitivity_seeds"]
            cache,payload=Study.build_cache(g,config,seed;sampler)
            payload["sample_paths_per_query"]==manifest["sample_counts"][kind] || error("sample count drift")
            checkwork=Controllers.freshwork();detected=Controllers.detector(sc,cache;work=checkwork)
            payload["fixture"]=kind;payload["configuration"]=config;payload["alert"]=detected.alert
            payload["alarms"]=length(detected.events);payload["pair_checks"]=checkwork["detector_pairs"]
            payload["qualification"]=Dict(string(policy,"_",extra)=>Study.row(d,sc,policy,extra,cache,catalogue,kind)
                for extra in (0,1) for policy in (:detector,:guarded_detector))
            push!(result["rows"],payload);checkpoint(output,result)
        end
    elseif mode=="primary"
        cell=manifest["primary_cells"][index+1];kind=cell["fixture"];extra=cell["extra_rows"];config=cell["configuration"]
        d,g,sc=domain(kind);result["cell"]=cell;result["caches"]=Any[]
        if cell["include_seed_independent_controls"]
            for policy in (:ordinary,:Q,:V,:CCG,:guard)
                row=Study.row(d,sc,policy,extra,nothing,catalogue,kind);row["seed_independent"]=true
                push!(result["rows"],row);checkpoint(output,result)
            end
        end
        for seed in manifest["primary_seeds"]
            cache,payload=Study.build_cache(g,config,seed;sampler=:weighted);push!(result["caches"],payload)
            for policy in (:detector,:guarded_detector)
                row=Study.row(d,sc,policy,extra,cache,catalogue,kind);row["seed"]=seed;row["seed_independent"]=false
                push!(result["rows"],row);checkpoint(output,result)
            end
        end
        expected=cell["include_seed_independent_controls"] ? 11 : 6
        length(result["rows"])==expected || error("primary row coverage")
    elseif mode in ("cold","warm")
        condition=manifest["benchmark_conditions"][index+1];kind=condition["fixture"];k=condition["k"]
        d,g,sc=domain(kind)
        trace=TOML.parsefile(joinpath(ROOT,manifest["reference_trace"]))["trace"]
        case=only(filter(c->c["fixture"]==kind && c["k"]==k && !c["noop"],trace["cases"]))
        caches=Dict(q["source"]=>Set(String.(q["cache_order"])) for q in case["queries"])
        function measured()
            work=Controllers.freshwork()
            timing=@timed Controllers.detector(sc,caches;work)
            work["detector_pairs"]==case["states_checked"] && length(timing.value.events)==case["violations_found"] || error("benchmark semantic mismatch")
            timing.time,timing.bytes
        end
        mode=="warm" && measured()
        timings=[measured() for _ in 1:(mode=="warm" ? manifest["warm_repetitions"] : 1)]
        result["mode"]="benchmark";result["implementation"]="julia";result["condition"]=index
        result["measurement"]=mode;result["fixture"]=kind;result["k"]=k
        result["elapsed_seconds"]=first.(timings);result["allocated_bytes"]=last.(timings)
        result["states_checked"]=case["states_checked"];result["alarms"]=case["violations_found"]
    elseif mode in ("analyze","sensitivity-review")
        include("analyze.jl")
        result["summary"]=analyze(manifest,catalogue,fixtures;sensitivity_only=mode=="sensitivity-review")
    else
        error("unknown study mode")
    end
    verify_manifest(manifest);sealcheck();result["status"]="PASS"
    println("STUDY PASS ",mode," ",index," rows=",length(result["rows"]))
catch error
    result["status"]="FAIL";result["error"]=sprint(showerror,error,catch_backtrace());rethrow()
finally
    result["resources"]=resources(cg,cgdir);checkpoint(output,result)
end
