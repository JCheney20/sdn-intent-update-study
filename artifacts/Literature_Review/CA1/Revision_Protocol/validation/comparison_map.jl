# Explicit representation map used only by independent validation.
function encoded(p,d)
    Handover.Packet(d.ids[p.node],d.ids[p.incoming],p.tag,p.epoch,p.age,p.status,
        p.arrival,p.admitted,p.ended,p.sourceip,p.destip)
end
function decoded(p,d)
    (node=d.names[p.node],incoming=d.names[p.input],tag=p.tag,epoch=p.epoch,age=p.age,status=p.status,
        arrival=p.arrival,admitted=p.admitted,ended=p.ended,sourceip=p.sourceip,destip=p.destip)
end
function concrete(t,d)
    rows=Dict{Tuple{String,String,Int},String}()
    for tag in 0:1,i in eachindex(d.names),s in eachindex(d.names)
        z=t.rows[s,i,tag+1]
        z==0 || (rows[(d.names[s],d.names[i],tag)]=d.names[z])
    end
    (rows=rows,oldopen=t.oldopen,newopen=t.newopen,newtag=t.tag)
end
concrete(v::View)=(rows=v.rows,oldopen=v.oldopen,newopen=v.newopen,newtag=v.newtag)
