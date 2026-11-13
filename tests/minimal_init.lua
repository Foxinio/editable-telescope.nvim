local deps = vim.env.DEPS_DIR
if not deps or deps == '' then deps = vim.fn.stdpath('data') .. '/lazy' end
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(deps .. '/plenary.nvim')
vim.opt.runtimepath:append(deps .. '/telescope.nvim')
