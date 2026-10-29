{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cue-platform = {
      # TODO: back to github:palekiwi-labs/cue-platform once feat/cast-tui lands
      url = "git+file:///home/pl/code/palekiwi-labs/cue-platform?ref=feat/cast-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-pr-sync = {
      url = "github:palekiwi-labs/git-pr-sync";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sb-scripts = {
      url = "git+ssh://git@github.com/spabreaks/sb-scripts.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
          overlays = [
            (final: prev: {
              cast = inputs.cue-platform.packages.x86_64-linux.cast;
              cast-mcp-client = inputs.cue-platform.packages.x86_64-linux.cast-mcp-client;
              cast-tui = inputs.cue-platform.packages.x86_64-linux.cast-tui;
              cue = inputs.cue-platform.packages.x86_64-linux.cue;
              git-pr-sync = inputs.git-pr-sync.packages.x86_64-linux.git-pr-sync;
              sb-scripts = inputs.sb-scripts.packages.${system}.default;
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
