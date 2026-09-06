# Neovim as a VSCode-shaped daily editor

**Scope note, because it contradicts the path on purpose.** `STRATEGY.md` says
replacing VSCode is a non-goal, and Day 7 ships a 30-line plugin-free
`init.lua`. Both still stand — that config is for a *server you have never
seen*, where plugins do not exist and `$HOME` may not either. This guide is the
opposite situation: your own laptop or dev box, where you want the full IDE.
Keep the two separate. Never install this on a production host.

---

## The decision: use LazyVim, don't hand-roll

You could assemble this from `lazy.nvim` plus twenty plugins. Don't, at least
not first. **LazyVim** is a maintained preset that already wires the VSCode
shape — file tree, fuzzy finder, LSP, completion, git gutter, statusline,
buffer tabs, format-on-save — and it stays out of your way when you override
things. You get a working editor in ten minutes and can read the parts you
care about later. Hand-rolling teaches more, but it costs a weekend and you
will end up reimplementing LazyVim badly.

Two competing presets, for completeness: **kickstart.nvim** is a single
annotated file you are meant to read and edit — better if learning the config
*is* the point. **NvChad** is prettier and more opinionated but harder to
override. LazyVim is the right middle for someone who wants an editor, not a
project.

---

## Install

### Neovim itself — version matters

LazyVim needs Neovim **0.9.4+** (0.10+ strongly preferred). Distribution
packages lag badly; Debian/Ubuntu stable has shipped 0.7 long after 0.10 was
out. Do not use `apt install neovim` and then wonder why everything errors.

```bash
# macOS
brew install neovim

# Linux — the AppImage is the reliable route on any distro
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod +x nvim-linux-x86_64.appimage
sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim

# Arch / Fedora are current enough to use the repo
sudo pacman -S neovim      # Arch
sudo dnf install neovim    # Fedora
```

Verify: `nvim --version | head -1` must show 0.9.4 or newer.

### Dependencies you will actually miss

```bash
# macOS
brew install ripgrep fd lazygit gcc
# Linux (Debian/Ubuntu)
sudo apt install ripgrep fd-find git build-essential unzip
```

`ripgrep` powers project-wide search, `fd` the file picker, and a C compiler
is needed for Treesitter parsers. On Debian `fd` is installed as `fdfind`;
symlink it: `ln -s $(which fdfind) ~/.local/bin/fd`.

**Clipboard.** macOS works out of the box. On Linux you need a bridge, or
`"+y` silently does nothing:

```bash
sudo apt install xclip        # X11
sudo apt install wl-clipboard # Wayland
```

### A Nerd Font — do this before you judge the look

Without one, every icon renders as a box. This is the single most common
reason people bounce off a Neovim distro in the first minute.

```bash
# macOS
brew install --cask font-jetbrains-mono-nerd-font

# Linux
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip && fc-cache -fv
```

Then set it in your terminal: iTerm2 → Profiles → Text → Font; Ghostty →
`font-family = "JetBrainsMono Nerd Font"`; GNOME Terminal → Preferences →
Custom font. **Restart the terminal**, not just Neovim.

### LazyVim

```bash
# Back up anything you already have
mv ~/.config/nvim{,.bak} 2>/dev/null
mv ~/.local/share/nvim{,.bak} 2>/dev/null

git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
nvim
```

First launch installs everything. Then run `:LazyHealth` and fix what it
complains about — it is specific and usually right.

---

## Making it feel like VSCode

### The theme

`Mofiqul/vscode.nvim` is a direct port of VSCode's Dark+ / Light+. Create
`~/.config/nvim/lua/plugins/colorscheme.lua`:

```lua
return {
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    opts = { transparent = false, italic_comments = true },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "vscode" } },
}
```

Restart. If you prefer the JetBrains look instead, swap in
`"navarasu/onedark.nvim"` and set `colorscheme = "onedark"`.

### The keymap overlay — this is what actually matters

Muscle memory is the real cost of switching. Put this in
`~/.config/nvim/lua/config/keymaps.lua` (LazyVim loads it automatically):

```lua
-- VSCode muscle-memory overlay. Ctrl-based on purpose: a terminal cannot
-- see Cmd, so Ctrl is the only binding that works identically on macOS
-- and Linux, and over SSH.
local map = vim.keymap.set

-- Ctrl-P: go to file.  Ctrl-Shift-P: command palette.
map({ "n", "i", "v" }, "<C-p>", "<cmd>Telescope find_files<cr>", { desc = "Go to file" })
map({ "n", "i", "v" }, "<C-S-p>", "<cmd>Telescope commands<cr>", { desc = "Command palette" })

-- Ctrl-Shift-F: search across the project.  Ctrl-B: toggle the sidebar.
map({ "n", "i", "v" }, "<C-S-f>", "<cmd>Telescope live_grep<cr>", { desc = "Find in files" })
map({ "n", "i", "v" }, "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Toggle sidebar" })

-- Ctrl-`: integrated terminal.
map({ "n", "t" }, "<C-`>", "<cmd>ToggleTerm<cr>", { desc = "Terminal" })

-- Ctrl-/ : toggle comment (LazyVim ships gc via Comment/mini.comment).
map("n", "<C-_>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<C-_>", "gc", { remap = true, desc = "Toggle comment" })

-- Ctrl-S save, from any mode, like every other editor on earth.
map({ "n", "i", "v" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "Save" })

-- LSP navigation, VSCode's function keys.
map("n", "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "<S-F12>", vim.lsp.buf.references, { desc = "Find references" })
map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix" })

-- Buffer tabs: Ctrl-Tab / Ctrl-Shift-Tab, plus Ctrl-W to close.
map("n", "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<C-w>", "<cmd>bdelete<cr>", { desc = "Close buffer" })
```

Two caveats, stated plainly:

- **If your LazyVim ships `fzf-lua` instead of Telescope** (newer versions may),
  substitute `FzfLua files`, `FzfLua commands`, `FzfLua live_grep`. Check with
  `:Telescope` — if it errors, you have fzf-lua.
- **`<C-_>` is not a typo.** Most terminals send Ctrl-/ as Ctrl-_. If it does
  nothing, try binding `<C-/>` as well; newer terminals send the literal.

### Language support

LazyVim installs LSP servers on demand. Run `:LazyExtras`, then enable the
languages you use — `lang.go`, `lang.python`, `lang.typescript`, `lang.docker`,
`lang.terraform`, `lang.json`, `lang.yaml`. Each pulls the right LSP,
formatter, linter and Treesitter parser. `:Mason` shows what is installed.

---

## What maps to what

| VSCode | Neovim + LazyVim | Notes |
|---|---|---|
| Explorer sidebar | `neo-tree` (`<C-b>`) | `a` add, `d` delete, `r` rename |
| Ctrl-P go to file | Telescope `find_files` | respects `.gitignore` |
| Ctrl-Shift-P palette | Telescope `commands` | also `<leader>` shows all keys |
| Ctrl-Shift-F search | Telescope `live_grep` | ripgrep-backed, instant |
| Integrated terminal | `toggleterm` | `<C-\><C-n>` to leave insert mode |
| Tabs | `bufferline` | these are *buffers*, not tabs |
| Status bar | `lualine` | |
| Problems panel | `trouble.nvim` (`<leader>xx`) | |
| Source control | `gitsigns` + `lazygit` (`<leader>gg`) | lazygit is better than VSCode's |
| Go to definition | `<F12>` / `gd` | `<C-o>` jumps back |
| Rename symbol | `<F2>` | |
| Format on save | `conform.nvim` | on by default |
| Settings UI | edit Lua files | this is the real trade |
| Extensions | `:Lazy` | `:LazyExtras` for curated sets |

---

## The honest gaps

Three things VSCode does better, so you are not surprised:

1. **Debugging.** `nvim-dap` works and LazyVim has `dap.core`, but it is
   fiddlier than F5. Many people keep VSCode open purely for debug sessions.
   That is a legitimate end state, not a failure.
2. **Live Share and notebooks.** No real equivalent.
3. **The first two weeks.** You will be slower. This is the actual cost, and
   no config removes it.

## A transition that survives contact

Do not switch cold — you will bounce back to VSCode inside a day and conclude
it does not work.

- **Week 1:** keep VSCode as primary. Open one file a day in Neovim and do a
  real edit in it. Goal is only that the keymaps stop feeling foreign.
- **Week 2:** Neovim for everything except debugging and one language you are
  under deadline pressure in.
- **Week 3:** Neovim primary. Keep VSCode installed. Use it without guilt for
  debugging.
- **Bail signal:** if after three weeks you are still consciously translating
  intent into keystrokes, the modal model has not landed — go back and do the
  Day 7 exercises in this path, which drill the grammar rather than the tools.

## Keep the config in git

```bash
cd ~/.config/nvim && git init && git add -A
git commit -m "nvim config"
```

Push it somewhere. Then on a new machine — Linux or macOS — the whole setup is
`brew install neovim` (or the AppImage), clone, `nvim`. The config is
platform-agnostic; only the font and clipboard steps differ, and both are
above.

**One rule.** This repo is for machines you own. On a server you are debugging,
the Day 7 `init.lua` is the whole config, and `vi` may be all you get. Do not
blur them — the point of `labs/day07/init.lua` being 22 lines is that you can
retype it from memory on a box that has nothing.
