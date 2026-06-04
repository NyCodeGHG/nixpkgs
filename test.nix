{ pkgs, ... }:
{
  services.credentialsd.enable = true;

  services.desktopManager.plasma6.enable = true;
  services.displayManager.plasma-login-manager.enable = true;

  users.users.marie = {
    isNormalUser = true;
    password = "meow";
  };

  programs.firefox.enable = true;
}
