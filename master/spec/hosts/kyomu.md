# Hosts: kyomu

---

## Context

`kyomu` host is configured in: `/home/pl/nix-config/hosts/kyomu/default.nix`

Both `kyomu` and `nagomi` currently exists on the same machine
and are distinct installations of NixOS on two separate SSD drives
plugged into this machine which means only one host can be booted
at the same time

## Purpose

Combine development/multimedia host.

### primary purpose

- serve as a secondary headless development machine for user `pl`
- runs headlessly

### secondary purpose

- serve as a home multimedia machine for user `jennifer`
- runs a desktop environment
- auto-logins for use `jennifer`
- must include support for Chinese input:
  - Traditional Taiwanese zhuyin/bopomofo
  - example existing ibus module: `/home/pl/nix-config/modules/ibus.nix`
