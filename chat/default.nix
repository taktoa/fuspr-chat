# Build dependencies
{ stdenv, cmake, pkgconfig, doxygen, ghostscript, ninja
# Program dependencies
, boost, zeromq, libmsgpack, libtoxcore-dev, nlohmann_json, qtbase, obs-studio
, gst_all_1
# Misc dependencies
, guile, parallel
}:

stdenv.mkDerivation rec {
  name = "fuspr-chat-0.0.1";

  src = ./.;

  nativeBuildInputs = [
    cmake pkgconfig ninja doxygen ghostscript guile parallel
  ];

  buildInputs = with gst_all_1; [
    boost zeromq libmsgpack qtbase nlohmann_json libtoxcore-dev obs-studio
    gstreamer gstreamermm gst-libav gst-plugins-base gst-plugins-good
  ];

  cmakeFlags = "-GNinja";

  buildPhase = "ninja";

  installPhase = ''
      ninja install
      mkdir $out/nix-support
      echo "doc manual $out/share/doc/fuspr-chat index.html" \
          >> $out/nix-support/hydra-build-products
  '';

  shellHook = ''
      cd ${toString src}
      [[ -d "$(pwd)/build" ]] && rm -rf build
      source ${../helpers}
      OLD_CMAKE_FLAGS="$cmakeFlags"
      cmakeFlags="-DCMAKE_C_FLAGS=-v -DCMAKE_CXX_FLAGS=-v $cmakeFlags" \
          cmakeConfigurePhase
      BUILD_LOG="$(mktemp -p /tmp build-log.XXXXXX)"
      ninja &> "$BUILD_LOG"
      echo ""
      echo ""
      echo ""
      note "FLYCHECK-CLANG-INCLUDE-PATH:"
      echo ""
      INCLUDE_PATH="$(generate-emacs-include-path "$BUILD_LOG")"
      echo "$INCLUDE_PATH"
      echo ""
      echo ""
      echo ""
      read -p "Copy generated include path into clipboard? [y/N] "
      if text-represents-yes "$REPLY"; then
          echo "$INCLUDE_PATH" | clipboard
      fi
      echo ""
      echo ""
      echo ""
      rm "$BUILD_LOG"
      cmakeFlags="$OLD_CMAKE_FLAGS"
      unset OLD_CMAKE_FLAGS BUILD_LOG
      refresh-plugin-build "${toString src}"
      note "Entering nix-shell"
  '';
}
