return {
  -- bufferline: 顶栏增强
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      {
        "L",
        function()
          vim.cmd("BufferLineCycleNext " .. vim.v.count1)
        end,
        desc = "Next Buffer",
      },
      {
        "H",
        function()
          vim.cmd("BufferLineCyclePrev " .. vim.v.count1)
        end,
        desc = "Prev Buffer",
      },
    },
    opts = {
      options = {
        numbers = "none",
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
      },
    },
  },

  -- sonokai: 色彩主题
  {
    "sainnhe/sonokai",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.sonokai_style = "andromeda"
      vim.g.sonokai_enable_italic = 1
    end,
    config = function()
      -- colorscheme 由 LazyVim opts.colorscheme 统一加载，此处不再重复调用
      -- 个性化高亮：使用 ColorScheme autocmd 确保在主题加载/切换后始终生效
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "sonokai",
        callback = function()
          vim.api.nvim_set_hl(0, "LineNr", { fg = "#ff8700", ctermfg = 208 })
        end,
      })
    end,
  },

  -- LazyVim: 全局主题设定
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
}
