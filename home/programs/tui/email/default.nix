{ pkgs, pkgs-unstable, ... }:

{
  home.packages = [
    (pkgs.himalaya.override { buildFeatures = [ "notmuch" "maildir" "imap" "smtp" ]; })
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
    ygt = {
      primary = true;

      flavor = "gmail.com";

      userName = "pawel.lisewski@yourgolftravel.com";
      realName = "Pawel Lisewski";
      address = "pawel.lisewski@yourgolftravel.com";
      passwordCommand = "${pkgs.pass}/bin/pass pawel.lisewski@yourgolftravel.com";

      maildir.path = "ygt";

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

      # himalaya = {
      #   enable = true;
      #   settings = {
      #     backend = {
      #       type = "maildir";
      #       root-dir = "~/Maildir";
      #     };

      #     folder.alias = {
      #       inbox = "ygt/Inbox";
      #       airbrake-s = "ygt/Airbrake/Staging";
      #       airbrake-p = "ygt/Airbrake/Production";
      #       sent = "ygt/[Gmail]/'Sent Mail'";
      #       important = "ygt/[Gmail]/Important";
      #       drafts = "ygt/[Gmail]/Drafts";
      #     };
      #   };
      # };

      mbsync = {
        enable = true;
        create = "maildir";
        expunge = "both";
        patterns = [
          "INBOX"
          "Accounts"
          "Airbrake/*"
          "GCP"
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
