# `preroll-safety` - a NixOS module for pre-checking that your NixOS configs can be activated

NixOS allows you to "test" your system configurations before you boot into them. That's really cool and helps weed out a bunch of errors. Unfortunately, NixOS also allows you to write system configurations that result in your machine (mainly systemd on the machine) throwing up its hands and going "I have no idea how you want me to operate", locking you out of SSH access but requiring a reboot into a working configuration.

One example is the [`fileSystems`](https://search.nixos.org/options?channel=24.05&show=fileSystems&from=0&size=50&sort=relevance&type=packages&query=fileSystems) attrset: If you add a mount point referencing a block device that doesn't exist, your system configuration will build, but `nixos-rebuild test` will cause systemd to enter emergency mode and then, good luck getting out of it.

The NixOS module in this repo is meant to help you avoid those situations!

## How it works

Since a nixos system configuration possibly gets "built" somewhere other than the machine it runs on (and even if it's built on the same machine, it's in a sandbox), we can not rely on the build process to find all the issues.

Instead, this module writes an additional script into the system config closure's "out" directory, which just sits there most times (it's named `pre-activate-safety-checks` by default). This script does nothing, and is ignored by `nixos-rebuild`.

However! If you're using a safety-aware deploy tool (e.g. [deploy-flake](https://github.com/boinkor-net/deploy-flake) by the author), you can instruct it to run the safety check program before activating your system; if that exits with a non-0 status, your tool knows that the system configuration isn't safe to apply and can exit before your machine drops off the network.

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
   preroll-safety.enable = true;
   ```

The repo comes with a few [pre-defined checks](./nixos/checks). You can define your own, too. See those checks for examples!
