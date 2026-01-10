{ pkgs, ... }:

{
  accounts.email.accounts = {
    spabreaks = {
      primary = true;

      flavor = "gmail.com";

      userName = "pawel.lisewski@spabreaks.com";
      realName = "Pawel Lisewski";
      address = "pawel.lisewski@spabreaks.com";
      passwordCommand = "cat /run/secrets/spabreaks/gmail/nixos";


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

      notmuch. enable = true;

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
