{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
  makeWrapper,
  sherpa-onnx,
  pipewire,
  wl-clipboard,
  xclip,
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
stdenvNoCC.mkDerivation {
  pname = "local-tts";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3 ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 -m unittest -v
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/local-tts" "$out/bin"
    cp speak.py "$out/lib/local-tts/"
    makeWrapper ${python3}/bin/python3 "$out/bin/speak" \
      --add-flags "$out/lib/local-tts/speak.py" \
      --set-default SPEAK_MODEL ${model} \
      --set-default SPEAK_ENGINE ${sherpa-onnx}/bin/sherpa-onnx-offline-tts \
      --set-default SPEAK_PLAYER ${pipewire}/bin/pw-play \
      --set-default SPEAK_WL_PASTE ${wl-clipboard}/bin/wl-paste \
      --set-default SPEAK_XCLIP ${xclip}/bin/xclip
    runHook postInstall
  '';
  passthru = { inherit model; };
  meta = {
    description = "Foreground local CPU Kokoro speech with Bella";
    mainProgram = "speak";
    platforms = lib.platforms.linux;
  };
}
