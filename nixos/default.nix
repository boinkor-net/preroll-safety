{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.preroll-safety;
in {
  imports = [
    ./safety-checks
  ];

  options.preroll-safety = let
    checkProgramSubmodule.options = {
      program = lib.mkOption {
        description = "Path to a program to invoke. If `items` is set, that program will be invoked with each item as $1.";
      };

      items = lib.mkOption {
        description = "Items over which to run the check code";
        type = lib.types.nullOr (lib.types.listOf lib.types.anything);
        default = null;
      };
    };

    checkSubmodule.options = {
      enable = lib.mkOption {
        description = "Whether to enable the check";
        default = true;
        type = lib.types.bool;
      };

      check = lib.mkOption {
        description = "Program that will be invoked to perform the check";
        type = lib.types.submodule checkProgramSubmodule;
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
  in {
    enable = lib.mkEnableOption "writing the pre-roll safety check script";

    scriptBaseName = lib.mkOption {
      description = "Name of the safety-check program that will be written to the root of the NixOS closure.";
      type = lib.types.str;
      default = "pre-activate-safety-checks";
    };

    stockChecks.enable = lib.mkOption {
      description = "Whether to enable the checks in this flake by default.";
      default = true;
      type = lib.types.bool;
    };

    checks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule checkSubmodule);
    };
  };

  config = lib.mkIf cfg.enable (
    let
      runnableCheck = validation: {
        program,
        items,
      }:
        if items == null
        then program
        else if items == []
        then
          # This auto-succeeds & is special-cased so shellcheck doesn't complain
          # about single-quoted arguments (yes, it's silly).
          ":"
        else
          lib.getExe (pkgs.writeShellApplication {
            name = "check-${validation}";
            text = ''
              declare -i failed=0
              # shellcheck disable=SC2043
              for item in ${lib.escapeShellArgs items} ; do
                if ! ${program} "$item"; then
                  failed=$((failed+1))
                fi
              done
              if [ $failed != 0 ]; then
                exit 1
              fi
            '';
          });

      writeOneCheckScript = validation: {
        enable,
        check,
        failureMessage,
        successMessage,
      }:
        if enable
        then ''
          echo ":: Running preroll-safety check ${validation}..."
          check__${validation}() {
            set -eu
            ${runnableCheck validation check}
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
        ''
        else "";

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
