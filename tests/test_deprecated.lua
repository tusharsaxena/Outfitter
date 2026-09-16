-- The deprecation layer's whole value is that it is detached.  If a live file
-- starts calling into it, or it starts writing to the live tables, it stops being
-- something that can be deleted in one step.
local Ctx = ...
local Kit, Outfitter = Ctx.Kit, Ctx.Outfitter

Kit.suite("deprecated layer")

local REMOVED_APIS = {
	"GetVoidTransferDepositInfo", "ClickVoidTransferDepositSlot",
	"BankButtonIDToInvSlotID", "GetNumCompanions", "CallCompanion",
	"GetContainerItemGems", "GetInventoryItemGems", "EquipmentManager_UnpackLocation",
	"MAX_SKILLLINE_TABS", "GetSpellTabInfo", "UnitDebuff", "GetMapNameByID",
	"UnitDefense", "BOOKTYPE_SPELL",
}

Kit.test("the layer loaded and published itself", function()
	Kit.equal(type(Outfitter.Deprecated), "table", "Outfitter.Deprecated")
	Kit.equal(type(Outfitter.DeprecatedFeature), "function", "Outfitter:DeprecatedFeature")
end)

Kit.test("no live file calls an API the game removed", function()
	local bad = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if rel ~= "Deprecated.lua" then
			local src = Ctx.readLF(rel)
			for lineNo, line in ipairs((function()
				local t = {}
				for l in src:gmatch("[^\n]*") do t[#t + 1] = l end
				return t
			end)()) do
				-- A comment naming the API is how the stubs document themselves.
				if not line:match("^%s*%-%-") then
					for _, api in ipairs(REMOVED_APIS) do
						if line:match("[^%w_]" .. api .. "%s*[%(%[]") or line:match("^" .. api .. "%s*[%(%[]") then
							bad[#bad + 1] = ("%s:%d  %s"):format(rel, lineNo, line:gsub("^%s+", ""))
						end
					end
				end
			end
		end
	end
	Kit.equal(#bad, 0, "live code calling a removed API:\n      " .. table.concat(bad, "\n      "))
end)

Kit.test("the layer writes nothing to the live Outfitter table but its own two keys", function()
	local writes = {}
	for line in Ctx.readLF("Deprecated.lua"):gmatch("[^\n]*") do
		local key = line:match("^Outfitter%.([%w_]+)%s*=") or line:match("^function Outfitter[:%.]([%w_]+)")
		if key then writes[#writes + 1] = key end
	end
	Kit.sameSet(writes, {"Deprecated", "DeprecatedFeature"}, "top-level writes from Deprecated.lua")
end)

Kit.test("every retired entry point still exists and returns without raising", function()
	for _, name in ipairs({
		"DepositOutfitToVoidStorage", "WithdrawOutfitFromVoidStorage", "CallCompanionByName",
	}) do
		Kit.equal(type(Outfitter[name]), "function", "Outfitter:" .. name)
		Kit.noError(function() Outfitter[name](Outfitter, {}) end, "Outfitter:" .. name .. "()")
	end
end)

Kit.test("DeprecatedFeature is quiet rather than chatty", function()
	-- These paths are reachable from saved outfits and user scripts, so a visible
	-- message would fire for people who never knowingly used the feature.
	Ctx.Mock.calls.chat = nil
	Outfitter:DeprecatedFeature("Test feature")
	Kit.isNil(Ctx.Mock.calls.chat, "DeprecatedFeature printed to chat")
end)

Kit.test("the preserved bodies are still there to revive", function()
	local D = Outfitter.Deprecated
	for _, key in ipairs({"VoidStorage", "Companions", "BankTooltip", "Gems",
	                      "QuickSlots", "SpellbookIcons", "TankPoints", "RetiredStrings"}) do
		Kit.notNil(D[key], "Outfitter.Deprecated." .. key)
	end
	for _, key in ipairs({"HasDebuffScriptBody", "LowHealthScriptBody", "ChampioningScriptBodies"}) do
		Kit.notNil(D[key], "Outfitter.Deprecated." .. key)
	end
end)

Kit.test("the revivable preserved bodies compile", function()
	-- HAS_DEBUFF and LOW_HEALTH are retired but sound: reviving either is a paste,
	-- so they have to still be valid Lua.
	local D = Outfitter.Deprecated
	for id, body in pairs({HAS_DEBUFF = D.HasDebuffScriptBody, LOW_HEALTH = D.LowHealthScriptBody}) do
		local src = Outfitter.cScriptPrefix .. body .. Outfitter.cScriptSuffix
		local chunk, err = loadstring(src, "deprecated " .. id)
		Kit.notNil(chunk, "deprecated body " .. id .. " does not compile: " .. tostring(err))
	end
end)

Kit.test("the three championing bodies are preserved verbatim", function()
	-- Kept as the record of what was there, not as something to paste back: all
	-- three call GetMapNameByID, which the game removed, and all three compare
	-- against an undefined `name` upvalue.  Reviving one means rewriting it.
	local D = Outfitter.Deprecated
	local n = 0
	for id, body in pairs(D.ChampioningScriptBodies) do
		Kit.equal(type(body), "string", "championing body " .. id)
		Kit.isTrue(#body > 200, "championing body " .. id .. " looks truncated")
		Kit.isTrue(body:match("GetMapNameByID") ~= nil, "body " .. id .. " kept its original calls")
		n = n + 1
	end
	Kit.equal(n, 3, "championing bodies kept")
end)

Kit.test("CHAMPFACTION was already invalid Lua before it was retired", function()
	-- Found by this harness, not by anyone playing.  Its condition closes with
	-- `))) then` against an `if` that opened no parentheses, so the preset never
	-- compiled and activating it always raised "Couldn't activate script" -- a
	-- separate defect from the removed API, and one that predates it.  Pinned so
	-- that if someone repairs the body, this says so rather than staying quiet.
	local body = Outfitter.Deprecated.ChampioningScriptBodies.CHAMPFACTION
	local chunk = loadstring(Outfitter.cScriptPrefix .. body .. Outfitter.cScriptSuffix, "CHAMPFACTION")
	Kit.isNil(chunk, "CHAMPFACTION now compiles -- if it was fixed, it can be revived")
end)

Kit.test("the other two championing bodies are valid Lua that simply cannot work", function()
	-- CHAMP and CHAMPCATACLYSM parse fine; they are retired because GetMapNameByID
	-- is gone and `name` is never defined, not because of a syntax error.
	local D = Outfitter.Deprecated
	for _, id in ipairs({"CHAMP", "CHAMPCATACLYSM"}) do
		local body = D.ChampioningScriptBodies[id]
		Kit.notNil(loadstring(Outfitter.cScriptPrefix .. body .. Outfitter.cScriptSuffix, id),
			"championing body " .. id .. " should still parse")
	end
end)

Kit.test("the header documents every entry point that calls into the layer", function()
	local header = Ctx.readLF("Deprecated.lua"):sub(1, 4000)
	local callSites = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if rel ~= "Deprecated.lua" then
			for feature in Ctx.readLF(rel):gmatch('DeprecatedFeature%("([^"]+)"') do
				callSites[#callSites + 1] = {rel = rel, feature = feature}
			end
		end
	end
	Kit.isTrue(#callSites >= 6, "expected the retired entry points, found " .. #callSites)
	local undocumented = {}
	for _, site in ipairs(callSites) do
		if not header:match(site.rel:gsub("%-", "%%-"):gsub("%.", "%%.")) then
			undocumented[#undocumented + 1] = site.rel
		end
	end
	local seen, uniq = {}, {}
	for _, f in ipairs(undocumented) do if not seen[f] then seen[f] = true; uniq[#uniq + 1] = f end end
	Kit.equal(#uniq, 0, "files with a stub the header does not mention: " .. table.concat(uniq, ", "))
end)
