# Bounded original-intent controller adaptations; no oracle imports.
module Controllers
using ..Handover, ..Lifecycle, ..SourceDetector
const H=Handover
const L=Lifecycle
const SD=SourceDetector

freshwork()=Dict("guard_states"=>0,"guard_edges"=>0,"scheduler_reads"=>0,"history_peak"=>0,"history_rounds"=>0,"detector_pairs"=>0,"detector_searches"=>0)
decision(schedule;status=:COMPLETE,encoding=:Q,branch="",work=freshwork(),history=Any[])=(;schedule,status,encoding,branch,work,history)
function request(d,epoch,arrival)
    path=epoch==0 ? d.old : d.new
    H.Packet(path[2],path[1],0,epoch,0,:waiting,arrival,-999,-999,0x0a000000,0x0a000000)
end
function probes(d)
    result=H.Packet[]
    for i in 1:length(d.old)-3
        push!(result,H.Packet(d.old[i+2],d.old[i+1],0,0,i,:live,-999,1-i,-999,0x0a000000,0x0a000000))
    end
    append!(result,[request(d,0,a) for a in 0:3])
    u=length(Set(vcat(d.old[2:end-1],d.new[2:end-1])));C=(3u+3)*(d.H+1)
    append!(result,[request(d,1,a) for a in 0:C])
    result,C,C+1+d.H
end
function runprobe(d,schedule,original;horizon,cap=10000,observe=nothing,stop_on_failure=false,work=freshwork())
    slot=nothing
    if original.status==:waiting && original.arrival==0 && original.node==d.new[2] && original.input==d.new[1]
        slot=L.SourceSlot();L.offer!(slot,1,original,d)
    end
    frontier=Dict{Any,Any}((original,L.slotkey(slot))=>(original,slot));tables=H.initial(d)
    bad=nothing
    for r in 1:horizon
        commands=get(schedule,r,H.Command[]);next=empty(frontier);edges=Set{Tuple{H.Packet,H.Packet}}()
        nexttables=H.finish(tables,commands,d)
        for (packet,buffer) in values(frontier)
            if buffer===nothing && packet.status==:waiting && r>packet.arrival &&
                packet.node==d.new[2] && packet.input==d.new[1]
                buffer=L.SourceSlot();L.offer!(buffer,1,packet,d)
            end
            successors,_=L.buffered_successors(packet,buffer,tables,commands,d,r)
            work["guard_states"]+=1;work["guard_edges"]+=length(successors)
            for (p,afterbuffer) in successors
                push!(edges,(packet,p));next[(p,L.slotkey(afterbuffer))]=(p,afterbuffer)
                if p.status in (:drop,:wrong_delivery) || p.age>d.H
                    bad=p
                    stop_on_failure && return (;status=:FAIL,complete=false,witness=p,round=r,packets=Set([p]),tables=nexttables)
                end
                length(next)>cap && return (;status=:INCOMPLETE,complete=false,witness=p,round=r,packets=Set([p]),tables=nexttables)
            end
        end
        observe!==nothing && observe(r,tables,commands,edges,nexttables,collect(values(next)))
        frontier=next;tables=nexttables
    end
    packets=Set(p for (p,_) in values(frontier))
    (;status=bad===nothing ? :PASS : :FAIL,complete=true,witness=bad,round=horizon,packets,tables)
end
function guard(d,schedule;cap=10000,work=freshwork())
    H.validate_plan(d,schedule)
    ps,C,T=probes(d)
    for original in ps
        result=runprobe(d,schedule,original;horizon=T,cap,stop_on_failure=true,work)
        result.status==:PASS && result.complete || return result
        if !H.target(result.tables,d,:Q) || any(p->!(p.status==:delivered ||
            (p.status==:rejected && p.epoch==0 && p.admitted==-999 && p.arrival>=0)),result.packets)
            return (;status=:FAIL,complete=false,witness=first(result.packets),round=T)
        end
        any(p->p.epoch==1 && p.ended>max(p.arrival,C)+1+d.H,result.packets) &&
            return (;status=:FAIL,complete=false,witness=first(result.packets),round=T)
    end
    (;status=:PASS,complete=true,witness=nothing,round=T)
end
function positive(d,before,after,history,epoch,work)
    source=epoch==0 ? d.old : d.new;expected=last(source)
    active=Set{Tuple{Int,Int}}();memo=Dict{NTuple{3,Int},Bool}()
    function visit(input,node,depth)
        node==0 && return false
        d.hosts[node] && return node==expected
        depth>=d.H && return false
        key=(input,node)
        key in active && return false
        memo_key=(input,node,depth)
        haskey(memo,memo_key) && return memo[memo_key]
        push!(active,key)
        outputs=Set([before.rows[node,input,1],after.rows[node,input,1]])
        for ((s,i,z),_) in history.removed;s==node && i==input && push!(outputs,z);end
        work["scheduler_reads"]+=length(outputs)
        valid=all(z->visit(node,z,depth+1),outputs)
        delete!(active,key);memo[memo_key]=valid;valid
    end
    visit(source[1],source[2],0)
end
function scheduled(d;work=freshwork())
    schedule=Dict(1=>[H.Command(:close,d.old[2])]);tables=H.finish(H.initial(d),schedule[1],d)
    history=L.RemovedHistory();audit=Any[];lastprogress=1
    changed=[s for s in findall(.!d.hosts) if d.oldtable[s,:,:]!=d.newtable[s,:,:]]
    remaining=Set(changed);_,C,_=probes(d)
    for r in 2:C
        L.expire!(history,r,d.H);work["history_rounds"]+=1
        push!(audit,(;round=r,removed=copy(history.removed)))
        actions=H.Command[]
        if !isempty(remaining)
            for s in sort!(collect(remaining);by=s->d.names[s])
                proposed=vcat(actions,[H.Command(:replace,s)])
                after=H.finish(tables,proposed,d)
                # Timer is based on the acknowledged closure, never actual probe state.
                if r>1+d.H || positive(d,tables,after,history,0,work)
                    push!(actions,last(proposed))
                end
            end
        elseif positive(d,tables,tables,history,1,work)
            push!(actions,H.Command(:open,d.new[2]))
        end
        if !isempty(actions)
            before=tables;tables=H.finish(tables,actions,d);schedule[r]=actions;lastprogress=r
            L.acknowledge!(history,before,tables,r)
            work["history_peak"]=max(work["history_peak"],length(history.removed))
            for c in actions;c.kind==:replace && delete!(remaining,c.switch);end
            if tables.newopen
                H.validate_plan(d,schedule)
                return decision(schedule;branch="ccg_inspired_no_rollback",work,history=audit)
            end
        elseif r-lastprogress>=d.H+1
            return decision(schedule;status=:PROGRESS_BLOCKED,branch="ccg_progress_blocked",work,history=audit)
        end
    end
    decision(schedule;status=:PROGRESS_BLOCKED,branch="ccg_deadline",work,history=audit)
end

# Full snapshot search, not a lookup into a precomputed exhaustive event set.
function detector(sc,caches;work=freshwork())
    initial=SD.initial_graph(sc);final=SD.updated_graph(initial,sc,(1<<length(sc.updated))-1)
    memo=Dict{Tuple{Int,String,String},Vector{String}}()
    function path(graph,key,a,b)
        get!(memo,(key,a,b)) do
            work["detector_searches"]+=1
            SD.shortest(graph,a,b)
        end
    end
    events=Tuple{Int,String,String}[]
    for mask in SD.subset_masks(length(sc.updated))
        hosts=Set{String}()
        for (i,s) in enumerate(sc.updated)
            mask&(1<<(i-1))!=0 && union!(hosts,filter(n->startswith(n,"H"),caches[s]))
        end
        updated=SD.updated_graph(initial,sc,mask)
        for i in eachindex(sc.hosts),j in i+1:length(sc.hosts)
            a,b=sc.hosts[i],sc.hosts[j]
            a in hosts || b in hosts || continue
            work["detector_pairs"]+=1
            for (source,dest) in ((a,b),(b,a))
                old=path(initial,-1,source,dest);now=path(updated,mask,source,dest);target=path(final,-2,source,dest)
                isempty(old) && isempty(target) && !isempty(now) && push!(events,(mask,source,dest))
            end
        end
    end
    (;alert=!isempty(events),events)
end
function build(d,policy,extra;sc=nothing,caches=nothing,guard_cap=10000)
    extra>=0 || throw(ArgumentError("negative row allowance"))
    work=freshwork()
    fallback(branch)=extra<1 ? decision(Dict{Int,Vector{H.Command}}();status=:RESOURCE_BLOCKED,encoding=:V,branch,work) :
        decision(H.plan(d,:V);encoding=:V,branch,work)
    policy==:ordinary && return decision(H.plan(d,:ordinary);branch="ordinary",work)
    policy==:Q && return decision(H.plan(d,:Q);branch="quiesce",work)
    policy==:V && return fallback("versioned")
    policy==:CCG && return scheduled(d;work)
    policy in (:guard,:detector,:guarded_detector) || throw(ArgumentError("unknown controller"))
    if policy!=:guard
        sc!==nothing && caches!==nothing || throw(ArgumentError("detector input missing"))
        result=detector(sc,caches;work)
        result.alert && return fallback("snapshot_alert")
    end
    ordinary=H.plan(d,:ordinary)
    policy==:detector && return decision(ordinary;branch="snapshot_negative_unguarded",work)
    verdict=guard(d,ordinary;cap=guard_cap,work)
    verdict.status==:PASS && verdict.complete && return decision(ordinary;branch="guard_pass",work)
    fallback(verdict.status==:INCOMPLETE ? "guard_incomplete" : "guard_rejected")
end
end
