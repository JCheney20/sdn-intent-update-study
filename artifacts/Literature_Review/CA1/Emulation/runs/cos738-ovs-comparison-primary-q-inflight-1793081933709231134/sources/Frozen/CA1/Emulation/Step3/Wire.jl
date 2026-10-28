# Uses the unchanged Step-2 adapter; only the declared link realization is expanded.
function addwire!(a;delay_ms=250)
    @assert isempty(a.evidence["snapshots"])
    left,right="C10","C4"
    raw=a.net.linksBetween(a.nodes[left],a.nodes[right])
    links=collect(PyList{Py}(raw))
    old=only(links)
    for s in (left,right)
        neighbor=s==left ? right : left
        CiscoAdapter.vsctl(a,"--if-exists","del-port",s,a.interfaces[s][neighbor])
    end
    a.net.delLink(old)
    helper=a.net.addHost("wire";inNamespace=false,ip=nothing)
    a.nodes["wire"]=helper
    push!(a.pids,pyconvert(Int,helper.pid));push!(a.shells,helper.shell)
    a.interfaces["wire"]=Dict{String,String}()
    for (index,s) in enumerate((left,right))
        neighbor=s==left ? right : left
        link=a.net.addLink(a.nodes[s],helper;port1=a.ports[(s,neighbor)],port2=index-1)
        @assert pyconvert(String,link.intf1.name)==a.interfaces[s][neighbor]
        interface=pyconvert(String,link.intf2.name)
        a.interfaces["wire"][s]=interface
        CiscoAdapter.command(a,["ip","link","set",a.interfaces[s][neighbor],"up"])
        CiscoAdapter.command(a,["ip","link","set",interface,"up"])
        CiscoAdapter.vsctl(a,"add-port",s,a.interfaces[s][neighbor],"--","set","Interface",a.interfaces[s][neighbor],"ofport_request=$(a.ports[(s,neighbor)])")
    end
    physical=deepcopy(a.interfaces)
    physical[left]["wire"]=pop!(physical[left],right)
    physical[right]["wire"]=pop!(physical[right],left)
    expanded=[(String(n),String(m)) for (n,m) in a.f["physical"]["edges"] if Set((n,m))!=Set((left,right))]
    append!(expanded,[(left,"wire"),("wire",right)])
    @assert length(expanded)==29
    namespace=Dict(n=>readlink("/proc/$(pyconvert(Int,node.pid))/ns/net") for (n,node) in a.nodes)
    @assert namespace["wire"]==readlink("/proc/self/ns/net")
    rootlinks=JSON.parse(CiscoAdapter.command(a,["ip","-details","-json","link","show"]))
    links=Dict{String,Any}(n=>rootlinks for n in [a.f["switches"];"wire"])
    for h in a.f["hosts"];links[h]=JSON.parse(pyconvert(String,a.nodes[h].cmd("ip -details -json link show")));end
    proof=Any[]
    for (n,m) in expanded
        l=only(filter(i->i["ifname"]==physical[n][m],links[n]))
        r=only(filter(i->i["ifname"]==physical[m][n],links[m]))
        @assert l["linkinfo"]["info_kind"]==r["linkinfo"]["info_kind"]=="veth"
        if namespace[n]==namespace[m]
            @assert l["link"]==r["ifname"] && r["link"]==l["ifname"]
        else
            @assert l["link_index"]==r["ifindex"] && r["link_index"]==l["ifindex"]
        end
        push!(proof,Dict("left"=>n,"right"=>m,"left_interface"=>l,"right_interface"=>r))
    end
    ports=Any[]
    for s in a.f["switches"],neighbor in a.f["adjacency"][s]
        port=parse(Int,strip(CiscoAdapter.vsctl(a,"get","interface",a.interfaces[s][neighbor],"ofport")))
        @assert port==a.ports[(s,neighbor)]
        push!(ports,Dict("switch"=>s,"neighbor"=>neighbor,"port"=>port))
    end
    a.evidence["wire_realization"]=Dict("logical_nodes"=>22,"logical_edges"=>28,"helper_nodes"=>1,
        "expanded_edges"=>proof,"physical_interfaces"=>physical,"node_namespaces"=>namespace,"actual_ports"=>ports)
    subprocess=pyimport("subprocess")
    err=pybuiltins.open(joinpath(a.run,"wire-worker.log"),"wb");push!(a.pyfiles,err)
    config=Dict("interfaces"=>[a.interfaces["wire"][left],a.interfaces["wire"][right]],"delay_ms"=>delay_ms)
    p=helper.popen(pylist([ENV["JULIA_PYTHONCALL_EXE"],"-I","-B",joinpath(@__DIR__,"wire.py"),JSON.json(config)]);stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err)
    a.workers["wire"]=p
    info=CiscoAdapter.readreply(a,p)
    @assert info["status"]=="READY" && info["netns"]==namespace["wire"] && info["delay_ns"]==delay_ms*1000000
    a.evidence["workers"]["wire"]=info
    CiscoAdapter.rpc(a,"wire",Dict("op"=>"drain"))
    a
end

# Common application-observation deadline; sequential collection occurs AFTER it.
function collectat!(a,deadline)
    remaining=(Int128(deadline)-Int128(time_ns()))/1e9
    remaining>0 && sleep(Float64(remaining))
    records=Any[];intervals=Any[]
    for n in sort!(collect(keys(a.workers)))
        before=time_ns();response=CiscoAdapter.rpc(a,n,Dict("op"=>"drain"));after=time_ns()
        push!(intervals,Dict("node"=>n,"before_ns"=>before,"after_ns"=>after))
        for event in response["events"];event["node"]=n;push!(records,event);end
    end
    Dict("deadline_ns"=>deadline,"records"=>records,"collection_intervals"=>intervals)
end
