{
  pkgs,
  nixos-lib,
  nixosModule,
}:
nixos-lib.runTest {
  name = "switch-to-configuration";
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
      preroll-safety.preSwitchChecks.enable = true;
      preroll-safety.stockChecks.enable = false;
      preroll-safety.checks.custom = {
        failureMessage = "Custom check failed";
        successMessage = "Custom check succeeded";
        runOn = ["check" "switch" "test" "boot"];
        check.program = lib.getExe (
          pkgs.writeShellApplication {
            name = "custom-check";
            text = ''
              [ ! -f /run/custom-check-failure ]
            '';
          }
        );
      };
      system.switch.enable = true;

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };
  };

  testScript = {nodes, ...}: let
    machineSystem = nodes.machine.system.build.toplevel;
  in ''
    machine.start()
    machine.succeed("udevadm settle")
    machine.wait_for_unit("multi-user.target")
    with subtest("Custom check is ok"):
        machine.succeed("${machineSystem}/bin/switch-to-configuration check")
    with subtest("Custom check can be made to fail"):
        machine.succeed("touch /run/custom-check-failure")
        machine.fail("${machineSystem}/bin/switch-to-configuration check")
        machine.fail("${machineSystem}/bin/switch-to-configuration test")
        machine.fail("${machineSystem}/bin/switch-to-configuration switch")
        machine.fail("${machineSystem}/bin/switch-to-configuration boot")
        # But the check doesn't run on "boot", so this should succeed:
        machine.succeed("${machineSystem}/bin/switch-to-configuration dry-activate")
  '';
}
