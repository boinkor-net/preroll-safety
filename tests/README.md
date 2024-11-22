# NixOS tests for the preroll-safety check suite

Tests for this are surprisingly non-trivial:

* This flake demonstrates its utility best in a situation where you run `nixos-rebuild test`
* NixOS tests make it pretty hard to run `nixos-rebuild` (build _or_ test) - you have to download 22GB of build deps, and then the rebuild takes ages anyway.

So, instead of the straightforward way, the tests follow this pattern:

1. Define a bootable, working VM with attributes that exercise the check
2. Boot the VM and run the check, expecting it to succeed
3. Alter the VM such that the attribute is no longer safe (in the case of filesystems, delete the block device)
4. Re-run the check, expecting it to fail.
