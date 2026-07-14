---
title: migrate to nixpkgs 26.05
status: in-progress
priority: high
---
## System and home-manager configs

- system flake: `/home/pl/nix-config/flake.nix`
- home manager: `/home/pl/nix-config/home/flake.nix`

## Neovim migration to v0.12

- nvim config is located in: `/home/pl/nix-config/home/config/nvim/`
- neovim v0.12 can't use nvim-treesitter plugin: `/home/pl/nix-config/home/config/nvim/lua/config/plugins/treesitter.lua`
- we need to disable the plugin and find out how to configure parsers, some
  guides exist, e.g. https://www.qu8n.com/posts/treesitter-migration-guide-for-nvim-0-12

