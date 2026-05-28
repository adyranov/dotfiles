-- Catppuccin Mocha colorscheme + Mocha-tinted devicons (cafetiere.nvim).
local config = vim.fn.stdpath("config")

local function prepend_rtp(name)
  local dir = config .. "/" .. name
  if vim.uv.fs_stat(dir) then
    vim.opt.rtp:prepend(dir)
  end
end

prepend_rtp("nvim-web-devicons")
prepend_rtp("catppuccin.nvim")
prepend_rtp("cafetiere.nvim")

if pcall(require, "nvim-web-devicons") then
  require("nvim-web-devicons").setup({ default = true, color_icons = true })
end

if pcall(require, "catppuccin") then
  require("catppuccin").setup({
    flavour = "mocha",
    integrations = {
      native_lsp = { enabled = true },
      treesitter = true,
    },
  })
  vim.cmd.colorscheme("catppuccin-mocha")
end

if pcall(require, "cafetiere") then
  require("cafetiere").setup()
end
