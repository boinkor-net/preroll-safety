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
        importTests = name: {
          "${name}" = import ./${name}.nix {
            inherit pkgs nixos-lib;
            nixosModule = self.nixosModules.default;
          };
        };
      in
        lib.mkMerge [
          (importTests "custom")
          (importTests "filesystems")
          (importTests "zfs")
        ];
  };
}
