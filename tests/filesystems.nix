{
  pkgs,
  flake-inputs,
  nixos-lib,
  nixosModule,
  writeTestFlakeWithConfig,
}:
nixos-lib.runTest {
  name = "filesystem-fails";
  hostPkgs = pkgs;
  node.pkgsReadOnly = false;
  nodes.machine = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      nixosModule
    ];
    config = {
      virtualisation.useDefaultFilesystems = false;
      virtualisation.rootDevice = "/dev/vda1";

      boot.initrd.postDeviceCommands = ''
        if ! test -b /dev/vda1; then
          ${pkgs.parted}/bin/parted --script /dev/vda -- mklabel msdos
          ${pkgs.parted}/bin/parted --script /dev/vda -- mkpart primary 1MiB -250MiB
          ${pkgs.parted}/bin/parted --script /dev/vda -- mkpart primary -250MiB 100%
          sync
        fi

        FSTYPE=$(blkid -o value -s TYPE /dev/vda1 || true)
        if test -z "$FSTYPE"; then
          ${pkgs.e2fsprogs}/bin/mke2fs -t ext4 -L root /dev/vda1
          ${pkgs.e2fsprogs}/bin/mke2fs -t ext4 -L ephemeral /dev/vda2
        fi
      '';
      virtualisation.fileSystems = {
        "/ephemeral" = {
          # our test partition
          device = "/dev/disk/by-label/ephemeral";
          fsType = "ext4";
        };

        "/" = {
          device = "/dev/disk/by-label/root";
          fsType = "ext4";
        };
      };

      preroll-safety.enable = true;
      preroll-safety.stockChecks.enable = false;
      preroll-safety.checks.filesystems.enable = true;

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };
  };

  testScript = ''
    machine.start()
    machine.succeed("udevadm settle")
    machine.wait_for_unit("multi-user.target")
    with subtest("Filesystems at boot are ok"):
        machine.succeed("/run/current-system/pre-acivate-safety-checks")
    with subtest("Removing a filesystem causes the check to fail"):
        machine.succeed("umount /dev/disk/by-label/ephemeral")
        machine.succeed("${pkgs.parted}/bin/parted --script /dev/vda rm 2")
        machine.succeed("udevadm settle")
        machine.fail("/run/current-system/pre-acivate-safety-checks")
  '';
}
