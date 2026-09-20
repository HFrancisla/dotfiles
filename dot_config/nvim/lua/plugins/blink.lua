return {
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      keymap = {
        -- 禁用 Enter 接受补全，让 Enter 只换行
        ["<CR>"] = {},
        -- Tab 接受补全 / 跳转 snippet / fallback 正常缩进
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
    },
  },
}
