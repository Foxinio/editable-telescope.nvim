local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local args = require('editable-telescope.args')
local builtin = require('telescope.builtin')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local telescope = require('telescope')

local config = {
	remember_query = false,
	mappings = {
		change_root = '<C-s>',
		edit_args = '<C-a>',
	},
}
local queries = {}

local function root_label(cwd)
	local label = vim.fn.fnamemodify(cwd, ':~:.')
	return label == '' and cwd or label
end

-- `edit_grep_args` is the pre-1.0 name of `edit_args`; keep accepting it.
local function edit_args_key(mappings)
	if mappings.edit_args ~= nil then return mappings.edit_args end
	return mappings.edit_grep_args
end

local function editable_picker(opts)
	opts.picker_opts = opts.picker_opts or {}
	local mappings = vim.tbl_extend('force', {}, config.mappings, opts.mappings or {})
	mappings.edit_args = edit_args_key(opts.mappings or {}) or edit_args_key(config.mappings)
	local initial_cwd = args.normalize_root(opts.picker_opts.cwd) or vim.fn.getcwd()
	local function open(default_text, state)
		state = vim.tbl_extend('force', { cwd = initial_cwd, cmd_args = {} }, state or {})
		local picker_opts = vim.tbl_extend('force', opts.picker_opts or {}, {
			cwd = state.cwd,
			default_text = default_text,
			prompt_title = opts.prompt_title(state),
		})
		local attach_mappings = picker_opts.attach_mappings

		picker_opts.attach_mappings = function(prompt_bufnr, map)
			if config.remember_query and opts.query_key then
				local picker = action_state.get_current_picker(prompt_bufnr)
				-- Not `once`: leaving for the preview and coming back must still save the final query.
				vim.api.nvim_create_autocmd('BufLeave', {
					buffer = prompt_bufnr,
					callback = function()
						-- Telescope may have already closed the prompt window.
						if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
						local line = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1]
						if line then queries[opts.query_key] = line:sub(#picker.prompt_prefix + 1) end
					end,
				})
			end
			if opts.parse_cmd_args then
				map({ 'i', 'n' }, mappings.edit_args, function()
					local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
					actions.close(prompt_bufnr)
					vim.schedule(function()
						vim.ui.input({
							prompt = opts.cmd_args_prompt or 'cmd args: ',
							default = opts.format_cmd_args
								and opts.format_cmd_args(state.cmd_args, state)
								or table.concat(state.cmd_args, ' '),
						}, vim.schedule_wrap(function(input)
							if input == nil then return open(prompt, state) end
							local parsed, err = opts.parse_cmd_args(input)
							local updated = vim.tbl_extend('force', {}, state, {
								cmd_args = parsed or state.cmd_args,
								cmd_args_text = input,
							})
							updated.cmd_args_error = err
							open(prompt, updated)
						end))
					end)
				end)
			end

			map({ 'i', 'n' }, mappings.change_root, function()
				local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = 'search root: ', default = state.cwd, completion = 'dir' }, vim.schedule_wrap(function(input)
						if input == nil then
							open(prompt, state)
							return
						end

						local cwd, err = args.normalize_root(input)
						if not cwd then
							vim.notify(err, vim.log.levels.WARN)
							open(prompt, state)
							return
						end

						open(prompt, vim.tbl_extend('force', {}, state, { cwd = cwd }))
					end))
				end)
			end)

			return not attach_mappings or attach_mappings(prompt_bufnr, map)
		end

		opts.open(state, picker_opts)
	end

	local default_text = opts.picker_opts.default_text
	if default_text == nil and config.remember_query and opts.query_key then
		default_text = queries[opts.query_key]
	end
	open(default_text, opts.initial_state)
end

local function find_files(opts)
	opts = opts or {}
	editable_picker({
		query_key = 'find_files',
		picker_opts = opts,
		prompt_title = function(state)
			local default_prompt_title = 'Find Files (' .. root_label(state.cwd) .. ')'
			return opts.prompt_title or default_prompt_title
		end,
		open = function(_, picker_opts)
			builtin.find_files(picker_opts)
		end,
	})
end

local function live_grep(opts)
	opts = opts or {}
	editable_picker({
		query_key = 'live_grep',
		picker_opts = opts,
		cmd_args_prompt = 'rg flags: ',
		parse_cmd_args = args.split,
		prompt_title = function(state)
			local default_prompt_title = 'Live Grep (' .. root_label(state.cwd) .. ') [' .. table.concat(state.cmd_args, ' ') .. ']'
			return opts.prompt_title or default_prompt_title
		end,
		open = function(state, picker_opts)
			picker_opts.entry_maker = make_entry.gen_from_vimgrep(picker_opts)
			local command = args.build(picker_opts, state.cmd_args, conf.vimgrep_arguments)

			pickers.new(picker_opts, {
				finder = finders.new_job(function(prompt)
					if not prompt or prompt == '' then
						return nil
					end

					return vim.list_extend(vim.deepcopy(command), { '--', prompt })
				end, picker_opts.entry_maker, picker_opts.max_results, picker_opts.cwd),
				previewer = conf.grep_previewer(picker_opts),
				sorter = sorters.highlighter_only(picker_opts),
				attach_mappings = picker_opts.attach_mappings,
			}):find()
		end,
	})
end

return telescope.register_extension({
	setup = function(ext_config)
		config = vim.tbl_deep_extend('force', config, ext_config)
		local user = (ext_config or {}).mappings or {}
		if user.edit_args == nil and user.edit_grep_args ~= nil then
			config.mappings.edit_args = user.edit_grep_args
		end
	end,
	exports = {
		editable_picker = editable_picker,
		find_files = find_files,
		live_grep = live_grep,
	},
})
