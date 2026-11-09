{
  pkgs ? (builtins.getFlake (toString ../../..)).inputs.nixpkgs.legacyPackages.x86_64-linux,
}:
pkgs.mkShell {
  packages = with pkgs; [
    python3
    stdenv.cc
    patchelf
    binutils
    pipewire
  ];
  LOCAL_TTS_PILOT_LOADER = "${pkgs.stdenv.cc.bintools.dynamicLinker}";
  LOCAL_TTS_PILOT_SYSTEM_LIBS = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];
}
