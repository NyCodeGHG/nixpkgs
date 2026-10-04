{
  lib,
  fetchFromGitLab,
  rustPlatform,
  protobuf,
  capnproto,
  cmake,
  testers,
  veilid,
  gitUpdater,
  openssl,
  pkg-config,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "veilid";
  version = "0.5.7";

  src = fetchFromGitLab {
    owner = "veilid";
    repo = "veilid";
    rev = "v${finalAttrs.version}";
    hash = "sha256-tl7K7yn+wdXlc3Gw4MbdCUY6vhI38hAuwdV1RfkORbQ=";
  };

  cargoHash = "sha256-a48+kCpsYjql+IGf3l0t4RXkthbc2mxqu9zCaeRPaR4=";

  nativeBuildInputs = [
    capnproto
    cmake
    protobuf
    pkg-config
  ];

  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "--workspace"
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
    RUSTFLAGS = "--cfg tokio_unstable";
  };

  doCheck = false;

  outputs = [
    "out"
    "lib"
    "dev"
  ];

  postInstall = ''
    moveToOutput "lib" "$lib"
  '';

  passthru = {
    updateScript = gitUpdater { rev-prefix = "v"; };
    tests = {
      veilid-version = testers.testVersion {
        package = veilid;
      };
    };
  };

  meta = {
    description = "Open-source, peer-to-peer, mobile-first, networked application framework";
    mainProgram = "veilid-server";
    homepage = "https://veilid.com";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [
      bbigras
      qbit
    ];
  };
})
