{ pkgs, ... }:

{
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

        # Dracula Theme for NeoMutt

        # General colors
        color normal default default
        color error brightred default
        color tilde black default
        color message cyan default
        color markers brightred white
        color attachment brightmagenta default
        color search brightgreen default
        color status brightwhite black
        color indicator black cyan
        color tree yellow default

        # Index colors
        color index cyan default ~N            # New messages
        color index blue default ~O            # Old messages
        color index brightred default ~D       # Deleted messages
        color index brightgreen default ~F     # Flagged messages
        color index brightyellow default ~T    # Tagged messages

        # Message headers
        color hdrdefault cyan default
        color header brightgreen default "^From:"
        color header brightblue default "^Subject:"
        color header brightmagenta default "^Date:"

        # Body colors
        color quoted green default
        color quoted1 blue default
        color quoted2 magenta default
        color quoted3 cyan default
        color quoted4 yellow default

        # URL colors
        color body brightblue default "([a-z][a-z0-9+-]*://(((([a-z0-9_.!~*'();:&=+$,-]|%[0-9a-f][0-9a-f])*@)?((([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?|[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)(:[0-9]+)?)|([a-z0-9_.!~*'()$,;:@&=+-]|%[0-9a-f][0-9a-f])+)(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?(#([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?|(www|ftp)\\.(([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?(:[0-9]+)?(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?(#([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?)[^].,:;!)? \t\r\n<>\"]"

        # Sidebar colors
        color sidebar_indicator black cyan
        color sidebar_highlight black color8
        color sidebar_divider color8 default
        color sidebar_flagged red default
        color sidebar_new green default
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
