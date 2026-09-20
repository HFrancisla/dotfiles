-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ==========================================
-- 1. Neovide (GUI) 专属配置
-- ==========================================
if vim.g.neovide then
	-- 设置字体和字号
	--vim.o.guifont = "CaskaydiaCove Nerd Font:h18"
	-- 开启 Neovide 的电磁炮光标特效
	vim.g.neovide_cursor_vfx_mode = "railgun"
	-- 缩放比例
	vim.g.neovide_scale_factor = 0.9
	-- 关闭 snacks_animate 动画，因为 Neovide 自带动画，防止冲突和卡顿
	vim.g.snacks_animate = false
end

-- 关闭老旧的netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

-- 开启自动换行显示
opt.wrap = true
-- 关闭在单词边界处折行
--opt.linebreak = false
-- 设置拼写检查语言，加入 cjk 防止中文字符被标红报错
opt.spelllang = { "en", "cjk" }

-- 同步 Neovim 的匿名寄存器与系统剪贴板
opt.clipboard = "unnamedplus"

-- 文件编码相关选项
opt.fileencodings = "utf-8,ucs-bom,gb18030,gbk,gb2312,cp936,latin1"

-- 注释中的字符串高亮
vim.g.c_comment_strings = 1
-- 强制使用当前工作目录 (cwd) 作为项目根目录
vim.g.root_spec = { "cwd" }

-- 禁用 0 开源的八进制解析
opt.nrformats:remove("octal")

-- 缩进设置
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4

-- 界面与布局
opt.colorcolumn = "80"
opt.scrolloff = 3

-- 禁用不需要的 provider
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Python 虚拟环境路径
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/nvim-python/bin/python")
