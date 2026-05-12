if vim.loader then
  vim.loader.enable()
end

_G.dd = function(...)
  require("util.debug").dump(...)
end
vim.print = _G.dd

require("config.lazy")

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.cpp", "*.c", "*.cs", "*.h" },
  command = "silent! !clang-format -style=file -i %",
})
