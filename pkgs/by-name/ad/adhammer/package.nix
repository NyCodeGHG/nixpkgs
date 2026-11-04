{
  lib,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  rustPlatform,
  versionCheckHook,
  aws-lc,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "adhammer";
  version = "1.5.2";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "icedracon";
    repo = "adhammer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/k2zdHBUysKopRcl34KOo7QlJu35aD+cv1Aza1XOAkE=";
  };

  cargoHash = "sha256-H2wlwVPTEH7E6TT/J54IenxUoLedaBG1kkF3ebioBc8=";

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    aws-lc
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];

  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Active Directory security-assessment toolkit";
    homepage = "https://github.com/icedracon/adhammer";
    changelog = "https://github.com/icedracon/adhammer/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ fab ];
    mainProgram = "adhammer";
  };
})
