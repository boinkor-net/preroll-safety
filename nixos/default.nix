{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.preroll-safety;
in {
  options.preroll-safety = let
    checkSubmodule = {
      options = {
        program = lib.mkOption {
          description = "Program that will be invoked to perform the check";
          type = lib.types.path;
        };

        failureMessage = lib.mkOption {
          description = "Message to emit when the check fails.";
          type = lib.types.str;
          default = "Check failed.";
        };

        successMessage = lib.mkOption {
          description = "Optional message to write when the check succeeds.";
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };
  in {
    enable = lib.mkEnableOption "writing the pre-roll safety check script";

    scriptBaseName = lib.mkOption {
      description = "Name of the safety-check program that will be written to the root of the NixOS closure.";
      type = lib.types.str;
      default = "pre-acivate-safety-checks";
    };

    checks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule checkSubmodule);
    };
  };

  config = lib.mkIf cfg.enable (
    let
      writeOneCheckScript = validation: {
        program,
        failureMessage,
        successMessage,
      }: ''
        echo ":: Running preroll-safety check ${validation}..."
        check__${validation}() {
          set -e
          ${program}
        }
        if ! check__${validation} ; then
          echo ${lib.escapeShellArg failureMessage} >&2
          failed=$((failed+1))
        else
          ${
          if successMessage != null
          then "echo ${lib.escapeShellArg successMessage} >&2"
          else ":"
        }
        fi
      '';

      checkScript = pkgs.writeShellApplication {
        name = cfg.scriptBaseName;
        text = ''
          declare -i failed=0
          ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList writeOneCheckScript cfg.checks)}
          if [ $failed != 0 ]; then
            echo "Pre-activation validations failed - it is not safe to activate this closure!"
            exit 1
          fi
        '';
      };
    in {
      system.extraSystemBuilderCmds = ''
        echo ":: Writing preroll-safety check program ${cfg.scriptBaseName}"
        ln -sf ${lib.getExe checkScript} $out/${cfg.scriptBaseName}
      '';
    }
  );
}
