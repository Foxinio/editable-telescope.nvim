local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local builtin = require('telescope.builtin')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local prompt_parser = require('telescope-live-grep-args.prompt_parser')
local sorters = require('telescope.sorters')
local telescope = require('telescope')

local function root_label(cwd)
	local label = vim.fn.fnamemodify(cwd, ':~:.')
	return label == '' and cwd or label
end

local function editable_picker(opts)
	local function open(default_text, state)
		state = vim.tbl_extend('force', { cwd = opts.picker_opts.cwd or vim.fn.getcwd(), cmd_args = {} }, state or {})
		local picker_opts = vim.tbl_extend('force', opts.picker_opts or {}, {
			cwd = state.cwd,
			default_text = default_text,
			prompt_title = opts.prompt_title(state),
		})
		local attach_mappings = picker_opts.attach_mappings

		picker_opts.attach_mappings = function(prompt_bufnr, map)
			if opts.parse_cmd_args then
				map('i', '<C-a>', function()
					local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
					actions.close(prompt_bufnr)
					vim.schedule(function()
						vim.ui.input({
							prompt = opts.cmd_args_prompt or 'cmd args: ',
							default = table.concat(state.cmd_args, ' '),
						}, function(input)
							open(prompt, input == nil and state or vim.tbl_extend('force', {}, state, {
								cmd_args = opts.parse_cmd_args(input),
							}))
						end)
					end)
				end)
			end

			map('i', '<C-s>', function()
				local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = 'search root: ', default = state.cwd, completion = 'dir' }, function(input)
						if input == nil then
							open(prompt, state)
							return
						end

						local cwd = vim.fn.fnamemodify(input, ':p')
						if vim.fn.isdirectory(cwd) == 0 then
							vim.notify('Search root is not a directory: ' .. input, vim.log.levels.WARN)
							open(prompt, state)
							return
						end

						open(prompt, vim.tbl_extend('force', {}, state, { cwd = cwd }))
					end)
				end)
			end)

			return not attach_mappings or attach_mappings(prompt_bufnr, map)
		end

		opts.open(state, picker_opts)
	end

	open(nil)
end

local function find_files(opts)
	opts = opts or {}
	editable_picker({
		picker_opts = opts,
		prompt_title = function(state)
			return opts.prompt_title or 'Find Files (' .. root_label(state.cwd) .. ')'
		end,
		open = function(_, picker_opts)
			builtin.find_files(picker_opts)
		end,
	})
end

local function live_grep(opts)
	opts = opts or {}
	editable_picker({
		picker_opts = opts,
		cmd_args_prompt = 'rg flags: ',
		parse_cmd_args = function(input)
			return input == '' and {} or prompt_parser.parse(input, false)
		end,
		prompt_title = function(state)
			return opts.prompt_title or 'Live Grep (' .. root_label(state.cwd) .. ') [' .. table.concat(state.cmd_args, ' ') .. ']'
		end,
		open = function(state, picker_opts)
			picker_opts.entry_maker = make_entry.gen_from_vimgrep(picker_opts)
			local args = vim.list_extend(vim.deepcopy(conf.vimgrep_arguments), state.cmd_args)

			pickers.new(picker_opts, {
				finder = finders.new_job(function(prompt)
					if not prompt or prompt == '' then
						return nil
					end

					return vim.list_extend(vim.deepcopy(args), { '--', prompt })
				end, picker_opts.entry_maker, picker_opts.max_results, picker_opts.cwd),
				previewer = conf.grep_previewer(picker_opts),
				sorter = sorters.highlighter_only(picker_opts),
				attach_mappings = picker_opts.attach_mappings,
			}):find()
		end,
	})
end

return telescope.register_extension({
	exports = {
		find_files = find_files,
		live_grep = live_grep,
	},
})
