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
