{ pkgs, lib, ... }:

let
  tools = [
    "atlassian.com"
    "fullstory.com"
    "lastpass.com"
    "slack.com"
  ];

  filters = [
    {
      message = "Airbrake";
      query = "from:airbrake.io";
      tags = [ "+airbrake" "-new" ];
    }
    {
      message = "Airbrake: Production alerts";
      query = "from:alerts.airbrake.io AND subject:Production";
      tags = ["+airbrake/production" "-new"];
    }
    {
      message = "Tagging Staging Airbrake alerts";
      query = "from:alerts.airbrake.io AND subject:Staging";
      tags = ["+airbrake/staging" "-new"];
    }
    {
      message = "Tagging Spabreaks";
      query = "to:team@spabreaks.com";
      tags = ["+spabreaks" "-new"];
    }
    {
      message = "Developers";
      query = "to:developers@spabreaks.com OR from:developers@spabreaks";
      tags = ["+developers" "-new"];
    }
    {
      message = "Bookings";
      query = "from:bookings@spabreaks.com";
      tags = ["+bookings" "-new"];
    }
    {
      message = "Tools";
      query = "${lib.concatMapStringsSep " OR" (domain: " from:${domain}") tools}";
      tags = ["+tools" "-new"];
    }
    {
      message = "Google";
      query = "from:google.com";
      tags = ["+google" "-new"];
    }
  ];

  headerMatchingFilters = [
    {
      header = "X-GitHub-Reason";
      pattern = "review_requested";
      tags = ["+github" "+review-requested" "+urgent"];
    }
    {
      header = "X-GitHub-Reason";
      pattern = "mention";
      tags = ["+github" "+mentioned"];
    }
    {
      header = "Message-ID";
      pattern = "calendar-.*@google\.com";
      tags = ["+calendar" "+spabreaks" "-new"];
    }
  ];

  mkConfigAttrs = attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value:
        if key == "tags"
        then "tags = ${lib.concatStringsSep ";" value}"
        else "${key} = ${value}"
      ) attrs
    );

  mkFilterSection = filterType: idx: attrs: ''
    [${filterType}.${toString idx}]
    ${mkConfigAttrs attrs}
  '';

  mkFilterSections = filterType: filters:
    lib.concatStringsSep "\n" (
      lib.imap0 (idx: attrs: (mkFilterSection filterType idx attrs)) filters
    );
in
{
  programs = {
    afew = {
      enable = true;

      extraConfig = ''
        ${mkFilterSections "Filter" filters}
        ${mkFilterSections "HeaderMatchingFilter" headerMatchingFilters}
      '';
    };

    notmuch.hooks.postNew = ''
      ${pkgs.afew}/bin/afew --tag --new
    '';
  };
}
