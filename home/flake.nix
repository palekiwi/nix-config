{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-rspec.url = "github:palekiwi/mcp-rspec/f4bf92f6f859ab35b060a3a932e7b7930d31d504";
    test-runner-mcp.url = "github:palekiwi-labs/test-runner-mcp/13d05835c8d8a3829a6f07776b6e646571944ab3";
    wrappedAgents.url = "github:palekiwi-labs/agents/137e07883605385f8989bbe96849a3da82923df9";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
          overlays = [
            (final: prev: {
              gemini = inputs.wrappedAgents.packages.x86_64-linux.gemini;
              mcp-rspec = inputs.mcp-rspec.packages.x86_64-linux.default;
              opencode = inputs.wrappedAgents.packages.x86_64-linux.opencode;
              opencode-ruby = inputs.wrappedAgents.packages.x86_64-linux.opencode-ruby;
              opencode-rust = inputs.wrappedAgents.packages.x86_64-linux.opencode-rust;
              test-runner-mcp = inputs.test-runner-mcp.packages.x86_64-linux.default;
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
