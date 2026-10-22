{
  config,
  lib,
  pkgs,
  nixd,
  nixdSettings,
  oxfmt,
  oxlint,
  dotnetSdk,
  roslyn-ls,
  csharpier,
  netcoredbg,
  ...
}: {
  globals.mapleader = " ";
  globals.maplocalleader = ",";
  viAlias = true;
  vimAlias = true;
  opts = {
    number = true;
    relativenumber = true;
    termguicolors = true;
    signcolumn = "yes";
    cursorline = true;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;
    ignorecase = true;
    smartcase = true;
    splitbelow = true;
    splitright = true;
    undofile = true;
    scrolloff = 8;
    updatetime = 250;
    timeoutlen = 400;
    completeopt = ["menu" "menuone" "noselect"];
    clipboard = "unnamedplus";
    foldlevel = 99;
  };

  colorschemes.catppuccin = {
    enable = true;
    settings.flavour = "mocha";
  };

  extraPlugins = [pkgs.vimPlugins.resession-nvim];

  extraPackages = with pkgs;
    [
      ripgrep
      fd
      git
      lazygit
      gdu
      bottom
      nodejs
      python3
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [wl-clipboard xclip];

  # Project dev shells can select an SDK; .NET 10 is the standalone fallback.
  extraPackagesAfter = [dotnetSdk];

  plugins = {
    web-devicons.enable = true;
    lualine = {
      enable = true;
      settings.winbar.lualine_c = ["aerial"];
    };
    bufferline.enable = true;
    which-key = {
      enable = true;
      settings.spec = [
        {
          __unkeyed-1 = "<leader>b";
          group = "Buffers";
        }
        {
          __unkeyed-1 = "<leader>d";
          group = "Debug";
        }
        {
          __unkeyed-1 = "<leader>f";
          group = "Find";
        }
        {
          __unkeyed-1 = "<leader>g";
          group = "Git";
        }
        {
          __unkeyed-1 = "<leader>l";
          group = "Language";
        }
        {
          __unkeyed-1 = "<leader>S";
          group = "Sessions";
        }
        {
          __unkeyed-1 = "<leader>t";
          group = "Terminal";
        }
      ];
    };
    neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        filesystem.follow_current_file.enabled = true;
      };
    };
    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        dashboard = {
          enabled = true;
          # The default startup statistics section requires lazy.nvim.
          sections = [
            {section = "header";}
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
          ];
        };
        indent.enabled = true;
        input.enabled = true;
        notifier.enabled = true;
        picker.enabled = true;
        quickfile.enabled = true;
        scope.enabled = true;
      };
    };
    toggleterm = {
      enable = true;
      settings = {
        direction = "float";
        open_mapping = "[[<C-\\>]]";
      };
    };
    gitsigns.enable = true;
    smart-splits.enable = true;
    guess-indent.enable = true;
    better-escape.enable = true;
    nvim-autopairs.enable = true;
    ts-autotag.enable = true;
    highlight-colors.enable = true;
    aerial.enable = true;
    treesitter = {
      enable = true;
      highlight.enable = true;
      indent.enable = true;
      folding.enable = true;
      grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
        bash
        c
        c_sharp
        cpp
        css
        diff
        html
        javascript
        json
        lua
        luadoc
        markdown
        markdown_inline
        nix
        python
        regex
        rust
        toml
        tsx
        typescript
        vim
        vimdoc
        xml
        yaml
      ];
    };
    treesitter-textobjects = {
      enable = true;
    };
    blink-cmp = {
      enable = true;
      settings = {
        keymap.preset = "default";
        snippets.preset = "luasnip";
        completion.documentation.auto_show = true;
      };
    };
    luasnip.enable = true;
    friendly-snippets.enable = true;
    lazydev.enable = true;
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd = {
          enable = true;
          package = nixd;
          settings = nixdSettings;
        };
        lua_ls.enable = true;
        rust_analyzer = {
          enable = true;
          # Project toolchains come from direnv/devenv, including their stdlib sources.
          installCargo = false;
          installRustc = false;
        };
        pyright.enable = true;
        roslyn_ls = {
          enable = true;
          package = roslyn-ls;
          cmd = [(lib.getExe roslyn-ls) "--stdio"];
        };
        ts_ls.enable = true;
        bashls.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
        html.enable = true;
        cssls.enable = true;
        marksman.enable = true;
        taplo.enable = true;
      };
    };
    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      autoInstall.overrides.oxfmt = oxfmt;
      autoInstall.overrides.csharpier = csharpier;
      settings = {
        formatters.oxfmt.command = lib.getExe oxfmt;
        formatters.csharpier = {
          command = lib.getExe csharpier;
          args = ["format" "--stdin-path" "$FILENAME"];
        };
        format_on_save = {
          timeout_ms = 1000;
          lsp_format = "fallback";
        };
        formatters_by_ft = {
          lua = ["stylua"];
          cs = ["csharpier"];
          python = ["ruff_format"];
          rust = ["rustfmt"];
          sh = ["shfmt"];
          javascript = ["oxfmt"];
          javascriptreact = ["oxfmt"];
          typescript = ["oxfmt"];
          typescriptreact = ["oxfmt"];
          json = ["oxfmt"];
          jsonc = ["oxfmt"];
          json5 = ["oxfmt"];
          yaml = ["oxfmt"];
          markdown = ["oxfmt"];
          mdx = ["oxfmt"];
          html = ["oxfmt"];
          css = ["oxfmt"];
          scss = ["oxfmt"];
          less = ["oxfmt"];
          toml = ["oxfmt"];
          graphql = ["oxfmt"];
          vue = ["oxfmt"];
          handlebars = ["oxfmt"];
        };
      };
    };
    lint = {
      enable = true;
      autoInstall.enable = true;
      autoInstall.overrides.oxlint = oxlint;
      linters.oxlint.cmd = lib.getExe oxlint;
      lintersByFt = {
        nix = ["statix"];
        python = ["ruff"];
        sh = ["shellcheck"];
        javascript = ["oxlint"];
        javascriptreact = ["oxlint"];
        typescript = ["oxlint"];
        typescriptreact = ["oxlint"];
        vue = ["oxlint"];
        svelte = ["oxlint"];
        astro = ["oxlint"];
      };
    };
    dap = {
      enable = true;
      adapters.executables.coreclr = {
        command = lib.getExe netcoredbg;
        args = ["--interpreter=vscode"];
      };
      adapters.servers.codelldb = {
        port = "\${port}";
        executable = {
          command = "${pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter}/bin/codelldb";
          args = ["--port" "\${port}"];
        };
      };
      configurations = let
        native = [
          {
            name = "Launch executable";
            type = "codelldb";
            request = "launch";
            program.__raw = "function() return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file') end";
            cwd = "\${workspaceFolder}";
            stopOnEntry = false;
          }
        ];
      in {
        rust = native;
        c = native;
        cpp = native;
        cs = [
          {
            name = "Launch .NET assembly";
            type = "coreclr";
            request = "launch";
            program.__raw = "function() return vim.fn.input('Assembly: ', vim.fn.getcwd() .. '/bin/Debug/', 'file') end";
            cwd = "\${workspaceFolder}";
            stopAtEntry = false;
          }
        ];
      };
    };
    dap-ui.enable = true;
    dap-virtual-text.enable = true;
    dap-python = {
      enable = true;
      adapterPythonPath = lib.getExe (pkgs.python3.withPackages (ps: [
        (ps.debugpy.overridePythonAttrs (old: {
          # The pinned Darwin patch fixes the LLDB command but misses its test.
          postPatch =
            (old.postPatch or "")
            + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
              substituteInPlace tests/debugpy/server/test_add_code_to_python_process.py \
                --replace-fail 'cmd.startswith("lldb --no-lldbinit' 'cmd.startswith("${pkgs.lldb}/bin/lldb --no-lldbinit'
            '';
        }))
      ]));
    };
  };

  extraConfigLua = builtins.readFile ./keymaps.lua;
}
