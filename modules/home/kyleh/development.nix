{
  programs = {
    bat.enable = true;
    fd.enable = true;
    fzf.enable = true;
    ripgrep.enable = true;

    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
      silent = true;
    };
  };
}
