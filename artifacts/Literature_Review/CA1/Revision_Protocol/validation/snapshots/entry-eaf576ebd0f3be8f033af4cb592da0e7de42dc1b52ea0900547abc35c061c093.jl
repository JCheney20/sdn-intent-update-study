using TOML, SHA, Dates

length(ARGS)==2 || error("expected mode and reserved run directory")
mode, outdir = ARGS
mode in ("preflight", "environment", "oracle", "differential", "lifecycle", "controllers-cisco", "controllers-fat4") || error("unapproved job")
const HERE = @__DIR__
const ROOT = dirname(HERE)
const HISTORICAL = abspath(joinpath(HERE,"..","..","..","..","SDN_Model_Comparison"))
isdir(outdir) && dirname(outdir)==joinpath(HERE,"runs") || error("invalid run directory")
readchomp(joinpath(outdir,"mode"))==mode || error("reservation mode mismatch")
seconds=parse(Int,readchomp(joinpath(outdir,"process_limit_seconds")))
seconds==(mode in ("preflight","environment") ? 30 : 120) || error("invalid limit")
reserved=parse(Int,readchomp(joinpath(outdir,"reserved.core_seconds")))
reserved==2*(seconds+2) || error("missing full reservation")
reservations=sum(parse(Int,readchomp(joinpath(path,"reserved.core_seconds")))
    for path in readdir(joinpath(HERE,"runs");join=true) if isfile(joinpath(path,"reserved.core_seconds")))
approval=TOML.parsefile(joinpath(HERE,"Three_Stage_Authorization.toml"))
approval["aggregate_runtime_cap"]=="none" && approval["scientific_gates_must_pass"] &&
    approval["max_cpu_cores"]==2 && approval["memory_max_bytes"]==2^31 &&
    approval["swap_max_bytes"]==0 && approval["max_process_seconds"]==120 || error("unexpected stage authorization")

# Verify the actual inherited scope, not systemd command-line claims.
cg=split(only(filter(x->startswith(x,"0::"),split(read("/proc/self/cgroup",String),'\n'))),"::";limit=2)[2]
occursin("cos738-revision-",cg) || error("not inside reserved scope")
cgdir=joinpath("/sys/fs/cgroup",cg[2:end])
mem=parse(Int,readchomp(joinpath(cgdir,"memory.max")))
swap=parse(Int,readchomp(joinpath(cgdir,"memory.swap.max")))
quota,period=parse.(Int,split(readchomp(joinpath(cgdir,"cpu.max"))))
mem<=2^31 && swap==0 && quota<=2period || error("effective resource contract missing")
Threads.nthreads()==1 || error("unexpected Julia workers")
function cpuset(s)
    result=Set{Int}()
    for field in split(strip(s),',')
        span=parse.(Int,split(field,'-'))
        length(span) in (1,2) || error("invalid CPU list")
        union!(result,first(span):last(span))
    end
    result
end
for tid in readdir("/proc/self/task")
    path="/proc/self/task/$tid/status"
    isfile(path) || continue
    mask=match(r"Cpus_allowed_list:\s*([^\n]+)",read(path,String)).captures[1]
    cpuset(mask) ⊆ Set([0,1]) || error("thread escaped CPU affinity")
end
println("LIMITS_OK memory=",mem," swap=",swap," quota=",quota,"/",period," affinity=0,1 Julia_workers=1 scope=",cg)

hashfile(path)=bytes2hex(sha256(read(path)))
function check_seal()
    manifest=joinpath(HISTORICAL,"Delivery_Manifest.json")
    hashfile(manifest)=="b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb" || error("historical seal changed")
    text=read(manifest,String)
    for (section,count) in [("files",194),("external_context_snapshots",2)]
        block=match(Regex("\\\""*section*"\\\":\\s*\\{(.*?)\\n  \\}","s"),text)
        block===nothing && error("seal format unsupported")
        entries=collect(eachmatch(r"\"([^\"]+)\":\s*\"([a-f0-9]{64})\"",block.captures[1]))
        length(entries)==count || error("incomplete seal coverage")
        for item in entries
            hashfile(joinpath(HISTORICAL,item.captures[1]))==item.captures[2] || error("historical file changed: "*item.captures[1])
        end
    end
end
function uptime()
    parse(Float64,first(split(read("/proc/uptime",String))))
end
function cpu_usec()
    parse(Int,match(r"(?m)^usage_usec (\d+)$",read(joinpath(cgdir,"cpu.stat"),String)).captures[1])
end
start=parse(Float64,readchomp(joinpath(outdir,"start.uptime")))
receipt=Dict{String,Any}("mode"=>mode,"status"=>"RUNNING","julia_version"=>string(VERSION),
    "scope"=>cg,"memory_max_bytes"=>mem,"swap_max_bytes"=>swap,"cpu_quota"=>quota,"cpu_period"=>period,
    "reserved_core_seconds"=>reserved,"aggregate_reserved_core_seconds"=>reservations,
    "initial_budget_core_seconds"=>600,"additional_budget_core_seconds"=>2000,
    "aggregate_runtime_cap"=>"none","process_ceiling_seconds"=>seconds,
    "accounting"=>"documentary full two-core time-limit tickets plus 2 seconds margin; no cumulative stop; includes failures/startup",
    "python_reference_executed"=>false,"primary_execution"=>false)
receipt["input_sha256"]=Dict(relpath(path,ROOT)=>hashfile(path) for path in
    [joinpath(ROOT,"Handover_Bounds.toml"),joinpath(ROOT,"Operational_Semantics_and_Bounds.md"),
     joinpath(HERE,"entry.jl"),joinpath(HERE,"run.sh"),joinpath(HERE,"Three_Stage_Authorization.toml")])
try
    check_seal()
    if mode!="preflight"
        preflights=filter(path->isfile(joinpath(path,"receipt.toml")) &&
            get(TOML.parsefile(joinpath(path,"receipt.toml")),"mode","")=="preflight" &&
            get(TOML.parsefile(joinpath(path,"receipt.toml")),"status","")=="PASS",readdir(joinpath(HERE,"runs");join=true))
        isempty(preflights) && error("successful resource preflight required")
        any(path->all(key->get(TOML.parsefile(joinpath(path,"receipt.toml"))["input_sha256"],key,"")==receipt["input_sha256"][key],
            ["validation/entry.jl","validation/run.sh","validation/Three_Stage_Authorization.toml"]),preflights) || error("resource bootstrap changed since preflight")
    end
    if mode=="environment"
        script=joinpath(HERE,"reference_environment.py")
        requirements=joinpath(HISTORICAL,"source_fidelity/sources/requirements.txt.txt")
        receipt["input_sha256"][relpath(script,ROOT)]=hashfile(script)
        receipt["input_sha256"][relpath(requirements,ROOT)]=hashfile(requirements)
        run(`python3 -I -B $script $requirements $(joinpath(outdir,"reference_environment.toml"))`)
        receipt["reference_environment"]=TOML.parsefile(joinpath(outdir,"reference_environment.toml"))
    elseif startswith(mode,"controllers-")
        paths=[joinpath(HERE,"oracle.jl"),joinpath(ROOT,"handover.jl"),joinpath(ROOT,"lifecycle.jl"),
            joinpath(ROOT,"controllers.jl"),joinpath(ROOT,"Controller_Validation_Spec.md"),
            joinpath(HERE,"Controller_Inputs.toml"),joinpath(HERE,"controller_checks.jl"),
            joinpath(HERE,"comparison_map.jl"),joinpath(HISTORICAL,"source_fidelity/detector.jl")]
        settings=TOML.parsefile(joinpath(HERE,"Controller_Inputs.toml"))
        push!(paths,joinpath(ROOT,settings["reference_trace"]))
        for path in paths;receipt["input_sha256"][relpath(path,ROOT)]=hashfile(path);end
        receipt["oracle"]=include(joinpath(HERE,"oracle.jl"))
        include(joinpath(ROOT,"handover.jl"));include(joinpath(ROOT,"lifecycle.jl"))
        include(joinpath(HISTORICAL,"source_fidelity/detector.jl"));include(joinpath(ROOT,"controllers.jl"))
        receipt["controllers"]=include(joinpath(HERE,"controller_checks.jl"))
    elseif mode in ("oracle","differential","lifecycle")
        receipt["input_sha256"]["validation/oracle.jl"]=hashfile(joinpath(HERE,"oracle.jl"))
        if mode in ("differential","lifecycle")
            for path in [joinpath(ROOT,"handover.jl"),joinpath(HERE,"differential.jl"),joinpath(HERE,"comparison_map.jl")]
                receipt["input_sha256"][relpath(path,ROOT)]=hashfile(path)
            end
        end
        receipt["oracle"]=include(joinpath(HERE,"oracle.jl"))
        if mode=="lifecycle"
            for path in [joinpath(ROOT,"lifecycle.jl"),joinpath(HERE,"lifecycle_checks.jl")]
                receipt["input_sha256"][relpath(path,ROOT)]=hashfile(path)
            end
        end
        if mode in ("differential","lifecycle")
            include(joinpath(ROOT,"handover.jl"))
            receipt["differential"]=include(joinpath(HERE,"differential.jl"))
        end
        if mode=="lifecycle"
            include(joinpath(ROOT,"lifecycle.jl"))
            receipt["lifecycle"]=include(joinpath(HERE,"lifecycle_checks.jl"))
        end
    end
    check_seal()
    receipt["status"]="PASS"
catch e
    receipt["status"]="FAIL"
    receipt["error"]=sprint(showerror,e,catch_backtrace())
    rethrow()
finally
    receipt["elapsed_seconds_including_startup"]=uptime()-start
    receipt["scope_cpu_seconds"]=cpu_usec()/1e6
    receipt["scope_memory_peak_bytes_at_checkpoint"]=parse(Int,readchomp(joinpath(cgdir,"memory.peak")))
    receipt["completed_utc"]=string(now(UTC))
    open(joinpath(outdir,"receipt.toml"),"w") do io
        TOML.print(io,receipt)
    end
    println("RESULT ",receipt["status"]," elapsed=",receipt["elapsed_seconds_including_startup"],
        " CPU=",receipt["scope_cpu_seconds"]," peak=",receipt["scope_memory_peak_bytes_at_checkpoint"],
        " documentary_limit_total=",reservations," aggregate_cap=none")
end
