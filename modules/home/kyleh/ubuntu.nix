{ pkgs, ... }:
{
  xdg.mime.enable = false;

  programs = {
    bash.package = null;
    man = {
      enable = true;
      package = null;
    };
  };

  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = [ "en_US.UTF-8/UTF-8" ];
  };
}
