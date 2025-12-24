{ pkgs, ... }:

{
  programs = {
    mbsync.enable = true;
    msmtp.enable = true;

    notmuch = {
      enable = true;
      hooks.postNew = ''
        ${pkgs.afew}/bin/afew --tag --new
      '';
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

        # Airbrake Alerts
        [Filter.1]
        query = from:donotreply@alerts.airbrake.io
        tags = +airbrake;-new
        message = Tagging Airbrake alerts

        # Airbrake Alerts Production
        [Filter.2]
        query = from:donotreply@alerts.airbrake.io AND subject:Production
        tags = +airbrake/production;-new
        message = Tagging Production Airbrake alerts

        # Airbrake Alerts Staging
        [Filter.3]
        query = from:donotreply@alerts.airbrake.io AND subject:Staging
        tags = +airbrake/staging;-new
        message = Tagging Staging Airbrake alerts

        # Airbrake Weekly reports
        [Filter.4]
        query = from:weekly@airbrake.io
        tags = +airbrake;-new
        message = Tagging Airbrake weekly reports

        # Spabreaks
        [Filter.5]
        query = to:team@spabreaks.com
        tags = +spabreaks;-new
        message = Tagging Spabreaks
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
          "[Gmail]/All Mail"
          "[Gmail]/Drafts"
          "[Gmail]/Sent Mail"
        ];
      };

      msmtp = {
        enable = true;
      };
    };
  };
}
