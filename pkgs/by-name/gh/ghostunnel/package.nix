{
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  lib,
  nixosTests,
}:

buildGoModule rec {
  pname = "ghostunnel";
  version = "1.8.3";

  src = fetchFromGitHub {
    owner = "ghostunnel";
    repo = "ghostunnel";
    rev = "v${version}";
    hash = "sha256-WO7dyz+S8dBSFfNCTHHg1lGDlUGSBqa5pcR5GCiWsl8=";
  };

  vendorHash = null;

  deleteVendor = true;

  # The certstore directory isn't recognized as a subpackage, but is when moved
  # into the vendor directory.
  postUnpack = ''
    mkdir -p $sourceRoot/vendor/ghostunnel
    mv $sourceRoot/certstore $sourceRoot/vendor/ghostunnel/
  '';

  passthru.tests = {
    nixos = nixosTests.ghostunnel;
    podman = nixosTests.podman-tls-ghostunnel;
  };

  meta = with lib; {
    broken = stdenv.hostPlatform.isDarwin;
    description = "TLS proxy with mutual authentication support for securing non-TLS backend applications";
    homepage = "https://github.com/ghostunnel/ghostunnel#readme";
    changelog = "https://github.com/ghostunnel/ghostunnel/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ roberth ];
    mainProgram = "ghostunnel";
  };
}
