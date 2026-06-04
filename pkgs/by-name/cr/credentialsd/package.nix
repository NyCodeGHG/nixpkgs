{
  lib,
  stdenv,
  blueprint-compiler,
  cargo,
  dbus,
  desktop-file-utils,
  fetchFromGitHub,
  glib,
  gtk4,
  meson,
  openssl,
  pkg-config,
  rustPlatform,
  rustc,
  systemdLibs,
  zip,
  ninja,
  pcsclite,
  libxml2,
  libnfc,
  gettext,
  python3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "credentialsd";
  version = "0.2.0-unstable-2026-07-21";

  src = fetchFromGitHub {
    owner = "linux-credentials";
    repo = "credentialsd";
    rev = "09d3ad67b9b587fd14039dce9afc5e9eea130715";
    hash = "sha256-Xrw28MCf67ShdG7pL/0F+NyAa6bJjs3voKytBD8qgh8=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  preConfigure = ''
    patchShebangs --build credentialsd-ui/data/resources/icons/copy-icons.py
    patchShebangs --host webext/app/credential_manager_shim.py
  '';

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    rustPlatform.bindgenHook
    meson
    rustc
    cargo
    pkg-config
    blueprint-compiler
    gtk4
    desktop-file-utils
    zip
    ninja
    libxml2
    python3
  ];

  buildInputs = [
    dbus
    glib
    gtk4
    openssl
    systemdLibs
    pcsclite
    libnfc
    gettext
    (python3.withPackages (p: [ p.dbus-next ]))
  ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-yZioDB1xwP8/psA8aE5azzT11bvYpZo595RN69jtRXY=";
  };

  mesonFlags = [
    (lib.mesonBool "cargo_offline" true)
  ];
})
