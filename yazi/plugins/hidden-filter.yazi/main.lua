local function read_show_file(cwd)
	local path = cwd .. "/.show"
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local entries = {}
	for line in f:lines() do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			entries[#entries + 1] = trimmed:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
		end
	end
	f:close()
	if #entries == 0 then
		return nil
	end
	return "^(" .. table.concat(entries, "|") .. ")$"
end

local function apply(show_hidden)
	local cwd = tostring(cx.active.current.cwd.path or cx.active.current.cwd)
	if show_hidden then
		ya.emit("filter_do", { "", done = true })
	else
		local pattern = read_show_file(cwd)
		ya.emit("filter_do", { pattern or "", done = true })
	end
end

return {
	setup = function()
		ps.sub("cd", function()
			apply(cx.active.pref.show_hidden)
		end)

		ps.sub("key-hidden", function(opt)
			local new_hidden
			if opt.state == "toggle" then
				new_hidden = not cx.active.pref.show_hidden
			elseif opt.state == "show" then
				new_hidden = true
			else
				new_hidden = false
			end
			apply(new_hidden)
			return opt
		end)
	end,
}
