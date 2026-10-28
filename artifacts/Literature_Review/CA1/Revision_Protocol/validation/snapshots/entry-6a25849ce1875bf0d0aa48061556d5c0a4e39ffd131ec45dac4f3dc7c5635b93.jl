using TOML, SHA, Dates

length(ARGS)==2 || error("expected mode and reserved run directory")
mode, outdir = ARGS
mode in ("preflight", "oracle", "differential") || error("unapproved job")
const HERE = @__DIR__
const ROOT = dirname(HERE)
const HISTORICAL = abspath(joinpath(HERE,"..","..","..","..","SDN_Model_Comparison"))
isdir(outdir) && dirname(outdir)==joinpath(HERE,"runs") || error("invalid run directory")
readchomp(joinpath(outdir,"mode"))==mode || error("reservation mode mismatch")
seconds=parse(Int,readchomp(joinpath(outdir,"process_limit_seconds")))
seconds==(mode=="preflight" ? 30 : 120) || error("invalid limit")
reserved=parse(Int,readchomp(joinpath(outdir,"reserved.core_seconds")))
reserved==2*(seconds+2) || error("missing full reservation")
reservations=sum(parse(Int,readchomp(joinpath(path,"reserved.core_seconds")))
    for path in readdir(joinpath(HERE,"runs");join=true) if isfile(joinpath(path,"reserved.core_seconds")))
approval=TOML.parsefile(joinpath(HERE,"Budget_Approval.toml"))
approval["initial_core_seconds"]==600 && approval["additional_core_seconds"]==2000 &&
    approval["cumulative_core_seconds"]==2600 || error("unexpected budget approval")
reservations<=approval["cumulative_core_seconds"] || error("aggregate reservation exceeded")

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
    "cumulative_budget_core_seconds"=>2600,"process_ceiling_seconds"=>seconds,
    "accounting"=>"immutable full two-core time-limit reservation plus 2 seconds margin; no refunds; includes failures/startup",
    "python_reference_executed"=>false,"primary_execution"=>false)
receipt["input_sha256"]=Dict(relpath(path,ROOT)=>hashfile(path) for path in
    [joinpath(ROOT,"Handover_Bounds.toml"),joinpath(ROOT,"Operational_Semantics_and_Bounds.md"),
     joinpath(HERE,"entry.jl"),joinpath(HERE,"run.sh"),joinpath(HERE,"Budget_Approval.toml")])
try
    check_seal()
    if mode in ("oracle","differential")
        preflights=filter(path->isfile(joinpath(path,"receipt.toml")) &&
            get(TOML.parsefile(joinpath(path,"receipt.toml")),"mode","")=="preflight" &&
            get(TOML.parsefile(joinpath(path,"receipt.toml")),"status","")=="PASS",readdir(joinpath(HERE,"runs");join=true))
        isempty(preflights) && error("successful resource preflight required")
        any(path->all(key->get(TOML.parsefile(joinpath(path,"receipt.toml"))["input_sha256"],key,"")==receipt["input_sha256"][key],
            ["validation/entry.jl","validation/run.sh","validation/Budget_Approval.toml"]),preflights) || error("resource bootstrap changed since preflight")
        receipt["input_sha256"]["validation/oracle.jl"]=hashfile(joinpath(HERE,"oracle.jl"))
        if mode=="differential"
            for path in [joinpath(ROOT,"handover.jl"),joinpath(HERE,"differential.jl")]
                receipt["input_sha256"][relpath(path,ROOT)]=hashfile(path)
            end
        end
        receipt["oracle"]=include(joinpath(HERE,"oracle.jl"))
        if mode=="differential"
            include(joinpath(ROOT,"handover.jl"))
            receipt["differential"]=include(joinpath(HERE,"differential.jl"))
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
        " reserved_total=",reservations,"/2600")
end
