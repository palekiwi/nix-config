{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-rspec.url = "github:palekiwi/mcp-rspec";
    cast.url = "github:palekiwi-labs/cast";
    cue.url = "github:palekiwi-labs/cue";
    ocx.url = "github:palekiwi-labs/ocx";
    handy.url = "github:cjpais/Handy";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
          overlays = [
            (final: prev: {
              mcp-rspec = inputs.mcp-rspec.packages.x86_64-linux.default;
              cast = inputs.cast.packages.x86_64-linux.cast;
              cast-mcp-client = inputs.cast.packages.x86_64-linux.cast-mcp-client;
              cue = inputs.cue.packages.x86_64-linux.cue;
              curator = inputs.cue.packages.x86_64-linux.curator;
              ocx = inputs.ocx.packages.x86_64-linux.default;
              handy = inputs.handy.packages.x86_64-linux.default;
            })
          ];
      };
      pkgs-unstable = import nixpkgs-unstable { inherit system; };
    in
    {
      # defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
      defaultPackage.x86_64-linux = home-manager.packages.x86_64-linux.default;

      homeConfigurations = {
        "pl@deck" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./users/pl/deck.nix
            ./options
          ];
          extraSpecialArgs = { inherit inputs pkgs-unstable; };
        };

        "pl@pale" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./users/pl/pale.nix
            ./options
          ];
          extraSpecialArgs = { inherit inputs pkgs-unstable; };
        };

        "pl@sayuri" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./users/pl/sayuri.nix ./options ];
          extraSpecialArgs = { inherit inputs; };
        };

        "pl@kyomu" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./users/pl/kyomu.nix ./options ];
          extraSpecialArgs = { inherit inputs pkgs-unstable; };
        };
      };
    };
}
