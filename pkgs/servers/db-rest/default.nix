{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs_18
, nix-update-script
}:
let
  buildNpmPackage' = buildNpmPackage.override { nodejs = nodejs_18; };
in buildNpmPackage' rec {
  pname = "db-rest";
  version = "6.0.2";

  src = fetchFromGitHub {
    owner = "derhuerst";
    repo = pname;
    rev = version;
    hash = "sha256-xgWMLGk4ksexOg0+KIPEKaW2d16QWdCElAivj/nle0k=";
  };

  npmDepsHash = "sha256-ZWD1FmGJX+GUSa1h/dDnfXVIWKR6Z92nN5YP3bbGwcU=";
  dontNpmBuild = true;

  buildPhase = ''
    runHook preBuild
    REDIS_URL="" ${nodejs_18}/bin/node ./build/index.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    cp -r * $out/lib

    makeWrapper ${nodejs_18}/bin/node $out/bin/db-rest \
      --add-flags "$out/lib/index.js"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A clean REST API wrapping around the Deutsche Bahn API";
    homepage = "https://v6.db.transport.rest/";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ marie ];
  };
}
