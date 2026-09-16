-- Preset scripts are source code stored as data.  They are compiled at runtime
-- with a prefix and suffix wrapped around them, so a syntax error in one shows up
-- as a broken outfit in a client rather than as anything visible here -- unless
-- this suite compiles them.
local Ctx = ...
local Kit, Outfitter = Ctx.Kit, Ctx.Outfitter

Kit.suite("preset scripts")

-- The fields a preset entry may carry.  Anything else is a typo, and a typo here
-- is silent: the reader falls back with `Category or Class or "GENERAL"`, so a
-- misspelt key files the preset under the wrong heading and nothing complains.
-- RESTING shipped as `CATEGORY = "TRADE"` and sat under General for years.
local KNOWN_FIELDS = {
	Name = true, ID = true, Script = true, Category = true, Class = true,
}

Kit.test("there are presets, and every one is well formed", function()
	Kit.isTrue(#Outfitter.PresetScripts > 40, "preset count: " .. #Outfitter.PresetScripts)
	for i, p in ipairs(Outfitter.PresetScripts) do
		Kit.equal(type(p.ID), "string", "preset " .. i .. " ID")
		Kit.equal(type(p.Name), "string", "preset " .. tostring(p.ID) .. " Name")
		Kit.equal(type(p.Script), "string", "preset " .. tostring(p.ID) .. " Script")
	end
end)

Kit.test("every preset files itself under a category or a class", function()
	local unfiled = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		if type(p.Category) ~= "string" and type(p.Class) ~= "string" then
			unfiled[#unfiled + 1] = p.ID
		end
	end
	Kit.equal(#unfiled, 0, "presets with neither Category nor Class: " ..
		table.concat(unfiled, ", "))
end)

Kit.test("no preset carries a misspelt field", function()
	local bad = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		for key in pairs(p) do
			if not KNOWN_FIELDS[key] then bad[#bad + 1] = p.ID .. "." .. tostring(key) end
		end
	end
	table.sort(bad)
	Kit.equal(#bad, 0, "unrecognised preset fields: " .. table.concat(bad, ", "))
end)

Kit.test("every declared category is one the menu knows how to order", function()
	local bad = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		if p.Category and Outfitter.cScriptCategoryOrder[p.Category] == nil then
			bad[#bad + 1] = p.ID .. " -> " .. p.Category
		end
	end
	Kit.equal(#bad, 0, "categories with no entry in cScriptCategoryOrder: " ..
		table.concat(bad, ", "))
end)

Kit.test("every class-filed preset names a real class", function()
	local bad = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		if p.Class and Outfitter.cClassSpecialOutfits[p.Class] == nil then
			bad[#bad + 1] = p.ID .. " -> " .. p.Class
		end
	end
	Kit.equal(#bad, 0, "presets filed under an unknown class: " .. table.concat(bad, ", "))
end)

Kit.test("preset IDs are unique", function()
	local seen, dupes = {}, {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		if seen[p.ID] then dupes[#dupes + 1] = p.ID end
		seen[p.ID] = true
	end
	Kit.equal(#dupes, 0, "duplicate preset IDs: " .. table.concat(dupes, ", "))
end)

Kit.test("preset names are non-empty", function()
	local blank = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		if p.Name == nil or p.Name == "" then blank[#blank + 1] = p.ID end
	end
	Kit.equal(#blank, 0, "presets with no name: " .. table.concat(blank, ", "))
end)

Kit.test("every preset compiles inside the runtime wrapper", function()
	local broken = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		local src = Outfitter.cScriptPrefix .. p.Script .. Outfitter.cScriptSuffix
		local chunk, err = loadstring(src, "preset " .. p.ID)
		if not chunk then broken[#broken + 1] = p.ID .. ": " .. tostring(err) end
	end
	Kit.equal(#broken, 0, "presets that do not compile:\n      " .. table.concat(broken, "\n      "))
end)

Kit.test("every preset declares at least one event", function()
	local silent = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		local fields = Outfitter:ParseScriptFields(p.Script)
		if not fields or not fields.Events or fields.Events:match("^%s*$") then
			silent[#silent + 1] = p.ID
		end
	end
	Kit.equal(#silent, 0, "presets with no $EVENTS (they can never run): " ..
		table.concat(silent, ", "))
end)

Kit.test("every event a preset declares is one the addon dispatches", function()
	local unknown = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		local fields = Outfitter:ParseScriptFields(p.Script)
		for ev in (fields and fields.Events or ""):gmatch("([%w_]+)") do
			if not Outfitter.BuiltinEvents[ev] and not ev:match("^[A-Z_]+$") then
				unknown[#unknown + 1] = p.ID .. " -> " .. ev
			end
		end
	end
	Kit.equal(#unknown, 0, "presets listening for events nothing sends: " ..
		table.concat(unknown, ", "))
end)

Kit.test("every preset's settings parse", function()
	local bad = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		local ok, fields = pcall(Outfitter.ParseScriptFields, Outfitter, p.Script)
		if not ok then bad[#bad + 1] = p.ID .. ": " .. tostring(fields) end
	end
	Kit.equal(#bad, 0, "presets whose $SETTING lines do not parse: " .. table.concat(bad, ", "))
end)

Kit.test("the retired presets are inert rather than missing", function()
	-- Retired by replacing their body, not by deleting the entry: an outfit already
	-- using one keeps resolving its ScriptID instead of erroring.
	local ids = {}
	for _, p in ipairs(Outfitter.PresetScripts) do ids[p.ID] = p end
	for _, id in ipairs({"HAS_DEBUFF", "LOW_HEALTH", "CHAMPFACTION", "CHAMP", "CHAMPCATACLYSM"}) do
		Kit.notNil(ids[id], "retired preset " .. id .. " is still registered")
		Kit.isTrue(ids[id].Script:match("no longer does anything") ~= nil,
			"preset " .. id .. " body is the inert one")
	end
end)

Kit.test("no live preset calls an API the game removed", function()
	local gone = {"UnitDebuff", "GetMapNameByID", "GetNumCompanions", "CallCompanion"}
	local bad = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		for _, api in ipairs(gone) do
			if p.Script:match(api .. "%s*%(") then bad[#bad + 1] = p.ID .. " -> " .. api end
		end
	end
	Kit.equal(#bad, 0, "presets calling removed APIs: " .. table.concat(bad, ", "))
end)

Kit.test("GetScript resolves a preset's text live from the table", function()
	-- The property the retirements depend on: an outfit stores only ScriptID, so
	-- editing a preset body changes behaviour for existing users with no migration.
	local outfit = {ScriptID = "LOW_HEALTH"}
	local text = Outfitter:GetScript(outfit)
	Kit.notNil(text, "GetScript for a preset outfit")
	Kit.isTrue(text:match("no longer does anything") ~= nil,
		"GetScript returned the current body, not a stored copy")
end)

Kit.test("GetScript returns a hand-written script unchanged", function()
	local outfit = {Script = "-- $EVENTS TIMER\nequip = true\n"}
	Kit.equal(Outfitter:GetScript(outfit), outfit.Script, "GetScript for a custom script")
end)
