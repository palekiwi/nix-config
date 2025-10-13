{ pkgs, pkgs-unstable, ... }:

{
  home.packages = [
    (pkgs.himalaya.override { withFeatures = [ "notmuch" "maildir" "imap" "smtp" ]; })
  ];

  programs = {
    mbsync.enable = true;
    msmtp.enable = true;
    notmuch. enable = true;

    # himalaya = {
    #   enable = true;
    #   package = pkgs-unstable.himalaya.override { buildFeatures = [ "notmuch" "maildir" "imap" "smtp" ]; };
    # };

    neomutt = {
      enable = true;
      vimKeys = true;

      sidebar = {
        enable = true;
        width = 30;
        shortPath = false;
      };

      settings = {
        mail_check_stats = "yes";
      };

      extraConfig = ''
        macro index,pager gi "<change-folder>=Inbox<Enter>" "Go to inbox"

        macro index,pager \cb "<pipe-message> ${pkgs.urlscan}/bin/urlscan<Enter>" "Extract URLs"

        ${builtins.readFile ./neomutt/dracula-theme.muttrc}

      '';
    };
  };

  services.mbsync = {
    enable = true;
    frequency = "*:0/2";
    postExec = "${pkgs.notmuch}/bin/notmuch new";
  };

  accounts.email.accounts = {
    spabreaks = {
      primary = true;

      flavor = "gmail.com";

      userName = "pawel.lisewski@spabreaks.com";
      realName = "Pawel Lisewski";
      address = "pawel.lisewski@spabreaks.com";
      passwordCommand = "${pkgs.pass}/bin/pass spabreaks/gmail/nixos";

      maildir.path = "spabreaks";

      imap = {
        port = 993;
        host = "imap.gmail.com";
        tls.enable = true;
      };

      smtp = {
        port = 465;
        host = "smtp.gmail.com";
      };

      notmuch = {
        enable = true;
      };

      mbsync = {
        enable = true;
        create = "maildir";
        expunge = "both";
        patterns = [
          "INBOX"
          "Accounts"
          "Airbrake/*"
          "GCP"
          "Spabreaks"
          "[Gmail]/Drafts"
          "[Gmail]/Important"
          "[Gmail]/Sent Mail"
          "[Gmail]/Starred"
        ];
      };

      msmtp = {
        enable = true;
      };
    };
  };
}
