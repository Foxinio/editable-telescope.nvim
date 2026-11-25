-- Every built-in ast-grep preset must find something in the fixture of its
-- group's language, and every general search in every fixture language.
local ast_grep = require('editable-telescope.ast_grep')
local presets = require('editable-telescope.presets')

if vim.fn.executable(ast_grep.default_command) == 0 then
	print('ast-grep preset tests skipped: ast-grep not installed')
	return
end

local dir = vim.fn.getcwd() .. '/tests/fixtures/ast_grep/'
local fixtures = {
	bash = 'sample.sh', c = 'sample.c', cpp = 'sample.cpp', go = 'sample.go', java = 'Sample.java',
	javascript = 'sample.js', lua = 'sample.lua', python = 'sample.py', rust = 'sample.rs', typescript = 'sample.ts',
}

local function run(preset, lang)
	local opts = vim.tbl_extend('force', preset.opts or {}, { lang = lang })
	local command, rule_lang = ast_grep.build(opts, {})
	local paths = { dir .. fixtures[lang] }
	if opts.rule then
		local rule = opts.rule(preset.prompt or '', rule_lang)
		assert(rule, preset.name .. ': no rule for ' .. lang)
		command = ast_grep.with_rule(command, rule, rule_lang, paths)
	else
		command = ast_grep.with_pattern(command, preset.prompt, paths)
	end
	local result = vim.system(command, { text = true }):wait()
	local count = 0
	for line in result.stdout:gmatch('[^\n]+') do
		if ast_grep.parse(line) then count = count + 1 end
	end
	return count, result.stderr
end

local failures, checked = {}, 0
local all = presets.resolve('ast_grep', {}, nil, { filetype = '' })
local groups = {}
for _, preset in ipairs(all) do
	groups[preset.group] = groups[preset.group] or {}
	table.insert(groups[preset.group], preset)
end

-- Language groups: their presets in the group's own language.
for _, group in ipairs(presets.language_groups()) do
	assert(groups[group] and #groups[group] > 0, 'empty group ' .. group)
	for _, preset in ipairs(groups[group]) do
		local lang = preset.opts.fallback_lang
		assert(fixtures[lang], 'no fixture for ' .. lang)
		local count, stderr = run(preset, lang)
		checked = checked + 1
		if count == 0 then failures[#failures + 1] = preset.name .. ' (' .. lang .. ') ' .. stderr:sub(1, 120) end
	end
end

-- General searches: every rule a language supports, in that language.
for lang in pairs(fixtures) do
	for _, preset in ipairs(groups.general) do
		if preset.opts.rule('', lang) then
			local count, stderr = run(preset, lang)
			checked = checked + 1
			if count == 0 then failures[#failures + 1] = preset.name .. ' (' .. lang .. ') ' .. stderr:sub(1, 120) end
		end
	end
end

assert(#failures == 0, 'presets without matches:\n' .. table.concat(failures, '\n'))
print(('ast-grep preset tests passed (%d checks)'):format(checked))
