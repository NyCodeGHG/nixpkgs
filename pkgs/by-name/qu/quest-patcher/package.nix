{ lib,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  libX11,
  libICE,
  libSM,
  fontconfig,
  copyDesktopItems,
  makeDesktopItem,
  android-tools,
}:

buildDotnetModule rec {
  pname = "QuestPatcher";
  version = "2.8.0";

  src = fetchFromGitHub {
    owner = "Lauriethefish";
    repo = "QuestPatcher";
    rev = "refs/tags/${version}";
    hash = "sha256-myDaWSo44b7c8uO0vmmCHiX9r6SaCWoz/GuS1+YegAc=";
  };

  nativeBuildInputs = [ copyDesktopItems ];

  projectFile = "QuestPatcher/QuestPatcher.csproj";
  executables = "QuestPatcher";

  dotnet-sdk = dotnetCorePackages.sdk_6_0;
  dotnet-runtime = dotnetCorePackages.runtime_6_0;

  buildType = "Release";

  selfContainedBuild = true;

  nugetDeps = ./nuget-deps.nix;

  runtimeDeps = [
    # Avalonia dependencies
    libX11
    libICE
    libSM
    fontconfig
  ];

  # Patcher uses adb to connect to the Quest Device
  makeWrapperArgs = [
    "--prefix PATH : ${android-tools}/bin"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "QuestPatcher";
      exec = "QuestPatcher";
      desktopName = "QuestPatcher";
      type = "Application";
      categories = [ "Game" ];
    })
  ];

  meta = {
    description = "GUI based mod installer for Meta Quest devices";
    homepage = "https://github.com/Lauriethefish/QuestPatcher";
    license = lib.licenses.zlib;
    mainProgram = "QuestPatcher";
    maintainers = with lib.maintainers; [ marie ];
    platforms = lib.platforms.linux;
  };
}
