{
  inputs,
  pkgs,
  ...
}:
let
  solarizedNvim = pkgs.vimUtils.buildVimPlugin {
    pname = "solarized.nvim";
    version = inputs.solarized-nvim.shortRev or "unstable";
    src = inputs.solarized-nvim;
  };
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  home.sessionVariables.MANPAGER = "nvim +Man! -";

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;

    nixpkgs.useGlobalPackages = true;

    extraConfigLua = ''
      require("solarized").setup({
        palette = "solarized",
        variant = "winter",
        transparent = {
          enabled = false,
        },
      })
      vim.cmd.colorscheme("solarized")
    '';
    extraPlugins = [ solarizedNvim ];

    globals = {
      loaded_node_provider = 0;
      loaded_perl_provider = 0;
      loaded_ruby_provider = 0;
      mapleader = " ";
    };

    opts = {
      autoindent = true;
      autowrite = true;
      clipboard.__raw = ''
        vim.env.SSH_CONNECTION and "" or "unnamedplus"
      '';
      confirm = true;
      cursorline = true;
      expandtab = true;
      guifont = "CaskaydiaCove Nerd Font Mono:h10";
      hidden = true;
      ignorecase = true;
      inccommand = "nosplit";
      laststatus = 3;
      list = false;
      modeline = false;
      mouse = "a";
      number = true;
      relativenumber = false;
      scrolloff = 4;
      shiftwidth = 4;
      showmatch = true;
      sidescroll = 1;
      sidescrolloff = 8;
      signcolumn = "yes";
      smartcase = true;
      smarttab = true;
      smoothscroll = true;
      softtabstop = -1;
      splitbelow = true;
      splitright = true;
      tabstop = 4;
      termguicolors = true;
      timeoutlen = 300;
      undofile = true;
      undolevels = 10000;
      updatetime = 200;
      wrap = false;
    };

  };
}
