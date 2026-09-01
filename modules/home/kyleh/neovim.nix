{
  inputs,
  pkgs,
  ...
}:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    withRuby = false;

    # Nixvim intentionally follows the repository's main nixpkgs input. Make
    # that choice explicit so Nixvim does not warn that its default changed.
    nixpkgs.source = inputs.nixpkgs.outPath;

    globals = {
      loaded_node_provider = 0;
      loaded_perl_provider = 0;
      loaded_ruby_provider = 0;
      mapleader = " ";
    };

    opts = {
      autoindent = true;
      cursorline = true;
      expandtab = true;
      hidden = true;
      ignorecase = true;
      list = false;
      modeline = false;
      number = true;
      relativenumber = false;
      scrolloff = 3;
      shiftwidth = 4;
      showmatch = true;
      sidescroll = 1;
      sidescrolloff = 2;
      smartcase = true;
      smarttab = true;
      softtabstop = -1;
      splitbelow = true;
      splitright = true;
      tabstop = 4;
      termguicolors = true;
      wrap = false;
    };

    colorschemes.base16 = {
      enable = true;
      colorscheme = "solarized-dark";
    };

    plugins = {
      blink-cmp = {
        enable = true;
        settings.keymap.preset = "super-tab";
      };
      bufferline.enable = true;
      conform-nvim.enable = true;
      gitsigns.enable = true;
      lualine.enable = true;
      noice.enable = true;
      telescope.enable = true;
      tmux-navigator.enable = true;
      todo-comments.enable = true;
      treesitter.enable = true;
      trouble.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;

      lint = {
        enable = true;
        lintersByFt.sh = [ "shellcheck" ];
      };

      lsp = {
        enable = true;
        servers = {
          bashls.enable = true;
          jsonls.enable = true;
          lua_ls.enable = true;
          nixd.enable = true;
          yamlls.enable = true;
        };
      };
    };

    extraPackages = with pkgs; [
      nixfmt
      shellcheck
      stylua
    ];

  };
}
