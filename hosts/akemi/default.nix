{ pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "akemi";

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Taipei";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFOyIzj48/XjyTC9B6HL7oxkIcGtxNgCaSpje+lldrlqb1Vmo2KGdlkHFSSDYkvOYzNgoE9ywKi7kYrvUXJ4SXhtqKu1VmYzYY8o2/aCgMY3Y1qmgCAvDsgec1imL3mCdCO447Iim+ckmlrAboSK8zBEGvBrEI2PMKLAStFf6zycJ4vJA94778GxpcA25g6mp/WHsKp1QvELLl/mL3I9z+SDoCSR7BK2vu6xgQfuJP+BepKzlHpZlpZF4OkGi9VAEsNxjSV0QbFTsL0Q04hrySzGi39b0eRe1AvWo/jFCtzS9BqM78NI4Ii8PP3PL3UUXgctqDwiLhSZaYVvFMR13LjJW1W1qe1KXbum6Q4+/YlWAaJ9322035aZRq0NzQgmZbC6wvcQDBVQru6NcZy1nnCGwJ77mLPm+nM+XIA5JzsBNCnMVVpa/tmC28fPbe0Z6tkJNeU53sCv5rQDg/kVagrZ2RP5Renf4PzJx8ps8ew8Q31nKXZcZ/Qb1eBFgqVubmvUGXC1C6RlfhkWOX/0oBsp7nI9nDeqa7wNJBJ29TMr/LQ6m1ZzblFZY91n2EsSGxM7RbBWTY2FS6xwXgM+AIdBNrU1Kn6F2mhlcuzGSbfQnLCEtr5HRxItJSu6XGx11Ps79yXHWbFai84V9777Xz8WftAeRoEcBixDrNXJmsw== cardno:15_196_430"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "pl" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    git
    gnupg
    neovim
    rsync
    wget
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  services.tailscale.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "24.11";

}
