-- Python LSP 配置（在 lang.python extra 基础上自定义）
-- lang.python extra 已处理: ruff hoverProvider 禁用、服务器启用/禁用切换
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            pyright = {
              -- 禁用 Pyright 的导入排序，交给 Ruff 处理
              disableOrganizeImports = true,
            },
            python = {
              analysis = {
                -- "off" 让 Pyright 只负责补全和定义跳转，诊断全部交给 Ruff
                typeCheckingMode = "off",
              },
            },
          },
        },
      },
    },
  },
}