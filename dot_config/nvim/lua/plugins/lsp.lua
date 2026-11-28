return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            pyright = {
              -- 导入排序交给 Ruff。
              disableOrganizeImports = true,
            },
            python = {
              analysis = {
                -- 保留 Pyright 语言服务；lint 交给 Ruff。
                typeCheckingMode = "off",
              },
            },
          },
        },
      },
    },
  },
}