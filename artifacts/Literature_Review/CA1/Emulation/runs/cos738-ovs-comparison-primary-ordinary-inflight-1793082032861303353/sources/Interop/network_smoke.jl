# Step-1 integration controls only: one switch/two hosts, not Cisco Q/V experiments.
using TOML, JSON
const HERE=@__DIR__
const RUN=ENV["COS738_OVS_RUN_DIR"]
@assert occursin("cos738-ovs-",read("/proc/self/cgroup",String))
@assert readlink("/proc/self/ns/net")!=ENV["HOST_NETNS"]
@assert readlink("/proc/self/ns/mnt")!=ENV["HOST_MNTNS"]
@assert readlink("/proc/self/ns/pid")!=ENV["HOST_PIDNS"]
@assert parse.(Int,split(read("/proc/self/uid_map",String)))==[0,1000,1]
@assert ENV["JULIA_CONDAPKG_BACKEND"]=="Null"
const OVS=JSON.parsefile(joinpath(HERE,"../Components.json"))["openvswitch"]["path"]
const PYTHON=ENV["JULIA_PYTHONCALL_EXE"]
result=Dict{String,Any}("status"=>"RUNNING","julia_pid"=>getpid(),"julia_version"=>string(VERSION),
    "scope"=>read("/proc/self/cgroup",String),"netns"=>readlink("/proc/self/ns/net"),
    "mntns"=>readlink("/proc/self/ns/mnt"),"pidns"=>readlink("/proc/self/ns/pid"))
const import_started=time_ns()
using PythonCall, CondaPkg
result["import_seconds"]=(time_ns()-import_started)/1e9
function command(args)
    read(Cmd(String.(args)),String)
end
function stop_daemon(p)
    process_exited(p) && return
    kill(p)
    timedwait(()->process_exited(p),2)==:ok || kill(p,Base.SIGKILL)
    wait(p)
end
function main()
processes=Any[];streams=IO[];net=nothing;net_stopped=false;receiver=nothing;shells=Any[];pids=Int[]
try
    @assert CondaPkg.backend()==:Null
    sys=pyimport("sys");sys.path.insert(0,ENV["MININET_PYTHON_SOURCE"])
    @assert realpath(pyconvert(String,sys.executable))==realpath(PYTHON)
    mn=pyimport("mininet.net");nodes=pyimport("mininet.node")
    pyimport("mininet.log").setLogLevel("info")
    @assert pyconvert(String,mn.VERSION)=="2.3.1b4"
    result["pythoncall_version"]=string(pkgversion(PythonCall))
    result["mininet_version"]=pyconvert(String,mn.VERSION)
    result["python_executable"]=pyconvert(String,sys.executable)
    @assert !any(id->id.name in ("MicroMamba","micromamba_jll","pixi_jll"),keys(Base.loaded_modules))
    private=mktempdir("/tmp";prefix="cos738-mininet-")
    ENV["OVS_RUNDIR"]=private;ENV["OVS_LOGDIR"]=private;ENV["OVS_DBDIR"]=private
    command([OVS*"/bin/ovsdb-tool","create",private*"/db",OVS*"/share/openvswitch/vswitch.ovsschema"])
    function daemon(binary,args)
        io=open(joinpath(RUN,binary*".log"),"w");push!(streams,io)
        push!(processes,run(pipeline(Cmd([OVS*"/bin/"*binary;args]);stdout=io,stderr=io);wait=false))
    end
    daemon("ovsdb-server",[private*"/db","--remote=punix:"*private*"/db.sock","--pidfile="*private*"/db.pid","--unixctl="*private*"/db.ctl","--no-chdir"])
    @assert timedwait(()->ispath(private*"/db.sock"),5)==:ok
    vsctl(args...)=command([OVS*"/bin/ovs-vsctl","--timeout=5",args...])
    vsctl("--no-wait","init")
    vsctl("--no-wait","set","Open_vSwitch",".","other_config:n-handler-threads=1","other_config:n-revalidator-threads=1")
    daemon("ovs-vswitchd",["unix:"*private*"/db.sock","--pidfile="*private*"/vs.pid","--unixctl="*private*"/vs.ctl","--no-chdir"])
    # Real upstream Mininet API calls from Julia; no stand-in topology classes.
    net=mn.Mininet(;controller=nothing,build=false,ipBase="10.77.0.0/24",autoSetMacs=true)
    h1=net.addHost("h1";ip="10.77.0.1/24")
    h2=net.addHost("h2";ip="10.77.0.2/24")
    sw=net.addSwitch("s1";cls=nodes.OVSSwitch,datapath="user",protocols="OpenFlow14",failMode="secure")
    link1=net.addLink(h1,sw);link2=net.addLink(h2,sw)
    net.build();net.start()
    @assert strip(vsctl("get","bridge","s1","datapath_type"))=="netdev"
    pids=Int[pyconvert(Int,h1.pid),pyconvert(Int,h2.pid),pyconvert(Int,sw.pid)]
    namespaces=[readlink("/proc/$pid/ns/net") for pid in pids]
    @assert namespaces[1]!=namespaces[2] && all(ns->ns!=result["netns"],namespaces[1:2])
    @assert namespaces[3]==result["netns"]
    result["node_pids"]=pids;result["node_netns"]=namespaces
    shells=[h1.shell,h2.shell,sw.shell]
    inport=pyconvert(Int,sw.ports[link1.intf2]);outport=pyconvert(Int,sw.ports[link2.intf2])
    endpoint="unix:"*private*"/s1.mgmt"
    @assert timedwait(()->ispath(private*"/s1.mgmt"),5)==:ok
    ofctl(args...)=command([OVS*"/bin/ovs-ofctl","-O","OpenFlow14",args...])
    function install(flows)
        path=joinpath(private,"flows");write(path,flows)
        ofctl("--bundle","replace-flows",endpoint,path)
        ofctl("dump-flows",endpoint)
    end
    install("priority=0,actions=NORMAL\n")
    # Warm basic bridge/Mininet calls and verify real IP traffic before readiness.
    @assert pyconvert(Float64,net.ping(;timeout="1"))==0.0
    @assert pyconvert(String,h1.cmd("printf WARM"))=="WARM"
    result["ready_monotonic_ns"]=time_ns()
    result["ready_definition"]="imports, real Mininet topology, initial packet/command warm-up completed"
    println("MININET READY (same resident Julia/embedded Python retained)")
    get(ENV,"FEASIBILITY_FAIL_AFTER_READY","0")=="1" && error("EXPECTED feasibility cleanup injection after readiness")
    result["post_ready_ping_loss_percent"]=pyconvert(Float64,net.ping(;timeout="1"))
    @assert result["post_ready_ping_loss_percent"]==0.0
    result["closed_flows"]=install("priority=0,actions=drop\n")
    closed=pyconvert(String,h1.cmd("ping -n -c 1 -W 1 10.77.0.2"))
    result["closed_ping_output"]=closed
    @assert occursin("0 received",closed) || occursin("0 packets received",closed)
    install("priority=0,actions=NORMAL\n")
    @assert pyconvert(Float64,net.ping(;timeout="1"))==0.0
    # Packet I/O helper only; network creation/control remains in this Julia process.
    result["vlan_flows"]=install("priority=100,in_port=$inport,dl_type=0x88b5,actions=push_vlan:0x8100,set_field:4197->vlan_vid,output:$outport\npriority=0,actions=drop\n")
    packetfile=joinpath(RUN,"mininet_packet.json")
    h1intf=pyconvert(String,h1.defaultIntf().name);h2intf=pyconvert(String,h2.defaultIntf().name)
    receiver=h2.popen(pylist([PYTHON,"-I","-B",joinpath(HERE,"packet_io.py"),"receive",h2intf,packetfile]))
    @assert timedwait(()->isfile(packetfile*".ready"),2)==:ok
    sendcmd=pyconvert(String,pyimport("shlex").join([PYTHON,"-I","-B",joinpath(HERE,"packet_io.py"),"send",h1intf,packetfile]))
    @assert occursin("SENT",pyconvert(String,h1.cmd(sendcmd)))
    @assert pyconvert(Int,receiver.wait(;timeout=3))==0
    packet=JSON.parsefile(packetfile)
    @assert packet["vlan_id"]==101 && packet["network_namespace"]==namespaces[2]
    result["vlan_id"]=packet["vlan_id"]
    @assert getpid()==result["julia_pid"] && pyconvert(Int,pyimport("os").getpid())==getpid()
    result["resident_interpreter_confirmed"]=true
    net.stop();net_stopped=true
    for shell in shells
        shell.wait(;timeout=3)
    end
    function links_gone()
        all(item->item["ifname"]=="lo",JSON.parse(command(["ip","-json","link","show"])))
    end
    @assert timedwait(links_gone,3)==:ok
    result["mininet_interfaces_removed"]=true
    @assert all(!ispath("/proc/$pid") for pid in pids)
    result["mininet_node_processes_reaped"]=true
    result["status"]="PASS"
    println("JULIA PYTHONCALL MININET OVS PACKET/LIFECYCLE PASS")
catch error
    result["status"]="FAIL";result["error"]=sprint(showerror,error,catch_backtrace());rethrow()
finally
    if receiver!==nothing
        try
            if pyisnone(receiver.poll());receiver.kill();receiver.wait(;timeout=2);end
        catch
        end
    end
    if net!==nothing && !net_stopped
        try;net.stop();net_stopped=true;catch error;result["cleanup_error"]=sprint(showerror,error);end
    end
    for shell in shells
        try;shell.wait(;timeout=3);catch error;result["cleanup_error"]=sprint(showerror,error);end
    end
    if net!==nothing
        removed=timedwait(()->all(item->item["ifname"]=="lo",JSON.parse(command(["ip","-json","link","show"]))),3)==:ok
        result["cleanup_interfaces_removed"]=removed
        result["cleanup_nodes_reaped"]=all(!ispath("/proc/$pid") for pid in pids)
        if !removed || !result["cleanup_nodes_reaped"] || haskey(result,"cleanup_error")
            result["status"]="FAIL"
        end
    end
    for p in reverse(processes)
        try;stop_daemon(p);catch;end
    end
    foreach(close,streams)
    result["ovs_daemons_exited"]=all(process_exited,processes)
    result["ovs_daemons_exited"] || (result["status"]="FAIL")
    open(joinpath(RUN,"network_smoke.toml"),"w") do io;TOML.print(io,result);end
end
@assert result["status"]=="PASS" "cleanup did not complete"
end
main()
