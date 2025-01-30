{
  description = "NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      sayuri = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/sayuri
          ./users/pl
          inputs.sops-nix.nixosModules.sops
        ];
      };

      akemi = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/akemi
          ./users/pl
          inputs.sops-nix.nixosModules.sops
        ];
      };

      asa = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/asa
          ./users/pl
          inputs.sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
