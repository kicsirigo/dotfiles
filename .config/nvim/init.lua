-- init.lua
-- Neovim configuration mimicking Micro editor behaviors and shortcuts

-- Ensure lazy.nvim is installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim and plugins
require("lazy").setup({
  -- Catppuccin and Nord themes
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  { "shaunsingh/nord.nvim", lazy = false, priority = 1000 },

  -- File Tree (Neo-tree)
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        window = {
          width = 25,
          mappings = {
            ["<space>"] = "none",
          }
        },
        filesystem = {
          filtered_items = {
            visible = true,
            show_hidden_count = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
          follow_current_file = {
            enabled = true,
          },
        }
      })
    end
  },

  -- Fuzzy finder (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<esc>"] = require("telescope.actions").close,
            },
          },
        },
      })
    end
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "auto",
        }
      })
    end
  },

  -- Key analyzer / keymap helper
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {}
  }
})

-- ==========================================
-- Micro-like Options and Settings
-- ==========================================
vim.opt.mouse = "a"           -- Full mouse support
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = false -- Do not use relative line numbers (like micro)
vim.opt.clipboard = "unnamedplus" -- Clipboard integration (Ctrl+C / Ctrl+V will work seamlessly)
vim.opt.undofile = true       -- Save undo history to disk
vim.opt.swapfile = false      -- Disable swap files (like micro)
vim.opt.backup = false        -- Disable backup files
vim.opt.writebackup = false
vim.opt.ignorecase = true     -- Case insensitive search
vim.opt.smartcase = true      -- Smart case search
vim.opt.tabstop = 4           -- Tab width 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true      -- Use spaces instead of tabs (micro default, configurable)
vim.opt.wrap = true           -- Wrap long lines (like micro)
vim.opt.cursorline = true     -- Highlight current line
vim.opt.scrolloff = 3         -- Keep at least 3 lines visible above/below cursor
vim.opt.sidescrolloff = 5

-- Set colorscheme (defaulting to catppuccin-macchiato as specified in micro settings)
vim.cmd("colorscheme catppuccin-macchiato")

-- ==========================================
-- Micro-like Keybindings (Insert and Normal mode)
-- ==========================================

-- Helper for key mapping
local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then options = vim.tbl_extend("force", options, opts) end
  vim.keymap.set(mode, lhs, rhs, options)
end

-- --- General File Operations ---
-- Ctrl+S: Save File (in both normal & insert modes)
map({ "n", "i", "v" }, "<C-s>", "<Esc>:w<CR>a", { desc = "Save File" })

-- Ctrl+Q: Quit editor / close buffer
map({ "n", "i", "v" }, "<C-q>", "<Esc>:qa<CR>", { desc = "Quit Neovim" })

-- Ctrl+O: Open File using Telescope (fuzzy finder)
map({ "n", "i", "v" }, "<C-o>", "<Esc>:Telescope find_files<CR>", { desc = "Open File (Fuzzy Finder)" })

-- Ctrl+F: Find / Search text in file
map({ "n", "i" }, "<C-f>", "<Esc>/", { desc = "Search in file" })

-- Ctrl+N: Next search result (in normal/insert mode, mimics micro behavior)
map({ "n", "i" }, "<C-n>", "<Esc>n", { desc = "Next search match" })

-- Ctrl+G: Go to line
map({ "n", "i" }, "<C-g>", "<Esc>:", { desc = "Go to line / Command prompt" })

-- Ctrl+E: Open Command/Vim command prompt (like micro's Command mode)
map({ "n", "i" }, "<C-e>", "<Esc>:", { desc = "Enter Command Mode" })

-- --- Undo / Redo ---
-- Ctrl+Z: Undo (Insert & Normal mode)
map({ "n", "i" }, "<C-z>", "<Esc>ua", { desc = "Undo" })

-- Ctrl+Y: Redo (Insert & Normal mode)
map({ "n", "i" }, "<C-y>", "<Esc><C-r>a", { desc = "Redo" })

-- --- Clipboard & Selection ---
-- Ctrl+A: Select All
map({ "n", "i", "v" }, "<C-a>", "<Esc>ggVG", { desc = "Select All" })

-- Ctrl+C: Copy (in visual mode)
map("v", "<C-c>", '"+y', { desc = "Copy Selection" })

-- Ctrl+X: Cut (in visual mode)
map("v", "<C-x>", '"+x', { desc = "Cut Selection" })

-- Ctrl+V: Paste (in normal/insert/visual mode)
map({ "n", "v" }, "<C-v>", '"+p', { desc = "Paste" })
map("i", "<C-v>", '<C-r>+', { desc = "Paste in insert mode" })

-- --- File Tree (Sidebar) ---
-- Ctrl+H: Toggle File Tree sidebar (Neo-tree)
map({ "n", "i", "v" }, "<C-h>", "<Esc>:Neotree toggle left<CR>", { desc = "Toggle File Tree" })

-- --- Tab management (Buffers in Neovim) ---
-- Ctrl+T: New tab (buffer)
map({ "n", "i" }, "<C-t>", "<Esc>:enew<CR>", { desc = "New Buffer" })

-- Ctrl+W: Close buffer
map({ "n", "i" }, "<C-w>", "<Esc>:bd<CR>", { desc = "Close Buffer" })

-- Alt+. (Alt+Period) or Alt+, (Alt+Comma): Switch buffers (next/prev tab in micro)
map({ "n", "i" }, "<A-.>", "<Esc>:bnext<CR>", { desc = "Next Buffer" })
map({ "n", "i" }, "<A-,>", "<Esc>:bprevious<CR>", { desc = "Previous Buffer" })

-- Alt+Right/Alt+Left: Switch buffers (alternative helper)
map({ "n", "i" }, "<A-Right>", "<Esc>:bnext<CR>", { desc = "Next Buffer" })
map({ "n", "i" }, "<A-Left>", "<Esc>:bprevious<CR>", { desc = "Previous Buffer" })

-- --- Shell / Terminal ---
-- Ctrl+B: Open terminal/shell command prompt (run terminal inside Neovim)
map({ "n", "i" }, "<C-b>", "<Esc>:terminal<CR>a", { desc = "Open Terminal" })

-- --- Navigation / Micro behaviors ---
-- Shift+Up/Down/Left/Right: Select text (Visual mode cursor movement)
map("n", "<S-Up>", "v<Up>", { desc = "Select Up" })
map("n", "<S-Down>", "v<Down>", { desc = "Select Down" })
map("n", "<S-Left>", "v<Left>", { desc = "Select Left" })
map("n", "<S-Right>", "v<Right>", { desc = "Select Right" })

map("i", "<S-Up>", "<Esc>v<Up>", { desc = "Select Up" })
map("i", "<S-Down>", "<Esc>v<Down>", { desc = "Select Down" })
map("i", "<S-Left>", "<Esc>v<Left>", { desc = "Select Left" })
map("i", "<S-Right>", "<Esc>v<Right>", { desc = "Select Right" })

map("v", "<S-Up>", "<Up>", { desc = "Select Up" })
map("v", "<S-Down>", "<Down>", { desc = "Select Down" })
map("v", "<S-Left>", "<Left>", { desc = "Select Left" })
map("v", "<S-Right>", "<Right>", { desc = "Select Right" })

-- Double click / click drag options are handled automatically by vim.opt.mouse = "a"
