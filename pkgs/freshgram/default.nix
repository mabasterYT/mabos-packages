# freshGram, a Telegram Desktop fork (Arch's freshgram-bin): the upstream build, unchanged, run in
# an FHS environment with the libraries it links and opens. Patching the binary (autoPatchelf)
# broke it: it died with an illegal instruction at its first one.
{ lib, stdenv, fetchurl, buildFHSEnv }:
let
  pname = "freshgram";
  version = "7.6.0";

  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/Snowy-Fluffy/freshGram/releases/download/v${version}/freshGram-linux-x86_64.tar.gz";
      hash = "sha256-pfUmpbn58St/wacPA8VR49grU2YtQ3ZDh4Kbj9ocoRc=";
    };
    sourceRoot = ".";
    dontPatchELF = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p $out
      cp -r usr/bin usr/share $out/
    '';
  };
in
buildFHSEnv {
  inherit pname version;
  executableName = "freshGram";
  runScript = "${unwrapped}/bin/freshGram";

  targetPkgs = pkgs: with pkgs; [
    glib pango cairo fontconfig freetype alsa-lib libpulseaudio pipewire dbus libGL wayland
    libxkbcommon xorg.libX11 xorg.libxcb xorg.xcbutilwm xorg.xcbutilimage xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil libva gtk3 vulkan-loader
    xkeyboard-config # /usr/share/X11/xkb: Qt's keyboard on Wayland
    desktop-file-utils # it registers its link handler
  ];

  # The system's graphics drivers (NixOS keeps them in /run/opengl-driver): without them it gets no
  # OpenGL context
  profile = ''
    export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
    export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri
    export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  '';

  extraInstallCommands = ''
    cp -r ${unwrapped}/share $out/
    chmod -R u+w $out/share
    substituteInPlace $out/share/dbus-1/services/*.service --replace-fail /usr/bin/freshGram $out/bin/freshGram
  '';

  meta = {
    description = "Telegram Desktop fork";
    homepage = "https://github.com/Snowy-Fluffy/freshGram";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "freshGram";
  };
}
