{
  lib,
  fetchFromGitHub,
  rustPlatform,
  perl,
  cacert,
  openssl,
  pkg-config,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "managarr";
  version = "0.7.3";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "Dark-Alex-17";
    repo = "managarr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NdKtyvWNFBhXb6bxclfa/68/5WqOhlqLnEd0e2LQ10Q=";
  };

  cargoHash = "sha256-yecVTD/UC0vNuCRpLBr7GxT3Bs+Zs5oZHNcBa2HQns4=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  nativeCheckInputs = [ cacert ];

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  __darwinAllowLocalNetworking = true;

  meta = {
    description = "TUI and CLI to manage your Servarrs";
    homepage = "https://github.com/Dark-Alex-17/managarr";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      IncredibleLaser
      darkalex
      nindouja
      kybe236
    ];
    mainProgram = "managarr";
  };
})
