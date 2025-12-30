{
  pkgs,
  nixos-lib,
  nixosModule,
}:
nixos-lib.runTest {
  name = "zfs";
  hostPkgs = pkgs;
  nodes.machine = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      nixosModule
    ];
    config = {
      networking.hostId = "deadbea7";
      virtualisation.useDefaultFilesystems = false;
      virtualisation.rootDevice = "/dev/vda1";

      boot.initrd.postDeviceCommands = ''
        if ! test -b /dev/vda1; then
          ${pkgs.parted}/bin/parted --script /dev/vda -- mklabel msdos
          ${pkgs.parted}/bin/parted --script /dev/vda -- mkpart primary 1MiB 100%
          sync
        fi

        if ! ${pkgs.zfs}/bin/zpool list test >/dev/null; then
          ${pkgs.zfs}/bin/zpool create test /dev/vda1
          ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy -o canmount=on test/root
          ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy -o canmount=on test/ephemeral
        fi
      '';
      virtualisation.fileSystems = {
        "/ephemeral" = {
          # our test partition
          device = "test/ephemeral";
          fsType = "zfs";
        };

        "/" = {
          device = "test/root";
          fsType = "zfs";
        };
      };

      preroll-safety.systemClosureScript.enable = true;
      preroll-safety.stockChecks.enable = false;
      preroll-safety.checks.zfs.enable = true;

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    with subtest("Filesystems at boot are ok"):
        machine.succeed("/run/current-system/pre-activate-safety-checks")
    with subtest("Removing a filesystem causes the check to fail"):
        machine.succeed("umount /ephemeral")
        machine.succeed("${pkgs.zfs}/bin/zfs destroy test/ephemeral")
        machine.fail("/run/current-system/pre-activate-safety-checks")
  '';
}
