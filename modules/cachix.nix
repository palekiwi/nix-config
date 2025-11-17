{ ... }:

{
  nix.settings = {
    substituters = [ "https://palekiwi.cachix.org" ];
    trusted-public-keys = [ "palekiwi.cachix.org-1:/S23j64quRTMpe+zteCPAd0p8fczVTWzOpV5mFoFOg8=" ];
  };
}
