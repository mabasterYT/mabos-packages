# Helium, a Chromium-based browser (Arch's helium-browser-bin): the upstream AppImage.
# helium-browser too, the name Arch's package gives it.
{ appimageTools, fetchurl }:
let
  pname = "helium";
  version = "0.21.2.1";
  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-IdP+SyvmN+uT/eogjWsG1/6feO6MF9gP/57SM3AsBmo=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    ln -s helium $out/bin/helium-browser
    install -Dm644 ${contents}/helium.desktop -t $out/share/applications
    install -Dm644 ${contents}/helium.png -t $out/share/icons/hicolor/256x256/apps
  '';
  meta.mainProgram = "helium";
}
