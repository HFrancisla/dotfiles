-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 自定义按键 (不覆盖 LazyVim 核心行为的设定)

-- 额外导航和操作 (从旧配置迁移)
keymap('n', 'c', '"_c', opts)

-- 模式切换快捷键
keymap('i', 'jf', '<esc>', opts)
keymap('c', 'jf', '<c-c>', opts)

-- 插入模式下使用 Ctrl+U 删除整行时，打断撤销树
keymap('i', '<C-U>', '<C-G>u<C-U>', opts)

-- Visual 模式下粘贴保留寄存器：yanky.nvim 的 <Plug>(YankyPutAfter) 已自动处理，
-- 无需手动 pgvy 映射。
