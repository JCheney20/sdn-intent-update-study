# Standalone oracle for the new contract; imports NO historical/production model helpers.
# Run only through run.sh: entry.jl supplies resource proof, TOML/SHA and ROOT.
isdefined(@__MODULE__, :cgdir) || error("use the bounded validation entry point")
const CHECKS=Ref(0)
function ok(condition, label)
    CHECKS[]+=1
    condition || error("CHECK FAILED: "*label)
end
function rejects(f)
    try
        f()
    catch e
        e isa ArgumentError || rethrow()
        return true
    end
    false
end
function source_function(text,name)
    m=match(Regex("^def "*name*"\\(.*?(?=^def |\\z)","ms"),text)
    m===nothing && throw(ArgumentError("source function missing"))
    String(m.match)
end
function graph_inputs(generator, kind)
    names=String[]; adj=Dict{String,Vector{String}}()
    function node(s)
        if !haskey(adj,s);push!(names,s);adj[s]=String[];end
    end
    function edge(a,b)
        node(a);node(b)
        b in adj[a] || push!(adj[a],b)
        a in adj[b] || push!(adj[b],a)
    end
    if kind=="cisco"
        text=source_function(generator,"create_cisco")
        for m in eachmatch(r"G\.add_node\(\"([^\"]+)\", type=\"(?:core|host)\"\)",text)
            node(String(m.captures[1]))
        end
        for m in eachmatch(r"G\.add_edge\(\"([^\"]+)\", \"([^\"]+)\"\)",text)
            edge(String(m.captures[1]),String(m.captures[2]))
        end
        length(names)==22 && sum(length,values(adj))==56 || throw(ArgumentError("unsupported Cisco source shape"))
    else
        # Independent closed-form expansion of the pinned k=4 generator, not eval/import.
        # ponytail: this source gate supports fk=4 only; generalize after a separately approved domain change.
        for fragment in ["core_switches = half_of_ports**2", "counter + half_of_ports", "f\"H{pod}-{e_id}-{h_id}\""]
            occursin(fragment,generator) || throw(ArgumentError("fat-tree source template changed"))
        end
        for c in 0:3;node("C$c");end
        for pod in 0:3
            for a in 0:1
                node("A$pod-$a")
                for c in 2a:2a+1;edge("C$c","A$pod-$a");end
            end
            for e in 0:1
                node("E$pod-$e")
                for a in 0:1;edge("A$pod-$a","E$pod-$e");end
                for h in 0:1
                    node("H$pod-$e-$h");edge("H$pod-$e-$h","E$pod-$e")
                end
            end
        end
    end
    names,adj
end
function ordered_bfs(adj,start,finish)
    queue=[start];parent=Dict(start=>"");head=1
    while head<=length(queue)
        v=queue[head];head+=1
        v==finish && break
        for z in adj[v]
            haskey(parent,z) && continue
            parent[z]=v;push!(queue,z)
        end
    end
    haskey(parent,finish) || throw(ArgumentError("unreachable endpoint"))
    path=[finish]
    while last(path)!=start;push!(path,parent[last(path)]);end
    reverse(path)
end
function literal_assignment(text,name)
    m=match(Regex("(?m)^    "*name*" = f?\"([^\"]+)\""),text)
    m===nothing && throw(ArgumentError("unsupported endpoint expression"))
    value=replace(String(m.captures[1]),"{k-1}"=>"3","{max_id}"=>"1")
    occursin('{',value) && throw(ArgumentError("unresolved source expression"))
    value
end
triples(path)=Set((path[i],path[i-1],path[i+1]) for i in 2:length(path)-1)
function union_ranks(rows)
    next=Dict{String,Set{String}}()
    for (s,_,z) in rows;push!(get!(next,s,Set{String}()),z);end
    ranks=Dict{String,Int}();active=Set{String}()
    function visit(s)
        !haskey(next,s) && return 0
        haskey(ranks,s) && return ranks[s]
        s in active && throw(ArgumentError("forwarding union contains a cycle"))
        push!(active,s)
        rank=1+maximum(visit(z) for z in next[s])
        delete!(active,s);ranks[s]=rank
        rank
    end
    for s in keys(next);visit(s);end
    ranks
end
function raw_fixture(kind,generator,detector)
    names,adj=graph_inputs(generator,kind)
    prep=source_function(detector,kind=="cisco" ? "prep_trial_cisco" : "prep_trial")
    occursin("host_ip = IPv4Address(\"10.0.0.0\")",prep) || throw(ArgumentError("host IP changed"))
    prefixes=[String(m.captures[1]) for m in eachmatch(r"(?:source|dest)_match=IPv4Network\(\"([^\"]+)\"\)",prep)]
    length(prefixes)==4 && all(==("10.0.0.0/8"),prefixes) || throw(ArgumentError("unsupported prefix domain"))
    if kind!="cisco"
        occursin("max_id = (k // 2) - 1",prep) || throw(ArgumentError("endpoint formula changed"))
    end
    old=ordered_bfs(adj,literal_assignment(prep,"first_pod_first_host"),literal_assignment(prep,"last_pod_last_host"))
    new=ordered_bfs(adj,literal_assignment(prep,"first_pod_second_host"),literal_assignment(prep,"last_pod_first_host"))
    ro=triples(old);rn=triples(new);ranks=union_ranks(union(ro,rn))
    switches=Set(filter(s->!startswith(s,"H"),names));hosts=setdiff(Set(names),switches)
    changed=sort!([s for s in keys(ranks) if Set(filter(x->x[1]==s,ro))!=Set(filter(x->x[1]==s,rn))])
    (kind=kind,names=names,adj=adj,switches=switches,hosts=hosts,old=old,new=new,ro=ro,rn=rn,
        ranks=ranks,H=maximum(values(ranks)),changed=changed)
end

# Concrete tables: key is (switch, physical incoming neighbor, ACTUAL forwarding tag).
# Authorization epoch is retained in the probe and is never used by forwarding/gates.
struct View
    rows::Dict{Tuple{String,String,Int},String}
    oldopen::Bool
    newopen::Bool
    newtag::Int
end
initial(f)=View(Dict((s,i,0)=>z for (s,i,z) in f.ro),true,false,0)
function apply_batch(v,action,f)
    kind,s=action;rows=copy(v.rows);old=v.oldopen;new=v.newopen;tag=v.newtag
    if kind==:close;old=false
    elseif kind==:open;new=true
    elseif kind==:commit;old=false;new=true;tag=1
    elseif kind in (:replace,:replace_activate)
        filter!(kv->kv.first[1]!=s,rows)
        for (sw,i,z) in f.rn;sw==s && (rows[(sw,i,0)]=z);end
        if kind==:replace_activate
            s==f.old[2] || throw(ArgumentError("activation must be local to the common ingress"))
            old=false;new=true;tag=0
        end
    elseif kind==:stage
        for (sw,i,z) in f.rn;sw==s && (rows[(sw,i,1)]=z);end
    elseif kind==:clean
        filter!(kv->!(kv.first[1]==s && kv.first[3]==0),rows)
    else;throw(ArgumentError("unknown batch"))
    end
    View(rows,old,new,tag)
end
function plan(f,kind)
    ingress=f.old[2]
    f.new[2]==ingress || throw(ArgumentError("commit is not switch-local"))
    if kind==:Q
        Dict(1=>[(:close,ingress)],f.H+2=>[(:replace,s) for s in f.changed],f.H+3=>[(:open,ingress)])
    elseif kind==:V
        Dict(1=>[(:stage,s) for s in f.new[2:end-1]],2=>[(:commit,ingress)],
            f.H+3=>[(:clean,s) for s in f.old[2:end-1]])
    else;throw(ArgumentError("unknown plan"))
    end
end
function round_views(v,actions,f)
    length(Set(last.(actions)))==length(actions) || throw(ArgumentError("noncommuting same-switch batches"))
    result=View[]
    for mask in 0:(1<<length(actions))-1
        w=v
        for (i,a) in enumerate(actions);isodd(mask>>(i-1)) && (w=apply_batch(w,a,f));end
        push!(result,w)
    end
    result,last(result)
end
function final_valid(v,f,kind)
    tag=kind==:V ? 1 : 0
    expected=Dict((s,i,tag)=>z for (s,i,z) in f.rn)
    !v.oldopen && v.newopen && v.newtag==tag && v.rows==expected
end
function prefix_matches(source,dest)
    source>>24==0x0a && dest>>24==0x0a
end
function outputs(v,node,incoming,tag,source,dest;fault=:none)
    fault==:no_prefix || prefix_matches(source,dest) || return String[]
    sort!(unique([z for ((s,i,t),z) in v.rows if s==node &&
        (i==incoming || fault==:no_ingress) && (t==tag || fault==:no_tag)]))
end
# Named tuples make the checked state explicit; no production packet/type is imported.
function request(f,epoch,arrival)
    path=epoch==0 ? f.old : f.new
    (node=path[2],incoming=path[1],tag=0,epoch=epoch,age=0,status=:waiting,
        arrival=arrival,admitted=-999,ended=-999,sourceip=UInt32(0x0a000000),destip=UInt32(0x0a000000))
end
function inflight(f,i)
    1<=i<length(f.old)-2 || throw(ArgumentError("unreachable pre-update position"))
    merge(request(f,0,-999),(node=f.old[i+2],incoming=f.old[i+1],age=i,status=:live,admitted=1-i))
end
terminal(p)=p.status in (:delivered,:wrong_delivery,:drop,:rejected)
function admission_channel(p,f)
    p.node==f.old[2] && p.incoming==first(f.old) && return :old
    p.node==f.new[2] && p.incoming==first(f.new) && return :new
    throw(ArgumentError("request is not at a declared physical source ingress"))
end
function service(p,v,f,r;fault=:none)
    terminal(p) && return [p]
    r>p.arrival || return [p]
    q=p
    if p.status==:waiting
        # Authorization epoch belongs to the monitor, never to admission/forwarding.
        channel=fault==:epoch_gate ? (p.epoch==0 ? :old : :new) : admission_channel(p,f)
        open=channel==:old ? v.oldopen : v.newopen
        !open && return channel==:old ? [merge(p,(status=:rejected,ended=r))] : [p]
        q=merge(p,(status=:live,admitted=r,tag=(channel==:old ? 0 : v.newtag)))
    end
    destinations=outputs(v,q.node,q.incoming,q.tag,q.sourceip,q.destip;fault)
    isempty(destinations) && return [merge(q,(status=:drop,age=q.age+1,ended=r))]
    result=typeof(q)[]
    for z in destinations
        expected=q.epoch==0 ? last(f.old) : last(f.new)
        state=z in f.hosts ? (z==expected ? :delivered : :wrong_delivery) : :live
        push!(result,merge(q,(node=z,incoming=q.node,age=q.age+1,status=state,
            ended=(state==:live ? -999 : r))))
    end
    result
end
function explore(f,schedule,p;rounds,cap=10000,fault=:none)
    frontier=Set([p]);v=initial(f);peak=0;states=1
    oldcount=Dict(s=>count(x->x[1]==s,f.ro) for s in f.switches)
    newcount=Dict(s=>count(x->x[1]==s,f.rn) for s in f.switches)
    for r in 1:rounds
        length(frontier)>cap && return (complete=false,controller_settled=false,packets=frontier,view=v,peak=peak,states=states)
        actions=get(schedule,r,Tuple{Symbol,String}[])
        views,v=round_views(v,actions,f)
        for view in views,s in f.switches
            peak=max(peak,count(k->k[1]==s,keys(view.rows))-max(oldcount[s],newcount[s]))
        end
        next=empty(frontier)
        for q in frontier,view in views,z in service(q,view,f,r;fault);push!(next,z);end
        frontier=next;states+=length(frontier)
        length(frontier)>cap && return (complete=false,controller_settled=false,packets=frontier,view=v,peak=peak,states=states)
    end
    (complete=true,controller_settled=all(r->r<=rounds,keys(schedule)),packets=frontier,view=v,peak=peak,states=states)
end
# Joint packets share one evolving table trace. Nested masks preserve causal order:
# two independent per-packet mask choices would admit impossible round schedules.
function explore_joint(f,schedule,p,q;rounds,cap=10000,fault=:none)
    frontier=Set([(p,q)]);v=initial(f);states=1
    for r in 1:rounds
        length(frontier)>cap && return (complete=false,pairs=frontier,view=v,states=states)
        actions=get(schedule,r,Tuple{Symbol,String}[])
        views,v=round_views(v,actions,f)
        masks=nested_views(length(actions))
        next=empty(frontier)
        for (a,b) in frontier,(i,j) in masks
            for x in service(a,views[i+1],f,r;fault),y in service(b,views[j+1],f,r;fault)
                push!(next,(x,y))
                length(next)>cap && return (complete=false,pairs=next,view=v,states=states+length(next))
            end
        end
        frontier=next;states+=length(frontier)
    end
    (complete=all(r->r<=rounds,keys(schedule)),pairs=frontier,view=v,states=states)
end
function qualified(result,f,kind)
    result.complete && result.controller_settled && final_valid(result.view,f,kind) && all(p->
        (p.status==:rejected && p.epoch==0 && p.admitted==-999 && p.arrival>=0) ||
        (p.status==:delivered && p.age<=f.H),result.packets)
end
function control_costs(f,schedule)
    v=initial(f);batches=insertions=removals=gates=tags=0
    for r in sort!(collect(keys(schedule))),action in schedule[r]
        before=v;v=apply_batch(v,action,f);batches+=1
        insertions+=length(setdiff(Set(v.rows),Set(before.rows)))
        removals+=length(setdiff(Set(before.rows),Set(v.rows)))
        gates+=(before.oldopen!=v.oldopen)+(before.newopen!=v.newopen)
        tags+=(before.newtag!=v.newtag)
    end
    (switch_batches=batches,row_insertions=insertions,row_removals=removals,gate_mutations=gates,tag_mutations=tags)
end
history_live(applied,H,round;early=false)=early ? round<applied+H : round<=applied+H

# An independent raw-row witness checker. It does not call service/outputs/apply_batch.
# A claimed new epoch with an old source is rejected rather than forgiving wrong delivery.
function trace_check(f,source,epoch,incoming,age,trace,rows)
    epoch==0 && source==first(f.old) || throw(ArgumentError("forged pre-update admission epoch"))
    position=findfirst(==(trace[1]),f.old)
    position!==nothing && 3<=position<length(f.old) && age==position-2 && incoming==f.old[position-1] ||
        throw(ArgumentError("invalid old in-flight position/history"))
    previous=incoming
    for j in 1:length(trace)-1
        (trace[j],previous,trace[j+1]) in rows || throw(ArgumentError("trace not supported by raw ingress row"))
        previous=trace[j]
    end
    age+length(trace)-1<=f.H || throw(ArgumentError("trace exceeds packet bound"))
    expected=epoch==0 ? last(f.old) : last(f.new)
    last(trace)==expected ? :delivered : :wrong_delivery
end

# Cross-check the commutation reduction against literal permutations, including two probes.
function literal_views(k)
    result=Set{Tuple{Int,Int}}()
    function visit(remaining,seen,a,b)
        if isempty(remaining);push!(result,(a,b));return;end
        for x in remaining
            visit(filter(!=(x),remaining),x<=k ? seen|(1<<(x-1)) : seen,
                x==k+1 ? seen : a,x==k+2 ? seen : b)
        end
    end
    visit(collect(1:k+2),0,-1,-1)
    result
end
function nested_views(k)
    Set((a,b) for a in 0:(1<<k)-1 for b in 0:(1<<k)-1 if (a&b)==a || (a&b)==b)
end

input=TOML.parsefile(joinpath(ROOT,"Handover_Bounds.toml"))
generator=read(joinpath(ROOT,"inputs/fattree-12735280.py.txt"),String)
detector=read(joinpath(ROOT,"inputs/detector-12735280.py.txt"),String)
ok(bytes2hex(sha256(generator))==input["source_generator_sha256"],"generator pin")
ok(bytes2hex(sha256(detector))==input["source_detector_sha256"],"detector pin")
for k in 0:5;ok(literal_views(k)==nested_views(k),"two-probe interleaving reduction k=$k");end
ok(rejects(()->union_ranks(Set([("x","a","y"),("y","x","x")]))),"cycle invalidates rank proof")
reports=Dict{String,Any}[]
for (kind,declared) in zip(["cisco","fat4"],input["fixtures"])
    f=raw_fixture(kind,generator,detector);before=CHECKS[]
    ok(length(f.switches)==declared["physical_switch_count"] && length(f.hosts)==declared["physical_host_count"],"raw graph counts")
    ok(f.old==declared["old_path"] && f.new==declared["new_path"],"ordered raw path derivation")
    ok(f.ro==Set(Tuple(String.(x)) for x in declared["old_rows"]),"independent old rows")
    ok(f.rn==Set(Tuple(String.(x)) for x in declared["new_rows"]),"independent target rows")
    ok(f.ranks==Dict(String(s)=>r for (s,r) in zip(declared["ranked_switches"],declared["ranks"])) && f.H==declared["H"],"independent union ranks")
    ok(Set(f.changed)==Set(declared["changed_switches"]),"independent changed switches")
    for host in setdiff(f.hosts,Set([first(f.old),first(f.new)]))
        ok(all(t->t[2]!=host,union(f.ro,f.rn)),"other host has no first-hop union match")
    end
    ok(all(t->!(t[3] in f.hosts) || t[3] in (last(f.old),last(f.new)),union(f.ro,f.rn)),
        "all raw union host egresses are old/new destinations")
    # Changing monitor-only authorization must not change admission or tag assignment.
    closed=apply_batch(initial(f),(:close,f.old[2]),f)
    old=request(f,0,0);forged=merge(old,(epoch=1,))
    ok(only(service(old,closed,f,1)).status==only(service(forged,closed,f,1)).status==:rejected,
        "physical old ingress cannot evade closure with forged epoch")
    ok(only(service(forged,closed,f,1;fault=:epoch_gate)).status==:waiting,
        "epoch-aware admission defect distinguished")
    committed=apply_batch(initial(f),(:commit,f.old[2]),f)
    fresh=request(f,1,0);forgednew=merge(fresh,(epoch=0,))
    observed(p)=(p.node,p.incoming,p.tag,p.status,p.admitted,p.age)
    ok(observed(only(service(fresh,committed,f,2)))==observed(only(service(forgednew,committed,f,2))),
        "physical new ingress assigns tag independently of epoch")
    ok(rejects(()->service(merge(fresh,(incoming="FAKE_HOST",)),committed,f,2)),
        "unknown admission ingress rejected")
    u=length(f.ranks);N=3u+2;C=(N+1)*(f.H+1);T=C+1+f.H
    ok(C==declared["common_controller_bound"] && T==declared["common_observation_horizon"],"common controller arithmetic")
    cases=0;statevisits=0;jointcases=0;jointvisits=0
    for policy in [:Q,:V]
        schedule=plan(f,policy);openround=policy==:Q ? f.H+3 : 2
        peak=0
        costs=control_costs(f,schedule)
        for key in keys(costs)
            ok(costs[key]==declared[lowercase(string(policy))*"_"*string(key)],"raw action cost: $key")
        end
        probes=[inflight(f,i) for i in 1:length(f.old)-3]
        # Old requests through/just after closure; all new boundary arrivals through C.
        append!(probes,[request(f,0,a) for a in 0:3])
        append!(probes,[request(f,1,a) for a in 0:C])
        for probe in probes
            result=explore(f,schedule,probe;rounds=T)
            cases+=1;statevisits+=result.states;peak=max(peak,result.peak)
            ok(qualified(result,f,policy),"$kind $policy complete service/isolation/target coverage")
            for q in result.packets
                if q.epoch==1
                    ok(q.admitted-q.arrival<=max(openround-q.arrival,0)+1,"request waiting from arrival")
                    ok(q.ended-q.arrival<=max(openround-q.arrival,0)+1+f.H,"request-to-delivery bound")
                end
                q.status==:delivered && ok(q.age<=f.H,"historical packet age")
            end
        end
        # Targeted actual joint exploration, not merely mask algebra. Every old
        # boundary position and launch 0:3 is paired with four new-arrival boundaries.
        oldprobes=[inflight(f,i) for i in 1:length(f.old)-3]
        append!(oldprobes,[request(f,0,a) for a in 0:3])
        for oldprobe in oldprobes,arrival in unique([0,openround-1,openround,C])
            newprobe=request(f,1,arrival)
            joint=explore_joint(f,schedule,oldprobe,newprobe;rounds=T)
            jointcases+=1;jointvisits+=joint.states
            ok(joint.complete && final_valid(joint.view,f,policy),"joint exploration settled with exact target")
            for (index,probe) in enumerate((oldprobe,newprobe))
                projected=Set(pair[index] for pair in joint.pairs)
                single=explore(f,schedule,probe;rounds=T)
                ok(single.complete && projected==single.packets,"joint/single reachable terminal projection agrees")
                ok(qualified(merge(single,(packets=projected,)),f,policy),"joint projection delivery obligations")
            end
            ok(all(pair->pair[2].admitted-arrival<=max(openround-arrival,0)+1 &&
                pair[2].ended-arrival<=max(openround-arrival,0)+1+f.H,joint.pairs),"joint request clocks preserved")
        end
        limitedjoint=explore_joint(f,schedule,request(f,0,0),request(f,1,0);rounds=T,cap=0)
        ok(!limitedjoint.complete,"joint truncation is incomplete")
        ok(peak==(policy==:Q ? 0 : 1),"forwarding row peak")
        # A cap hit must not be counted as full coverage or PASS.
        truncated=explore(f,schedule,request(f,1,0);rounds=T,cap=0)
        ok(!truncated.complete && !qualified(truncated,f,policy),"partial coverage never PASS")
    end
    # Executable ordinary negative: use the original target replacements immediately.
    ordinary=Dict(1=>[(:replace,s) for s in f.changed])
    neg=declared["ordinary_negative"];age=Int(neg["initial_age"])
    negative=explore(f,ordinary,inflight(f,age);rounds=f.H+1)
    ok(negative.complete && any(p->p.status==:wrong_delivery,negative.packets),"ordinary cross-delivery witness")
    trace=String.(neg["expected_suffix"])
    ok(trace_check(f,String(neg["source"]),0,String(neg["incoming_neighbor"]),age,trace,f.rn)==:wrong_delivery,"separate raw-row trace checker")
    ok(rejects(()->trace_check(f,String(neg["source"]),1,String(neg["incoming_neighbor"]),age,trace,f.rn)),"epoch forgery cannot forgive witness")
    ok(rejects(()->trace_check(f,String(neg["source"]),0,"FAKE_PORT",age,trace,f.rn)),"wrong trace incoming port rejected")
    ok(rejects(()->trace_check(f,String(neg["source"]),0,String(neg["incoming_neighbor"]),1,trace,f.rn)),"reset packet history rejected")
    # Prefix/port/tag matching controls use the lookup primitive, not final verdict labels.
    v=initial(f);s,i,z=first(f.ro)
    ok(isempty(outputs(v,s,"FAKE_PORT",0,UInt32(0x0a000000),UInt32(0x0a000000))),"physical incoming port required")
    ok(!isempty(outputs(v,s,"FAKE_PORT",0,UInt32(0x0a000000),UInt32(0x0a000000);fault=:no_ingress)),"missing-ingress defect exposed")
    for (src,dst) in [(0x0b000000,0x0a000000),(0x0a000000,0x0b000000)]
        ok(isempty(outputs(v,s,i,0,src,dst)),"source and destination prefix required")
        ok(!isempty(outputs(v,s,i,0,src,dst;fault=:no_prefix)),"prefix defect exposed")
    end
    staged=v
    for a in plan(f,:V)[1];staged=apply_batch(staged,a,f);end
    q=inflight(f,age)
    good=service(q,staged,f,1)
    bad=service(q,staged,f,1;fault=:no_tag)
    ok(all(p->p.status!=:wrong_delivery,good),"correct tag retains old path")
    # Fat-tree wrong branch reaches its host one lookup later, so inspect possible next hop too.
    bad2=vcat(bad,[z for p in bad for z in service(p,staged,f,2;fault=:no_tag)])
    ok(any(p->p.status==:wrong_delivery,bad2),"missing-tag defect exposed")
    early=plan(f,:V);cleanup=pop!(early,f.H+3);early[3]=cleanup
    earlyresult=explore(f,early,inflight(f,1);rounds=T)
    ok(any(p->p.status==:drop,earlyresult.packets),"premature cleanup defect exposed")
    missing=plan(f,:V);lastsw=f.new[end-1]
    filter!(a->last(a)!=lastsw,missing[1])
    missingresult=explore(f,missing,request(f,1,0);rounds=T)
    ok(!qualified(missingresult,f,:V) && any(p->p.status==:drop,missingresult.packets),"opening without full staging rejected")
    never=plan(f,:Q);delete!(never,f.H+3)
    neverresult=explore(f,never,request(f,1,0);rounds=T)
    ok(neverresult.complete && !qualified(neverresult,f,:Q),"never-admit cannot give vacuous PASS")
    ended=explore(f,plan(f,:Q),request(f,1,0);rounds=T).view
    ok(!final_valid(View(ended.rows,true,true,0),f,:Q),"false completion/old admission rejected")
    ok(!final_valid(View(merge(ended.rows,initial(f).rows),false,true,0),f,:Q),"missing cleanup/target mismatch rejected")
    # Expiry after H FULL subsequent rounds; expiry at the final same-round boundary is too early.
    for r in 1:3
        ok(history_live(r,f.H,r+f.H) && !history_live(r,f.H,r+f.H+1),"history expiry boundary obligation")
        ok(!history_live(r,f.H,r+f.H;early=true),"one-round-early expiry mutation distinguished")
    end
    future=plan(f,:Q);future[T+1]=[(:close,f.old[2])]
    future_result=explore(f,future,request(f,1,0);rounds=T)
    ok(!qualified(future_result,f,:Q),"outstanding future command prevents false completion")
    unsafejoint=explore_joint(f,ordinary,inflight(f,age),request(f,1,0);rounds=T)
    ok(unsafejoint.complete && any(pair->pair[1].status==:wrong_delivery,unsafejoint.pairs),
        "joint exploration retains ordinary wrong-delivery witness")
    push!(reports,Dict("fixture"=>kind,"checks"=>CHECKS[]-before,"probe_cases"=>cases,
        "joint_probe_cases"=>jointcases,"joint_boundary_state_visits"=>jointvisits,
        "joint_projection_agreement"=>true,"physical_ingress_admission_checked"=>true,
        "boundary_state_visits"=>statevisits,"packet_bound"=>f.H,"controller_bound"=>C,"observation_horizon"=>T,
        "ordinary_witness_confirmed"=>true,"Q_V_probe_coverage_complete"=>true))
    println("ORACLE_FIXTURE ",kind," checks=",CHECKS[]-before," cases=",cases," boundary_states=",statevisits,
        " joint_cases=",jointcases," joint_boundary_states=",jointvisits)
end
Dict("status"=>"PASS","checks"=>CHECKS[],"fixtures"=>reports,
    "scope"=>"standalone raw-input Q/V oracle and listed defect controls; NOT production differential or Python replay",
    "reduction"=>"single-probe projections under controller/packet independence; targeted joint Q/V projections checked; two-probe mask reduction checked against permutations through five switch batches",
    "full_CCG_adapter_validated"=>false,"python_reference_replay_validated"=>false,
    "production_transition_equivalence_validated"=>false)
