local ast_grep = require('editable-telescope.ast_grep')

-- Command building.
assert(vim.deep_equal(ast_grep.build({}, {}), { 'ast-grep', 'run', '--json=stream' }))
assert(vim.deep_equal(
	ast_grep.build({
		command = 'sg',
		hidden = true,
		lang = 'lua',
		globs = { '*.lua' },
		additional_args = function() return { '--strictness', 'ast' } end,
	}, { '--follow' }),
	{
		'sg', 'run', '--json=stream', '--no-ignore', 'hidden', '--lang', 'lua',
		'--globs', '*.lua', '--strictness', 'ast', '--follow',
	}
))
local no_ignore = ast_grep.build({ no_ignore = true }, {})
assert(#no_ignore == 3 + 10 and no_ignore[4] == '--no-ignore')
-- An edited or additional language replaces the default one.
for _, edited in ipairs({ { '-l', 'rust' }, { '--lang', 'rust' }, { '--lang=rust' }, { '-lrust' } }) do
	local command = ast_grep.build({ lang = 'lua' }, edited)
	assert(not vim.tbl_contains(command, 'lua'), vim.inspect(command))
end
assert(not vim.tbl_contains(ast_grep.build({ lang = 'lua', additional_args = { '-l', 'c' } }, {}), 'lua'))
-- Flags that merely start with `-l` are not languages.
assert(vim.tbl_contains(ast_grep.build({ lang = 'lua' }, { '--follow' }), 'lua'))

assert(vim.deep_equal(
	ast_grep.with_pattern({ 'ast-grep', 'run' }, '-$A', { 'src', 'lib' }),
	{ 'ast-grep', 'run', '--pattern=-$A', '--', 'src', 'lib' }
))
assert(vim.deep_equal(ast_grep.with_pattern({ 'x' }, 'p'), { 'x', '--pattern=p' }))

-- Language resolution.
local buf = vim.api.nvim_create_buf(false, true)
vim.bo[buf].filetype = 'lua'
assert(ast_grep.resolve_lang({ lang = true, bufnr = buf }) == 'lua')
assert(ast_grep.resolve_lang({ lang = 'rust', bufnr = buf }) == 'rust')
assert(ast_grep.resolve_lang({}) == nil)
vim.bo[buf].filetype = ''
assert(ast_grep.resolve_lang({ lang = true, bufnr = buf }) == nil)

-- Parsing: character columns become byte columns, multi-line ranges survive.
local function json(file, lines, sl, sc, el, ec)
	return vim.json.encode({
		file = file,
		text = 'ignored',
		lines = lines,
		range = { start = { line = sl, column = sc }, ['end'] = { line = el, column = ec } },
	})
end
local parsed = ast_grep.parse(json('a.lua', 'local s = "żółć" .. foo(1)', 0, 20, 0, 26))
assert(parsed.lnum == 1 and parsed.lnend == 1)
assert(parsed.col == 25 and parsed.colend == 31, vim.inspect(parsed))
parsed = ast_grep.parse(json('a.lua', 'local t = bar(\n  2\n)', 1, 10, 3, 1))
assert(parsed.lnum == 2 and parsed.col == 11 and parsed.lnend == 4 and parsed.colend == 2)
assert(parsed.text == 'local t = bar(')
assert(ast_grep.parse('not json') == nil)
assert(ast_grep.parse('{"file":"x"}') == nil)

local entry = ast_grep.entry_maker({ cwd = '/tmp' })(json('a.lua', 'x = foo(1)', 4, 4, 4, 10))
assert(entry.filename == 'a.lua' and entry.lnum == 5 and entry.col == 5)
assert(entry.lnend == 5 and entry.colend == 11 and entry.text == 'x = foo(1)')
assert(entry.path == '/tmp/a.lua' and entry.match.file == 'a.lua')
assert(entry:display():match('a.lua:5:5:x = foo%(1%)'))

if vim.fn.executable(ast_grep.default_command) == 0 then
	print('ast-grep tests passed (picker tests skipped: ast-grep not installed)')
	return
end

-- The picker against a real project.
local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
telescope.setup({ defaults = { initial_mode = 'normal' } })
telescope.load_extension('editable')

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/sub', 'p')
vim.fn.writefile({ 'local a = foo(1)', 'local b = foo(', '  2', ')' }, root .. '/a.lua')
vim.fn.writefile({ 'foo(3)' }, root .. '/sub/b.lua')
vim.fn.writefile({ 'foo(4)' }, root .. '/c.py')

local function current()
	return action_state.get_current_picker(vim.api.nvim_get_current_buf())
end

local function results(picker, count)
	assert(vim.wait(5000, function()
		return picker.manager and picker.manager:num_results() == count
	end), 'expected ' .. count .. ' results, got ' .. (picker.manager and picker.manager:num_results() or 'none'))
	local found = {}
	for e in picker.manager:iter() do found[#found + 1] = e end
	table.sort(found, function(x, y) return x.filename .. x.lnum < y.filename .. y.lnum end)
	return found
end

local source = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(source)
vim.bo[source].filetype = 'lua'
telescope.extensions.editable.ast_grep({ cwd = root, lang = true, default_text = 'foo($A)' })
local picker = current()
assert(picker.prompt_title:match('<lua>'), picker.prompt_title)
local found = results(picker, 3)
assert(found[1].filename == 'a.lua' and found[1].lnum == 1 and found[1].col == 11 and found[1].colend == 17)
assert(found[2].lnum == 2 and found[2].lnend == 4 and found[2].colend == 2)
assert(found[3].filename == 'sub/b.lua')

-- Editing the flags reopens the picker with the prompt and overrides the language.
local input = vim.ui.input
vim.ui.input = function(opts, callback)
	assert(opts.prompt == 'ast-grep flags: ')
	callback('--lang python')
end
vim.fn.maparg('<C-a>', 'n', false, true).callback()
assert(vim.wait(2000, function()
	return vim.bo.filetype == 'TelescopePrompt' and current() ~= picker
end))
picker = current()
assert(picker:_get_prompt() == 'foo($A)')
found = results(picker, 1)
assert(found[1].filename == 'c.py')

-- Changing the root keeps the flags.
vim.ui.input = function(_, callback) callback(root .. '/sub') end
vim.fn.maparg('<C-s>', 'n', false, true).callback()
assert(vim.wait(2000, function()
	return vim.bo.filetype == 'TelescopePrompt' and current() ~= picker
end))
picker = current()
assert(picker.prompt_title:match('%[%-%-lang python%]'), picker.prompt_title)
results(picker, 0)
picker:set_prompt('foo($A)', true)
vim.ui.input = input
actions.close(picker.prompt_bufnr)

-- Selecting opens the file at the match.
telescope.extensions.editable.ast_grep({ cwd = root, search_dirs = { 'sub' }, default_text = 'foo($A)' })
picker = current()
results(picker, 1)
assert(vim.wait(2000, function() return picker:get_selection() ~= nil end))
actions.select_default(picker.prompt_bufnr)
assert(vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('sub/b.lua$') end))
assert(vim.api.nvim_win_get_cursor(0)[1] == 1)
print('ast-grep tests passed')
