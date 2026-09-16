-- Outfit objects: the slot bookkeeping behind the character-sheet checkboxes and
-- the complete/accessory distinction the whole category system rests on.
local Ctx = ...
local Kit, Outfitter = Ctx.Kit, Ctx.Outfitter

Kit.suite("outfits")

local function newOutfit(name)
	return Outfitter:NewEmptyOutfit(name or "Test")
end

Kit.test("a new outfit is empty and named", function()
	local o = newOutfit("Fishing")
	Kit.equal(o:GetName(), "Fishing", "GetName")
	local n = 0
	for _ in pairs(o:GetItems()) do n = n + 1 end
	Kit.equal(n, 0, "a new outfit holds no items")
end)

Kit.test("a slot is disabled until something is put in it", function()
	local o = newOutfit()
	for _, slot in ipairs(Outfitter.cSlotNames) do
		Kit.isFalse(o:SlotIsEnabled(slot), slot .. " on a new outfit")
	end
end)

Kit.test("setting an item enables exactly that slot", function()
	local o = newOutfit()
	o:SetItem("HeadSlot", {Name = "Hat", Code = 1})
	Kit.isTrue(o:SlotIsEnabled("HeadSlot"), "HeadSlot after SetItem")
	Kit.isFalse(o:SlotIsEnabled("ChestSlot"), "ChestSlot should be untouched")
end)

Kit.test("removing an item disables the slot again", function()
	local o = newOutfit()
	o:SetItem("HeadSlot", {Name = "Hat", Code = 1})
	o:RemoveItem("HeadSlot")
	Kit.isFalse(o:SlotIsEnabled("HeadSlot"), "HeadSlot after RemoveItem")
end)

Kit.test("EnableAllSlots turns on every managed slot", function()
	local o = newOutfit()
	o:EnableAllSlots()
	for _, slot in ipairs(Outfitter.cSlotNames) do
		Kit.isTrue(o:SlotIsEnabled(slot), slot .. " after EnableAllSlots")
	end
end)

Kit.test("DisableAllSlots turns them all off", function()
	local o = newOutfit()
	o:EnableAllSlots()
	o:DisableAllSlots()
	for _, slot in ipairs(Outfitter.cSlotNames) do
		Kit.isFalse(o:SlotIsEnabled(slot), slot .. " after DisableAllSlots")
	end
end)

Kit.test("EnableAllSlots then DisableAllSlots is a round trip", function()
	local o = newOutfit()
	o:SetItem("HeadSlot", {Name = "Hat", Code = 1})
	o:EnableAllSlots()
	o:DisableAllSlots()
	local n = 0
	for _ in pairs(o:GetItems()) do n = n + 1 end
	Kit.equal(n, 0, "no items survive a disable-all")
end)

Kit.test("an outfit with every slot set is complete", function()
	local o = newOutfit()
	o:EnableAllSlots()
	Kit.equal(o:CalculateOutfitCategory(), "Complete", "category with all slots")
end)

Kit.test("an outfit with some slots set is an accessory", function()
	local o = newOutfit()
	o:SetItem("HeadSlot", {Name = "Hat", Code = 1})
	Kit.notEqual(o:CalculateOutfitCategory(), "Complete", "category with one slot")
end)

Kit.test("an unknown slot name is rejected rather than silently stored", function()
	local o = newOutfit()
	Kit.isFalse(o:SlotIsEnabled("NoSuchSlot"), "SlotIsEnabled on a bogus slot")
end)

Kit.test("outfit names round-trip through SetName", function()
	local o = newOutfit("Before")
	o:SetName("After")
	Kit.equal(o:GetName(), "After", "GetName after SetName")
end)

Kit.suite("slot tables")

Kit.test("cSlotNames, cSlotOrder and cSlotIDs describe the same slots", function()
	for _, slot in ipairs(Outfitter.cSlotNames) do
		Kit.notNil(Outfitter.cSlotOrder[slot], "cSlotOrder." .. slot)
		Kit.notNil(Outfitter.cSlotIDs[slot], "cSlotIDs." .. slot)
		Kit.notNil(Outfitter.cSlotDisplayNames[slot], "cSlotDisplayNames." .. slot)
	end
	local n = 0
	for _ in pairs(Outfitter.cSlotIDs) do n = n + 1 end
	Kit.equal(n, #Outfitter.cSlotNames, "cSlotIDs holds one entry per managed slot")
end)

Kit.test("slot IDs are unique and map back to their slot", function()
	local seen = {}
	for slot, id in pairs(Outfitter.cSlotIDs) do
		Kit.isNil(seen[id], "slot ID " .. tostring(id) .. " used twice")
		seen[id] = slot
		Kit.equal(Outfitter.cSlotIDToInventorySlot[id], slot, "cSlotIDToInventorySlot[" .. id .. "]")
	end
end)

Kit.test("cSlotOrder is a permutation of cSlotNames", function()
	local seen = {}
	for slot, index in pairs(Outfitter.cSlotOrder) do
		Kit.isNil(seen[index], "two slots share order index " .. tostring(index))
		seen[index] = slot
	end
	for i = 1, #Outfitter.cSlotNames do
		Kit.notNil(seen[i], "no slot at order index " .. i)
	end
end)

Kit.suite("outfits: removal fallback")

-- F-004.  Both conditions in the walk-back used `#t` as a truth test, which is
-- always true in Lua, so the loop gave up after one entry and the fallback never
-- searched. These cases pin the searching, not just the first hit.

local function withRecent(names, fn)
	local saved = Outfitter.Settings.RecentCompleteOutfits
	Outfitter.Settings.RecentCompleteOutfits = names
	local ok, err = pcall(fn)
	Outfitter.Settings.RecentCompleteOutfits = saved
	if not ok then error(err, 0) end
end

Kit.test("an empty recent-complete history is not walked", function()
	-- The `> 0` guard: with `#t` the body ran against an empty list and indexed [0].
	withRecent({}, function()
		Kit.noError(function()
			Outfitter:RemoveOutfit({CategoryID = "Complete", Name = "Gone"})
		end, "RemoveOutfit with no history")
	end)
end)

Kit.test("the walk-back passes over entries that no longer exist", function()
	-- The heart of F-004: with the old `#t` break the loop stopped after one entry
	-- and never searched the rest of the history.
	--
	-- RemoveOutfit returns early unless the outfit is on the live outfit stack, so
	-- this puts it there through OutfitStack:AddOutfit rather than faking a table.
	local outfit = Outfitter:NewEmptyOutfit("WalkBackTarget")
	outfit.CategoryID = "Complete"
	Outfitter.OutfitStack:AddOutfit(outfit)

	withRecent({"WalkBackTarget", "StaleC", "StaleB", "StaleA"}, function()
		Outfitter:RemoveOutfit(outfit)
		-- Three stale names sit above the only real one. The walk reads from the
		-- end, so reaching WalkBackTarget means it passed all three -- which is
		-- exactly what the broken break prevented.
		local left = Outfitter.Settings.RecentCompleteOutfits
		Kit.isTrue(#left <= 2,
			"expected the stale entries to be consumed, " .. #left .. " left")
	end)
end)

Kit.test("removing a non-Complete outfit leaves the history alone", function()
	withRecent({"Something"}, function()
		Outfitter:RemoveOutfit({CategoryID = "Accessory", Name = "Gone"})
		Kit.equal(#Outfitter.Settings.RecentCompleteOutfits, 1, "history untouched")
	end)
end)
