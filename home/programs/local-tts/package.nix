{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  python3,
  makeWrapper,
  sherpa-onnx,
  pipewire,
  wl-clipboard,
  xclip,
  backend ? "cpu",
  volume ? 1.0,
}:
let
  model = stdenvNoCC.mkDerivation {
    pname = "kokoro-int8-en";
    version = "0.19";
    src = fetchurl {
      url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2";
      hash = "sha256-yfDdOTYVgFsLqwUMNAg01eaE5zKuyRwOhgzTDpgsCL0=";
    };
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r . "$out/"
      runHook postInstall
    '';
    meta.license = lib.licenses.asl20;
  };
in
stdenv.mkDerivation {
  pname = "local-tts";
  version = "0.3.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3 ];
  buildInputs = [ sherpa-onnx ];
  buildPhase = ''
    runHook preBuild
    $CXX -std=c++17 -Wall -Wextra -Werror engine.cc -o speak-engine \
      -lsherpa-onnx-cxx-api -lsherpa-onnx-c-api
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 -m unittest -v
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/local-tts" "$out/bin"
    cp speak.py http_engine.py speak-engine "$out/lib/local-tts/"
    makeWrapper ${python3}/bin/python3 "$out/bin/speak" \
      --add-flags "$out/lib/local-tts/speak.py" \
      --set-default SPEAK_BACKEND ${lib.escapeShellArg backend} \
      --set-default SPEAK_MODEL ${model} \
      --set-default SPEAK_ENGINE "$out/lib/local-tts/speak-engine" \
      --set-default SPEAK_PLAYER ${pipewire}/bin/pw-play \
      --set-default SPEAK_VOLUME ${toString volume} \
      --set-default SPEAK_WL_PASTE ${wl-clipboard}/bin/wl-paste \
      --set-default SPEAK_XCLIP ${xclip}/bin/xclip
    runHook postInstall
  '';
  passthru = { inherit model; };
  meta = {
    description = "Foreground local Kokoro speech with Bella";
    mainProgram = "speak";
    platforms = lib.platforms.linux;
  };
}
