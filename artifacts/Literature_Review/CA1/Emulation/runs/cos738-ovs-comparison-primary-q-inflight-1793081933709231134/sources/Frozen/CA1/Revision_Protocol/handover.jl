# Candidate Q/V adapter for the revised contract. No oracle or historical imports.
module Handover

struct Domain
    names::Vector{String}
    ids::Dict{String,Int}
    old::Vector{Int}
    new::Vector{Int}
    hosts::BitVector
    oldtable::Array{Int,3}
    newtable::Array{Int,3}
    H::Int
end
function Domain(fixture)
    paths=[String.(fixture[k]) for k in ("old_path","new_path")]
    all(p->length(p)>=3 && length(unique(p))==length(p),paths) || throw(ArgumentError("invalid path"))
    all(p->startswith(first(p),"H") && startswith(last(p),"H") &&
        all(s->!startswith(s,"H"),p[2:end-1]),paths) || throw(ArgumentError("unsupported physical labels"))
    paths[1][2]==paths[2][2] && paths[1][1]!=paths[2][1] || throw(ArgumentError("requires distinct sources at one ingress"))
    names=sort!(unique(vcat(paths...)));ids=Dict(s=>i for (i,s) in enumerate(names));n=length(names)
    old,new=([ids[s] for s in p] for p in paths)
    tables=[zeros(Int,n,n,2) for _ in 1:2]
    for (p,t) in zip((old,new),tables),j in 2:length(p)-1;t[p[j],p[j-1],1]=p[j+1];end
    # Bottom-up sink elimination, independent of the oracle's recursive rank DFS.
    remaining=Set(vcat(old[2:end-1],new[2:end-1]));ranks=zeros(Int,n)
    while !isempty(remaining)
        ready=[s for s in remaining if all(z->!(z in remaining),
            [t[s,i,1] for t in tables for i in 1:n if t[s,i,1]!=0])]
        isempty(ready) && throw(ArgumentError("cyclic forwarding union"))
        for s in ready
            ranks[s]=1+maximum([ranks[t[s,i,1]] for t in tables for i in 1:n if t[s,i,1]!=0];init=0)
        end
        setdiff!(remaining,ready)
    end
    H=maximum(ranks)
    H==fixture["H"] || throw(ArgumentError("declared packet bound mismatch"))
    Domain(names,ids,old,new,BitVector(startswith.(names,"H")),tables[1],tables[2],H)
end
struct Tables
    rows::Array{Int,3}
    oldopen::Bool
    newopen::Bool
    tag::Int
end
initial(d)=Tables(copy(d.oldtable),true,false,0)
struct Command
    kind::Symbol
    switch::Int
end
function apply(t,c,d)
    rows=copy(t.rows);old=t.oldopen;new=t.newopen;tag=t.tag;s=c.switch
    1<=s<=length(d.names) && !d.hosts[s] || throw(ArgumentError("command is not at a switch"))
    if c.kind in (:close,:open,:commit)
        s==d.old[2] || throw(ArgumentError("nonlocal admission command"))
        if c.kind==:close;old=false
        elseif c.kind==:open;new=true
        else;old=false;new=true;tag=1
        end
    elseif c.kind in (:replace,:replace_activate)
        rows[s,:,:].=d.newtable[s,:,:]
        if c.kind==:replace_activate
            s==d.old[2] || throw(ArgumentError("nonlocal activation"))
            old=false;new=true;tag=0
        end
    elseif c.kind==:stage
        rows[s,:,2].=d.newtable[s,:,1]
    elseif c.kind==:clean
        rows[s,:,1].=0
    else;throw(ArgumentError("unsupported command"))
    end
    Tables(rows,old,new,tag)
end
function plan(d,policy)
    switches=findall(.!d.hosts)
    if policy==:ordinary
        changed=[s for s in switches if d.oldtable[s,:,:]!=d.newtable[s,:,:]]
        Dict(1=>[Command(s==d.old[2] ? :replace_activate : :replace,s) for s in changed])
    elseif policy==:Q
        changed=[s for s in switches if d.oldtable[s,:,:]!=d.newtable[s,:,:]]
        Dict(1=>[Command(:close,d.old[2])],d.H+2=>[Command(:replace,s) for s in changed],
            d.H+3=>[Command(:open,d.new[2])])
    elseif policy==:V
        Dict(1=>[Command(:stage,s) for s in d.new[2:end-1]],2=>[Command(:commit,d.old[2])],
            d.H+3=>[Command(:clean,s) for s in d.old[2:end-1]])
    else;throw(ArgumentError("only candidate Q/V adapters supported"))
    end
end
function validate_plan(d,schedule)
    used=Set{Tuple{Symbol,Int}}();gates=0;previous=0
    union_switches=Set(vcat(d.old[2:end-1],d.new[2:end-1]))
    for r in sort!(collect(keys(schedule)))
        r>=1 && r-previous<=d.H+1 || throw(ArgumentError("progress interval exceeds bound"))
        commands=schedule[r]
        !isempty(commands) && length(unique(c.switch for c in commands))==length(commands) ||
            throw(ArgumentError("empty phase or multiple batches at one switch"))
        for c in commands
            c.switch in union_switches || throw(ArgumentError("command outside union"))
            key=(c.kind==:replace_activate ? :replace : c.kind,c.switch)
            key in used && throw(ArgumentError("repeated action slot"))
            push!(used,key)
            if c.kind in (:close,:open,:commit)
                gates+=1;c.switch==d.old[2] || throw(ArgumentError("nonlocal gate"))
            else
                c.kind in (:replace,:replace_activate,:stage,:clean) || throw(ArgumentError("unknown action slot"))
                if c.kind==:replace_activate
                    gates+=1;c.switch==d.old[2] || throw(ArgumentError("nonlocal activation"))
                end
            end
        end
        previous=r
    end
    gates<=2 && length(used)<=3length(union_switches)+2 || throw(ArgumentError("action envelope exceeded"))
    previous<=(3length(union_switches)+3)*(d.H+1) || throw(ArgumentError("controller deadline exceeded"))
    true
end

# Numeric located packets and dense port/tag tables, separate from string-row oracle.
struct Packet
    node::Int
    input::Int
    tag::Int
    epoch::Int
    age::Int
    status::Symbol
    arrival::Int
    admitted::Int
    ended::Int
    sourceip::UInt32
    destip::UInt32
end
function serve(p,t,d,r;fault=:none)
    p.status in (:delivered,:wrong_delivery,:drop,:rejected) && return p
    p.arrival>=r && return p
    node,input,tag,age,status,admitted=p.node,p.input,p.tag,p.age,p.status,p.admitted
    if status==:waiting
        node==d.old[2] || throw(ArgumentError("request not at ingress"))
        old=input==d.old[1]
        old || input==d.new[1] || throw(ArgumentError("unknown source port"))
        if !(old ? t.oldopen : t.newopen)
            return old ? Packet(node,input,tag,p.epoch,age,:rejected,p.arrival,admitted,r,p.sourceip,p.destip) : p
        end
        admitted=r;tag=old ? 0 : t.tag
    end
    valid=(p.sourceip&0xff000000)==0x0a000000 && (p.destip&0xff000000)==0x0a000000
    z=valid ? t.rows[node,input,(fault==:ignore_tag ? 0 : tag)+1] : 0
    if z==0
        status=:drop;ended=r
    else
        input=node;node=z
        status=d.hosts[z] ? (z==(p.epoch==0 ? d.old[end] : d.new[end]) ? :delivered : :wrong_delivery) : :live
        ended=status==:live ? -999 : r
    end
    Packet(node,input,tag,p.epoch,age+1,status,p.arrival,admitted,ended,p.sourceip,p.destip)
end
function finish(t,commands,d)
    for c in commands;t=apply(t,c,d);end
    t
end
# Literal event recursion: reorder command applications and one packet event.
# ponytail: factorial enumeration is intentional for tiny validation, not a production search optimizer.
function successors(p,t,commands,d,r;fault=:none)
    length(unique(c.switch for c in commands))==length(commands) || throw(ArgumentError("dependent same-switch commands"))
    final=finish(t,commands,d)
    if isempty(commands) || p.status in (:delivered,:wrong_delivery,:drop,:rejected) || p.arrival>=r
        return Set([serve(p,t,d,r;fault)]),final
    end
    result=Set{Packet}()
    function visit(current,remaining,packet,served)
        if isempty(remaining)
            push!(result,served ? packet : serve(packet,current,d,r;fault))
            return
        end
        if !served;visit(current,remaining,serve(packet,current,d,r;fault),true);end
        for i in eachindex(remaining)
            rest=[remaining[j] for j in eachindex(remaining) if i!=j]
            visit(apply(current,remaining[i],d),rest,packet,served)
        end
    end
    visit(t,commands,p,false)
    result,final
end
function target(t,d,policy)
    expected=zeros(Int,size(t.rows))
    expected[:,:,policy==:V ? 2 : 1].=d.newtable[:,:,1]
    !t.oldopen && t.newopen && t.tag==(policy==:V ? 1 : 0) && t.rows==expected
end
end
