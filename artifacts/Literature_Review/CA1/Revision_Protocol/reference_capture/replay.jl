using TOML, SHA
length(ARGS)==2 || error("expected capture and replay output directories")
capture_dir, outdir = abspath.(ARGS)
const HERE=@__DIR__
const CHECKS=Ref(0)
function check(condition,label)
    CHECKS[]+=1
    condition || error("REPLAY MISMATCH: "*label)
end
function rejected(f)
    try;f();false;catch;true;end
end
cg=split(only(filter(x->startswith(x,"0::"),split(read("/proc/self/cgroup",String),'\n'))),"::";limit=2)[2]
occursin("cos738-reference-",cg) || error("bounded replay scope required")
cgdir=joinpath("/sys/fs/cgroup",cg[2:end])
parse(Int,readchomp(joinpath(cgdir,"memory.max")))<=2^31 || error("RAM limit")
readchomp(joinpath(cgdir,"memory.swap.max"))=="0" || error("swap limit")
quota,period=parse.(Int,split(readchomp(joinpath(cgdir,"cpu.max"))))
quota<=2period && Threads.nthreads()==1 || error("CPU/thread limit")
include(joinpath(HERE,"../../../../SDN_Model_Comparison/source_fidelity/detector.jl"))
const SD=SourceDetector
bits(x)=string(reinterpret(UInt64,Float64(x));base=16,pad=16)

function graphcheck(g,record)
    check(g.names==record["nodes"],"ordered graph nodes")
    check([g.names[ns] for ns in g.out]==record["adjacency"],"ordered graph adjacency")
    check(g.directed==record["directed"],"graph directedness")
    edges=[[g.names[i],g.names[j]] for i in eachindex(g.names) for j in g.out[i] if g.directed || j>=i]
    check(edges==record["edges"],"ordered graph edges")
end
function controlgraph(record)
    g=SD.Graph(;directed=record["directed"])
    for name in record["nodes"];SD.addnode!(g,name);end
    # Reconstruct directed arcs from the captured raw ordered adjacency.
    for (name,neighbors) in zip(record["nodes"],record["adjacency"]),neighbor in neighbors
        SD.arc!(g,g.ids[name],g.ids[neighbor])
    end
    graphcheck(g,record);g
end
function rngcheck(rng)
    check(rng["algorithm"]=="MT19937" && length(rng["keys"])==624,"RNG family/state shape")
    check(all(x->0<=x<=typemax(UInt32),rng["keys"]) && 0<=rng["position"]<=624,"RNG state range")
    check(rng["has_gauss"] in (0,1) && occursin(r"^[0-9a-f]{16}$",rng["cached_gaussian_bits"]),"RNG Gaussian state")
end
function querycheck(g,q,k)
    n=length(g.names);s=g.ids[q["source"]];R=q["sample_count"]
    check(q["requested_k"]==k && q["path_length"]==q["generator_path_length"]==4 && q["weight"]=="None","effective helper parameters")
    check(R==SD.sample_count(g,4) && length(q["walks"])==R,"exact sample count")
    memberships=Dict{String,Set{Int}}();indexorder=String[];walks=Vector{Int}[]
    for (j,path) in enumerate(q["walks"])
        check(length(path)==5 && all(name->haskey(g.ids,name),path),"walk length/domain")
        ids=[g.ids[name] for name in path]
        check(all(i->ids[i+1] in g.out[ids[i]],1:4),"every walk step is a physical edge")
        push!(walks,ids)
        for name in path
            if !haskey(memberships,name);memberships[name]=Set{Int}();push!(indexorder,name);end
            push!(memberships[name],j-1)
        end
    end
    check(indexorder==q["index_order"],"inverted-index insertion order")
    check(Dict(n=>sort!(collect(ids)) for (n,ids) in memberships)==q["memberships"],"per-walk membership sets; repeated visits deduplicated")
    scores=SD.score_walks(walks,s,n)
    independent=[length(intersect(get(memberships,name,Set{Int}()),memberships[q["source"]])) for name in g.names]
    check(scores==independent,"Julia co-occurrence kernel agrees with reference membership counts")
    check(length(q["argpartition_calls"])==length(q["argsort_calls"])==1,"one ranking operation per query")
    part=only(q["argpartition_calls"]);sortcall=only(q["argsort_calls"])
    scorebits=bits.(scores .* (1/R))
    check(scorebits==part["scores_bits"],"bit-exact reference score arithmetic")
    k=min(k,n);indices=Int.(part["indices"]).+1
    check(sort(indices)==collect(1:n) && part["kth"]==-k,"argpartition domain/permutation")
    selected=indices[end-k+1:end];cutoff=minimum(scores[selected])
    check(all(i->scores[i]<=cutoff,indices[1:end-k]) && all(i->scores[i]>=cutoff,selected),"top-k boundary eligibility")
    check(scorebits[selected]==sortcall["scores_bits"],"reference argsort input scores")
    order=Int.(sortcall["indices"]).+1
    check(sort(order)==collect(1:k),"ranking order permutation")
    check(issorted(scores[selected[order]]),"non-tied ranking exact; only equal-score order is supplied")
    top=reverse(selected[order]);retained=filter(!=(s),top)
    check(g.names[retained]==q["cache_order"],"derived cache including conditional query removal")
    check(scorebits[retained]==q["cache_score_bits"],"cache scores bit exact")
    rngcheck(q["rng_before"]);rngcheck(q["rng_after"])
    natural,_=SD.rank_cache(scores,s,k)
    (;members=Set(g.names[retained]),ordered=g.names[retained],natural=g.names[natural],scores)
end
function expectedrules(sc)
    Dict(s=>Dict(key=>[[r[2],r[3],"10.0.0.0/8","10.0.0.0/8"] for r in rows if r[1]==s]
        for (key,rows) in [("initial",sc.initial),("removed",sc.removed),("added",sc.added)]) for s in sc.switches)
end
function replaycase(c)
    g=c["fixture"]=="cisco" ? SD.cisco() : SD.fattree()
    graphcheck(g,c["physical"])
    sc=SD.scenario(g,c["fixture"])
    if c["noop"];sc=merge(sc,(removed=SD.Rule[],added=SD.Rule[],updated=String[]));end
    check(sc.hosts==c["hosts"] && sc.switches==c["switches"],"source-derived host/switch query order")
    rules=expectedrules(sc);check(rules==c["rules"],"independent original rule differences and prefixes")
    initial=SD.initial_graph(sc);final=SD.updated_graph(initial,sc,(1<<length(sc.updated))-1)
    graphcheck(initial,c["initial_graph"]);graphcheck(final,c["final_graph"])
    check([q["source"] for q in c["queries"]]==(c["noop"] ? String[] : sc.switches),"no missing/duplicate/reordered queries")
    caches=Dict{String,Set{String}}();orderdiff=String[];memberdiff=String[];laststate=c["initial_rng"]
    for q in c["queries"]
        check(q["rng_before"]==laststate,"continuous RNG state between queries")
        replay=querycheck(g,q,c["k"]);caches[q["source"]]=replay.members
        replay.ordered!=replay.natural && push!(orderdiff,q["source"])
        replay.members!=Set(replay.natural) && push!(memberdiff,q["source"])
        laststate=q["rng_after"]
    end
    check(laststate==c["final_rng"],"final complete RNG checkpoint")
    masks=SD.subset_masks(length(sc.updated))
    subsetnames(mask)=[s for (i,s) in enumerate(sc.updated) if mask&(1<<(i-1))!=0]
    check(subsetnames.(masks)==c["subsets"],"all subset identities and order")
    expectedmatches=Dict{String,Any}[];pairindex=0;checked=0;events=Tuple{Int,String,String}[]
    for mask in masks
        subset=subsetnames(mask);updated=SD.updated_graph(initial,sc,mask)
        likely=Set{String}()
        for s in subset;union!(likely,filter(n->startswith(n,"H"),caches[s]));end
        for i in eachindex(sc.hosts),j in i+1:length(sc.hosts)
            pairindex+=1;p=c["pairs"][pairindex];a,b=sc.hosts[i],sc.hosts[j]
            check(p["subset"]==subset && p["source"]==a && p["destination"]==b,"pair enumeration order")
            tested=c["noop"] || a in likely || b in likely
            check(length(p["directions"])==(tested ? 2 : 0),"exact tested/skipped pair domain")
            tested || continue
            checked+=1
            for (direction,(source,dest)) in zip(p["directions"],[(a,b),(b,a)])
                check(direction["source"]==source && direction["destination"]==dest,"direction order")
                paths=[SD.shortest(graph,source,dest) for graph in (initial,updated,final)]
                check(paths==direction["lookup_paths"],"exact connector paths including shortest-path ties")
                extra=isempty(paths[1]) && isempty(paths[3]) && !isempty(paths[2])
                normalconnected=!isempty(paths[1]) || !isempty(paths[3])
                check(direction["expectation"]==(extra ? "EXTRA" : "NORMAL"),"source alarm definition")
                check(direction["status"]==(extra || normalconnected ? "CONNECTED" : "DISCONNECTED"),"source connection status semantics")
                check(direction["path"]==(extra ? paths[2] : String[]),"extra path/witness")
                if extra
                    devices=filter(n->haskey(g.ids,n),paths[2])
                    check(first(devices)==source && last(devices)==dest && all(n->n in sc.switches,devices[2:end-1]),"hyphenated device versus connector identity")
                    # Faithfully retain source's initial-at-updated/added-at-unchanged
                    # prefix loop. It is not the new temporal safety contract.
                    matches=all(sw->all(r->r[3]=="10.0.0.0/8" && r[4]=="10.0.0.0/8",
                        rules[sw][sw in subset ? "initial" : "added"]),devices[2:end-1])
                    push!(expectedmatches,Dict("subset"=>subset,"source"=>source,"destination"=>dest,"path"=>paths[2],"matches"=>matches))
                    matches && push!(events,(mask,source,dest))
                end
            end
        end
    end
    check(pairindex==length(c["pairs"]) && checked==c["states_checked"],"complete pair coverage and normal state count")
    check(expectedmatches==c["packet_matches"] && length(events)==c["violations_found"],"prefix decisions and complete alarm/witness sequence")
    log=join(["WARNING:ALERT: Extra connectivity found between $s and $d for update $(join(subsetnames(mask),","))\n" for (mask,s,d) in events])
    check(log==c["normal_log"],"first/all warning output order")
    exhaustive=SD.baseline(sc)
    found=c["noop"] ? exhaustive.events : SD.coverage(sc,exhaustive,caches).found
    check(Set(found)==Set(events),"existing Julia detector coverage agrees with executed Python")
    Dict("fixture"=>c["fixture"],"k"=>c["k"],"noop"=>c["noop"],"states_checked"=>checked,
        "alarms"=>length(events),"natural_tie_order_differences_on_replayed_walks"=>orderdiff,
        "natural_tie_membership_differences_on_replayed_walks"=>memberdiff)
end

receipt=Dict{String,Any}("status"=>"RUNNING","primary_data"=>false,"scope"=>cg)
try
    readchomp(joinpath(capture_dir,"exit_code"))=="0" || error("capture job not successful")
    envelope=read(joinpath(capture_dir,"capture_receipt.json"),String)
    expected=only(collect(eachmatch(r"\"trace_sha256\":\s*\"([a-f0-9]{64})\"",envelope))).captures[1]
    check(bytes2hex(sha256(read(joinpath(capture_dir,"trace.toml"))))==expected,"capture trace checksum")
    trace=TOML.parsefile(joinpath(capture_dir,"trace.toml"))["trace"]
    plan=TOML.parsefile(joinpath(HERE,"Capture_Plan.toml"))
    check(trace["source_sha256"]==plan["source_sha256"] && trace["seed"]==plan["seed"],"frozen source/seed policy")
    check(trace["source_cli_cisco_k_hardcoded_20"],"helper/CLI distinction retained")
    reports=[replaycase(c) for c in trace["cases"]]
    for control in trace["controls"]["cache_boundaries"]
        g=controlgraph(control["physical"])
        check(length(control["queries"])==1 && control["observability_passed"],"boundary-control observability")
        querycheck(g,only(control["queries"]),control["k"])
        check((control["k"]>length(g.names))==!isempty(control["warnings"]),"reference k>N clamp/warning behavior")
    end
    check(trace["controls"]["prefix_matches"]==[true,false,false],"executed source prefix controls")
    check(length(unique(trace["controls"]["all_zero_top3"]))==3 && all(i->0<=i<5,trace["controls"]["all_zero_top3"]),"eligible all-zero boundary tie choices")
    firstcase=first(trace["cases"]);g=SD.cisco();q=first(firstcase["queries"])
    bad=deepcopy(q);bad["walks"][1][2]=bad["walks"][1][1]
    check(rejected(()->querycheck(g,bad,3)),"corrupted walk rejected")
    bad=deepcopy(q);push!(bad["memberships"][q["source"]],first(bad["memberships"][q["source"]]))
    check(rejected(()->querycheck(g,bad,3)),"corrupted count/membership rejected")
    bad=deepcopy(q);bad["argpartition_calls"][1]["indices"][1]=bad["argpartition_calls"][1]["indices"][2]
    check(rejected(()->querycheck(g,bad,3)),"corrupted ranking/tie selection rejected")
    bad=deepcopy(firstcase);pop!(bad["queries"])
    check(rejected(()->replaycase(bad)),"missing query rejected")
    receipt["status"]="PASS";receipt["checks"]=CHECKS[];receipt["cases"]=reports
    receipt["observability_and_replay_passed"]=true
    receipt["native_RNG_equivalence_established"]=false
    receipt["all_method_controller_validation_passed"]=false
    println("REPLAY PASS checks=",CHECKS[]," cases=",length(reports))
catch error
    receipt["status"]="FAIL";receipt["error"]=sprint(showerror,error,catch_backtrace());rethrow()
finally
    receipt["memory_peak_at_checkpoint_bytes"]=parse(Int,readchomp(joinpath(cgdir,"memory.peak")))
    open(joinpath(outdir,"replay_receipt.toml"),"w") do io;TOML.print(io,receipt);end
end
