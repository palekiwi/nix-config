alias v = nvim
alias hms = home-manager switch --flake $"($nu.home-path)/nix-config/home#(whoami)@(hostname -s)"
alias rebuild = sudo nixos-rebuild switch --flake $"($nu.home-path)/nix-config#(hostname -s)"
