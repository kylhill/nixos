_: {
  imports = [ ./neovim.nix ];

  programs.nixvim = {
    # Basic editing must not pull in provider runtimes or clipboard utilities.
    withPython3 = false;
    withNodeJs = false;
    withPerl = false;
    waylandSupport = false;
    globals.loaded_python3_provider = 0;
    opts.path = ".,**";

    # Use built-in commands on the same leader keys as the development pickers.
    keymaps = [
      {
        key = "<leader><space>";
        action = ":find ";
        options.desc = "Find Files";
      }
      {
        key = "<leader>,";
        action = ":ls<CR>:buffer ";
        options.desc = "Buffers";
      }
      {
        key = "<leader>/";
        action = "<cmd>lua BasicEditorGrep()<cr>";
        options.desc = "Grep";
      }
      {
        key = "<leader>:";
        action = "q:";
        options.desc = "Command History";
      }
      {
        key = "<leader>e";
        action = "<cmd>Explore<cr>";
        options.desc = "Explorer";
      }
      {
        key = "<leader>fb";
        action = ":ls<CR>:buffer ";
        options.desc = "Buffers";
      }
      {
        key = "<leader>ff";
        action = ":find ";
        options.desc = "Find Files";
      }
      {
        key = "<leader>fr";
        action = "<cmd>browse oldfiles<cr>";
        options.desc = "Recent Files";
      }
      {
        key = "<leader>sb";
        action = "/";
        options.desc = "Buffer Lines";
      }
      {
        key = "<leader>sg";
        action = "<cmd>lua BasicEditorGrep()<cr>";
        options.desc = "Grep";
      }
      {
        key = "<leader>sw";
        mode = [
          "n"
          "x"
        ];
        action.__raw = ''
          function()
            local text = vim.fn.expand("<cword>")
            local mode = vim.fn.mode()
            if mode == "v" or mode == "V" or mode == "\22" then
              text = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
              vim.cmd.normal({ vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bang = true })
            end
            BasicEditorGrep(text)
          end
        '';
        options.desc = "Visual Selection or Word";
      }
      {
        key = "<leader>sh";
        action = ":help ";
        options.desc = "Help Pages";
      }
      {
        key = "<leader>sk";
        action = "<cmd>map<cr>";
        options.desc = "Keymaps";
      }
      {
        key = "<leader>sR";
        action = "<cmd>copen<cr>";
        options.desc = "Resume Search Results";
      }
    ];

    extraConfigLua = ''
      -- vimgrep searches internally; no grep/ripgrep executable is required.
      function BasicEditorGrep(text)
        local function search(query)
          if not query or query == "" then return end
          local pattern = "\\V" .. vim.fn.escape(query, [[\/]]):gsub("\n", [[\n]])
          local ok, err = pcall(vim.cmd, "vimgrep /" .. pattern .. "/gj **/*")
          if ok then
            vim.cmd.copen()
          else
            vim.notify(tostring(err), vim.log.levels.INFO)
          end
        end
        if text then
          search(text)
        else
          vim.ui.input({ prompt = "Search files (literal text): " }, search)
        end
      end
    '';
  };
}
