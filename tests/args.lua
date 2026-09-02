local args = require('editable-telescope.args')
local split = args.split

assert(vim.deep_equal(split([[ -g '*.cpp']]), { '-g', '*.cpp' }))
assert(vim.deep_equal(split([[--glob="src files/*.cpp" --hidden]]), { '--glob=src files/*.cpp', '--hidden' }))
assert(vim.deep_equal(split([[--glob \*.lua]]), { '--glob', '*.lua' }))
assert(vim.deep_equal(split([[one\ two three]]), { 'one two', 'three' }))
assert(vim.deep_equal(split([[-g ""]]), { '-g', '' }))

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
