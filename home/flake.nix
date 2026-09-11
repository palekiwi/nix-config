{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cast = {
      url = "github:palekiwi-labs/cast/v0.2.0-rc.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cue = {
      url = "github:palekiwi-labs/cue/data-model-spike";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cue-legacy = {
      url = "github:palekiwi-labs/cue/6748aa3a8a4386fbff90d7aea63443aeb2bfcee7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-pr-sync = {
      url = "github:palekiwi-labs/git-pr-sync";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    handy.url = "github:cjpais/Handy";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
          overlays = [
            (final: prev: {
              cast = inputs.cast.packages.x86_64-linux.cast;
              cast-mcp-client = inputs.cast.packages.x86_64-linux.cast-mcp-client;
              cue = inputs.cue.packages.x86_64-linux.cue;
              cue-legacy = final.writeShellScriptBin "cue-legacy" ''
                exec ${inputs.cue-legacy.packages.x86_64-linux.cue}/bin/cue "$@"
              '';
              git-pr-sync = inputs.git-pr-sync.packages.x86_64-linux.git-pr-sync;
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
