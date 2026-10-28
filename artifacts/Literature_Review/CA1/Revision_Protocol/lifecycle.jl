# Revised lifecycle components. No independent-oracle imports.
module Lifecycle
using ..Handover
const H=Handover

function joint_successors(pair,t,commands,d,r)
    length(unique(c.switch for c in commands))==length(commands) || throw(ArgumentError("same-switch batches"))
    final=H.finish(t,commands,d)
    result=Set{typeof(pair)}()
    inactive(p)=p.status in (:delivered,:wrong_delivery,:drop,:rejected) || p.arrival>=r
    function visit(current,remaining,packets,done)
        if all(done)
            # Remaining independent commands cannot affect already serviced packets.
            push!(result,packets);return
        end
        for i in 1:2
            done[i] && continue
            q=H.serve(packets[i],current,d,r)
            visit(current,remaining,i==1 ? (q,packets[2]) : (packets[1],q),
                i==1 ? (true,done[2]) : (done[1],true))
        end
        for i in eachindex(remaining)
            rest=[remaining[j] for j in eachindex(remaining) if j!=i]
            visit(H.apply(current,remaining[i],d),rest,packets,done)
        end
    end
    visit(t,commands,pair,(inactive(pair[1]),inactive(pair[2])))
    result,final
end

struct Pending
    id::Int
    packet::H.Packet
end
mutable struct SourceSlot
    pending::Union{Nothing,Pending}
    originals::Dict{Int,H.Packet}
    admitted::Dict{Int,H.Packet}
    outside_domain::Vector{Int}
end
SourceSlot()=SourceSlot(nothing,Dict{Int,H.Packet}(),Dict{Int,H.Packet}(),Int[])
function offer!(slot,id,p,d)
    id>0 && !haskey(slot.originals,id) && !(id in slot.outside_domain) || throw(ArgumentError("duplicate/invalid request identity"))
    p.status==:waiting && p.node==d.new[2] && p.input==d.new[1] && p.arrival>=0 ||
        throw(ArgumentError("request is not at the declared new physical source"))
    if slot.pending!==nothing
        push!(slot.outside_domain,id)
        return :outside_domain
    end
    slot.originals[id]=p;slot.pending=Pending(id,p)
    :pending
end
function admit!(slot,t,d,r)
    slot.pending===nothing && return nothing
    pending=slot.pending;q=H.serve(pending.packet,t,d,r)
    if q.status!=:waiting
        q.admitted==r || throw(ArgumentError("new source was not admitted"))
        slot.admitted[pending.id]=q;slot.pending=nothing
    end
    q
end
function slot_valid(slot)
    pendingids=slot.pending===nothing ? Set{Int}() : Set([slot.pending.id])
    admittedids=Set(keys(slot.admitted));originalids=Set(keys(slot.originals))
    isempty(intersect(pendingids,admittedids)) && union(pendingids,admittedids)==originalids || return false
    isempty(intersect(Set(slot.outside_domain),originalids)) || return false
    if slot.pending!==nothing
        p=slot.pending
        p.packet==slot.originals[p.id] || return false
    end
    all(pair->begin
        id,p=pair;o=slot.originals[id]
        p.arrival==o.arrival && p.epoch==o.epoch && p.sourceip==o.sourceip && p.destip==o.destip &&
            p.admitted>=p.arrival+1 && p.age==1 && p.status!=:waiting
    end,slot.admitted)
end

# Canonical audit state keeps explicit source-slot branches deduplicated.
function slotkey(slot)
    slot===nothing && return nothing
    pending=slot.pending===nothing ? nothing : (slot.pending.id,slot.pending.packet)
    (pending,Tuple(sort!(collect(slot.originals);by=first)),
        Tuple(sort!(collect(slot.admitted);by=first)),Tuple(slot.outside_domain))
end
function buffered_successors(p,slot,t,commands,d,r)
    length(unique(c.switch for c in commands))==length(commands) || throw(ArgumentError("same-switch batches"))
    if slot===nothing || p.status!=:waiting
        packets,final=H.successors(p,t,commands,d,r)
        return [(q,slot) for q in packets],final
    end
    slot.pending!==nothing && slot.pending.packet==p || throw(ArgumentError("pending packet identity lost"))
    outcomes=Dict{Any,Tuple{H.Packet,SourceSlot}}()
    function visit(current,remaining)
        copy_slot=deepcopy(slot);q=admit!(copy_slot,current,d,r)
        slot_valid(copy_slot) || throw(ArgumentError("source-slot conservation failed"))
        outcomes[(q,slotkey(copy_slot))]=(q,copy_slot)
        for i in eachindex(remaining)
            rest=[remaining[j] for j in eachindex(remaining) if j!=i]
            visit(H.apply(current,remaining[i],d),rest)
        end
    end
    visit(t,commands)
    collect(values(outcomes)),H.finish(t,commands,d)
end

mutable struct RemovedHistory
    # Key: unversioned (switch, physical incoming port, outgoing port).
    removed::Dict{NTuple{3,Int},Int}
end
RemovedHistory()=RemovedHistory(Dict{NTuple{3,Int},Int}())
function acknowledge!(history,before,after,r)
    r>=1 || throw(ArgumentError("invalid acknowledgement round"))
    for s in axes(before.rows,1),i in axes(before.rows,2)
        z=before.rows[s,i,1]
        z!=0 && z!=after.rows[s,i,1] && (history.removed[(s,i,z)]=r)
    end
    history
end
function expire!(history,opening_round,Hbound)
    opening_round>=1 && Hbound>=1 || throw(ArgumentError("invalid history clock"))
    filter!(pair->opening_round<=pair.second+Hbound,history.removed)
    history
end
end
