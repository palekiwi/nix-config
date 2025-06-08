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

  outputs = { self, nixpkgs, claude-desktop, ... }@inputs: {
    nixosConfigurations = {
      claude-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./vm/claude/default.nix ];

        specialArgs = {
          claude-desktop-pkg = claude-desktop.packages.x86_64-linux;
        };
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

    packages.x86_64-linux = {
      claude = self.nixosConfigurations.claude-vm.config.system.build.vm;
    };
  };
}
