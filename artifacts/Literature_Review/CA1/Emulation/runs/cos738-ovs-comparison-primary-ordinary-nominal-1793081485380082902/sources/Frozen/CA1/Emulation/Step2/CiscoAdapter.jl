module CiscoAdapter
using TOML, JSON, SHA, PythonCall
export fixture, Adapter, start!, stop!, configure!, install!, rows, emit!, observe!, frame, Slot, Request, offer!, admit!, slotvalid, stage!, commit!, clean!

const ROOT=abspath(joinpath(@__DIR__,"../../Revision_Protocol"))
const TRACE="reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml"
function fixture()
    manifest=TOML.parsefile(joinpath(ROOT,"study/Manifest.toml"))
    for name in (TRACE,"Handover_Bounds.toml")
        bytes2hex(sha256(read(joinpath(ROOT,name))))==manifest["source_sha256"][name] || error("frozen fixture changed")
    end
    c=only(filter(c->c["fixture"]=="cisco" && c["k"]==3 && !c["noop"],TOML.parsefile(joinpath(ROOT,TRACE))["trace"]["cases"]))
    f=TOML.parsefile(joinpath(ROOT,"Handover_Bounds.toml"))["fixtures"][1]
    p=c["physical"];length(p["nodes"])==22 && length(p["edges"])==28 || error("wrong Cisco topology")
    adjacency=Dict(String(n)=>String.(a) for (n,a) in zip(p["nodes"],p["adjacency"]))
    old=Tuple{String,String,String}[];new=Tuple{String,String,String}[]
    for s in c["switches"]
        r=c["rules"][s]
        for row in r["initial"]
            row[3:4]==["10.0.0.0/8","10.0.0.0/8"] || error("unsupported source prefix")
            push!(old,(s,row[1],row[2]))
        end
        target=vcat(filter(x->!(x in r["removed"]),r["initial"]),r["added"])
        for row in target;push!(new,(s,row[1],row[2]));end
    end
    Set(old)==Set(Tuple(String.(x)) for x in f["old_rows"]) || error("raw old rows disagree")
    Set(new)==Set(Tuple(String.(x)) for x in f["new_rows"]) || error("raw target rows disagree")
    for edge in p["edges"]
        edge[2] in adjacency[edge[1]] && edge[1] in adjacency[edge[2]] || error("asymmetric physical edge")
    end
    Dict{String,Any}("physical"=>p,"adjacency"=>adjacency,"switches"=>String.(c["switches"]),
        "hosts"=>String.(c["hosts"]),"old_rows"=>old,"new_rows"=>new,
        "source_trace_sha256"=>manifest["source_sha256"][TRACE])
end

# Forwarding rows are separate from gate/helper flow entries.
const Row=Tuple{String,String,String,Int}
rows(f,which;tag=0)=Row[(s,i,o,tag) for (s,i,o) in f[which*"_rows"]]
mutable struct Adapter
    f::Dict{String,Any}
    run::String
    ovs::String
    private::String
    net::Py
    nodes::Dict{String,Py}
    ports::Dict{Tuple{String,String},Int}
    interfaces::Dict{String,Dict{String,String}}
    tables::Dict{String,Vector{Row}}
    oldopen::Bool
    newopen::Bool
    newtag::Int
    workers::Dict{String,Py}
    pyfiles::Vector{Py}
    processes::Vector{Any}
    streams::Vector{IO}
    pids::Vector{Int}
    shells::Vector{Py}
    evidence::Dict{String,Any}
end
function Adapter(f,run)
    ovs=JSON.parsefile(joinpath(@__DIR__,"../Components.json"))["openvswitch"]["path"]
    Adapter(f,run,ovs,"",Py(nothing),Dict(),Dict(),Dict(),Dict(s=>Row[] for s in f["switches"]),
        true,false,0,Dict(),Py[],Any[],IO[],Int[],Py[],Dict{String,Any}("commands"=>Any[],"snapshots"=>Any[],"packet_io"=>Any[]))
end
function command(a,args)
    output=read(Cmd(String.(args)),String)
    push!(a.evidence["commands"],Dict("argv"=>args,"output"=>output))
    output
end
vsctl(a,args...)=command(a,[a.ovs*"/bin/ovs-vsctl","--timeout=5",args...])
ofctl(a,s,args...)=command(a,[a.ovs*"/bin/ovs-ofctl","--no-names","-O","OpenFlow14",args[1],"unix:"*a.private*"/$s.mgmt",args[2:end]...])
function start!(a;internal_worker=false)
    @assert occursin("cos738-ovs-",read("/proc/self/cgroup",String))
    @assert readlink("/proc/self/ns/net")!=ENV["HOST_NETNS"]
    @assert parse.(Int,split(read("/proc/self/uid_map",String)))==[0,1000,1]
    sys=pyimport("sys");sys.path.insert(0,ENV["MININET_PYTHON_SOURCE"])
    @assert realpath(pyconvert(String,sys.executable))==realpath(ENV["JULIA_PYTHONCALL_EXE"])
    mn=pyimport("mininet.net");node=pyimport("mininet.node");pyimport("mininet.log").setLogLevel("info")
    a.private=mktempdir("/tmp";prefix="cos738-cisco-")
    ENV["OVS_RUNDIR"]=a.private;ENV["OVS_LOGDIR"]=a.private;ENV["OVS_DBDIR"]=a.private
    command(a,[a.ovs*"/bin/ovsdb-tool","create",a.private*"/db",a.ovs*"/share/openvswitch/vswitch.ovsschema"])
    function daemon(name,args)
        io=open(joinpath(a.run,name*".log"),"w");push!(a.streams,io)
        push!(a.processes,run(pipeline(Cmd([a.ovs*"/bin/"*name;args]);stdout=io,stderr=io);wait=false))
    end
    daemon("ovsdb-server",[a.private*"/db","--remote=punix:"*a.private*"/db.sock","--pidfile="*a.private*"/db.pid","--unixctl="*a.private*"/db.ctl","--no-chdir"])
    @assert timedwait(()->ispath(a.private*"/db.sock"),5)==:ok
    vsctl(a,"--no-wait","init")
    vsctl(a,"--no-wait","set","Open_vSwitch",".","other_config:n-handler-threads=1","other_config:n-revalidator-threads=1")
    daemon("ovs-vswitchd",["unix:"*a.private*"/db.sock","--pidfile="*a.private*"/vs.pid","--unixctl="*a.private*"/vs.ctl","--no-chdir"])
    a.net=mn.Mininet(;controller=nothing,build=false,autoSetMacs=true)
    for (idx,s) in enumerate(a.f["switches"])
        a.nodes[s]=a.net.addSwitch(s;cls=node.OVSSwitch,datapath="user",protocols="OpenFlow14",failMode="secure",dpid=string(idx;base=16,pad=16))
    end
    for h in a.f["hosts"];a.nodes[h]=a.net.addHost(h;ip=nothing);end
    for (n,adj) in a.f["adjacency"]
        a.interfaces[n]=Dict{String,String}()
        for (index,other) in enumerate(adj);a.ports[(n,other)]=index-(startswith(n,"H") ? 1 : 0);end
    end
    for (n,m) in a.f["physical"]["edges"]
        link=a.net.addLink(a.nodes[n],a.nodes[m];port1=a.ports[(n,m)],port2=a.ports[(m,n)])
        a.interfaces[n][m]=pyconvert(String,link.intf1.name)
        a.interfaces[m][n]=pyconvert(String,link.intf2.name)
    end
    a.net.build();a.net.start()
    a.pids=[pyconvert(Int,a.nodes[n].pid) for n in a.f["physical"]["nodes"]]
    a.shells=[a.nodes[n].shell for n in a.f["physical"]["nodes"]]
    ns=Dict(n=>readlink("/proc/$(pyconvert(Int,a.nodes[n].pid))/ns/net") for n in a.f["physical"]["nodes"])
    @assert length(unique(ns[h] for h in a.f["hosts"]))==12
    @assert all(ns[s]==readlink("/proc/self/ns/net") for s in a.f["switches"])
    @assert all(ns[h]!=readlink("/proc/self/ns/net") for h in a.f["hosts"])
    actualports=Any[]
    for s in a.f["switches"]
        @assert strip(vsctl(a,"get","bridge",s,"datapath_type"))=="netdev"
        for other in a.f["adjacency"][s]
            name=a.interfaces[s][other]
            port=parse(Int,strip(vsctl(a,"get","interface",name,"ofport")))
            @assert port==a.ports[(s,other)]
            @assert pyconvert(Int,a.nodes[s].ports[a.nodes[s].nameToIntf[name]])==port
            push!(actualports,Dict("switch"=>s,"neighbor"=>other,"interface"=>name,"port"=>port))
        end
    end
    a.evidence["actual_ports"]=actualports;a.evidence["node_namespaces"]=ns
    a.evidence["interfaces"]=a.interfaces
    rootlinks=JSON.parse(command(a,["ip","-details","-json","link","show"]))
    links=Dict{String,Any}(s=>rootlinks for s in a.f["switches"])
    for h in a.f["hosts"]
        links[h]=JSON.parse(pyconvert(String,a.nodes[h].cmd("ip -details -json link show")))
    end
    actualedges=Any[]
    for (n,m) in a.f["physical"]["edges"]
        left=only(filter(i->i["ifname"]==a.interfaces[n][m],links[n]))
        right=only(filter(i->i["ifname"]==a.interfaces[m][n],links[m]))
        if ns[n]==ns[m]
            @assert left["link"]==right["ifname"] && right["link"]==left["ifname"]
        else
            @assert left["link_index"]==right["ifindex"] && right["link_index"]==left["ifindex"]
        end
        push!(actualedges,Dict("left"=>n,"right"=>m,"left_interface"=>left,"right_interface"=>right))
    end
    a.evidence["kernel_edges"]=actualedges
    subprocess=pyimport("subprocess")
    for n in [a.f["hosts"];internal_worker ? ["C10"] : String[]]
        err=pybuiltins.open(joinpath(a.run,n*"-packet-worker.log"),"wb");push!(a.pyfiles,err)
        proc=a.nodes[n].popen(pylist([ENV["JULIA_PYTHONCALL_EXE"],"-I","-B",joinpath(@__DIR__,"packet_worker.py"),JSON.json(a.interfaces[n])]);stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err)
        a.workers[n]=proc
    end
    a.evidence["workers"]=Dict(n=>readreply(a,p) for (n,p) in a.workers)
    @assert all(info["netns"]==ns[n] for (n,info) in a.evidence["workers"])
    a
end
function readreply(a,p)
    ready=pyimport("select").select(pylist([p.stdout]),pylist(),pylist(),5.0)
    pylen(ready[0])>0 || error("packet worker response timeout")
    line=pyconvert(String,p.stdout.readline().decode("utf-8"))
    isempty(line) && error("packet worker exited")
    JSON.parse(line)
end
function rpc(a,n,cmd)
    p=a.workers[n]
    p.stdin.write(pybuiltins.bytes(JSON.json(cmd)*"\n","utf-8"));p.stdin.flush()
    result=readreply(a,p)
    push!(a.evidence["packet_io"],Dict("node"=>n,"command"=>cmd,"response"=>result))
    result
end
function observe!(a;window=.12)
    sleep(window)
    found=Any[]
    for n in sort!(collect(keys(a.workers)))
        for event in rpc(a,n,Dict("op"=>"drain"))["events"]
            event["node"]=n;push!(found,event)
        end
    end
    found
end
function emit!(a,n,id,hex;neighbor=first(a.f["adjacency"][n]))
    response=rpc(a,n,Dict("op"=>"send","neighbor"=>neighbor,"hex"=>hex))
    @assert response["status"]=="SENT"
    response
end
function flowtext(a,s,rs,oldopen,newopen,newtag)
    lines=["cookie=0x10000000,table=0,priority=0,actions=goto_table:1","cookie=0x10000000,table=1,priority=0,actions=drop"]
    if s=="C2"
        for (host,opened,tag) in [("H5",oldopen,0),("H6",newopen,newtag)]
            base="cookie=0x30000000,table=0,in_port=$(a.ports[(s,host)])"
            if !opened
                push!(lines,base*",priority=200,actions=drop")
            else
                assigned=tag==0 ? "goto_table:1" : "push_vlan:0x8100,set_field:4197->vlan_vid,goto_table:1"
                # OF1.4 requires a tag-present match before pop_vlan; untagged input skips the pop.
                push!(lines,base*",priority=201,vlan_tci=0x1000/0x1000,actions=strip_vlan,"*assigned)
                push!(lines,base*",priority=200,dl_vlan=0xffff,actions="*assigned)
            end
        end
    end
    for (sw,ingress,egress,tag) in rs
        @assert sw==s && tag in (0,1)
        version=tag==0 ? "vlan_tci=0x0000/0x1fff" : "dl_vlan=101"
        push!(lines,"cookie=0x20000000,table=1,priority=100,in_port=$(a.ports[(s,ingress)]),ip,nw_src=10.0.0.0/8,nw_dst=10.0.0.0/8,$version,actions=output:$(a.ports[(s,egress)])")
    end
    join(lines,"\n")*"\n"
end
function install!(a,s,rs;oldopen=a.oldopen,newopen=a.newopen,newtag=a.newtag,label="state")
    s=="C2" || @assert (oldopen,newopen,newtag)==(a.oldopen,a.newopen,a.newtag)
    path=joinpath(a.private,"flows-$s")
    write(path,flowtext(a,s,rs,oldopen,newopen,newtag))
    cp(path,joinpath(a.run,"flow-$(length(a.evidence["snapshots"])+1)-$s.txt"))
    # One bridge-local bundle, not a network-wide commit.
    command(a,[a.ovs*"/bin/ovs-ofctl","--no-names","-O","OpenFlow14","--bundle","replace-flows","unix:"*a.private*"/$s.mgmt",path])
    dump=ofctl(a,s,"dump-flows")
    a.tables[s]=copy(rs)
    if s=="C2";a.oldopen=oldopen;a.newopen=newopen;a.newtag=newtag;end
    push!(a.evidence["snapshots"],Dict("label"=>label,"switch"=>s,"rows"=>[collect(r) for r in rs],"oldopen"=>oldopen,"newopen"=>newopen,"newtag"=>newtag,"dump"=>dump))
    dump
end
function configure!(a,rs;oldopen=true,newopen=false,newtag=0,label="static")
    # Initial/static fixtures only. No packets are in flight; no network-atomic claim.
    for s in ["C2";filter(!=("C2"),a.f["switches"])]
        install!(a,s,filter(r->r[1]==s,rs);oldopen=oldopen,newopen=newopen,newtag=newtag,label=label)
    end
end
stateis(a,rs)=all(Set(a.tables[s])==Set(r for r in rs if r[1]==s) for s in a.f["switches"])
function stage!(a;allowance=1)
    allowance>=0 || throw(ArgumentError("negative capacity allowance"))
    stateis(a,rows(a.f,"old")) && a.oldopen && !a.newopen && a.newtag==0 || throw(ArgumentError("staging requires the intact old state"))
    proposed=vcat(rows(a.f,"old"),rows(a.f,"new";tag=1))
    for s in a.f["switches"]
        base=max(count(r->r[1]==s,a.f["old_rows"]),count(r->r[1]==s,a.f["new_rows"]))
        count(r->r[1]==s,proposed)<=base+allowance || return :RESOURCE_BLOCKED
    end
    for s in unique(r[1] for r in rows(a.f,"new"))
        install!(a,s,filter(r->r[1]==s,proposed);label="staged")
    end
    :STAGED
end
function commit!(a)
    stateis(a,vcat(rows(a.f,"old"),rows(a.f,"new";tag=1))) && a.oldopen && !a.newopen && a.newtag==0 || throw(ArgumentError("commit requires complete staging"))
    install!(a,"C2",a.tables["C2"];oldopen=false,newopen=true,newtag=1,label="committed")
end
function clean!(a)
    stateis(a,vcat(rows(a.f,"old"),rows(a.f,"new";tag=1))) && !a.oldopen && a.newopen && a.newtag==1 || throw(ArgumentError("cleanup requires the committed staged state"))
    # This primitive checks phase state, NOT drainage; timing policy remains a later gate.
    for s in unique(r[1] for r in rows(a.f,"old"))
        install!(a,s,filter(r->r[4]==1,a.tables[s]);label="cleaned")
    end
end
function frame(id;label="probe",source=0x0a000000,destination=0x0a000000,vlan=nothing)
    payload=collect(codeunits("COS738S2:$id:$label"))
    while length(payload)<26;push!(payload,UInt8('.'));end
    total=20+length(payload)
    ip=UInt8[0x45,0,total>>8,total&255,(id>>8)&255,id&255,0,0,64,253,0,0,
        (source>>24)&255,(source>>16)&255,(source>>8)&255,source&255,
        (destination>>24)&255,(destination>>16)&255,(destination>>8)&255,destination&255]
    sum16=sum((Int(ip[i])<<8)+ip[i+1] for i in 1:2:20)
    while sum16>65535;sum16=(sum16&65535)+(sum16>>16);end
    checksum=(~sum16)&65535;ip[11]=checksum>>8;ip[12]=checksum&255
    ethernet=UInt8[fill(0xff,6);0x02;0;0;0;0;1]
    if vlan!==nothing;append!(ethernet,UInt8[0x81,0,0x10|(vlan>>8),vlan&255]);end
    append!(ethernet,UInt8[0x08,0]);bytes2hex([ethernet;ip;payload])
end

struct Request
    id::Int
    source::String
    hex::String
    arrival_ns::UInt64
end
mutable struct Slot
    pending::Union{Nothing,Request}
    original::Dict{Int,Request}
    disposition::Dict{Int,Symbol}
    emitted::Dict{Int,Any}
end
Slot()=Slot(nothing,Dict(),Dict(),Dict())
function offer!(s,r)
    r.id>0 && !haskey(s.disposition,r.id) || throw(ArgumentError("duplicate/invalid request"))
    r.source=="H6" || throw(ArgumentError("wrong physical new source"))
    s.original[r.id]=r
    if s.pending!==nothing;s.disposition[r.id]=:OUTSIDE_DOMAIN;return :OUTSIDE_DOMAIN;end
    s.pending=r;s.disposition[r.id]=:PENDING;:PENDING
end
function admit!(s,opened,send)
    s.pending===nothing && return nothing
    opened || return nothing
    r=s.pending
    # Single-task at-most-once emission. Any send exception is explicit and non-retryable.
    s.pending=nothing;s.disposition[r.id]=:EMISSION_INCOMPLETE
    result=send(r)
    result["before_ns"]>=r.arrival_ns || error("arrival clock reset or clock mismatch")
    s.emitted[r.id]=result;s.disposition[r.id]=:ADMITTED
    result
end
function slotvalid(s)
    Set(keys(s.original))==Set(keys(s.disposition)) &&
    all(d in (:PENDING,:ADMITTED,:OUTSIDE_DOMAIN,:EMISSION_INCOMPLETE) for d in values(s.disposition)) &&
    length([d for d in values(s.disposition) if d==:PENDING])==(s.pending===nothing ? 0 : 1) &&
    (s.pending===nothing || s.original[s.pending.id]===s.pending) &&
    Set(keys(s.emitted))==Set(id for (id,d) in s.disposition if d==:ADMITTED)
end
function stop!(a)
    cleanup=Dict{String,Any}()
    for (n,p) in a.workers
        try;rpc(a,n,Dict("op"=>"stop"));p.wait(;timeout=3);catch;p.kill();p.wait(;timeout=2);end
    end
    foreach(file->file.close(),a.pyfiles)
    if !pyis(a.net,pybuiltins.None)
        a.net.stop()
        for shell in a.shells;shell.wait(;timeout=3);end
    end
    cleanup["interfaces_removed"]=timedwait(()->all(i->i["ifname"]=="lo",JSON.parse(command(a,["ip","-json","link","show"]))),4)==:ok
    cleanup["nodes_reaped"]=all(!ispath("/proc/$pid") for pid in a.pids)
    for p in reverse(a.processes)
        if !process_exited(p)
            kill(p);timedwait(()->process_exited(p),2)==:ok || kill(p,Base.SIGKILL);wait(p)
        end
    end
    foreach(close,a.streams)
    cleanup["ovs_daemons_exited"]=all(process_exited,a.processes)
    cleanup
end
end
