include("common.jl")
cg,cgdir=scopecheck();sealcheck()
function clean_ast(node)
    node isa Expr || return
    node.head in (:error,:incomplete) && error("study source parse error: "*repr(node))
    foreach(clean_ast,node.args)
end
for name in ("common.jl","entry.jl","Study.jl","analyze.jl")
    clean_ast(Meta.parseall(read(joinpath(HERE,name),String)))
end
isfile(joinpath(HERE,"Manifest.toml")) && error("study already frozen; do not overwrite after outcomes")
include(joinpath(HISTORICAL,"source_fidelity/detector.jl"))
include(joinpath(ROOT,"handover.jl"));include(joinpath(ROOT,"lifecycle.jl"));include(joinpath(ROOT,"controllers.jl"))
include("Study.jl")
authority=TOML.parsefile(joinpath(ROOT,"validation/Three_Stage_Authorization.toml"))
authority["scientific_gates_must_pass"] && authority["aggregate_runtime_cap"]=="none" && length(authority["stages"])==3 || error("stage authority")
reference="reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml"
replay="reference_capture/runs/cos738-reference-replay-1792957198528826086/replay_receipt.toml"
r=TOML.parsefile(joinpath(ROOT,replay));r["status"]=="PASS" && r["observability_and_replay_passed"] || error("reference gate")
validation=["validation/runs/cos738-revision-1792996081759461393/receipt.toml",
            "validation/runs/cos738-revision-1792996109974263456/receipt.toml"]
plans=Dict{String,Any}()
for file in validation
    receipt=TOML.parsefile(joinpath(ROOT,file));receipt["status"]=="PASS" || error("controller gate")
    for (name,want) in receipt["input_sha256"]
        hashfile(joinpath(ROOT,name))==want || error("controller validation no longer matches: "*name)
    end
    result=receipt["controllers"]
    for row in result["rows"]
        key=string(result["fixture"],"|",row["extra_rows"],"|",row["plan_fingerprint"])
        proof=row["independent"]
        haskey(plans,key) && plans[key]!=proof && error("contradictory plan evidence")
        plans[key]=proof
    end
end
# Small implementation controls, not sensitivity/primary seed outcomes.
@assert Study.pick([0.0,0.5,0.0,0.5],0.0)==2
@assert Study.pick([0.0,0.5,0.0,0.5],0.5)==4
@assert Study.pick([0.0,0.5,0.0,0.5],prevfloat(1.0))==4
for g in (SourceDetector.cisco(),SourceDetector.fattree()),k in (3,20)
    optimized=Study.native_cache(g,k,1;sampler=:neighbors)
    @assert optimized.cache==SourceDetector.caches(g,k,1).published
    weighted=Study.native_cache(g,k,1;sampler=:weighted)
    @assert all(s->s in g.names,vcat(collect.(values(weighted.cache))...))
    @assert all(count->0<=count<=weighted.R,vcat(collect(values(weighted.counts))...))
end
for (kind,fixture) in zip(("cisco","fat4"),TOML.parsefile(joinpath(ROOT,"Handover_Bounds.toml"))["fixtures"])
    d=Handover.Domain(fixture);g=kind=="cisco" ? SourceDetector.cisco() : SourceDetector.fattree()
    sc=SourceDetector.scenario(g,kind)
    for (policy,prefix) in [(:Q,"q"),(:V,"v")]
        row=Study.row(d,sc,policy,1,nothing,plans,kind)
        @assert row["qualified"]
        for field in ("switch_batches","row_insertions","row_removals","gate_mutations","tag_mutations")
            @assert row["control_costs"][field]==fixture[prefix*"_"*field]
        end
    end
    _,payload=Study.build_cache(g,"k3",1;sampler=:neighbors)
    TOML.print(IOBuffer(),payload)
end
open(joinpath(HERE,"Catalogue.toml"),"w") do io;TOML.print(io,Dict("plans"=>plans,"controller_gate_receipts"=>validation));end
sensitivity=[Dict("index"=>i-1,"fixture"=>kind,"configuration"=>config) for (i,(kind,config)) in
    enumerate([(kind,config) for kind in ("cisco","fat4") for config in ("k3","k20","k3_adjacent")])]
primary=Dict{String,Any}[]
for kind in ("cisco","fat4"),extra in (0,1),config in ("k3","k20","k3_adjacent")
    push!(primary,Dict("index"=>length(primary),"fixture"=>kind,"extra_rows"=>extra,"configuration"=>config,
        "include_seed_independent_controls"=>config=="k3","control_cell_index"=>length(primary)-(config=="k3" ? 0 : config=="k20" ? 1 : 2)))
end
bench=[Dict("index"=>i-1,"fixture"=>kind,"k"=>k) for (i,(kind,k)) in
    enumerate([(kind,k) for kind in ("cisco","fat4") for k in (3,20)])]
files=["study/Study.jl","study/common.jl","study/entry.jl","study/freeze.jl","study/python_study.py",
    "study/run.sh","study/run_all.sh","study/analyze.jl","study/Protocol.md","study/Catalogue.toml",
    "handover.jl","lifecycle.jl","controllers.jl","Handover_Bounds.toml","Operational_Semantics_and_Bounds.md",
    "Controller_Validation_Spec.md","validation/Controller_Inputs.toml","validation/Three_Stage_Authorization.toml",
    "reference_capture/Capture_Plan.toml","reference_capture/sources/detector.py","reference_capture/sources/fattree.py",
    "reference_capture/sources/detectortypes.py","reference_environment/run_reference.py","reference_environment/Setup_Status.toml",
    "reference_environment/flake.nix","reference_environment/flake.lock","reference_environment/referenceComponents.json",
    "reference_environment/referenceVersions.json","reference_environment/transitiveVersions.json",reference,replay]
append!(files,validation)
for receipt in validation
    append!(files,keys(TOML.parsefile(joinpath(ROOT,receipt))["input_sha256"]))
end
push!(files,relpath(joinpath(HISTORICAL,"source_fidelity/detector.jl"),ROOT))
manifest=Dict("status"=>"FROZEN","frozen_utc"=>string(now(UTC)),"julia_version"=>string(VERSION),
    "julia_executable"=>realpath(joinpath(Sys.BINDIR,"julia")),"reference_trace"=>reference,
    "sensitivity_seeds"=>collect(20261101:20261132),"primary_seeds"=>collect(20261025:20261027),
    "sensitivity_cells"=>sensitivity,"primary_cells"=>primary,"benchmark_conditions"=>bench,
    "warm_repetitions"=>20,"cold_repetitions"=>5,"sample_counts"=>Dict("cisco"=>82,"fat4"=>141),
    "primary_attempts_per_cell"=>1,"primary_sampler"=>"weighted","direct_seed_labels_no_CRN_claim"=>true,
    "source_sha256"=>Dict(name=>hashfile(joinpath(ROOT,name)) for name in unique(files)))
open(joinpath(HERE,"Sources.sha256"),"w") do io
    for (name,want) in sort!(collect(manifest["source_sha256"]);by=first)
        println(io,want,"  ",abspath(joinpath(ROOT,name)))
    end
end
open(joinpath(HERE,"Manifest.toml"),"w") do io;TOML.print(io,manifest);end
sealcheck();verify_manifest(manifest)
println("FROZEN Stage3: ",length(plans)," exact plan proofs; 6 sensitivity conditions; 12 primary cells; 4 benchmark conditions")
