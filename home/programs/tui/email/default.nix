{ pkgs, ... }:

{
  imports = [
    ./accounts/spabreaks.nix
    ./afew.nix
  ];

  programs = {
    mbsync.enable = true;
    msmtp.enable = true;
    notmuch.enable = true;
  };

  services.mbsync = {
    enable = true;
    frequency = "*:0/2";
    postExec = "${pkgs.notmuch}/bin/notmuch new";
  };
}
