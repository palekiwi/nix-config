{ pkgs, lib, ... }:

let
  tools = [
    "atlassian.com"
    "fullstory.com"
    "lastpass.com"
    "slack.com"
  ];

  headerMatchingFilters = [
    {
      header = "X-GitHub-Reason";
      pattern = "review_requested";
      tags = "+github;+review-requested;+urgent";
    }
    {
      header = "X-GitHub-Reason";
      pattern = "mention";
      tags = "+github;+mentioned";
    }
    {
      header = "Message-ID";
      pattern = "calendar-.*@google\.com";
      tags = "+calendar;+spabreaks;-new";
    }
  ];

  mkConfigAttrs = attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value: "${key} = ${value}") attrs
    );

  mkFilterSection = filterType: idx: attrs: ''
    [${filterType}.${toString idx}]
    ${mkConfigAttrs attrs}
  '';

  mkFilterSections = filterType: filters:
    lib.concatStringsSep "\n" (
      lib.imap0 (idx: attrs: (mkFilterSection filterType idx attrs)) headerMatchingFilters
    );
in
{
  programs = {
    afew = {
      enable = true;

      extraConfig = ''
        ${mkFilterSections "headerMatchingFilters" headerMatchingFilters}

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

        [Filter.6]
        message = Developers
        query = to:developers@spabreaks.com OR from:developers@spabreaks
        tags = +developers;-new

        [Filter.7]
        message = Bookings
        query = from:bookings@spabreaks.com
        tags = +developers;-new

        [Filter.8]
        message = Tools
        query = ${lib.concatMapStringsSep " OR" (domain: " from:${domain}") tools}
        tags = +tools;-new

        [Filter.9]
        message = Google
        query = from:google.com
        tags = +google;-new
      '';
    };

    notmuch.hooks.postNew = ''
      ${pkgs.afew}/bin/afew --tag --new
    '';
  };
}
