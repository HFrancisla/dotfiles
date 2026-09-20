-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- ...

local my_augroup = vim.api.nvim_create_augroup('MyVimrcSetup', { clear = true })

-- 格式化: 禁用自动插入注释领导符 
vim.api.nvim_create_autocmd('FileType', {
  group = my_augroup,
  pattern = '*',
  command = 'setlocal formatoptions-=c formatoptions-=r formatoptions-=o'
})

-- 差异对比命令
if vim.fn.exists(":DiffOrig") == 0 then
  vim.cmd([[
    command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
  ]])
end

-- 高亮行尾空格（排除 Dashboard 等特殊缓冲区，防止匹配累积）
vim.api.nvim_set_hl(0, 'ExtraWhitespace', { ctermbg = 'red', bg = 'red' })
vim.api.nvim_create_autocmd({"BufEnter", "InsertLeave"}, {
  group = my_augroup,
  pattern = "*",
  callback = function()
    local bt = vim.bo.buftype
    if bt == "nofile" or bt == "prompt" or bt == "terminal" then
      return
    end
    pcall(function()
      if vim.w.extra_whitespace_match then
        vim.fn.matchdelete(vim.w.extra_whitespace_match)
      end
    end)
    vim.w.extra_whitespace_match = vim.fn.matchadd('ExtraWhitespace', [[\s\+$]])
  end
})

-- --- 一键清除行尾多余空格 ---
vim.api.nvim_create_user_command('CleanSpace', function()
  local save_cursor = vim.fn.getpos('.')
  local old_query = vim.fn.getreg('/')
  vim.cmd([[%s/\s\+$//e]])
  vim.fn.setpos('.', save_cursor)
  vim.fn.setreg('/', old_query)
  vim.api.nvim_echo({{ "✨ 已清除行尾多余空格！", "Normal" }}, false, {})
end, {})
