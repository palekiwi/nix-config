{ pkgs, lib, ... }:

let
  filters = import ./filters.nix { inherit lib; };
  headerMatchingFilters = import ./header-matching-filters.nix;

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
      lib.imap1 (idx: attrs: (mkFilterSection filterType idx attrs)) filters
    );
in
{
  programs = {
    afew = {
      enable = true;

      extraConfig = ''
        ${mkFilterSections "HeaderMatchingFilter" headerMatchingFilters}
        ${mkFilterSections "Filter" filters}
      '';
    };

    notmuch.hooks.postNew = ''
      ${pkgs.afew}/bin/afew --tag --new
    '';
  };
}
