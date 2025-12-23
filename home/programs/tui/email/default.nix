{ pkgs, ... }:

{
  home.packages = [
    (pkgs.himalaya.override { withFeatures = [ "notmuch" "maildir" "imap" "smtp" ]; })
  ];

  programs = {
    mbsync.enable = true;
    msmtp.enable = true;

    notmuch = {
      enable = true;

      hooks = {
        postNew = ''
          ${pkgs.afew}/bin/afew --tag --new
        '';
      };
    };

    afew = {
      enable = true;

      extraConfig = ''
        [HeaderMatchingFilter.1]
        header = X-GitHub-Reason
        pattern = review_requested
        tags = +github;+review-requested;+urgent

        [HeaderMatchingFilter.2]
        header = X-GitHub-Reason
        pattern = mention
        tags = +github;+mentioned
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
          "[Gmail]/All Mail"
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
