{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    test-runner-mcp = {
      url = "github:palekiwi-labs/test-runner-mcp";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    wrappedOpencode = {
      url = "github:palekiwi-labs/agents";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, wrappedOpencode, test-runner-mcp, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
          overlays = [
            (final: prev: {
              opencode = wrappedOpencode.packages.x86_64-linux.opencode;
              opencode-rust = wrappedOpencode.packages.x86_64-linux.opencode-rust;
              test-runner-mcp = test-runner-mcp.packages.x86_64-linux.default;
            })
          ];
      };
      pkgs-unstable = import nixpkgs-unstable { inherit system; };
    in
    {
      defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;

      homeConfigurations = {
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
      };
    };
}
