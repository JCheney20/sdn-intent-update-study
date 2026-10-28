{
  description = "Isolated, cache-only OVS feasibility and bounded handover emulation";

  # Reuse the already available revision without modifying reference artifact pins.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/dddccde11a6c6be45f58a76828a5f48d58262e9a";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      tools = {
        openvswitch = pkgs.openvswitch;
        iproute2 = pkgs.iproute2;
        tcpdump = pkgs.tcpdump;
        python = pkgs.python311;
      };
    in {
      packages.${system} = tools;
      emulationComponents.${system} = builtins.mapAttrs (_: p: {
        version = p.version;
        path = p.outPath;
      }) tools;
      # Metadata/shell descriptions do not authorize compilation or unbounded execution.
      devShells.${system}.default = pkgs.mkShell {
        packages = builtins.attrValues tools;
        PYTHONNOUSERSITE = "1";
        OMP_NUM_THREADS = "1";
        OPENBLAS_NUM_THREADS = "1";
      };
    };
}
