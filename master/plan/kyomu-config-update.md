---
status: open
---
# Implementation Plan: Update `kyomu` host configuration

Based on the spec in `.cue/master/spec/hosts/kyomu.md`, `kyomu` needs to be updated to support its dual purpose:
1. Headless development machine for user `pl`.
2. Home multimedia machine for user `jennifer` with desktop environment and Chinese input support.

## Proposed Changes

### 1. User Configuration (`hosts/kyomu/user.nix`)
- Add user `jennifer`.
- Enable auto-login for `jennifer` via GDM.

### 2. Desktop Environment (`hosts/kyomu/default.nix`)
- Import `../../modules/awesome.nix` (which enables GDM, GNOME, and Awesome WM).
- Import `../../modules/ibus.nix` for Chinese input support.

### 3. Chinese Input Support (`hosts/kyomu/default.nix`)
- Enable `modules.ibus.enable = true`.
- Update `modules/ibus.nix` or override in `kyomu` to include Traditional Taiwanese zhuyin/bopomofo (likely `ibus-chewing`).

### 4. Hardware/System tweaks
- Ensure the kernel version and other settings are appropriate for desktop use.

## Detailed Steps

### Phase 1: User `jennifer` and Autologin
- Edit `hosts/kyomu/user.nix` to add `jennifer` user.
- Configure `services.displayManager.autoLogin` for `jennifer`.

### Phase 2: Desktop Environment and IBus
- Edit `hosts/kyomu/default.nix` to include `awesome.nix` and `ibus.nix`.
- Enable `modules.ibus.enable = true`.

### Phase 3: Input Method Engines
- Verify which ibus engine provides "Traditional Taiwanese zhuyin/bopomofo". `ibus-chewing` is a common choice.
- Update `modules/ibus.nix` or `hosts/kyomu/default.nix` to include `pkgs.ibus-engines.chewing`.

## Verification Plan

### Automated Tests
- Since this is a host configuration, we can use `nixos-rebuild dry-activate` (if on the machine) or check for evaluation errors.

### Manual Verification
- Verify `jennifer` is added to the system.
- Verify `services.xserver.displayManager.autoLogin.user` is set to `jennifer`.
- Verify `i18n.inputMethod.ibus.engines` includes `chewing`.
- Verify `services.xserver.enable` is `true`.
