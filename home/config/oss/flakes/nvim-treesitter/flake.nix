{
  description = "Development environment for contributing to nvim-treesitter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "nvim-treesitter-dev-shell";
          buildInputs = with pkgs; [
            # Required linting and formatting tools
            luajitPackages.luacheck
            stylua
            
            # Development essentials
            git
            neovim
            
            # Tree-sitter tools for testing
            tree-sitter
          ];

          shellHook = ''
            echo "nvim-treesitter development environment"
            echo "========================================"
            echo ""
            echo "Available tools:"
            echo "  - luacheck: $(luacheck --version 2>/dev/null || echo 'not found')"
            echo "  - stylua: $(stylua --version 2>/dev/null || echo 'not found')"
            echo "  - tree-sitter: $(tree-sitter --version 2>/dev/null || echo 'not found')"
            echo "  - neovim: $(nvim --version | head -1)"
            echo ""
            echo "Setup steps after cloning nvim-treesitter:"
            echo "  1. ln -s ../../scripts/pre-push .git/hooks/pre-push"
            echo "  2. Test validation: make query"
            echo ""
            echo "Working on injection queries:"
            echo "  - File location: queries/nix/injections.scm"
            echo "  - Test with: nvim your-test-file.nix"
            echo "  - Validate with: make checkquery"
            echo ""
            echo "Happy contributing!"
          '';
        };

        # Optional: Package for the injection query (for testing)
        packages.test-injection = pkgs.writeTextFile {
          name = "test-nix-nu-injection";
          text = ''
            # Test file for nix-nu injection
            # Place your injection query in queries/nix/injections.scm
            
            # Example nix file with nu script (adjust based on your specific use case)
            {
              programs.nushell = {
                enable = true;
                configFile.text = '''
                  # This should be highlighted as nu script
                  def hello [name: string] {
                    print $"Hello ($name)!"
                  }
                  
                  ls | where type == file | get name
                ''';
              };
            }
          '';
          destination = "/test.nix";
        };
      });
}
