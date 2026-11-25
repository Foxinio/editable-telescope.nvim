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

-- Every built-in preset has a `group`; `default_presets` can enable or disable
-- built-in presets group by group (see `M.resolve`).
local function grouped(group, list)
	for _, preset in ipairs(list) do preset.group = group end
	return list
end

local function concat(lists)
	local out = {}
	for _, list in ipairs(lists) do vim.list_extend(out, list) end
	return out
end

M.defaults = {}

M.defaults.find_files = grouped('scope', {
	{ name = 'All files', desc = 'hidden and ignored', opts = { hidden = true, no_ignore = true } },
	{ name = 'Hidden files', desc = 'dotfiles, still respecting .gitignore', opts = { hidden = true } },
	{ name = 'Ignored files', desc = 'skip .gitignore, no dotfiles', opts = { no_ignore = true } },
})

M.defaults.live_grep = concat({
	grouped('modes', {
		{ name = 'Literal', desc = 'no regex', cmd_args = { '--fixed-strings' } },
		{ name = 'Whole word', cmd_args = { '--word-regexp' } },
		{ name = 'Case sensitive', cmd_args = { '--case-sensitive' } },
		{ name = 'Multiline', desc = '. and \\n match across lines', cmd_args = { '--multiline', '--multiline-dotall' } },
	}),
	grouped('scope', {
		{ name = 'All files', desc = 'hidden and ignored', cmd_args = { '--hidden', '--no-ignore' } },
		{ name = 'Same extension', desc = 'as the current file', cmd_args = ext_glob },
		{ name = 'Exclude tests', cmd_args = test_globs },
	}),
	grouped('types', {
		{ name = 'Lua files', cmd_args = rg_types('lua') },
		{ name = 'C/C++ files', cmd_args = rg_types('c', 'cpp') },
		{ name = 'Python files', cmd_args = rg_types('py') },
		{ name = 'Rust files', cmd_args = rg_types('rust') },
		{ name = 'JS/TS files', cmd_args = rg_types('js', 'ts') },
		{ name = 'Go files', cmd_args = rg_types('go') },
		{ name = 'Java files', cmd_args = rg_types('java') },
		{ name = 'Shell files', cmd_args = rg_types('sh') },
		{ name = 'Build files', desc = 'CMake, Make', cmd_args = rg_types('cmake', 'make') },
		{ name = 'Config files', desc = 'JSON, YAML, TOML', cmd_args = rg_types('json', 'yaml', 'toml') },
		{ name = 'Docs', desc = 'Markdown', cmd_args = rg_types('md') },
	}),
})

-- ast-grep language groups. Each entry is `{ name, prompt, rule = ... }`:
-- without a rule the prompt is an ast-grep pattern, with one it is the regex
-- the rule filters by. Presets are listed only for the group's filetypes and
-- search in the buffer's language, or the group's `lang` without a filetype.
-- (A bare call parses as a type in C, so C calls use rules or statements.)
local function language_groups()
	local rules = require('editable-telescope.ast_grep').rules
	local calls, kind = rules.calls, rules.kind
	return {
		{
			group = 'lua', label = 'Lua', lang = 'lua', ft = { 'lua' },
			{ 'require', 'require($MOD)' },
			{ 'setup calls', 'require($MOD).setup($$$)' },
			{ 'keymaps', 'vim.keymap.set($MODE, $LHS, $$$)' },
			{ 'autocommands', 'vim.api.nvim_create_autocmd($EVENT, $$$)' },
			{ 'user commands', 'vim.api.nvim_create_user_command($NAME, $$$)' },
			{ 'vim.cmd', 'vim.cmd($$$)' },
			{ 'notifications', 'vim.notify($$$)' },
			{ 'scheduled callbacks', '^vim\\.(schedule|schedule_wrap|defer_fn)$', rule = calls },
			{ 'pcall', '^x?pcall$', rule = calls },
			{ 'pairs loops', 'for $K, $V in pairs($T) do $$$ end' },
			{ 'ipairs loops', 'for $I, $V in ipairs($T) do $$$ end' },
			{ 'methods', 'function $T:$METHOD($$$) $$$ end' },
			{ 'module tables', 'local $M = {}' },
			{ 'vim.loop (deprecated)', 'vim.loop.$FN($$$)' },
			{ 'anonymous functions', '', rule = kind('function_definition') },
		},
		{
			group = 'python', label = 'Python', lang = 'python', ft = { 'python' },
			{ 'import', 'import $MOD' },
			{ 'from import', 'from $MOD import $$$' },
			{ 'print', 'print($$$)' },
			{ '== None', '$X == None' },
			{ '!= None', '$X != None' },
			{ 'isinstance', 'isinstance($X, $TYPE)' },
			{ 'self attributes', 'self.$ATTR = $VALUE' },
			{ 'list comprehensions', '[$E for $X in $ITER]' },
			{ 'lambdas', 'lambda $$$: $E' },
			{ 'open', 'open($$$)' },
			{ 'raise', 'raise $E' },
			{ 'assert', 'assert $$$' },
			{ 'eval/exec', '^(eval|exec)$', rule = calls },
			{ 'subprocess', '^subprocess\\.', rule = calls },
			{ 'decorators', '', rule = kind('decorator') },
			{ 'with blocks', '', rule = kind('with_statement') },
			{ 'bare except', '^except\\s*:', rule = kind('except_clause') },
		},
		{
			group = 'rust', label = 'Rust', lang = 'rust', ft = { 'rust' },
			{ 'unwrap', '$E.unwrap()' },
			{ 'expect', '$E.expect($MSG)' },
			{ '? operator', '$E?' },
			{ 'panics', '^(panic|todo|unimplemented|unreachable)$', rule = calls },
			{ 'debug output', '^(println|eprintln|print|eprint|dbg)$', rule = calls },
			{ 'unsafe blocks', 'unsafe { $$$ }' },
			{ 'clone', '$E.clone()' },
			{ 'trait impls', 'impl $TRAIT for $TYPE { $$$ }' },
			{ 'all impls', '', rule = kind('impl_item') },
			{ 'match', 'match $E { $$$ }' },
			{ 'Box::new', 'Box::new($E)' },
			{ 'Rc/Arc', '^(Rc|Arc)::new$', rule = calls },
			{ '.await', '$E.await' },
			{ 'casts', '$E as $TYPE' },
			{ 'derives', 'derive', rule = kind('attribute_item') },
			{ 'closures', '', rule = kind('closure_expression') },
		},
		{
			group = 'c', label = 'C/C++', lang = 'c', ft = { 'c', 'cpp' },
			{ 'includes', '#include $HEADER' },
			{ 'macros', '', rule = kind('preproc_def', 'preproc_function_def') },
			{ 'allocations', '^(malloc|calloc|realloc|free)$', rule = calls },
			{ 'unsafe string functions', '^(strcpy|strcat|sprintf|vsprintf|gets)$', rule = calls },
			{ 'printf family', '^(printf|fprintf|sprintf|snprintf|puts)$', rule = calls },
			{ 'NULL checks', 'NULL', rule = kind('binary_expression') },
			{ 'goto', 'goto $LABEL;' },
			{ 'sizeof', '', rule = kind('sizeof_expression') },
			{ 'switch', '', rule = kind('switch_statement') },
			{ 'static functions', '^static', rule = kind('function_definition') },
			{ 'casts', '', rule = kind('cast_expression') },
		},
		{
			group = 'cpp', label = 'C++', lang = 'cpp', ft = { 'cpp' },
			{ 'new', 'new $TYPE($$$)' },
			{ 'delete', '', rule = kind('delete_expression') },
			{ 'smart pointers', '^std::make_(shared|unique)', rule = calls },
			{ 'std::move', '^std::(move|forward)$', rule = calls },
			{ 'C++ casts', '^(static|dynamic|reinterpret|const)_cast', rule = calls },
			{ 'lambdas', '', rule = kind('lambda_expression') },
			{ 'range for', '', rule = kind('for_range_loop') },
			{ 'auto declarations', 'auto $X = $E;' },
			{ 'using namespace', 'using namespace $NS;' },
			{ 'templates', '', rule = kind('template_declaration') },
			{ 'std::cout', 'std::cout << $$$' },
			{ 'classes', '', rule = kind('class_specifier') },
		},
		{
			group = 'go', label = 'Go', lang = 'go', ft = { 'go' },
			{ 'error checks', 'if err != nil { $$$ }' },
			{ 'error assignments', '$V, err := $CALL' },
			{ 'goroutines', 'go $FN($$$)' },
			{ 'defer', 'defer $FN($$$)' },
			{ 'panic', 'panic($$$)' },
			{ 'fmt output', '^fmt\\.(Print|Fprint|Sprint)', rule = calls },
			{ 'make', 'make($$$)' },
			{ 'channel sends', '$CH <- $V' },
			{ 'channel receives', '<-$CH' },
			{ 'select', '', rule = kind('select_statement') },
			{ 'type assertions', '$X.($TYPE)' },
			{ 'context roots', '^context\\.(TODO|Background)$', rule = calls },
			{ 'closures', '', rule = kind('func_literal') },
		},
		{
			group = 'javascript', label = 'JS/TS', lang = 'javascript',
			ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
			{ 'console', '^console\\.', rule = calls },
			{ 'await', 'await $E' },
			{ 'import from', "import $$$ from '$MOD'" },
			{ 'require', 'require($MOD)' },
			{ 'exports', '', rule = kind('export_statement') },
			{ 'arrow functions', '', rule = kind('arrow_function') },
			{ 'promise then', '$P.then($$$)' },
			{ 'fetch', 'fetch($$$)' },
			{ 'JSON', '^JSON\\.(parse|stringify)$', rule = calls },
			{ 'timers', '^(setTimeout|setInterval)$', rule = calls },
			{ 'event listeners', '$TARGET.addEventListener($$$)' },
			{ 'loose equality', '$A == $B' },
			{ 'React hooks', '^use[A-Z]', rule = calls },
			{ 'template literals', '', rule = kind('template_string') },
			{ 'debugger', '', rule = kind('debugger_statement') },
		},
		{
			group = 'typescript', label = 'TS', lang = 'typescript', ft = { 'typescript', 'typescriptreact' },
			{ 'as any', '$E as any' },
			{ 'any annotations', 'any', rule = kind('type_annotation') },
			{ 'non-null assertions', '$E!' },
			{ 'ts-ignore', '@ts-(ignore|expect-error|nocheck)', rule = kind('comment') },
			{ 'interfaces', '', rule = kind('interface_declaration') },
			{ 'type aliases', '', rule = kind('type_alias_declaration') },
			{ 'enums', '', rule = kind('enum_declaration') },
			{ 'satisfies', '$E satisfies $TYPE' },
			{ 'decorators', '', rule = kind('decorator') },
		},
		{
			group = 'java', label = 'Java', lang = 'java', ft = { 'java' },
			{ 'System.out', 'System.out.$METHOD($$$)' },
			{ 'printStackTrace', '$E.printStackTrace()' },
			{ 'new', 'new $TYPE($$$)' },
			{ 'throw', 'throw $E;' },
			{ 'catch blocks', '', rule = kind('catch_clause') },
			{ 'equals', '$A.equals($B)' },
			{ 'annotations', '', rule = kind('marker_annotation', 'annotation') },
			{ 'Optional', '^Optional\\.', rule = kind('method_invocation') },
			{ 'streams', '$E.stream()' },
			{ 'lambdas', '', rule = kind('lambda_expression') },
			{ 'synchronized', '', rule = kind('synchronized_statement') },
		},
		{
			group = 'bash', label = 'Bash', lang = 'bash', ft = { 'sh', 'bash', 'zsh' },
			{ 'eval', '^eval$', rule = calls },
			{ 'rm', '^rm$', rule = calls },
			{ 'sudo', '^sudo$', rule = calls },
			{ 'downloads', '^(curl|wget)$', rule = calls },
			{ 'source', '^(source|\\.)$', rule = calls },
			{ 'echo/printf', '^(echo|printf)$', rule = calls },
			{ 'command substitution', '', rule = kind('command_substitution') },
			{ 'tests', '', rule = kind('test_command') },
			{ 'pipelines', '', rule = kind('pipeline') },
			{ 'heredocs', '', rule = kind('heredoc_redirect') },
			{ 'exports', '^export', rule = kind('declaration_command') },
			{ 'assignments', '', rule = kind('variable_assignment') },
		},
	}
end

-- Names of the ast-grep language groups, in order.
function M.language_groups()
	return vim.tbl_map(function(g) return g.group end, language_groups())
end

M.defaults.ast_grep = function()
	local rules = require('editable-telescope.ast_grep').rules
	local function search(name, desc, fn, prompt)
		return { name = name, desc = desc, prompt = prompt, opts = { rule = fn, lang = true } }
	end
	local list = concat({
		grouped('general', {
			search('Text in comments', 'prompt is a regex; empty lists all', rules.comments),
			search('TODO comments', 'TODO, FIXME, HACK, XXX', rules.comments, 'TODO|FIXME|HACK|XXX'),
			search('Text in strings', 'prompt is a regex; empty lists all', rules.strings),
			search('Function definitions', 'prompt filters names', rules.functions),
			search('Type definitions', 'classes, structs, enums...; prompt filters names', rules.types),
			search('Function calls', 'prompt filters the called name', rules.calls),
			search('Imports', 'prompt filters the import text', rules.imports),
			search('Loops', 'prompt filters the loop text', rules.loops),
			search('Error handling', 'try blocks; prompt filters their text', rules.errors),
		}),
		grouped('match', {
			{ name = 'Relaxed match', desc = 'ignore comments', cmd_args = { '--strictness', 'relaxed' } },
			{ name = 'Structure only', desc = 'ignore names and text', cmd_args = { '--strictness', 'signature' } },
			{ name = 'Exact match', desc = 'every node, including punctuation', cmd_args = { '--strictness', 'cst' } },
			{ name = 'All languages', desc = 'language inferred per file', opts = { lang = false } },
			{ name = 'All files', desc = 'hidden and ignored', opts = { hidden = true, no_ignore = true } },
			{ name = 'Exclude tests', opts = { globs = { '!**/test/**', '!**/tests/**', '!*_test.*', '!*.test.*', '!*.spec.*', '!test_*' } } },
		}),
	})
	for _, g in ipairs(language_groups()) do
		for _, item in ipairs(g) do
			local name, prompt = item[1], item[2]
			list[#list + 1] = {
				name = g.label .. ': ' .. name,
				desc = item.rule and (prompt ~= '' and 'regex ' .. prompt or nil) or prompt,
				group = g.group,
				ft = g.ft,
				prompt = prompt,
				opts = { lang = true, fallback_lang = g.lang, rule = item.rule },
			}
		end
	end
	return list
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

-- Whether built-in presets of `group` are enabled by `setting`, the value of
-- `default_presets[picker]`: true/nil (all groups), false (none), a list of
-- the groups to keep, or a map with `false` for the groups to drop.
local function group_enabled(setting, group)
	if setting == nil or setting == true then return true end
	if setting == false then return false end
	if vim.islist(setting) then return vim.tbl_contains(setting, group) end
	return setting[group] ~= false
end

-- Build the preset list for picker `name`: the defaults of the groups enabled
-- by `config.default_presets`, then `config.presets[name]`, then `extra`.
-- A later preset with the same name replaces an earlier one in place, so
-- `{ name = 'All files', disabled = true }` hides a default.
function M.resolve(name, config, extra, ctx)
	local list = {}
	local setting = config.default_presets
	if type(setting) == 'table' then setting = setting[name] end
	local defaults = M.defaults[name]
	if type(defaults) == 'function' then defaults = defaults(ctx) end
	defaults = vim.tbl_filter(function(preset)
		return group_enabled(setting, preset.group)
	end, defaults or {})
	local sources = { defaults, (config.presets or {})[name], extra }
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
				return { value = preset, display = text, ordinal = preset.name .. ' ' .. (preset.desc or '') .. ' ' .. (preset.group or '') }
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
