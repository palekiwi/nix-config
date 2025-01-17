# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "akemi"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Taipei";

  # Select internationalisation properties.
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFOyIzj48/XjyTC9B6HL7oxkIcGtxNgCaSpje+lldrlqb1Vmo2KGdlkHFSSDYkvOYzNgoE9ywKi7kYrvUXJ4SXhtqKu1VmYzYY8o2/aCgMY3Y1qmgCAvDsgec1imL3mCdCO447Iim+ckmlrAboSK8zBEGvBrEI2PMKLAStFf6zycJ4vJA94778GxpcA25g6mp/WHsKp1QvELLl/mL3I9z+SDoCSR7BK2vu6xgQfuJP+BepKzlHpZlpZF4OkGi9VAEsNxjSV0QbFTsL0Q04hrySzGi39b0eRe1AvWo/jFCtzS9BqM78NI4Ii8PP3PL3UUXgctqDwiLhSZaYVvFMR13LjJW1W1qe1KXbum6Q4+/YlWAaJ9322035aZRq0NzQgmZbC6wvcQDBVQru6NcZy1nnCGwJ77mLPm+nM+XIA5JzsBNCnMVVpa/tmC28fPbe0Z6tkJNeU53sCv5rQDg/kVagrZ2RP5Renf4PzJx8ps8ew8Q31nKXZcZ/Qb1eBFgqVubmvUGXC1C6RlfhkWOX/0oBsp7nI9nDeqa7wNJBJ29TMr/LQ6m1ZzblFZY91n2EsSGxM7RbBWTY2FS6xwXgM+AIdBNrU1Kn6F2mhlcuzGSbfQnLCEtr5HRxItJSu6XGx11Ps79yXHWbFai84V9777Xz8WftAeRoEcBixDrNXJmsw== cardno:15_196_430"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    gnupg
    neovim
    rsync
    wget
    zsh
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
