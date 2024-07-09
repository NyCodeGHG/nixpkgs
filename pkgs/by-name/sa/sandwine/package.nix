{
  lib,
  python3Packages,
  fetchFromGitHub,
  bubblewrap,
  util-linux,
  withX ? true,
  xorg,
  withNxAgent ? false,
  nx-libs,
  withXpra ? false,
  xpra,
}:

python3Packages.buildPythonApplication rec {
  pname = "sandwine";
  version = "4.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "hartwork";
    repo = "sandwine";
    rev = "refs/tags/${version}";
    hash = "sha256-pH0Zi4yzOvHQI3Q58o6eOLEBbXheFkRu/AzP8felz5I=";
  };

  patches = [
    # Bind mount paths required to get software to run on NixOS
    ./Add-nix-binds.patch
  ];

  postPatch = ''
    substituteInPlace sandwine/_main.py \
      --replace-fail "'bwrap'" "'${lib.getExe bubblewrap}'"
    substituteInPlace sandwine/_main.py \
      --replace-fail "'script'" "'${lib.getExe' util-linux "script"}'"
    ${lib.optionalString withNxAgent ''
      substituteInPlace sandwine/_x11.py \
        --replace-fail "_command = 'nxagent'" "_command = '${lib.getExe' nx-libs "nxagent"}'"
    ''}
    ${lib.optionalString withX ''
      substituteInPlace sandwine/_x11.py \
        --replace-fail "_command = 'Xephyr'" "_command = '${lib.getExe' xorg.xorgserver "Xephyr"}'"
      substituteInPlace sandwine/_x11.py \
        --replace-fail "_command = 'Xnest'" "_command = '${lib.getExe' xorg.xorgserver "Xnest"}'"
    ''}
    ${lib.optionalString withXpra ''
      substituteInPlace sandwine/_x11.py \
        --replace-fail "_command = 'xpra'" "_command = '${lib.getExe' xpra "xpra"}'"
    ''}
  '';

  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [ coloredlogs ];

  meta = {
    description = "Command-line tool to run Windows apps with Wine and bwrap/bubblewrap isolation";
    homepage = "https://github.com/hartwork/sandwine";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ marie ];
    mainProgram = "sandwine";
  };
}
