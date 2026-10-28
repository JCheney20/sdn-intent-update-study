# Topology/flow logic: Weintraub et al., Zenodo 12735280 (CC BY 4.0).
# Panther/BFS: NetworkX 3.2.1 (BSD-3-Clause); license retained in sources/.
# Julia implementation with disclosed RNG/tie adaptations, not original code execution.
module SourceDetector
using Random
export Graph, cisco, fattree, shortest, scenario, baseline, caches, coverage, sample_count,
       score_walks, rank_cache, addnode!, edge!

# ponytail: insertion-ordered adjacency for the two pinned artifact generators.
mutable struct Graph
    names::Vector{String}
    ids::Dict{String,Int}
    out::Vector{Vector{Int}}
    incoming::Vector{Vector{Int}}
    directed::Bool
end
Graph(;directed=false)=Graph(String[],Dict{String,Int}(),Vector{Int}[],Vector{Int}[],directed)
function addnode!(g,name)
    get!(g.ids,name) do
        push!(g.names,name);push!(g.out,Int[]);push!(g.incoming,Int[])
        length(g.names)
    end
end
function arc!(g,a,b)
    b in g.out[a] || push!(g.out[a],b)
    a in g.incoming[b] || push!(g.incoming[b],a)
end
function edge!(g,an,bn)
    a=addnode!(g,an);b=addnode!(g,bn)
    arc!(g,a,b);g.directed || arc!(g,b,a)
end
function remove!(g,an,bn)
    a=g.ids[an];b=g.ids[bn]
    b in g.out[a] || error("artifact removal references absent edge $an->$bn")
    filter!(!=(b),g.out[a]);filter!(!=(a),g.incoming[b])
end
function cisco()
    g=Graph()
    for i in 1:10;addnode!(g,"C$i");end
    for i in 1:12;addnode!(g,"H$i");end
    for (a,b) in [(7,8),(7,9),(7,10),(8,9),(8,10),(1,9),(9,10),
                  (9,2),(9,3),(9,6),(10,2),(10,3),(10,4),(4,5)]
        edge!(g,"C$a","C$b")
    end
    for (h,s) in [(1,1),(2,1),(2,2),(3,6),(4,6),(5,2),(6,2),
                  (7,2),(7,3),(8,3),(9,5),(10,5),(11,4),(12,4)]
        edge!(g,"H$h","C$s")
    end
    g
end
function fattree(k=4)
    @assert k>=4
    half=k÷2;g=Graph()
    for i in 0:half^2-1;addnode!(g,"C$i");end
    for p in 0:k-1
        for a in 0:half-1
            name="A$p-$a";addnode!(g,name)
            for c in a*half:(a+1)*half-1;edge!(g,"C$c",name);end
        end
        for e in 0:half-1
            name="E$p-$e";addnode!(g,name)
            for a in 0:half-1;edge!(g,"A$p-$a",name);end
            for h in 0:half-1;edge!(g,"H$p-$e-$h",name);end
        end
    end
    g
end
function shortest(g,source,target)
    s=g.ids[source];t=g.ids[target];s==t && return [source]
    pred=zeros(Int,length(g.names));succ=copy(pred);pred[s]=-1;succ[t]=-1
    front=[s];back=[t];meet=0
    while !isempty(front) && !isempty(back) && meet==0
        if length(front)<=length(back)
            level=front;front=Int[]
            for v in level
                for w in g.out[v]
                    if pred[w]==0;pred[w]=v;push!(front,w);end
                    if succ[w]!=0;meet=w;break;end
                end
                meet!=0 && break
            end
        else
            level=back;back=Int[]
            for v in level
                for w in g.incoming[v]
                    if succ[w]==0;succ[w]=v;push!(back,w);end
                    if pred[w]!=0;meet=w;break;end
                end
                meet!=0 && break
            end
        end
    end
    meet==0 && return String[]
    path=Int[];at=meet
    while at!=-1;push!(path,at);at=pred[at];end
    reverse!(path);at=succ[meet]
    while at!=-1;push!(path,at);at=succ[at];end
    g.names[path]
end
const Rule=NTuple{3,String} # switch, ingress device, egress device
triples(path)=Rule[(path[i],path[i-1],path[i+1]) for i in 2:length(path)-1]
function scenario(g,kind)
    if kind=="cisco"
        old=shortest(g,"H5","H9");new=shortest(g,"H6","H10")
    elseif kind=="fat4"
        old=shortest(g,"H0-0-0","H3-1-1");new=shortest(g,"H0-0-1","H3-0-0")
    else
        error("undeclared topology")
    end
    @assert !isempty(old) && !isempty(new)
    initial=triples(old);diff=setdiff(Set(old),Set(new))
    removed=[r for r in initial if any(x -> x in diff,r)]
    added=[r for r in triples(new) if !(r in initial)]
    switches=[n for n in g.names if !startswith(n,"H")]
    updated=[s for s in switches if any(r -> r[1]==s,vcat(removed,added))]
    hosts=[n for n in g.names if startswith(n,"H")]
    (;old,new,initial,removed,added,switches,updated,hosts)
end
connector(a,b)=join(sort([a,b]),"-")
function rule_edges(r)
    s,ingress,egress=r
    left=startswith(ingress,"H") ? ingress : connector(ingress,s)
    right=startswith(egress,"H") ? egress : connector(s,egress)
    ((s,right),(left,s))
end
function initial_graph(sc)
    g=Graph(;directed=true)
    for h in sc.hosts;addnode!(g,h);end
    for s in sc.switches
        addnode!(g,s)
        for r in sc.initial
            r[1]==s || continue
            for (a,b) in rule_edges(r);edge!(g,a,b);end
        end
    end
    g
end
function updated_graph(base,sc,mask)
    g=deepcopy(base)
    for (i,s) in enumerate(sc.updated)
        mask & (1<<(i-1))==0 && continue
        for r in sc.removed
            r[1]==s || continue
            for (a,b) in rule_edges(r);remove!(g,a,b);end
        end
        for r in sc.added
            r[1]==s || continue
            for (a,b) in rule_edges(r);edge!(g,a,b);end
        end
    end
    g
end
subset_masks(m)=sort(collect(0:(1<<m)-1);by=x ->
    (count_ones(x),Tuple(i for i in 1:m if x & (1<<(i-1))!=0)))
function baseline(sc)
    init=initial_graph(sc);last=(1<<length(sc.updated))-1
    final=updated_graph(init,sc,last)
    pairs=[(a,b) for a in sc.hosts for b in sc.hosts if a!=b]
    allowed=Set((a,b) for (a,b) in pairs if !isempty(shortest(init,a,b)) || !isempty(shortest(final,a,b)))
    events=Tuple{Int,String,String}[]
    for mask in subset_masks(length(sc.updated))
        g=updated_graph(init,sc,mask)
        for (a,b) in pairs
            (a,b) in allowed && continue
            isempty(shortest(g,a,b)) || push!(events,(mask,a,b))
        end
    end
    (;events,subsets=last+1,pair_checks=(last+1)*length(sc.hosts)*(length(sc.hosts)-1)÷2)
end
sample_count(g,T=4)=floor(Int,0.5*(sum(length,g.out)÷2)*(log2(binomial(T,2))+1+log(10)))
function score_walks(walks,source,n)
    scores=zeros(Int,n);source_seen=false
    for path in walks
        source in path || continue
        source_seen=true
        for v in unique(path);scores[v]+=1;end
    end
    source_seen || error("query absent from sampled paths: source artifact would fail")
    scores
end
function rank_cache(scores,source,k)
    order=sortperm(collect(eachindex(scores));by=i -> (-scores[i],-i))
    top=order[1:min(k,length(order))]
    retained=filter(!=(source),top)
    cutoff=scores[top[end]]
    ties=count(==(cutoff),scores)
    # Only flag a tie when it straddles the selected/unselected boundary.
    boundary=count(i -> scores[i]==cutoff,top)<ties ? ties : 0
    retained,boundary
end
function caches(g,k,seed)
    rng=MersenneTwister(seed);n=length(g.names);R=sample_count(g)
    result=Dict{String,Set{String}}();adjacent=empty(result);hostonly=empty(result)
    ties=0
    for (source,name) in enumerate(g.names)
        startswith(name,"H") && continue
        walks=Vector{Int}[]
        for _ in 1:R
            at=rand(rng,1:n);path=[at]
            for _ in 1:4;at=rand(rng,g.out[at]);push!(path,at);end
            push!(walks,path)
        end
        scores=score_walks(walks,source,n)
        ids,nties=rank_cache(scores,source,k);ties+=nties>1
        result[name]=Set(g.names[ids])
        adjacent[name]=union(result[name],Set(g.names[v] for v in g.out[source] if startswith(g.names[v],"H")))
        hosts=sort([v for v in 1:n if startswith(g.names[v],"H")];by=v -> (-scores[v],-v))
        hostonly[name]=Set(g.names[hosts[1:min(length(ids),length(hosts))]])
    end
    (;published=result,adjacent,hostonly,R,boundary_tied_queries=ties)
end
function coverage(sc,base,cs)
    unions=[Set{String}() for _ in 1:base.subsets]
    checked=0
    for mask in 0:base.subsets-1
        for (i,s) in enumerate(sc.updated)
            mask & (1<<(i-1))!=0 && union!(unions[mask+1],filter(h -> startswith(h,"H"),cs[s]))
        end
        for i in 1:length(sc.hosts),j in i+1:length(sc.hosts)
            (sc.hosts[i] in unions[mask+1] || sc.hosts[j] in unions[mask+1]) && (checked+=1)
        end
    end
    found=[e for e in base.events if e[2] in unions[e[1]+1] || e[3] in unions[e[1]+1]]
    (;found,pair_checks=checked,pairs_skipped=base.pair_checks-checked)
end
end
