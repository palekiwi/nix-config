{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;

      homeConfigurations = {
        "pl@pale" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./users/pl/pale.nix ./options ];
          extraSpecialArgs = { inherit inputs; };
        };

        "pl@sayuri" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./users/pl/sayuri.nix ./options ];
          extraSpecialArgs = { inherit inputs; };
        };
      };
    };
}
