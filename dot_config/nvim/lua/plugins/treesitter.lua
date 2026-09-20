-- nvim-treesitter: 补充 Snacks.image 等插件需要的额外解析器
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "css",
        "norg",
        "scss",
        "svelte",
        "typst",
        "vue",
      },
    },
  },
}
