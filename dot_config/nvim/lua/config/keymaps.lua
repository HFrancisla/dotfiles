local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Change 不覆盖默认寄存器。
keymap('n', 'c', '"_c', opts)

keymap('i', 'jf', '<esc>', opts)
keymap('c', 'jf', '<c-c>', opts)

-- 插入模式下使用 Ctrl+U 删除整行时，打断撤销树
keymap('i', '<C-U>', '<C-G>u<C-U>', opts)
