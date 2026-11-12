local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local args = require('editable-telescope.args')
local command, build = nil, args.build
args.build = function(...)
	command = build(...)
	return command
end

telescope.setup({ defaults = { initial_mode = 'normal' } })
telescope.load_extension('editable')
local editable = telescope.extensions.editable

local function current()
	return action_state.get_current_picker(vim.api.nvim_get_current_buf())
end

local function open(kind, opts, expected)
	editable[kind](opts)
	local picker = current()
	assert(picker:_get_prompt() == (expected or ''), vim.inspect({ expected, picker:_get_prompt() }))
	return picker
end

local function close(query)
	local picker = current()
	picker:set_prompt(query, true)
	actions.close(picker.prompt_bufnr)
	vim.wait(20)
end

-- Disabled by default, including after cancellation.
open('find_files')
close('ignored')
open('find_files')
close('')

telescope.setup({ extensions = { editable = { remember_query = true } } })
telescope.load_extension('editable')
open('find_files')
close('files')
open('live_grep')
close('grep')
require('telescope.builtin').buffers()
actions.close(current().prompt_bufnr)
vim.wait(20)
open('find_files', { hidden = true, no_ignore = true }, 'files')
close('all files')
open('find_files', nil, 'all files')
close('')
open('find_files', nil, '')
close('files')
open('live_grep', { additional_args = { '--hidden', '--no-ignore' } }, 'grep')
close('all grep')
open('live_grep', nil, 'all grep')
close('')
open('live_grep', nil, '')
close('grep')

for _, kind in ipairs({ 'find_files', 'live_grep' }) do
	open(kind, { default_text = 'explicit' }, 'explicit')
	close('remembered')
	open(kind, { default_text = '' }, '')
	close('remembered')
end

-- Selection saves too, without replacing caller mappings or Telescope actions.
local attached = 0
local picker = open('find_files', {
	default_text = '',
	find_command = { 'printf', 'README.md\n' },
	attach_mappings = function(_, map)
		attached = attached + 1
		map('n', '<C-x>', function() end)
		return true
	end,
}, '')
assert(attached == 1)
assert(vim.fn.maparg('<C-x>', 'n', false, true).buffer == 1)
assert(vim.wait(2000, function() return picker.manager and picker.manager:num_results() > 0 end))
picker:set_prompt('README', true)
assert(vim.wait(2000, function() return picker:get_selection() ~= nil end))
actions.select_default(picker.prompt_bufnr)
vim.wait(20)
open('find_files', nil, 'README')
close('remembered')

local input = vim.ui.input
local function edit(key, answer)
	local previous = current().prompt_bufnr
	vim.ui.input = function(_, callback) callback(answer) end
	vim.fn.maparg(key, 'n', false, true).callback()
	assert(vim.wait(2000, function()
		return vim.api.nvim_get_current_buf() ~= previous
			and vim.bo.filetype == 'TelescopePrompt'
	end))
	assert(current():_get_prompt() == 'editing')
end

for _, enabled in ipairs({ false, true }) do
	telescope.setup({ extensions = { editable = { remember_query = enabled } } })
	telescope.load_extension('editable')
	open('live_grep', { default_text = 'editing' }, 'editing')
	for _, mode in ipairs({ 'i', 'n' }) do
		assert(vim.fn.maparg('<C-s>', mode, false, true).buffer == 1)
		assert(vim.fn.maparg('<C-a>', mode, false, true).buffer == 1)
	end
	local cwd = current().cwd
	edit('<C-s>', '/tmp')
	assert(current().cwd == args.normalize_root('/tmp'))
	edit('<C-s>', nil)
	assert(current().cwd == args.normalize_root('/tmp'))
	edit('<C-a>', [[--glob '*.lua']])
	assert(vim.deep_equal(vim.list_slice(command, #command - 1), { '--glob', '*.lua' }))
	edit('<C-a>', nil)
	assert(vim.deep_equal(vim.list_slice(command, #command - 1), { '--glob', '*.lua' }))
	close('editing')
	open('live_grep', nil, enabled and 'editing' or '')
	assert(current().cwd == cwd)
	assert(not vim.tbl_contains(command, '--glob'))
	close('')
	open('find_files', {
		default_text = 'editing',
		attach_mappings = function() return false end,
	}, 'editing')
	edit('<C-s>', '/tmp')
	assert(vim.fn.fnamemodify(current().cwd, ':p') == vim.fn.fnamemodify('/tmp', ':p'))
	close('editing')
	open('find_files', nil, enabled and 'editing' or '')
	assert(current().cwd == cwd)
	close('')
end
vim.ui.input = input
args.build = build
print('query tests passed')
