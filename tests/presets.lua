local presets = require('editable-telescope.presets')
local ast_grep = require('editable-telescope.ast_grep')

-- Resolving: defaults, then config, then per call; same names replace in place.
local ctx = { filetype = 'lua', filename = '/x/init.lua' }
local list = presets.resolve('live_grep', {
	presets = { live_grep = { { name = 'Whole word', cmd_args = '-w' }, { name = 'Mine', cmd_args = {} } } },
}, { { name = 'Call', cmd_args = {} }, { name = 'Literal', disabled = true } }, ctx)
local names = vim.tbl_map(function(p) return p.name end, list)
assert(names[1] == 'All files' and names[#names - 1] == 'Mine' and names[#names] == 'Call', vim.inspect(names))
assert(not vim.tbl_contains(names, 'Literal'))
local whole = list[vim.fn.index(names, 'Whole word') + 1]
assert(vim.deep_equal(presets.cmd_args(whole, ctx), { '-w' }))
assert(#presets.resolve('live_grep', { default_presets = false }, nil, ctx) == 0)
assert(#presets.resolve('live_grep', { default_presets = { live_grep = false } }, nil, ctx) == 0)
assert(#presets.resolve('find_files', { default_presets = { live_grep = false } }, nil, ctx) > 0)

-- Function cmd_args get the context.
local same_ext = list[vim.fn.index(names, 'Same extension') + 1]
assert(vim.deep_equal(presets.cmd_args(same_ext, ctx), { '--glob', '*.lua' }))
assert(vim.deep_equal(presets.cmd_args(same_ext, { filename = '' }), {}))

-- Language presets are filtered by filetype; all are shown without one.
local function ast_names(filetype)
	return vim.tbl_map(function(p) return p.name end, presets.resolve('ast_grep', {}, nil, { filetype = filetype }))
end
local lua_names, all_names = ast_names('lua'), ast_names('')
assert(vim.tbl_contains(lua_names, 'Lua: require') and vim.tbl_contains(lua_names, 'Text in comments'))
assert(not vim.tbl_contains(lua_names, 'Rust: unwrap'))
assert(vim.tbl_contains(ast_names('typescriptreact'), 'TS: as any'))
assert(vim.tbl_contains(all_names, 'Rust: unwrap') and #all_names > #lua_names)

-- Rules: every language has comment and string rules; prompts become regexes.
for lang in pairs(ast_grep.languages) do
	assert(ast_grep.rules.comments('', lang) and ast_grep.rules.strings('x', lang), lang)
end
assert(ast_grep.rules.types('', 'lua') == nil and ast_grep.rules.comments('', 'cobol') == nil)
assert(vim.deep_equal(ast_grep.rules.comments('TODO', 'rust'), {
	any = { { kind = 'line_comment', regex = 'TODO' }, { kind = 'block_comment', regex = 'TODO' } },
}))
assert(vim.deep_equal(ast_grep.rules.functions('^f', 'c'), {
	any = { { all = { { kind = 'function_definition' }, { has = { field = 'declarator', regex = '^f' } } } } },
}))
assert(vim.deep_equal({ ast_grep.extract_lang({ '-l', 'rust', '--follow', '--lang=go' }) }, { 'go', { '--follow' } }))
local command, lang = ast_grep.build({ rule = ast_grep.rules.comments, lang = 'lua' }, { '-l', 'rust', '--follow' })
assert(command[2] == 'scan' and lang == 'rust' and command[#command] == '--follow')
local full = ast_grep.with_rule({ 'ast-grep', 'scan' }, { kind = 'comment' }, 'lua', { 'src' })
assert(full[3] == '--inline-rules' and vim.json.decode(full[4]).language == 'lua' and full[6] == 'src')

-- The selection window and applying presets.
local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local builtin = require('telescope.builtin')
local args = require('editable-telescope.args')
telescope.setup({
	defaults = { initial_mode = 'normal' },
	extensions = { editable = { presets = { find_files = { { name = 'Docs root', cwd = '/tmp' } } } } },
})
telescope.load_extension('editable')
local editable = telescope.extensions.editable

local function current()
	return action_state.get_current_picker(vim.api.nvim_get_current_buf())
end
local function wait_picker(previous, title)
	assert(vim.wait(3000, function()
		local picker = vim.bo.filetype == 'TelescopePrompt' and current()
		return picker and picker ~= previous and (not title or picker.prompt_title:match(title))
	end), 'picker did not open: ' .. tostring(title))
	return current()
end
-- Open the preset window, then choose `name` (or cancel with nil).
local function choose(name, key)
	local picker = current()
	vim.fn.maparg(key or '<C-o>', 'n', false, true).callback()
	local window = wait_picker(picker, '^Presets$')
	assert(window.layout_strategy == 'center' and window.previewer == nil, 'expected the dropdown theme')
	if not name then
		vim.fn.maparg('<Esc>', 'n', false, true).callback()
	else
		window:set_prompt(name, true)
		assert(vim.wait(3000, function()
			local entry = window:get_selection()
			return entry and entry.value.name == name
		end), 'preset not found: ' .. name)
		actions.select_default(window.prompt_bufnr)
	end
	return wait_picker(window)
end

local command, build = nil, args.build
args.build = function(...)
	command = build(...)
	return command
end

editable.live_grep({ default_text = 'needle' })
local picker = choose('Whole word')
assert(picker:_get_prompt() == 'needle' and picker.prompt_title:match('{Whole word}'), picker.prompt_title)
assert(command[#command] == '--word-regexp')
picker = choose('All files')
assert(vim.deep_equal(vim.list_slice(command, #command - 1), { '--hidden', '--no-ignore' }))
assert(not vim.tbl_contains(command, '--word-regexp'))
picker = choose(nil)
assert(picker.prompt_title:match('{All files}') and command[#command] == '--no-ignore')
picker = choose('Default')
assert(not picker.prompt_title:match('{') and not vim.tbl_contains(command, '--hidden'))
actions.close(picker.prompt_bufnr)
args.build = build

-- find_files presets set picker options and roots.
local seen, find_files = nil, builtin.find_files
builtin.find_files = function(opts)
	seen = opts
	return find_files(opts)
end
editable.find_files({ default_text = 'x' })
choose('All files')
assert(seen.hidden and seen.no_ignore and seen.prompt_title:match('{All files}'))
choose('Docs root')
assert(not seen.hidden and seen.cwd == args.normalize_root('/tmp'))
actions.close(current().prompt_bufnr)
builtin.find_files = find_files

-- Remapping or disabling the key.
telescope.setup({ extensions = { editable = { mappings = { presets = '<C-b>' } } } })
telescope.load_extension('editable')
editable.live_grep()
assert(vim.fn.maparg('<C-b>', 'n', false, true).buffer == 1 and vim.fn.maparg('<C-o>', 'n') == '')
actions.close(current().prompt_bufnr)
telescope.setup({ extensions = { editable = { mappings = { presets = false } } } })
telescope.load_extension('editable')
editable.live_grep()
assert(vim.fn.maparg('<C-b>', 'n') == '')
actions.close(current().prompt_bufnr)
telescope.setup({ extensions = { editable = { mappings = { presets = '<C-o>' } } } })
telescope.load_extension('editable')

if vim.fn.executable(ast_grep.default_command) == 0 then
	print('preset tests passed (ast-grep presets skipped: ast-grep not installed)')
	return
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile({ '-- TODO first', 'local x = require("a")', '-- second', 'local s = "TODO str"' }, root .. '/a.lua')
vim.fn.writefile({ 'fn main() { let v: Option<i32> = None; v.unwrap(); }' }, root .. '/b.rs')
local function results(p, count)
	assert(vim.wait(5000, function() return p.manager and p.manager:num_results() == count end),
		'expected ' .. count .. ', got ' .. (p.manager and p.manager:num_results() or 'none'))
	local texts = {}
	for e in p.manager:iter() do texts[#texts + 1] = e.match.text end
	table.sort(texts)
	return texts
end

local source = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(source)
vim.bo[source].filetype = 'lua'
editable.ast_grep({ cwd = root })
picker = choose('Text in comments')
-- An empty prompt lists every comment, a prompt filters them.
assert(vim.deep_equal(results(picker, 2), { '-- TODO first', '-- second' }))
picker:set_prompt('TODO', true)
assert(vim.deep_equal(results(picker, 1), { '-- TODO first' }))
picker = choose('Text in strings')
assert(picker:_get_prompt() == 'TODO')
assert(vim.deep_equal(results(picker, 1), { '"TODO str"' }))
picker = choose('Lua: require')
assert(picker:_get_prompt() == 'require($MOD)' and picker.prompt_title:match('<lua>'))
assert(vim.deep_equal(results(picker, 1), { 'require("a")' }))
picker = choose('All languages')
picker:set_prompt('$E.unwrap()', true)
assert(vim.deep_equal(results(picker, 1), { 'v.unwrap()' }))
actions.close(picker.prompt_bufnr)

-- A rule's language can come from the edited flags.
vim.bo[source].filetype = ''
editable.ast_grep({ cwd = root })
picker = choose('Function calls')
local input = vim.ui.input
vim.ui.input = function(_, callback) callback('-l rust') end
vim.fn.maparg('<C-a>', 'n', false, true).callback()
picker = wait_picker(picker)
vim.ui.input = input
assert(picker.prompt_title:match('<rust>'), picker.prompt_title)
picker:set_prompt('unwrap', true)
assert(vim.deep_equal(results(picker, 1), { 'v.unwrap()' }))
actions.close(picker.prompt_bufnr)
print('preset tests passed')
