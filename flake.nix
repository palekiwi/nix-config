{
  description = "NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, claude-desktop, ... }@inputs: {
    nixosConfigurations = {
      vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/vm
          {
            environment.systemPackages = [
              claude-desktop.packages.x86_64-linux.claude-desktop-with-fhs
            ];
          }
        ];
      };

      pale = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/pale
          inputs.sops-nix.nixosModules.sops
        ];
      };

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

      haze = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/haze
          ./users/pl
          ./users/git
          inputs.sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
