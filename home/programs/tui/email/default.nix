{ pkgs, ... }:

{
  home.packages = [ pkgs.himalaya];

  programs = {
    mbsync.enable = true;
    msmtp.enable = true;

    notmuch = {
      enable = true;
      hooks = {
        preNew = "mbsync --all";
      };
    };

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

      neomutt = {
        enable = true;

        extraMailboxes = [
          "Accounts"
          "Airbrake/Production"
          "Airbrake/Staging"
          "GCP"
        ];
      };

      mbsync = {
        enable = true;
        create = "maildir";
        expunge = "both";
        patterns = [ "*" ];
      };

      msmtp = {
        enable = true;
      };
    };
  };
}
