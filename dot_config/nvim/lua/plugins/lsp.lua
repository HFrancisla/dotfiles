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
                -- 关闭 Pyright 类型检查；仍保留语言服务及其基础诊断，Ruff 负责 lint
                typeCheckingMode = "off",
              },
            },
          },
        },
      },
    },
  },
}