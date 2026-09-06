-- Linux Operator Mastery: plugin-free operator config.
-- No plugin manager, no LSP, no completion. Motions and ex commands only.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.undofile = true
-- clipboard: deliberately left at the default. A container has no host
-- clipboard, so learning the plus-register here would teach you a lie.

-- Arrow keys are off. h j k l is the whole point.
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  for _, mode in ipairs({ "n", "i", "v" }) do
    vim.keymap.set(mode, key, function()
      vim.notify("Use h j k l.", vim.log.levels.WARN)
    end)
  end
end
