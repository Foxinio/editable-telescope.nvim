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

-- Resolve `opts.lang`: a string is used as is, `true` takes the filetype of
-- `opts.bufnr` (or the current buffer). Returns nil when no language applies.
function M.resolve_lang(opts)
	local lang = opts.lang
	if lang == true then
		local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
		lang = vim.bo[bufnr].filetype
	end
	if type(lang) ~= 'string' or lang == '' then return nil end
	return lang
end

-- The command without the pattern: `<command> run --json=stream [flags]`.
-- `opts.lang` must already be resolved to a string (see `resolve_lang`).
-- A language in the edited arguments wins over `opts.lang`.
function M.build(opts, edited)
	edited = edited or {}
	local additional = opts.additional_args
	if type(additional) == 'function' then
		additional = additional(opts)
	elseif type(additional) ~= 'table' then
		additional = {}
	end

	local command = { opts.command or M.default_command, 'run', '--json=stream' }
	if opts.hidden then
		vim.list_extend(command, { '--no-ignore', 'hidden' })
	end
	if opts.no_ignore then
		for _, value in ipairs(NO_IGNORE) do
			vim.list_extend(command, { '--no-ignore', value })
		end
	end
	if type(opts.lang) == 'string' and not has_lang(edited) and not has_lang(additional) then
		vim.list_extend(command, { '--lang', opts.lang })
	end
	for _, glob in ipairs(opts.globs or {}) do
		vim.list_extend(command, { '--globs', glob })
	end
	return vim.list_extend(vim.list_extend(command, additional), edited)
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
