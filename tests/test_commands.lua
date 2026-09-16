-- Slash commands.  A command in the dispatch table that nothing documents is
-- undiscoverable; a documented command that does not dispatch is a promise the
-- addon does not keep.
local Ctx = ...
local Kit, Outfitter = Ctx.Kit, Ctx.Outfitter

Kit.suite("slash commands")

--- The command words ExecuteCommand dispatches on, read out of its source.
local function dispatchedCommands()
	local src = Ctx.readLF("Outfitter.lua")
	local body = src:match("function Outfitter:ExecuteCommand.-\n\tlocal vCommands =\n\t{(.-)\n\t}")
	assert(body, "could not find the vCommands table in ExecuteCommand")
	local out = {}
	for word in body:gmatch("\n%s*([%w_]+)%s*=%s*{") do out[#out + 1] = word end
	return out
end

--- The command words ShowCommandHelp prints.
local function documentedCommands()
	local src = Ctx.readLF("Outfitter.lua")
	local body = src:match("function Outfitter:ShowCommandHelp.-\nend")
	assert(body, "could not find ShowCommandHelp")
	local seen, out = {}, {}
	for word in body:gmatch('"/outfitter ([%w_]+)') do
		if not seen[word] then seen[word] = true; out[#out + 1] = word end
	end
	return out
end

Kit.test("the addon registers its slash commands", function()
	Kit.equal(SLASH_OUTFITTER1, "/outfitter", "SLASH_OUTFITTER1")
	Kit.equal(type(SlashCmdList.OUTFITTER), "function", "SlashCmdList.OUTFITTER")
end)

Kit.test("every dispatched command is documented in the help", function()
	local documented = {}
	for _, w in ipairs(documentedCommands()) do documented[w] = true end
	local undocumented = {}
	for _, w in ipairs(dispatchedCommands()) do
		-- daxdax is a deliberate undocumented alias for the errors toggle.
		if not documented[w] and w ~= "daxdax" and w ~= "help" then
			undocumented[#undocumented + 1] = w
		end
	end
	table.sort(undocumented)
	Kit.equal(#undocumented, 0, "commands with no help line: " .. table.concat(undocumented, ", "))
end)

Kit.test("every documented command actually dispatches", function()
	local dispatched = {}
	for _, w in ipairs(dispatchedCommands()) do dispatched[w] = true end
	local broken = {}
	for _, w in ipairs(documentedCommands()) do
		if not dispatched[w] then broken[#broken + 1] = w end
	end
	table.sort(broken)
	Kit.equal(#broken, 0, "documented but not dispatched: " .. table.concat(broken, ", "))
end)

Kit.test("every dispatch target is a function that exists", function()
	local src = Ctx.readLF("Outfitter.lua")
	local body = src:match("function Outfitter:ExecuteCommand.-\n\tlocal vCommands =\n\t{(.-)\n\t}")
	local missing = {}
	for method in body:gmatch("func%s*=%s*self%.([%w_]+)") do
		if type(Outfitter[method]) ~= "function" then missing[#missing + 1] = method end
	end
	Kit.equal(#missing, 0, "dispatch table points at missing methods: " .. table.concat(missing, ", "))
end)

--- The command words the user manual's table documents.
--
-- The manual is the third surface, after the dispatch table and the in-game help.
-- The README used to be a fourth, carrying its own copy of the table; it now
-- points at the manual instead, which is one fewer place to drift.
local function manualCommands()
	local seen, out = {}, {}
	for word in Ctx.readLF("UsersManual.md"):gmatch("`/outfitter ([%w_]+)") do
		if not seen[word] then seen[word] = true; out[#out + 1] = word end
	end
	return out
end

Kit.test("the user manual documents every command the addon dispatches", function()
	local documented = {}
	for _, w in ipairs(manualCommands()) do documented[w] = true end
	local missing = {}
	for _, w in ipairs(dispatchedCommands()) do
		if not documented[w] and w ~= "daxdax" and w ~= "help" then
			missing[#missing + 1] = w
		end
	end
	table.sort(missing)
	Kit.equal(#missing, 0, "commands missing from the manual: " .. table.concat(missing, ", "))
end)

Kit.test("the user manual does not document a command that does not exist", function()
	local dispatched = {}
	for _, w in ipairs(dispatchedCommands()) do dispatched[w] = true end
	local phantom = {}
	for _, w in ipairs(manualCommands()) do
		if not dispatched[w] and w ~= "help" then phantom[#phantom + 1] = w end
	end
	table.sort(phantom)
	Kit.equal(#phantom, 0, "manual documents commands that do not dispatch: " ..
		table.concat(phantom, ", "))
end)

Kit.test("the README points at the manual rather than copying its table", function()
	-- If a command table comes back to the README it becomes a surface that can
	-- drift again, and nothing here would notice.
	local readme = Ctx.readLF("README.md")
	local rows = select(2, readme:gsub("|%s*`/outfitter [%w_]+", ""))
	Kit.equal(rows, 0, "the README has grown a command table again (" .. rows .. " rows)")
	Kit.isTrue(readme:match("UsersManual%.md") ~= nil, "the README links the manual")
end)

Kit.test("every local file the manual references exists", function()
	-- The screenshots are absolute raw URLs now, because the manual sits at the
	-- repo root and ships, while Media/ deliberately does not. Any RELATIVE link
	-- it still carries has to resolve against the root.
	local missing = {}
	for path in Ctx.readLF("UsersManual.md"):gmatch("%]%(([^)]+)%)") do
		if not path:match("^https?://") and not path:match("^#") then
			local f = io.open(Ctx.root .. "/" .. path, "rb")
			if f then f:close() else missing[#missing + 1] = path end
		end
	end
	Kit.equal(#missing, 0, "manual references missing files: " .. table.concat(missing, ", "))
end)

Kit.test("the manual never points at an image that does not ship", function()
	-- UsersManual.md ships; Media/ deliberately does not.  A relative image
	-- reference from the manual into an ignored directory renders fine on GitHub
	-- and is a broken image for every player who opens the shipped copy -- the
	-- kind of mistake that is invisible to whoever makes it.
	--
	-- Absolute URLs are not checked: those resolve from the web wherever the
	-- manual is read, which is a deliberate and different choice.
	local ignored = {}
	local inIgnore = false
	for line in Ctx.readLF(".pkgmeta"):gmatch("[^\n]*") do
		if line:match("^ignore:") then inIgnore = true
		elseif line:match("^%a") then inIgnore = false
		elseif inIgnore then
			local entry = line:match("^%s+%-%s*([%w%._/%-]+)%s*$")
			if entry then ignored[entry] = true end
		end
	end

	local offenders = {}
	for path in Ctx.readLF("UsersManual.md"):gmatch("%]%(([^)]+)%)") do
		if not path:match("^https?://") and not path:match("^#") then
			-- Resolved against the repo root, then checked against the manifest.
			local full = path
			local top = full:match("^([^/]+)")
			if ignored[top] or ignored[full] then
				offenders[#offenders + 1] = path .. " (under an ignored path)"
			end
		end
	end
	Kit.equal(#offenders, 0, "the shipped manual links to files that do not ship: " ..
		table.concat(offenders, ", "))
end)

Kit.test("the zone diagnostic reports without raising", function()
	Ctx.Mock.state.instanceType = "pvp"
	Ctx.Mock.state.instanceMapID = 30
	Outfitter.CurrentZoneIDs = Outfitter:GetCurrentZoneIDs()
	Kit.noError(function() Outfitter:ShowZoneInfo() end, "Outfitter:ShowZoneInfo()")
	Ctx.Mock.reset()
end)

Kit.test("an unknown command falls through to the help rather than raising", function()
	Kit.noError(function() Outfitter:ExecuteCommand("nosuchcommand") end, "unknown command")
	Kit.noError(function() Outfitter:ExecuteCommand("") end, "empty command")
end)
