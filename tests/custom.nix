{
  pkgs,
  nixos-lib,
  nixosModule,
}:
nixos-lib.runTest {
  name = "custom";
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
      preroll-safety.enable = true;
      preroll-safety.stockChecks.enable = false;
      preroll-safety.checks.custom = {
        failureMessage = "Custom check failed";
        successMessage = "Custom check succeeded";
        check.program = lib.getExe (pkgs.writeShellApplication {
          name = "custom-check";
          text = ''
            [ ! -f /run/custom-check-failure ]
          '';
        });
      };

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
    with subtest("Custom check is ok"):
        machine.succeed("/run/current-system/pre-activate-safety-checks")
    with subtest("Custom check can be made to fail"):
        machine.succeed("touch /run/custom-check-failure")
        machine.fail("/run/current-system/pre-activate-safety-checks")
  '';
}
