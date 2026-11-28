return {
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

  {
    "sainnhe/sonokai",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.sonokai_style = "andromeda"
      vim.g.sonokai_enable_italic = 1
    end,
    config = function()
      -- 主题切换后重新应用自定义行号颜色。
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "sonokai",
        callback = function()
          vim.api.nvim_set_hl(0, "LineNr", { fg = "#ff8700", ctermfg = 208 })
        end,
      })
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
}
