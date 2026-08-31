local split = require('editable-telescope.args').split

assert(vim.deep_equal(split([[ -g '*.cpp']]), { '-g', '*.cpp' }))
assert(vim.deep_equal(split([[--glob="src files/*.cpp" --hidden]]), { '--glob=src files/*.cpp', '--hidden' }))
assert(vim.deep_equal(split([[--glob \*.lua]]), { '--glob', '*.lua' }))
assert(vim.deep_equal(split([[one\ two three]]), { 'one two', 'three' }))
assert(vim.deep_equal(split([[-g ""]]), { '-g', '' }))
