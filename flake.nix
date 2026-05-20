{
  description = "GNU Radio out-of-tree module for DVB-S2 receiver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          python = pkgs.python3;
          pythonPackages = pkgs.python3Packages;
          
          # Workaround for pyqtgraph test failure if it happens during build
          pyqtgraph_no_tests = pythonPackages.pyqtgraph.overridePythonAttrs (old: {
            doCheck = false;
          });
          
          # Python environment with all required runtime dependencies
          pythonEnv = python.withPackages (ps: with ps; [
            numpy
            scipy
            six
            pybind11
            packaging
            pyqt5
            pyqtgraph_no_tests
          ]);
        in
        {
          gr-dvbs2rx = pkgs.stdenv.mkDerivation {
            pname = "gr-dvbs2rx";
            version = "1.4.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
              doxygen
              makeWrapper
              qt5.wrapQtAppsHook
            ];

            buildInputs = with pkgs; [
              spdlog
              fmt
              fftwFloat
              libsndfile
              boost
              gmp
              volk
              gnuradio
              cpu_features
              pythonEnv
              pythonPackages.numpy
              pythonPackages.scipy
              qt5.qtwayland
            ];
            cmakeFlags = [
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              "-DGR_PYTHON_DIR=${placeholder "out"}/${python.sitePackages}"
            ];

            # Wrap the binaries to ensure they can find the installed module and dependencies
            postInstall = ''
              for file in $out/bin/dvbs2-*; do
                wrapProgram $file \
                  --prefix PYTHONPATH : "$out/${python.sitePackages}:$PYTHONPATH"
              done
            '';

            meta = with pkgs.lib; {
              description = "GNU Radio DVB-S2 receiver implementation";
              homepage = "https://github.com/igorauad/gr-dvbs2rx";
              license = licenses.gpl3;
              platforms = platforms.linux;
            };
          };
          default = self.packages.${system}.gr-dvbs2rx;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          python = pkgs.python3;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.gr-dvbs2rx ];
            
            nativeBuildInputs = with pkgs; [
              cmake
              gnumake
              gcc
              rustc
              cargo
              rust-analyzer
              clippy
              rustfmt
            ];

            shellHook = ''
              # Point PYTHONPATH to the build directory for local development
              export PYTHONPATH="$(pwd)/build/${python.sitePackages}:$PYTHONPATH"
              echo "gr-dvbs2rx development environment loaded."
            '';
          };
        }
      );
    };
}
