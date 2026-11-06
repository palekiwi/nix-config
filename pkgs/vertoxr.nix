{ appimageTools, requireFile }:

appimageTools.wrapType2 rec {
  pname = "vertoxr";
  version = "0.2.14";

  src = requireFile {
    name = "vertoxr_linux_${version}.appimage";
    sha256 = "2858761c6de262c090e5f4fe5ca2fcdc076269e228a39e17ff030889a48cb5cd";
    message = ''
      Add the AppImage to the nix store first:
        nix store add-file ~/Downloads/vertoxr_linux_${version}.appimage
    '';
  };

  extraPkgs = p: with p; [ libepoxy ];
}
