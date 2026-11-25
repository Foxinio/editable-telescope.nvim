-- Helpers for the `ast_grep` picker: building the `ast-grep run` command and
-- turning its `--json=stream` output into Telescope entries.
local make_entry = require('telescope.make_entry')

local M = {}

-- `sg` is `newgrp` on many Linux systems, so the long name is the safe default.
M.default_command = 'ast-grep'

-- rg's `--no-ignore` maps to several ast-grep `--no-ignore` values.
local NO_IGNORE = { 'dot', 'exclude', 'global', 'parent', 'vcs' }

local function has_lang(list)
	for _, arg in ipairs(list) do
		if arg == '-l' or arg == '--lang' or arg:match('^%-%-lang=') or arg:match('^%-l.') then
			return true
		end
	end
	return false
end

-- Neovim filetypes whose ast-grep language has another name.
M.filetype_langs = {
	javascriptreact = 'javascript',
	sh = 'bash',
	typescriptreact = 'tsx',
	zsh = 'bash',
}

-- Resolve `opts.lang`: a string is used as is, `true` takes the filetype of
-- `opts.bufnr` (or the current buffer), or `opts.fallback_lang` when it has
-- none. Returns nil when no language applies.
function M.resolve_lang(opts)
	local lang = opts.lang
	if lang == true then
		local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
		lang = vim.bo[bufnr].filetype
		lang = M.filetype_langs[lang] or lang
		if lang == '' then lang = opts.fallback_lang end
	end
	if type(lang) ~= 'string' or lang == '' then return nil end
	return lang
end

-- Split a language flag out of `list`: returns the language (or nil) and the
-- remaining arguments. `ast-grep scan` takes the language from the rule.
function M.extract_lang(list)
	local lang, rest, i = nil, {}, 1
	while i <= #list do
		local arg = list[i]
		if (arg == '-l' or arg == '--lang') and list[i + 1] then
			lang, i = list[i + 1], i + 1
		elseif arg:match('^%-%-lang=') then
			lang = arg:sub(8)
		elseif arg:match('^%-l.') then
			lang = arg:sub(3)
		else
			rest[#rest + 1] = arg
		end
		i = i + 1
	end
	return lang, rest
end

-- The command without the pattern: `<command> run --json=stream [flags]`, or
-- `<command> scan ...` when `opts.rule` is set. `opts.lang` must already be
-- resolved to a string (see `resolve_lang`). A language in the edited
-- arguments wins over `opts.lang`. Returns the command and, in rule mode, the
-- language the rule must be written for.
function M.build(opts, edited)
	edited = edited or {}
	local additional = opts.additional_args
	if type(additional) == 'function' then
		additional = additional(opts)
	elseif type(additional) ~= 'table' then
		additional = {}
	end

	local lang = type(opts.lang) == 'string' and opts.lang or nil
	local command = { opts.command or M.default_command, opts.rule and 'scan' or 'run', '--json=stream' }
	if opts.hidden then
		vim.list_extend(command, { '--no-ignore', 'hidden' })
	end
	if opts.no_ignore then
		for _, value in ipairs(NO_IGNORE) do
			vim.list_extend(command, { '--no-ignore', value })
		end
	end
	if opts.rule then
		local edited_lang
		edited_lang, edited = M.extract_lang(edited)
		lang = edited_lang or lang
	elseif lang and not has_lang(edited) and not has_lang(additional) then
		vim.list_extend(command, { '--lang', lang })
	end
	for _, glob in ipairs(opts.globs or {}) do
		vim.list_extend(command, { '--globs', glob })
	end
	return vim.list_extend(vim.list_extend(command, additional), edited), opts.rule and lang or nil
end

-- Append the pattern and paths. `--pattern=` keeps patterns starting with `-`
-- from being read as flags.
function M.with_pattern(command, pattern, search_dirs)
	local full = vim.list_extend(vim.deepcopy(command), { '--pattern=' .. pattern })
	if search_dirs and #search_dirs > 0 then
		table.insert(full, '--')
		vim.list_extend(full, search_dirs)
	end
	return full
end

-- Append an inline rule (an ast-grep rule object as a Lua table) for `lang`.
function M.with_rule(command, rule, lang, search_dirs)
	local full = vim.list_extend(vim.deepcopy(command), {
		'--inline-rules',
		vim.json.encode({ id = 'editable-telescope', language = lang, rule = rule }),
	})
	if search_dirs and #search_dirs > 0 then
		table.insert(full, '--')
		vim.list_extend(full, search_dirs)
	end
	return full
end

-- Node kinds per ast-grep language, used by the rules below. A definition kind
-- is a string (its name is in the `name` field) or `{ kind, field = ..., has = ... }`.
local js = {
	comments = { 'comment' },
	strings = { 'string', 'template_string' },
	functions = {
		'function_declaration', 'generator_function_declaration', 'method_definition',
		{ 'variable_declarator', has = { field = 'value', kind = 'arrow_function' } },
	},
	types = { 'class_declaration' },
	calls = { { 'call_expression', field = 'function' }, { 'new_expression', field = 'constructor' } },
	imports = { 'import_statement' },
	loops = { 'for_statement', 'for_in_statement', 'while_statement', 'do_statement' },
	errors = { 'try_statement' },
}
local ts = vim.tbl_extend('force', js, {
	types = { 'class_declaration', 'abstract_class_declaration', 'interface_declaration', 'type_alias_declaration', 'enum_declaration' },
})
local c = {
	comments = { 'comment' },
	strings = { 'string_literal' },
	functions = { { 'function_definition', field = 'declarator' } },
	types = {
		{ 'struct_specifier', has = { field = 'body', kind = 'field_declaration_list' } },
		{ 'enum_specifier', has = { field = 'body', kind = 'enumerator_list' } },
		{ 'union_specifier', has = { field = 'body', kind = 'field_declaration_list' } },
		{ 'type_definition', field = 'declarator' },
	},
	calls = { { 'call_expression', field = 'function' } },
	imports = { 'preproc_include' },
	loops = { 'for_statement', 'while_statement', 'do_statement' },
}
local cpp = vim.tbl_extend('force', c, {
	strings = { 'string_literal', 'raw_string_literal' },
	loops = { 'for_statement', 'for_range_loop', 'while_statement', 'do_statement' },
	errors = { 'try_statement' },
	types = vim.list_extend({
		{ 'class_specifier', has = { field = 'body', kind = 'field_declaration_list' } },
		{ 'alias_declaration' },
	}, vim.deepcopy(c.types)),
})
M.languages = {
	bash = {
		comments = { 'comment' },
		strings = { 'string', 'raw_string' },
		functions = { 'function_definition' },
		calls = { 'command' },
		loops = { 'for_statement', 'c_style_for_statement', 'while_statement' },
	},
	c = c,
	cpp = cpp,
	go = {
		comments = { 'comment' },
		strings = { 'interpreted_string_literal', 'raw_string_literal' },
		functions = { 'function_declaration', 'method_declaration' },
		types = { 'type_spec' },
		calls = { { 'call_expression', field = 'function' } },
		imports = { 'import_spec' },
		loops = { 'for_statement' },
	},
	java = {
		comments = { 'line_comment', 'block_comment' },
		strings = { 'string_literal' },
		functions = { 'method_declaration', 'constructor_declaration' },
		types = { 'class_declaration', 'interface_declaration', 'enum_declaration', 'record_declaration' },
		calls = { 'method_invocation', { 'object_creation_expression', field = 'type' } },
		imports = { 'import_declaration' },
		loops = { 'for_statement', 'enhanced_for_statement', 'while_statement', 'do_statement' },
		errors = { 'try_statement', 'try_with_resources_statement' },
	},
	javascript = js,
	lua = {
		comments = { 'comment' },
		strings = { 'string' },
		functions = { 'function_declaration' },
		calls = { 'function_call' },
		loops = { 'for_statement', 'while_statement', 'repeat_statement' },
	},
	python = {
		comments = { 'comment' },
		strings = { 'string' },
		functions = { 'function_definition' },
		types = { 'class_definition' },
		calls = { { 'call', field = 'function' } },
		imports = { 'import_statement', 'import_from_statement' },
		loops = { 'for_statement', 'while_statement' },
		errors = { 'try_statement' },
	},
	rust = {
		comments = { 'line_comment', 'block_comment' },
		strings = { 'string_literal', 'raw_string_literal' },
		functions = { 'function_item', 'function_signature_item' },
		types = { 'struct_item', 'enum_item', 'union_item', 'trait_item', 'type_item' },
		calls = { { 'call_expression', field = 'function' }, { 'macro_invocation', field = 'macro' } },
		imports = { 'use_declaration', 'extern_crate_declaration' },
		loops = { 'for_expression', 'while_expression', 'loop_expression' },
	},
	tsx = ts,
	typescript = ts,
}

-- Rules for the `rule` option: `function(prompt, lang)` returning an ast-grep
-- rule, or nil when the language has no such nodes. The prompt is a regex
-- matched against the node text (comments, strings) or its name (functions,
-- types, calls: the called expression, e.g. `vim.keymap.set` or `obj.method`).
M.rules = {}

local function text_rule(group)
	return function(prompt, lang)
		local kinds = (M.languages[lang] or {})[group]
		if not kinds then return nil end
		local any = {}
		for _, kind in ipairs(kinds) do
			any[#any + 1] = { kind = kind, regex = prompt ~= '' and prompt or nil }
		end
		return { any = any }
	end
end

local function definition_rule(group)
	return function(prompt, lang)
		local kinds = (M.languages[lang] or {})[group]
		if not kinds then return nil end
		local any = {}
		for _, item in ipairs(kinds) do
			if type(item) == 'string' then item = { item } end
			local all = { { kind = item[1] } }
			if item.has then all[#all + 1] = { has = item.has } end
			if prompt ~= '' then
				all[#all + 1] = { has = { field = item.field or 'name', regex = prompt } }
			end
			any[#any + 1] = { all = all }
		end
		return { any = any }
	end
end

M.rules.comments = text_rule('comments')
M.rules.strings = text_rule('strings')
M.rules.functions = definition_rule('functions')
M.rules.types = definition_rule('types')
M.rules.calls = definition_rule('calls')
M.rules.imports = text_rule('imports')
M.rules.loops = text_rule('loops')
M.rules.errors = text_rule('errors')

-- A rule for fixed node kinds in any language; the prompt filters their text.
function M.rules.kind(...)
	local kinds = { ... }
	return function(prompt)
		local any = {}
		for _, kind in ipairs(kinds) do
			any[#any + 1] = { kind = kind, regex = prompt ~= '' and prompt or nil }
		end
		return #any == 1 and any[1] or { any = any }
	end
end

-- ast-grep reports character columns; Telescope wants byte columns.
local function byte_col(line, col)
	local ok, idx = pcall(vim.str_byteindex, line, 'utf-32', col, false)
	return ok and idx or col
end

-- Decode one `--json=stream` line into position fields with 1-based lines and
-- byte columns (`colend` is exclusive, as the vimgrep previewer expects).
function M.parse(line)
	local ok, match = pcall(vim.json.decode, line)
	if not ok or type(match) ~= 'table' or not match.file or not match.range then return nil end
	local lines = vim.split(match.lines or match.text or '', '\n', { plain = true })
	local first, last = lines[1] or '', lines[#lines] or ''
	local start, finish = match.range.start, match.range['end']
	return {
		match = match,
		filename = match.file,
		lnum = start.line + 1,
		col = byte_col(first, start.column) + 1,
		lnend = finish.line + 1,
		colend = byte_col(last, finish.column) + 1,
		text = first,
	}
end

-- Entries look and behave like `live_grep` ones (path display, quickfix,
-- preview), plus `lnend`/`colend` so the previewer highlights the whole match
-- and `match` with the decoded ast-grep result (meta variables, language...).
function M.entry_maker(opts)
	local vimgrep = make_entry.gen_from_vimgrep(opts)
	return function(line)
		local parsed = M.parse(line)
		if not parsed then return nil end
		local entry = vimgrep(('%s:%d:%d:%s'):format(parsed.filename, parsed.lnum, parsed.col, parsed.text))
		if not entry then return nil end
		entry.filename = parsed.filename
		entry.lnum, entry.col = parsed.lnum, parsed.col
		entry.lnend, entry.colend = parsed.lnend, parsed.colend
		entry.text = parsed.text
		entry.match = parsed.match
		return entry
	end
end

return M
