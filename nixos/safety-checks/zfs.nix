{
  pkgs,
  lib,
  config,
  ...
}: {
  preroll-safety.checks.zfs = {
    enable = lib.mkDefault config.preroll-safety.stockChecks.enable;

    failureMessage = "ZFS datasets referenced in fileSystems are inconsistent.";

    check = {
      items = lib.mapAttrsToList (_n: fs: fs.device) (lib.filterAttrs (_n: fs: fs.fsType == "zfs") config.fileSystems);

      program = lib.getExe (pkgs.writeShellApplication {
        name = "check-zfs-filesystem-entry";
        text = ''
          if ! zfs list -o name -H "$1" >/dev/null 2>/dev/null; then
            echo "ZFS dataset $1 does not exist" >&2
            exit 1
          fi

          # Further checks on an existing dataset:
          declare -i exitStatus=0
          if [ "$(zfs get canmount -o value -H "$1")" != "on" ]; then
            echo "ZFS dataset $1 does not have canmount=on set but is referenced in fileSystems" >&2
            zfs get -H canmount "$1" >&2
            exitStatus=$((exitStatus+1))
          fi

          if [ "$(zfs get mountpoint -o value -H "$1")" != "legacy" ]; then
            echo "ZFS dataset $1 does not have mountpoint=legacy set but is referenced in fileSystems" >&2
            zfs get -H mountpoint "$1" >&2
            exitStatus=$((exitStatus+1))
          fi
          exit "$exitStatus"
        '';
      });
    };
  };
}
