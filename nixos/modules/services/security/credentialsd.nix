{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.credentialsd;
in

{
  options.services.credentialsd = {
    enable = lib.mkEnableOption "credentialsd";
    package = lib.mkPackageOption pkgs "credentialsd" { };
  };
  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ];
    programs.firefox.nativeMessagingHosts.packages = [ cfg.package ];
    xdg.portal.configPackages = [ cfg.package ];
  };
}
