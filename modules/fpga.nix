# FPGA development module
#
# Provides an FPGA development environment using a local oss-cad-suite.nix file.
# The file defines the OSS CAD Suite package with version and hashes.
{
  lib,
  config,
  ...
}:
let
  cfg = config.templates.fpga;
in
{
  options.templates.fpga = {
    enable = lib.mkEnableOption "FPGA development environment";

    # OSS CAD Suite package file (required)
    ossCadSuiteFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to oss-cad-suite.nix file containing the package definition.
        Edit this file to change the OSS CAD Suite version.
      '';
      example = lib.literalExpression "./oss-cad-suite.nix";
    };

    # Verible for SystemVerilog development
    includeVerible = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Verible for SystemVerilog linting and formatting";
    };

    # Additional packages to include
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to include in the FPGA development shell";
    };
  };

  config = lib.mkIf cfg.enable {
    perSystem =
      {
        pkgs,
        system,
        ...
      }:
      let
        # Build oss-cad-suite from the provided file
        oss-cad-suite = pkgs.callPackage cfg.ossCadSuiteFile {
          inherit system;
        };

        # Collect all FPGA-related packages
        fpgaPackages = [
          oss-cad-suite
        ]
        ++ lib.optionals cfg.includeVerible [ pkgs.verible ]
        ++ cfg.extraPackages
        ++ config.templates.commonPackages;
      in
      {
        # Export the oss-cad-suite package
        packages.oss-cad-suite = oss-cad-suite;

        # Development shell using devshell
        devshells.fpga = {
          name = "fpga-dev";
          motd = ''
            {202}FPGA Development Environment{reset}
            {bold}OSS CAD Suite ${oss-cad-suite.version}{reset}

            Tools: yosys, nextpnr, gtkwave, verilator (oss-cad-suite) + verible
            $(type -p menu &>/dev/null && menu)
          '';

          packages = fpgaPackages;

          env = [
            {
              name = "OSS_CAD_SUITE_ROOT";
              value = "${oss-cad-suite}";
            }
          ];

          commands = [
            {
              name = "fpga-info";
              help = "Show FPGA toolchain information";
              command = ''
                echo "OSS CAD Suite: ${oss-cad-suite.version}"
                echo "Yosys: $(yosys --version 2>/dev/null || echo 'not found')"
              '';
            }
            {
              name = "synth";
              help = "Run Yosys synthesis";
              command = "yosys \"$@\"";
            }
          ];
        };
      };
  };
}
