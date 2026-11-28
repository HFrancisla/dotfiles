local my_augroup = vim.api.nvim_create_augroup('MyVimrcSetup', { clear = true })

-- 新行不自动延续注释符。
vim.api.nvim_create_autocmd('FileType', {
  group = my_augroup,
  pattern = '*',
  command = 'setlocal formatoptions-=c formatoptions-=r formatoptions-=o'
})

-- Lua 缩进与 stylua.toml 一致；其他语言仍使用全局 4 空格。
vim.api.nvim_create_autocmd("FileType", {
  group = my_augroup,
  pattern = "lua",
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.shiftwidth = 2
  end,
})

if vim.fn.exists(":DiffOrig") == 0 then
  vim.cmd([[
    command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
  ]])
end

-- 高亮行尾空格，仅用于普通缓冲区；match 属于窗口而非缓冲区。
local function whitespace_highlight()
  vim.api.nvim_set_hl(0, "ExtraWhitespace", { ctermbg = "red", bg = "red" })
end
whitespace_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = my_augroup,
  callback = whitespace_highlight,
})
vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
  group = my_augroup,
  callback = function()
    if vim.w.extra_whitespace_match then
      pcall(vim.fn.matchdelete, vim.w.extra_whitespace_match)
      vim.w.extra_whitespace_match = nil
    end
    if vim.bo.buftype ~= "" then
      return
    end
    vim.w.extra_whitespace_match = vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
  end,
})

vim.api.nvim_create_user_command('CleanSpace', function()
  local save_cursor = vim.fn.getpos('.')
  local old_query = vim.fn.getreg('/')
  vim.cmd([[%s/\s\+$//e]])
  vim.fn.setpos('.', save_cursor)
  vim.fn.setreg('/', old_query)
  vim.api.nvim_echo({{ "✨ 已清除行尾多余空格！", "Normal" }}, false, {})
end, {})
