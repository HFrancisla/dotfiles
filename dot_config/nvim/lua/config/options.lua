if vim.g.neovide then
  vim.g.neovide_cursor_vfx_mode = "railgun"
  vim.g.neovide_scale_factor = 0.9
  vim.g.snacks_animate = false
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

opt.wrap = true
opt.spelllang = { "en", "cjk" }
opt.clipboard = "unnamedplus"
opt.fileencodings = "utf-8,ucs-bom,gb18030,gbk,gb2312,cp936,latin1"

vim.g.c_comment_strings = 1
vim.g.root_spec = { "cwd" }

opt.nrformats:remove("octal")
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.colorcolumn = "80"
opt.scrolloff = 3

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/nvim-python/bin/python")

-- mise shim 不能直接作为 Node provider 入口，解析到真实可执行文件。
if vim.fn.executable("mise") == 1 then
  local host = vim.fn.trim(vim.fn.system({ "mise", "which", "neovim-node-host" }))
  if vim.v.shell_error == 0 and vim.fn.filereadable(host) == 1 then
    vim.g.node_host_prog = host
  end
end
