local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local args = require('editable-telescope.args')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')

telescope.setup({ defaults = { initial_mode = 'normal' } })
local state
telescope.extensions.editable.editable_picker({
	picker_opts = { default_text = 'editing' },
	initial_state = { cmd_args = { '--hidden' }, cmd_args_text = '--hidden' },
	mappings = { change_root = '<C-x>', edit_grep_args = '<C-y>' },
	parse_cmd_args = function(input) return args.split(input, true) end,
	format_cmd_args = function(_, editor) return editor.cmd_args_text end,
	prompt_title = function() return 'Shared wrapper test' end,
	open = function(editor, opts)
		state = editor
		pickers.new(opts, { finder = finders.new_table({}), sorter = sorters.empty() }):find()
	end,
})

local function current()
	return action_state.get_current_picker(vim.api.nvim_get_current_buf())
end
for _, mode in ipairs({ 'i', 'n' }) do
	assert(vim.fn.maparg('<C-x>', mode, false, true).buffer == 1)
	assert(vim.fn.maparg('<C-y>', mode, false, true).buffer == 1)
end

local original_input = vim.ui.input
local function edit(key, answer, expected_default)
	local previous = current().prompt_bufnr
	vim.ui.input = function(opts, callback)
		assert(opts.default == expected_default, vim.inspect(opts))
		callback(answer)
	end
	vim.fn.maparg(key, 'n', false, true).callback()
	assert(vim.wait(2000, function()
		return vim.api.nvim_get_current_buf() ~= previous and vim.bo.filetype == 'TelescopePrompt'
	end), 'picker did not reopen')
	assert(current():_get_prompt() == 'editing')
end

edit('<C-y>', [[-g 'unfinished]], '--hidden')
assert(state.cmd_args_error and vim.deep_equal(state.cmd_args, { '--hidden' }))
assert(state.cmd_args_text == [[-g 'unfinished]])
edit('<C-y>', nil, [[-g 'unfinished]])
assert(state.cmd_args_error and state.cmd_args_text == [[-g 'unfinished]])
edit('<C-x>', '/tmp', state.cwd)
assert(state.cmd_args_error and state.cmd_args_text == [[-g 'unfinished]])
edit('<C-y>', [[-g 'src files/*.lua']], [[-g 'unfinished]])
assert(not state.cmd_args_error and vim.deep_equal(state.cmd_args, { '-g', 'src files/*.lua' }))
edit('<C-y>', nil, [[-g 'src files/*.lua']])
assert(not state.cmd_args_error)
actions.close(current().prompt_bufnr)

-- Built-in grep retains its original mappings, formatting and permissive input.
telescope.extensions.editable.live_grep({ default_text = 'editing' })
assert(vim.fn.maparg('<C-s>', 'n', false, true).buffer == 1)
edit('<C-a>', [[--glob '*.lua']], '')
edit('<C-a>', [[--glob 'unfinished]], '--glob *.lua')
edit('<C-a>', nil, '--glob unfinished')
actions.close(current().prompt_bufnr)
vim.ui.input = original_input
print('shared wrapper tests passed')
