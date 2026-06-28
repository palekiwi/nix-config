{
  description = "NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notifications-server = {
      url = "github:palekiwi-labs/notifications-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cue = {
      url = "github:palekiwi-labs/cue";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cast-haze = {
      # Pinned to a specific rev so the claude-ping service and the haze
      # systemwide cast use one reproducible version. Bump deliberately.
      url = "github:palekiwi-labs/cast/20201aa8c6a919a53d5798c2c36e8f2ab9ede7f9";
    };
  };

  outputs = { self, nixpkgs, claude-desktop, home-manager, ... }@inputs:
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

        deck = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/deck
            inputs.notifications-server.nixosModules.default
            inputs.sops-nix.nixosModules.sops
          ];
        };

        pale = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/pale
            inputs.notifications-server.nixosModules.default
            inputs.cue.nixosModules.acuity
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

          specialArgs = {
            z2m = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.zigbee2mqtt;
            cast-haze = inputs.cast-haze.packages.x86_64-linux.cast;
          };
        };

        kyomu = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/kyomu
            inputs.notifications-server.nixosModules.default
            inputs.sops-nix.nixosModules.sops
          ];
        };

        nagomi = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/nagomi
          ];
        };
      };

      packages.x86_64-linux = {
        claude = self.nixosConfigurations.claude-vm.config.system.build.vm;

        claude-spice = pkgs.writeShellScriptBin "claude-spice" ''
          ${pkgs.spice-gtk}/bin/spicy -h localhost -p 5930
        '';
      };

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          luajit
          lua-language-server
          nixd
          nixfmt-rfc-style
        ];
      };
    };
}
