local M = {}

function M.split(input)
	local args, current, quote, escaped = {}, {}, nil, false
	local started = false

	for char in (input or ''):gmatch('.') do
		if escaped then
			table.insert(current, char)
			escaped = false
			started = true
		elseif char == '\\' and quote ~= "'" then
			escaped = true
			started = true
		elseif quote then
			if char == quote then
				quote = nil
			else
				table.insert(current, char)
			end
		elseif char == "'" or char == '"' then
			quote = char
			started = true
		elseif char:match('%s') then
			if started then
				table.insert(args, table.concat(current))
				current, started = {}, false
			end
		else
			table.insert(current, char)
			started = true
		end
	end

	if escaped then
		table.insert(current, '\\')
	end
	if started or #current > 0 then
		table.insert(args, table.concat(current))
	end

	return args
end

return M
