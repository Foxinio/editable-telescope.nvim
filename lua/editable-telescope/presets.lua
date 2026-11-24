-- Built-in presets and the small preset selection window.
--
-- A preset is a table:
--   name      shown in the selection window and the picker title (required)
--   desc      optional description shown after the name
--   ft        filetype or list of filetypes; the preset is listed only when the
--             picker was opened from a buffer of one of them (or one without a
--             filetype)
--   opts      picker option overrides (`hidden`, `no_ignore`, `lang`, `rule`...)
--   cmd_args  flags for the editable arguments: a list, a string parsed like
--             typed input, or `function(ctx)` returning either
--   cwd       optional search root
--   prompt    optional text that replaces the prompt (e.g. an ast-grep pattern)
-- Selecting a preset replaces the edited flags with its `cmd_args` and the
-- previous preset's `opts`; the root and prompt are kept unless it sets them.
local M = {}

local function ext_glob(ctx)
	local ext = vim.fn.fnamemodify(ctx.filename or '', ':e')
	if ext == '' then return {} end
	return { '--glob', '*.' .. ext }
end

local function rg_types(...)
	local out = {}
	for _, t in ipairs({ ... }) do vim.list_extend(out, { '--type', t }) end
	return out
end

local test_globs = {
	'--glob', '!**/test/**', '--glob', '!**/tests/**', '--glob', '!**/__tests__/**',
	'--glob', '!*_test.*', '--glob', '!*.test.*', '--glob', '!*.spec.*', '--glob', '!test_*',
}

M.defaults = {}

M.defaults.find_files = {
	{ name = 'All files', desc = 'hidden and ignored', opts = { hidden = true, no_ignore = true } },
	{ name = 'Hidden files', desc = 'dotfiles, still respecting .gitignore', opts = { hidden = true } },
	{ name = 'Ignored files', desc = 'skip .gitignore, no dotfiles', opts = { no_ignore = true } },
}

M.defaults.live_grep = {
	{ name = 'All files', desc = 'hidden and ignored', cmd_args = { '--hidden', '--no-ignore' } },
	{ name = 'Literal', desc = 'no regex', cmd_args = { '--fixed-strings' } },
	{ name = 'Whole word', cmd_args = { '--word-regexp' } },
	{ name = 'Case sensitive', cmd_args = { '--case-sensitive' } },
	{ name = 'Multiline', desc = '. and \\n match across lines', cmd_args = { '--multiline', '--multiline-dotall' } },
	{ name = 'Same extension', desc = "as the current file", cmd_args = ext_glob },
	{ name = 'Exclude tests', cmd_args = test_globs },
	{ name = 'Lua files', cmd_args = rg_types('lua') },
	{ name = 'C/C++ files', cmd_args = rg_types('c', 'cpp') },
	{ name = 'Python files', cmd_args = rg_types('py') },
	{ name = 'Rust files', cmd_args = rg_types('rust') },
	{ name = 'JS/TS files', cmd_args = rg_types('js', 'ts') },
	{ name = 'Go files', cmd_args = rg_types('go') },
	{ name = 'Build files', desc = 'CMake, Make', cmd_args = { '--type', 'cmake', '--type', 'make' } },
	{ name = 'Config files', desc = 'JSON, YAML, TOML', cmd_args = rg_types('json', 'yaml', 'toml') },
	{ name = 'Docs', desc = 'Markdown', cmd_args = rg_types('md') },
}

-- ast-grep presets: general ones first, then language constructs. The latter
-- are filtered by the buffer's filetype so the list stays short.
local function rule(name, desc, fn)
	return { name = name, desc = desc, opts = { rule = fn, lang = true } }
end
local function pattern(ft, name, prompt, lang)
	return { name = name, desc = prompt, ft = ft, prompt = prompt, opts = { lang = lang or true } }
end

M.defaults.ast_grep = function()
	local rules = require('editable-telescope.ast_grep').rules
	local c_like = { 'c', 'cpp' }
	local js_like = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }
	local ts_like = { 'typescript', 'typescriptreact' }
	return {
		rule('Text in comments', 'prompt is a regex; empty lists all comments', rules.comments),
		rule('Text in strings', 'prompt is a regex; empty lists all strings', rules.strings),
		rule('Function definitions', 'prompt filters names (regex)', rules.functions),
		rule('Type definitions', 'classes, structs, enums...; prompt filters names', rules.types),
		rule('Function calls', 'prompt filters the called name (regex)', rules.calls),
		{ name = 'Relaxed match', desc = 'ignore comments', cmd_args = { '--strictness', 'relaxed' } },
		{ name = 'Structure only', desc = 'ignore names and text', cmd_args = { '--strictness', 'signature' } },
		{ name = 'Exact match', desc = 'every node, including punctuation', cmd_args = { '--strictness', 'cst' } },
		{ name = 'All languages', desc = 'language inferred per file', opts = { lang = false } },
		{ name = 'All files', desc = 'hidden and ignored', opts = { hidden = true, no_ignore = true } },
		{ name = 'Exclude tests', opts = { globs = { '!**/test/**', '!**/tests/**', '!*_test.*', '!*.test.*', '!*.spec.*', '!test_*' } } },

		pattern('lua', 'Lua: require', 'require($MOD)', 'lua'),
		pattern('lua', 'Lua: keymaps', 'vim.keymap.set($MODE, $LHS, $$$)', 'lua'),
		pattern('lua', 'Lua: autocommands', 'vim.api.nvim_create_autocmd($EVENT, $$$)', 'lua'),
		pattern('lua', 'Lua: pcall', 'pcall($FN, $$$)', 'lua'),
		pattern('lua', 'Lua: vim.loop (deprecated)', 'vim.loop.$FN($$$)', 'lua'),

		pattern('python', 'Python: imports from', 'from $MOD import $$$', 'python'),
		pattern('python', 'Python: print', 'print($$$)', 'python'),
		pattern('python', 'Python: == None', '$X == None', 'python'),
		pattern('python', 'Python: attribute assignment', 'self.$ATTR = $VALUE', 'python'),

		pattern('rust', 'Rust: unwrap', '$E.unwrap()', 'rust'),
		pattern('rust', 'Rust: expect', '$E.expect($MSG)', 'rust'),
		pattern('rust', 'Rust: unsafe blocks', 'unsafe { $$$ }', 'rust'),
		pattern('rust', 'Rust: todo!', 'todo!($$$)', 'rust'),
		pattern('rust', 'Rust: trait impls', 'impl $TRAIT for $TYPE { $$$ }', 'rust'),

		pattern(c_like, 'C/C++: includes', '#include $HEADER'),
		-- A bare call parses as a type in C, so calls use a rule or a statement.
		{
			name = 'C/C++: allocations', desc = 'malloc, calloc, realloc, free', ft = c_like,
			prompt = '^(malloc|calloc|realloc|free)$', opts = { rule = rules.calls, lang = true },
		},
		pattern(c_like, 'C/C++: printf', 'printf($$$);'),
		pattern('cpp', 'C++: new', 'new $TYPE($$$)', 'cpp'),
		pattern('cpp', 'C++: make_shared', 'std::make_shared<$TYPE>($$$)', 'cpp'),

		pattern('go', 'Go: error checks', 'if err != nil { $$$ }', 'go'),
		pattern('go', 'Go: goroutines', 'go $FN($$$)', 'go'),
		pattern('go', 'Go: defer', 'defer $FN($$$)', 'go'),

		pattern(js_like, 'JS/TS: console.log', 'console.log($$$)'),
		pattern(js_like, 'JS/TS: await', 'await $E'),
		pattern(js_like, 'JS/TS: imports', "import $$$ from '$MOD'"),
		pattern(ts_like, 'TS: as any', '$E as any'),
	}
end

-- Turn a preset's `cmd_args` into a list (or nil when it has none).
function M.cmd_args(preset, ctx, parse)
	local value = preset.cmd_args
	if type(value) == 'function' then value = value(ctx) end
	if type(value) == 'string' then value = (parse or require('editable-telescope.args').split)(value) end
	return value
end

local function listed(preset, ctx)
	if not preset.ft or not ctx.filetype or ctx.filetype == '' then return true end
	local fts = type(preset.ft) == 'table' and preset.ft or { preset.ft }
	return vim.tbl_contains(fts, ctx.filetype)
end

-- Build the preset list for picker `name`: the defaults (unless disabled by
-- `config.default_presets`), then `config.presets[name]`, then `extra`.
-- A later preset with the same name replaces an earlier one in place, so
-- `{ name = 'All files', disabled = true }` hides a default.
function M.resolve(name, config, extra, ctx)
	local list = {}
	local use_defaults = config.default_presets
	if type(use_defaults) == 'table' then use_defaults = use_defaults[name] ~= false end
	local sources = {
		use_defaults ~= false and M.defaults[name] or nil,
		(config.presets or {})[name],
		extra,
	}
	local index = {}
	for i = 1, 3 do
		local source = sources[i]
		if type(source) == 'function' then source = source(ctx) end
		for _, preset in ipairs(source or {}) do
			if index[preset.name] then
				list[index[preset.name]] = preset
			else
				list[#list + 1] = preset
				index[preset.name] = #list
			end
		end
	end
	return vim.tbl_filter(function(preset)
		return not preset.disabled and listed(preset, ctx)
	end, list)
end

-- Open the selection window. `on_choice(preset)` gets the chosen preset,
-- `M.reset` for the "Default" entry, or nil when the window is cancelled.
M.reset = { name = 'Default', desc = 'no preset' }

function M.pick(list, active, picker_config, on_choice)
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local conf = require('telescope.config').values
	local finders = require('telescope.finders')
	local pickers = require('telescope.pickers')
	local themes = require('telescope.themes')

	picker_config = vim.deepcopy(picker_config or {})
	local theme = picker_config.theme
	if theme == nil then theme = 'dropdown' end
	picker_config.theme = nil
	local opts = vim.tbl_extend('force', { prompt_title = 'Presets', previewer = false, winblend = 10 }, picker_config)
	if theme then opts = themes['get_' .. theme](opts) end

	local entries = { M.reset }
	vim.list_extend(entries, list)
	local done = false
	local function finish(prompt_bufnr, choice)
		if done then return end
		done = true
		actions.close(prompt_bufnr)
		vim.schedule(function() on_choice(choice) end)
	end

	pickers.new(opts, {
		finder = finders.new_table({
			results = entries,
			entry_maker = function(preset)
				local is_active = preset.name == active or (preset == M.reset and not active)
				local text = (is_active and '● ' or '  ') .. preset.name
				if preset.desc then text = text .. '  — ' .. preset.desc end
				return { value = preset, display = text, ordinal = preset.name .. ' ' .. (preset.desc or '') }
			end,
		}),
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				finish(prompt_bufnr, entry and entry.value)
			end)
			local function cancel() finish(prompt_bufnr, nil) end
			map('i', '<C-c>', cancel)
			map('n', '<Esc>', cancel)
			map('n', 'q', cancel)
			return true
		end,
	}):find()
end

return M
