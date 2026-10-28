{
  description = "Pinned Python reference environment for the SDN artifact";

  inputs = {
    # Contains NumPy 1.26.2, NetworkX 3.2.1 and Matplotlib 3.8.2 together.
    nixpkgs.url = "github:NixOS/nixpkgs/dddccde11a6c6be45f58a76828a5f48d58262e9a";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python311;
        ps = python.pkgs;
        reference = python.withPackages (p: [ p.numpy p.networkx p.matplotlib ]);
        versions = {
          python = python.version;
          numpy = ps.numpy.version;
          networkx = ps.networkx.version;
          matplotlib = ps.matplotlib.version;
        };
      in
      assert versions.numpy == "1.26.2";
      assert versions.networkx == "3.2.1";
      assert versions.matplotlib == "3.8.2";
      assert ps.pyparsing.version == "3.1.1";
      {
        packages.default = reference;
        devShells.default = pkgs.mkShell {
          packages = [ reference ];
          PYTHONNOUSERSITE = "1";
          MPLBACKEND = "Agg";
          OPENBLAS_NUM_THREADS = "1";
          OMP_NUM_THREADS = "1";
          shellHook = ''
            unset PYTHONPATH PYTHONHOME
          '';
        };
        # Metadata evaluation does not realize/build the Python closure.
        referenceVersions = versions;
        referenceComponents = {
          interpreter = "${python}/bin/python3.11";
          sitePackages = python.sitePackages;
          tkinterVersion = ps.tkinter.version;
          # Same dependency expansion used by python.withPackages, without building its wrapper.
          paths = map (p: p.outPath) (ps.requiredPythonModules [
            ps.numpy ps.networkx ps.matplotlib python
          ]);
        };
        transitiveVersions = {
          contourpy = ps.contourpy.version;
          cycler = ps.cycler.version;
          fonttools = ps.fonttools.version;
          kiwisolver = ps.kiwisolver.version;
          packaging = ps.packaging.version;
          pillow = ps.pillow.version;
          pyparsing = ps.pyparsing.version;
          python-dateutil = ps.python-dateutil.version;
          six = ps.six.version;
          # Additional propagated Pillow dependencies in the full Nix runtime expansion.
          olefile = ps.olefile.version;
          defusedxml = ps.defusedxml.version;
        };
      });
}
