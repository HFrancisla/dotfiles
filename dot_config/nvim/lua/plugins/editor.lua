return {
  {
    "gbprod/yanky.nvim",
    opts = {
      highlight = { timer = 150 },
    },
  },

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
