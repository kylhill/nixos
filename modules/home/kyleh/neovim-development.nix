{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkSnacksMap = key: command: desc: {
    inherit key;
    action = "<cmd>lua ${command}<cr>";
    options = { inherit desc; };
  };
in
{
  imports = [ ./neovim.nix ];

  programs.nixvim = {
    enablePrintInit = false;
    waylandSupport = lib.mkDefault true;
    withPython3 = false;

    globals.loaded_python3_provider = 0;

    dependencies = {
      git.enable = false;
      ripgrep.enable = false;
    };

    extraPlugins = [ pkgs.vimPlugins.vim-tmux-navigator ];

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
      mini-ai.enable = true;
      mini-pairs.enable = true;
      blink-cmp = {
        enable = true;
        settings.keymap.preset = "super-tab";
      };
      gitsigns.enable = true;
      lualine = {
        enable = true;
        settings.options.globalstatus = true;
      };
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
          scroll.enabled = true;
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
        servers.lua_ls.enable = true;
      };
    };
  };
}
