{
  description = "Pinned Mininet/PythonCall feasibility; no automatic Conda/Pkg installation";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dddccde11a6c6be45f58a76828a5f48d58262e9a";
    PythonCall = { url = "github:JuliaPy/PythonCall.jl/v0.9.37"; flake = false; };
    CondaPkg = { url = "github:JuliaPy/CondaPkg.jl/v0.2.38"; flake = false; };
    MacroTools = { url = "github:FluxML/MacroTools.jl/v0.5.16"; flake = false; };
    Preferences = { url = "github:JuliaPackaging/Preferences.jl/v1.5.0"; flake = false; };
    Scratch = { url = "github:JuliaPackaging/Scratch.jl/v1.3.0"; flake = false; };
    JSON = { url = "github:JuliaIO/JSON.jl/v1.2.0"; flake = false; };
    Parsers = { url = "github:JuliaData/Parsers.jl/v2.8.3"; flake = false; };
    PrecompileTools = { url = "github:JuliaLang/PrecompileTools.jl/v1.2.1"; flake = false; };
    StructUtils = { url = "github:JuliaServices/StructUtils.jl/v2.5.1"; flake = false; };
    Tables = { url = "github:JuliaData/Tables.jl/v1.12.1"; flake = false; };
    DataAPI = { url = "github:JuliaData/DataAPI.jl/v1.16.0"; flake = false; };
    DataValueInterfaces = { url = "github:queryverse/DataValueInterfaces.jl/v1.0.0"; flake = false; };
    IteratorInterfaceExtensions = { url = "github:queryverse/IteratorInterfaceExtensions.jl/v1.0.0"; flake = false; };
    OrderedCollections = { url = "github:JuliaCollections/OrderedCollections.jl/v1.8.1"; flake = false; };
    TableTraits = { url = "github:queryverse/TableTraits.jl/v1.0.1"; flake = false; };
    UnsafePointers = { url = "github:cjdoris/UnsafePointers.jl/v1.0.0"; flake = false; };
  };
  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      tools = {
        mininet = pkgs.mininet;
        mininet-python = pkgs.mininet.py;
        python = pkgs.python311;
        nettools = pkgs.nettools;
        iputils = pkgs.iputils;
        util-linux = pkgs.util-linux;
        ethtool = pkgs.ethtool;
        procps = pkgs.procps;
        psmisc = pkgs.psmisc;
        which = pkgs.which;
      };
    in {
      packages.${system} = tools;
      components.${system} = builtins.mapAttrs (_: p: { path = p.outPath; version = p.version; }) tools;
      juliaSources.${system} = builtins.mapAttrs (_: p: p.outPath) (builtins.removeAttrs inputs [ "self" "nixpkgs" ]);
      mininetSourcePosition.${system} = pkgs.mininet.meta.position;
    };
}
