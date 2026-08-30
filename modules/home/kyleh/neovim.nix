{ pkgs, ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    globals.mapleader = " ";

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

    extraPlugins = [ pkgs.vimPlugins.vim-tmux-navigator ];

    extraPackages = with pkgs; [
      bash-language-server
      lua-language-server
      nixd
      nixfmt-rfc-style
      shellcheck
      stylua
      yaml-language-server
    ];

    extraConfigLua = ''
      vim.g.loaded_node_provider = 0
      vim.g.loaded_perl_provider = 0
      vim.g.loaded_ruby_provider = 0

      vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Go to left window/pane" })
      vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Go to lower window/pane" })
      vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Go to upper window/pane" })
      vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Go to right window/pane" })
      vim.keymap.set("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", { desc = "Go to previous window/pane" })
    '';
  };

  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile ./files/vimrc;
  };
}
