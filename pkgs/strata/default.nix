# Strata, MabOS's file manager: the upstream release build (Arch's strata-bin), made to run on
# NixOS. 1.1.1 is the version MabOS's style was checked against (see Strata in docs/programs.md).
{ lib, stdenv, fetchurl, autoPatchelfHook, wrapGAppsHook4, gtk4, pango, gdk-pixbuf, cairo
, graphene, glib, poppler, fontconfig, gtksourceview5, gst_all_1, ffmpeg, ffmpegthumbnailer
, bubblewrap, desktop-file-utils, xdg-utils }:
stdenv.mkDerivation (finalAttrs: {
  pname = "strata";
  version = "1.1.1";

  src = fetchurl {
    url = "https://github.com/lgse/strata/releases/download/v${finalAttrs.version}/strata-${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-4FUuB3L83tE6gohHR7KPCzIiCjKTHNpuVfg1dbvlBzQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook wrapGAppsHook4 ];
  buildInputs = [
    gtk4 pango gdk-pixbuf cairo graphene glib poppler fontconfig gtksourceview5
    gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good gst_all_1.gst-libav
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 strata $out/bin/strata
    install -Dm644 io.github.lgse.Strata.desktop -t $out/share/applications
    install -Dm644 io.github.lgse.Strata.svg -t $out/share/icons/hicolor/scalable/apps
    install -Dm644 LICENSE -t $out/share/licenses/strata
    # "Show in folder" when nothing else owns FileManager1 (MabOS's mabos-filemanager1 does)
    install -Dm644 io.github.lgse.Strata.FileManager1.service -t $out/share/dbus-1/services
    substituteInPlace $out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service \
      --replace-fail /usr/bin/strata $out/bin/strata
    # Its file chooser as a portal backend (what strata --install-portal writes into ~ on Arch)
    install -Dm644 portal/strata.portal -t $out/share/xdg-desktop-portal/portals
    install -Dm644 portal/org.freedesktop.impl.portal.desktop.strata.service.in \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
    substituteInPlace $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service \
      --replace-fail @STRATA_EXECUTABLE@ $out/bin/strata
    runHook postInstall
  '';

  # Previews, thumbnails, sandboxed archive tools and opening files
  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ ffmpeg ffmpegthumbnailer bubblewrap desktop-file-utils xdg-utils ]})
  '';

  meta = {
    description = "A fast, keyboard-first file manager for Linux";
    homepage = "https://stratafiles.io/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata";
  };
})
