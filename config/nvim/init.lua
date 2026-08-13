-- Your shell aliases `vim` to `nvim`, but nvim does not read ~/.vimrc on its
-- own. Source it so plain `vim` and `nvim` behave identically.
local vimrc = vim.fn.expand("~/.vimrc")
if vim.fn.filereadable(vimrc) == 1 then
  vim.cmd.source(vimrc)
end

-- Neovim-only settings (things ~/.vimrc can't assume in plain vim).
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 5
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.signcolumn = "yes"

-- Clear search highlight.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Briefly highlight yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank() end,
})
