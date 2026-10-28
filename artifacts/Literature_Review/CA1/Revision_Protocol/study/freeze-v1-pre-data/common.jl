using TOML, SHA, Dates, Statistics
const HERE=@__DIR__
const ROOT=dirname(HERE)
const HISTORICAL=abspath(joinpath(ROOT,"../../../SDN_Model_Comparison"))
hashfile(p)=bytes2hex(sha256(read(p)))
function sealcheck()
    path=joinpath(HISTORICAL,"Delivery_Manifest.json")
    hashfile(path)=="b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb" || error("historical seal changed")
    text=read(path,String)
    for (section,count) in [("files",194),("external_context_snapshots",2)]
        block=match(Regex("\\\""*section*"\\\":\\s*\\{(.*?)\\n  \\}","s"),text)
        block===nothing && error("seal layout changed")
        entries=collect(eachmatch(r"\"([^\"]+)\":\s*\"([a-f0-9]{64})\"",block.captures[1]))
        length(entries)==count || error("seal coverage")
        for item in entries;hashfile(joinpath(HISTORICAL,item.captures[1]))==item.captures[2] || error("sealed file changed");end
    end
end
function scopecheck()
    cg=split(only(filter(x->startswith(x,"0::"),split(read("/proc/self/cgroup",String),'\n'))),"::";limit=2)[2]
    occursin("cos738-study-",cg) || error("bounded study scope required")
    dir=joinpath("/sys/fs/cgroup",cg[2:end]);mem=parse(Int,readchomp(joinpath(dir,"memory.max")))
    swap=parse(Int,readchomp(joinpath(dir,"memory.swap.max")))
    quota,period=parse.(Int,split(readchomp(joinpath(dir,"cpu.max"))))
    mem<=2^31 && swap==0 && quota<=2period && Threads.nthreads()==1 || error("study resource contract missing")
    mask=match(r"Cpus_allowed_list:\s*([^\n]+)",read("/proc/self/status",String)).captures[1]
    cpus=Int[]
    for field in split(strip(mask),',')
        span=parse.(Int,split(field,'-'));append!(cpus,first(span):last(span))
    end
    Set(cpus)⊆Set([0,1]) || error("study CPU affinity")
    cg,dir
end
function checkpoint(path,data)
    temp=path*".tmp"
    open(temp,"w") do io;TOML.print(io,Dict("data"=>data));end
    filesize(temp)<=4*1024^2 || error("study output ceiling exceeded")
    mv(temp,path;force=true)
end
function verify_manifest(manifest)
    manifest["status"]=="FROZEN" || error("unfrozen study")
    for (name,want) in manifest["source_sha256"]
        hashfile(joinpath(ROOT,name))==want || error("study source/input drift: "*name)
    end
    string(VERSION)==manifest["julia_version"] || error("Julia version drift")
    realpath(joinpath(Sys.BINDIR,"julia"))==manifest["julia_executable"] || error("Julia executable drift")
end
function resources(cg,dir)
    value(name)=readchomp(joinpath(dir,name))
    Dict("scope"=>cg,"memory_max_bytes"=>parse(Int,value("memory.max")),
        "swap_max_bytes"=>parse(Int,value("memory.swap.max")),"cpu_max"=>value("cpu.max"),
        "memory_peak_at_checkpoint_bytes"=>parse(Int,value("memory.peak")),
        "cpu_usage_seconds"=>parse(Int,match(r"(?m)^usage_usec (\d+)$",value("cpu.stat")).captures[1])/1e6)
end
