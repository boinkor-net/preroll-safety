{
  pkgs,
  lib,
  config,
  ...
}: {
  preroll-safety.checks.filesystems = {
    failureMessage = "Contents of fileSystems would result in a system that will enter emergency mode.";

    check.forEach = {
      items = lib.mapAttrsToList (_n: fs: fs.device) (lib.filterAttrs
        (_n: fs: (lib.hasPrefix "/dev/" fs.device))
        config.fileSystems);
      program = pkgs.writeShellApplication {
        name = "check-one-filesystem-entry";
        text = ''
          if [ -b "$1" ]; then
            echo "Device reference $1 is not a block device, very likely not mountable: " >&2
            ls -l "$1" >&2
            exit 1
          fi
        '';
      };
    };
  };
}