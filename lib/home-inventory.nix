let
  defaults = {
    system = "x86_64-linux";
    homeDirectory = "/home/kyleh";
    stateVersion = "26.05";
  };
in
{
  gateway = defaults;
  oci = defaults // {
    system = "aarch64-linux";
  };
  syntax = defaults;
  wsl = defaults;
}
