# sc-controller-cc: Steam-free user-mode driver for the Steam Controller.
# Vendored from https://github.com/Patola/sc-controller-cc (package.nix),
# with xorg.* inputs renamed to their top-level nixpkgs names.
#
# To bump: change `version`, set `hash` to lib.fakeHash, rebuild, and paste
# the real hash from the mismatch error.
{ lib
, fetchFromGitHub
, python3
, gobject-introspection
, wrapGAppsHook3
, gtk3
, gtk-layer-shell
, libayatana-appindicator
, librsvg
, zlib
, libx11
, libxfixes
, libxext
, xinput
, libudev-zero
, bluez
, linuxHeaders
}:

let
  # Libraries scc dlopens by soname at runtime via ctypes (the Nix Python loader
  # does not search /usr/lib). Shared by the runtime wrapper and the test phase.
  runtimeLibraries = [
    libx11
    libxfixes
    libxext
    libudev-zero
    bluez # libbluetooth.so.3, for Bluetooth controller detection
  ];
in
python3.pkgs.buildPythonApplication rec {
  pname = "sc-controller-cc";
  version = "0.6.0.11";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Patola";
    repo = "sc-controller-cc";
    rev = "v${version}";
    hash = "sha256-4ttaCCF5WGFvRV8p8XjZ+7xVhmcf2AvLlMCXGzSObJU=";
  };

  patches = [
    ./stick-menu-cancel.patch
    ./stick-menu-confirm.patch
    ./stick-menu-centre-confirm.patch
  ];

  # The project's version is "dynamic" via setuptools_scm, which reads it from
  # git tags. fetchFromGitHub strips the .git directory, so hand setuptools_scm
  # the version explicitly instead of letting it fail with "no version found".
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  build-system = with python3.pkgs; [
    setuptools
    setuptools-scm
    wheel
  ];

  # gobject-introspection + wrapGAppsHook3 make the GTK3 GUI find its GObject
  # typelibs (Gtk, GtkLayerShell, AyatanaAppIndicator3), GdkPixbuf SVG loaders
  # and GSettings schemas at runtime.
  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsHook3
    # Test runner for the post-install pytest gate (see postFixup).
    python3.pkgs.pytest
    python3.pkgs.toml
  ];

  buildInputs = [
    gtk3
    gtk-layer-shell
    libayatana-appindicator
    librsvg # so GTK can render the app's SVG icons via gdk-pixbuf
    zlib # the libcemuhook C extension links against libz
  ];

  # Python runtime dependencies — mirrors the PKGBUILD's python-* depends.
  # Note: libusb1 (the Python binding) already loads the C libusb by an absolute
  # /nix/store path baked into its loader by nixpkgs (usb1/_libusb1.py), so —
  # unlike the old official sc-controller package — the C libusb does NOT need to
  # go on LD_LIBRARY_PATH; it is a pinned closure dependency and cannot silently
  # go missing.
  dependencies = with python3.pkgs; [
    evdev
    pygobject3
    ioctl-opt
    libusb1
    pylibacl
    vdf
    setuptools # scc imports pkg_resources at runtime
  ];

  # Tests run in postFixup (see below), not checkPhase: buildPythonApplication's
  # checkPhase runs before install, but the CC fork's scc/constants.py needs the
  # package's installed dist metadata at import time
  # (packages_distributions()["scc"]), which only exists once the wheel is in $out.
  doCheck = false;

  # scc/device_monitor.py resolves libbluetooth via ctypes.util.find_library,
  # which does not consult LD_LIBRARY_PATH and returns None under Nix (so
  # HAVE_BLUETOOTH_LIB stays False and Bluetooth controller detection is
  # incomplete). Point it straight at the soname; the actual load then honours
  # the bluez path we add to LD_LIBRARY_PATH below. Same fix the official
  # nixpkgs sc-controller package uses.
  postPatch = ''
    substituteInPlace scc/device_monitor.py \
      --replace-fail 'find_library("bluetooth")' '"libbluetooth.so.3"'
  '';

  # scc/uinput.py parses linux/input-event-codes.h at import time. Its preferred
  # source is a copy sitting next to the module itself, so drop one there (from
  # linuxHeaders) to make the package self-contained instead of depending on the
  # host having kernel headers under /usr/include (SteamOS ships none).
  postInstall = ''
    install -Dm644 ${linuxHeaders}/include/linux/input-event-codes.h \
      "$out/${python3.sitePackages}/scc/input-event-codes.h"
  '';

  # scc/x11/scc-osd-daemon.py and scc-autoswitch-daemon.py are NOT console
  # entry points — the daemon runs them directly as `[sys.executable, <script>]`
  # (see find_binary/find_python in scc/tools.py). Spawned that way they get the
  # bare interpreter with no access to scc or its deps (gi, evdev, …), so they
  # crash with ModuleNotFoundError. patchPythonScript injects the same sitedir
  # bootstrap that buildPythonApplication bakes into $out/bin wrappers. Same fix
  # the official nixpkgs sc-controller package uses.
  postFixup = ''
    (
      cd "$out/${python3.sitePackages}/scc/x11"
      patchPythonScript scc-osd-daemon.py
      patchPythonScript scc-autoswitch-daemon.py
    )

    # Post-install test gate. Runs here (not checkPhase) because scc only imports
    # once its dist metadata exists in $out. Import the installed scc from $out
    # (has metadata + the bundled input-event-codes.h) rather than the source
    # tree: `python -P` drops the build cwd (which still holds ./scc) from
    # sys.path so `import scc` resolves via PYTHONPATH to $out. The X11/udev/
    # bluetooth libs scc dlopens at import must be reachable, hence LD_LIBRARY_PATH.
    echo "Running post-install test suite..."
    PYTHONPATH="$out/${python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}" \
    SCC_SHARED="$out/share/scc" \
    LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibraries}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    python -P -m pytest -q --import-mode=importlib tests/ \
      `# GUI test needs a display / GTK; skip it in the sandbox. Still required:` \
      `# the gate's bare interpreter has no GI_TYPELIB_PATH (the wrapper supplies` \
      `# it at runtime), so this fails with "Namespace Gtk not available".` \
      --ignore=tests/test_setup.py
  '';

  # buildPythonApplication does its own console-script wrapping, so disable the
  # separate GApps wrapper and fold its env (GI_TYPELIB_PATH,
  # GDK_PIXBUF_MODULE_FILE, XDG_DATA_DIRS, GSETTINGS_SCHEMAS_PATH) into the
  # Python wrappers, alongside:
  #   * LD_LIBRARY_PATH — the X11 + libudev libraries scc dlopens by soname via
  #     ctypes (the Nix Python loader does not look in /usr/lib).
  #   * PATH — `xinput`, which scc/lib/xinput.py shells out to.
  #   * SCC_SHARED — scc/paths.py locates its data (glade, images, default
  #     profiles/menus) relative to sys.prefix, which for a Nix app points at
  #     the Python interpreter's store path, not $out; without this it falls
  #     back to /usr/share/scc and the GUI fails to load app.glade. SCC_SHARED
  #     is scc's own documented override.
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=(
      "''${gappsWrapperArgs[@]}"
      --set SCC_SHARED "$out/share/scc"
      --prefix PATH : ${lib.makeBinPath [ xinput ]}
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries}
    )
  '';

  meta = {
    description = "LLM-assisted fork of sc-controller: user-mode driver and GTK3 GUI for Steam Controller, DS4 and similar controllers";
    homepage = "https://github.com/Patola/sc-controller-cc";
    license = lib.licenses.gpl2Only;
    mainProgram = "sc-controller";
    platforms = lib.platforms.linux;
  };
}
