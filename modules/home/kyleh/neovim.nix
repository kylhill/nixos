{
  config,
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
  mkSnacksMap = key: command: desc: {
    inherit key;
    action = "<cmd>lua ${command}<cr>";
    options = { inherit desc; };
  };
in
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
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

    keymaps = [
      (mkSnacksMap "<leader><space>" "Snacks.picker.files()" "Find Files")
      (mkSnacksMap "<leader>," "Snacks.picker.buffers()" "Buffers")
      (mkSnacksMap "<leader>/" "Snacks.picker.grep()" "Grep")
      (mkSnacksMap "<leader>:" "Snacks.picker.command_history()" "Command History")
      (mkSnacksMap "<leader>e" "Snacks.explorer()" "Explorer")
      (mkSnacksMap "<leader>fb" "Snacks.picker.buffers()" "Buffers")
      (mkSnacksMap "<leader>ff" "Snacks.picker.files()" "Find Files")
      (mkSnacksMap "<leader>fr" "Snacks.picker.recent()" "Recent Files")
      (mkSnacksMap "<leader>sb" "Snacks.picker.lines()" "Buffer Lines")
      (mkSnacksMap "<leader>sg" "Snacks.picker.grep()" "Grep")
      (
        (mkSnacksMap "<leader>sw" "Snacks.picker.grep_word()" "Visual Selection or Word")
        // {
          mode = [
            "n"
            "x"
          ];
        }
      )
      (mkSnacksMap "<leader>sh" "Snacks.picker.help()" "Help Pages")
      (mkSnacksMap "<leader>sk" "Snacks.picker.keymaps()" "Keymaps")
      (mkSnacksMap "<leader>sR" "Snacks.picker.resume()" "Resume")
    ];

    plugins = {
      blink-cmp = {
        enable = true;
        settings.keymap.preset = "super-tab";
      };
      conform-nvim.enable = true;
      gitsigns.enable = true;
      lualine = {
        enable = true;
        settings.options.globalstatus = true;
      };
      mini-ai.enable = true;
      mini-pairs.enable = true;
      noice = {
        enable = true;
        settings.presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
        };
      };
      snacks = {
        enable = true;
        settings = {
          explorer.enabled = true;
          picker.enabled = true;
        };
      };
      todo-comments.enable = true;
      treesitter = {
        enable = true;
        highlight.enable = true;
        grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
          bash
          diff
          json
          lua
          markdown
          markdown_inline
          nix
          query
          regex
          vim
          vimdoc
          yaml
        ];
      };
      trouble.enable = true;
      ts-comments.enable = true;
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

    extraPackages = [
      pkgs.nixfmt
      pkgs.stylua
    ];

  };
}
