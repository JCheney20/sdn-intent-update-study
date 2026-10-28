# Dependency/embedding feasibility only; does not create a network or run Cisco cases.
using TOML
const HERE=@__DIR__
const RUN=ENV["COS738_OVS_RUN_DIR"]
@assert occursin("cos738-ovs-",read("/proc/self/cgroup",String))
@assert ENV["JULIA_CONDAPKG_BACKEND"]=="Null"
@assert ENV["JULIA_PKG_OFFLINE"]=="true"
result=Dict{String,Any}("status"=>"RUNNING","julia_version"=>string(VERSION))
try
    result["pythoncall_import_seconds"]=@elapsed @eval using PythonCall
    @eval using CondaPkg
    @assert CondaPkg.backend()==:Null
    sys=pyimport("sys")
    @assert pyconvert(Int,sys.version_info.major)==3 && pyconvert(Int,sys.version_info.minor)==11
    pyexe=pyconvert(String,sys.executable)
    @assert realpath(pyexe)==realpath(ENV["JULIA_PYTHONCALL_EXE"])
    @assert pyconvert(Int,sys.flags.no_user_site)==1
    source=ENV["MININET_PYTHON_SOURCE"]
    sys.path.insert(0,source)
    result["mininet_import_seconds"]=@elapsed mn=pyimport("mininet.net")
    @assert startswith(pyconvert(String,mn.__file__),source)
    @assert pyconvert(String,mn.VERSION)=="2.3.1b4"
    sqrt=pyimport("math").sqrt
    @assert pyconvert(Float64,sqrt(144))==12.0
    # Same live interpreter/module objects reused after a warm-up, not a new process per call.
    elapsed=Float64[]
    for _ in 1:5
        push!(elapsed,@elapsed @assert pyconvert(Float64,sqrt(144))==12.0)
    end
    @assert !any(id->id.name in ("MicroMamba","micromamba_jll","pixi_jll"),keys(Base.loaded_modules))
    result["python_executable"]=pyexe
    result["python_version"]=pyconvert(String,sys.version)
    result["mininet_version"]=pyconvert(String,mn.VERSION)
    result["mininet_module"]=pyconvert(String,mn.__file__)
    result["pythoncall_version"]=string(pkgversion(PythonCall))
    result["condapkg_backend"]=string(CondaPkg.backend())
    result["repeated_bridge_call_seconds"]=elapsed
    result["status"]="PASS"
    println("JULIA PYTHONCALL MININET IMPORT PASS")
catch error
    result["status"]="FAIL";result["error"]=sprint(showerror,error,catch_backtrace());rethrow()
finally
    open(joinpath(RUN,"bridge_smoke.toml"),"w") do io;TOML.print(io,result);end
end
