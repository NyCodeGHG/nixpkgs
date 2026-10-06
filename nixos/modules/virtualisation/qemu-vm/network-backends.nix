{
  pkgs,
  lib,
  qemuValue,
}:
let
  inherit (lib)
    mkOption
    mkPackageOption
    types
    ;
in
{ name }:
{
  slirp = mkOption {
    type = types.submodule (
      { config, ... }: {
        options = {
          settings = mkOption {
            type = types.submodule {
              freeformType = types.attrsOf qemuValue;
              config.id = name;
              options = {
                restrict = mkOption {
                  type = types.bool;
                  default = false;
                  example = true;
                  description = ''
                    If this option is enabled, the guest will be isolated, i.e. it will
                    not be able to contact the host and no guest IP packets will be
                    routed over the host to the outside. This option does not affect
                    any explicitly set forwarding rules.
                  '';
                };
              };
            };
          };
        };
      }
    );
  };
  passt = mkOption {
    type = types.submodule (
      { config, ... }: {
        options = {
          package = mkPackageOption pkgs "passt" { };
          settings = mkOption {
            type = types.submodule {
              freeformType = types.attrsOf qemuValue;
              options = {
                path = mkOption {
                  type = types.path;
                  default = lib.getExe config.package;
                  description = "Path to the passt executable.";
                };
              };
              config.id = name;
            };
          };
        };
      }
    );
  };
}
