# Tests for the nixos module. Intended to be invoked via & merged into
# the flake's check attribute.
{
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    final,
    system,
    ...
  }: {
    checks = let
      nixos-lib = import "${inputs.nixpkgs}/nixos/lib" {};
    in
      if ! pkgs.lib.hasSuffix "linux" system
      then {}
      else let
        writeTestFlakeWithConfig = config:
          pkgs.writeText "flake.nix" ''
            {pkgs, lib, config, ...}: {
              imports = [
                ./hardware-configuration.nix
                <nixpkgs/nixos/modules/testing/test-instrumentation.nix>
                ./preroll-safety/nixos/default.nix
              ];

              config = ${config};
            }
          '';

        importTests = name: {
          "${name}" = import ./${name}.nix {
            inherit pkgs nixos-lib writeTestFlakeWithConfig;
            nixosModule = self.nixosModules.default;
            flake-inputs = inputs;
          };
        };
      in
        lib.mkMerge [
          (importTests "filesystems")
        ];
  };
}
