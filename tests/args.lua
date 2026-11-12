local args = require('editable-telescope.args')
local split = args.split

assert(vim.deep_equal(split([[ -g '*.cpp']]), { '-g', '*.cpp' }))
assert(vim.deep_equal(split([[--glob="src files/*.cpp" --hidden]]), { '--glob=src files/*.cpp', '--hidden' }))
assert(vim.deep_equal(split([[--glob \*.lua]]), { '--glob', '*.lua' }))
assert(vim.deep_equal(split([[one\ two three]]), { 'one two', 'three' }))
assert(vim.deep_equal(split([[-g ""]]), { '-g', '' }))
assert(vim.deep_equal(split([[-g 'unfinished]]), { '-g', 'unfinished' }))
assert(vim.deep_equal(split('tail\\'), { 'tail\\' }))
for _, input in ipairs({ [[-g 'unfinished]], 'tail\\' }) do
	local parsed, err = split(input, true)
	assert(not parsed and err, input)
end
local quoted = { '-g', "it's a/*.lua", '', 'back\\slash', '"double"' }
assert(vim.deep_equal(split(args.format(quoted), true), quoted))

assert(vim.deep_equal(
	args.build({ additional_args = { '-g', '*.cpp' } }, { '--hidden' }, { 'rg', '--vimgrep' }),
	{ 'rg', '--vimgrep', '-g', '*.cpp', '--hidden' }
))
assert(vim.deep_equal(
	args.build({ hidden = true, no_ignore = true }, {}, { 'rg', '--vimgrep' }),
	{ 'rg', '--vimgrep', '--hidden', '--no-ignore' }
))
assert(vim.deep_equal(
	args.build({ vimgrep_arguments = { 'custom-rg' }, additional_args = function()
		return { '--glob=*.lua' }
	end }, {}, { 'rg' }),
	{ 'custom-rg', '--glob=*.lua' }
))

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local resolved = vim.fs.normalize(vim.uv.fs_realpath(tmp))
assert(args.normalize_root(tmp .. '/') == vim.fs.normalize(tmp))
assert(args.normalize_root(resolved) == resolved)
local missing, err = args.normalize_root(tmp .. '/missing')
assert(missing == nil and err:match('not a directory'))
