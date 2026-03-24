# FPGA Development Template
#
# Usage: nix flake init -t github:sibeov/nix-shell-templates#fpga
#
# A standalone FPGA development environment using:
# - oss-cad-suite.nix: OSS CAD Suite package definition (edit to change version)
#
# This template is self-contained: all configuration is in this directory.
# Edit oss-cad-suite.nix to update the toolchain version.
{
  description = "FPGA development environment with OSS CAD Suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      nix2container,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        {
          pkgs,
          system,
          inputs',
          config,
          ...
        }:
        let
          # Build oss-cad-suite from local file
          oss-cad-suite = pkgs.callPackage ./oss-cad-suite.nix {
            inherit system;
          };

          # Additional SystemVerilog development tools
          extraTools = [
            pkgs.verible # SystemVerilog linter/formatter for IDE integration
            pkgs.surfer # Extensible and Snappy Waveform Viewer
          ];
        in
        {
          # Export packages
          packages.oss-cad-suite = oss-cad-suite;
          packages.default = oss-cad-suite;

          # OCI image for containerized development
          packages.ociImage =
            let
              n2c = inputs'.nix2container.packages.nix2container;
            in
            n2c.buildImage {
              name = "fpga-dev";
              tag = "latest";
              copyToRoot = pkgs.buildEnv {
                name = "root";
                paths = [
                  oss-cad-suite
                  pkgs.bashInteractive
                  pkgs.coreutils
                  pkgs.git
                ]
                ++ extraTools;
                pathsToLink = [
                  "/bin"
                  "/lib"
                  "/share"
                ];
              };
              config = {
                Entrypoint = [ "/bin/bash" ];
                Env = [
                  "OSS_CAD_SUITE_ROOT=${oss-cad-suite}"
                  "USER=fpga"
                ];
                WorkingDir = "/workspace";
                Labels = {
                  "org.opencontainers.image.description" = "FPGA development environment with OSS CAD Suite";
                  "org.opencontainers.image.source" = "https://github.com/sibeov/nix-shell-templates";
                };
              };
            };

          # Default formatter
          formatter = pkgs.nixfmt;

          # Apps for container management
          apps.pushImage = {
            type = "app";
            program = "${config.packages.ociImage}/bin/copy-to-registry";
          };

          # Development shell
          devShells.default = pkgs.mkShell {
            name = "fpga-dev";

            packages = [ oss-cad-suite ] ++ extraTools;

            env = {
              OSS_CAD_SUITE_ROOT = "${oss-cad-suite}";
            };

            shellHook = ''
              echo ""
              echo "FPGA Development Environment"
              echo "============================="
              echo "OSS CAD Suite: ${oss-cad-suite.version}"
              echo ""
              echo "Tools available:"
              echo "  yosys       - Synthesis"
              echo "  nextpnr-*   - Place and route"
              echo "  icepack     - iCE40 bitstream"
              echo "  ecppack     - ECP5 bitstream"
              echo "  GHDL        - VHDL simulator"
              echo "  gtkwave     - Waveform viewer (in oss-cad-suite)"
              echo "  surfer      - Extensible and Snappy Waveform Viewer"
              echo "  verilator   - Verilog simulator (in oss-cad-suite)"
              echo "  verible-*   - SystemVerilog linter/formatter"
              echo ""
              echo "Container commands:"
              echo "  nix build .#ociImage  - Build OCI image"
              echo "  nix run .#pushImage   - Push to registry"
              echo ""
              echo "To update the toolchain, edit oss-cad-suite.nix"
              echo ""
            '';
          };
        };
    };
}
