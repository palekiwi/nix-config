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
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notifications-server = {
      url = "path:/home/pl/code/palekiwi-labs/notifications-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-desktop, home-manager, notifications-server, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      nixosConfigurations = {
        claude-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./vm/claude/default.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.claude = import ./vm/claude/home.nix;
            }
          ];

          specialArgs = {
            claude-desktop-pkg = claude-desktop.packages.x86_64-linux;
          };
        };

        pale = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/pale
            notifications-server.nixosModules.default
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

        kyomu = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/kyomu
            inputs.sops-nix.nixosModules.sops
          ];
        };
      };

      packages.x86_64-linux = {
        claude = self.nixosConfigurations.claude-vm.config.system.build.vm;

        claude-spice = pkgs.writeShellScriptBin "claude-spice" ''
          ${pkgs.spice-gtk}/bin/spicy -h localhost -p 5930
        '';
      };
    };
}
