# `preroll-safety` - a NixOS module for pre-checking that your NixOS configs can be activated

NixOS allows you to "test" your system configurations before you boot into them. That's really cool and helps weed out a bunch of errors. Unfortunately, NixOS also allows you to write system configurations that result in your machine (mainly systemd on the machine) throwing up its hands and going "I have no idea how you want me to operate", locking you out of SSH access but requiring a reboot into a working configuration.

One example is the [`fileSystems`](https://search.nixos.org/options?channel=24.05&show=fileSystems&from=0&size=50&sort=relevance&type=packages&query=fileSystems) attrset: If you add a mount point referencing a block device that doesn't exist, your system configuration will build, but `nixos-rebuild test` will cause systemd to enter emergency mode and then, good luck getting out of it.

The NixOS module in this repo is meant to help you avoid those situations!

## How it works

As a nixos system configuration possibly gets "built" somewhere other than the machine it runs on (and even if it's built on the same machine, it's in a sandbox and can not make accurate predictions about the destination system state), we can not rely on the build process to find all possible issues.

However, as of November 2024, NixOS ships an option called [`system.preSwitchChecks`](https://search.nixos.org/options?channel=unstable&show=system.preSwitchChecks&query=preSwitchChecks), which allows registering checks that run before the system gets live-activated (or a variety of other conditions, see the [`switch-to-configuration`](https://github.com/NixOS/nixpkgs/blob/39070b6fa9efe06ae1ea43cc034e436ae5366d44/pkgs/by-name/sw/switch-to-configuration-ng/src/src/main.rs#L99-L107) script for details).

So this module presents a friendly structured front-end for these pre-switch checks, and adds a few "stock" checks (for mountability of block-device based and zfs file systems).

## Using it

1. Add it to your flake:
   ```nix
   inputs = {
      # ...
      preroll-safety = "github:boinkor-net/preroll-safety";
   }
   ```
2. Include it as a module in your nixos configuration:
   ```nix
   lib.nixosSystem {
     modules = [
       inputs.preroll-safety.nixosModules.default
       # ...
     ]
   }
   ```
3. Enable writing the safety script, in your system config:
   ```nix
   preroll-safety.preSwitchChecks.enable = true;
   ```

As mentioned, this repo comes with a few [pre-defined checks](./nixos/safety-checks). You can define your own, too. See those checks for examples! There are some nixos-vm based [tests](./tests) also.
