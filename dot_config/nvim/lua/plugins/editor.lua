return {
  -- yanky: 剪贴板历史增强（keys 和 opts 由 coding.yanky extra 提供，此处仅做自定义覆盖）
  {
    "gbprod/yanky.nvim",
    opts = {
      highlight = { timer = 150 },
    },
  },

  -- tmux-navigator: Tmux & Neovim 窗口无缝跳转
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
    },
  },

  -- fugitive: Git 深度集成
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gdiffsplit", "Gvdiffsplit" },
    keys = {
      { "<leader>gF", "<cmd>Git<CR>", desc = "Fugitive: Git Status" },
      { "<leader>dx", "<cmd>Gdiffsplit<CR>", desc = "Fugitive: Git Diff Split" },
      { "<leader>dv", "<cmd>Gvdiffsplit<CR>", desc = "Fugitive: Git Diff Vert" },
    },
  },
}
