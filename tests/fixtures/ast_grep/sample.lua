-- TODO: sample comment
local M = {}
local util = require('util')
require('plugin').setup({ enabled = true })

function M:method(a)
	return self, a
end

local function helper(x)
	for k, v in pairs(x) do print(k, v) end
	for i, v in ipairs(x) do print(i, v) end
	while false do end
	return "a string"
end

vim.keymap.set('n', '<leader>x', helper, { desc = 'x' })
vim.api.nvim_create_autocmd('BufEnter', { callback = function() end })
vim.api.nvim_create_user_command('Sample', helper, {})
vim.cmd('echo 1')
vim.notify('hello')
vim.schedule(function() helper({}) end)
pcall(helper, {})
vim.loop.fs_stat('x')
return M
