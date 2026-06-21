---
status: complete
---
# Plan: Add Docker Package Option to Docker Module

To allow configuring the Docker package used by the system, we will modify `/home/pl/nix-config/modules/docker.nix` to include a `package` option.

## Proposed Changes

### 1. Update `modules/docker.nix`

- Add `pkgs` to the module arguments.
- Add `package` to `options.modules.docker` with a default value of `pkgs.docker`.
- Set `virtualisation.docker.package` in the `config` block.

```nix
{ config, lib, pkgs, ... }:
{
  options.modules.docker = {
    enable = lib.mkEnableOption "enable docker";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.docker;
      description = "The docker package to use";
    };
  };

  config = lib.mkIf config.modules.docker.enable {
    users.users.pl = {
      extraGroups = [ "docker" ];
    };

    virtualisation.docker.enable = true;
    virtualisation.docker.package = config.modules.docker.package;
  };
}
```

## Verification Plan

### Automated Tests
- Since this is a NixOS configuration change, I will run `nix-instantiate` to ensure the syntax is correct (though I don't have a full system to build).
- I can check the evaluation of the flake.

### Manual Verification
- After applying the changes, the user can verify they can set `modules.docker.package` in their host configuration, e.g., in `hosts/sayuri/default.nix`:
  ```nix
  modules.docker.package = pkgs.moby;
  ```
