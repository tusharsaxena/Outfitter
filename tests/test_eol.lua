-- Line endings are mixed per file in this repo and must stay that way: a
-- whole-file re-ending buries the real change in a diff nobody can review.
local Ctx = ...
local Kit = Ctx.Kit

Kit.suite("line endings")

-- The shipped state, pinned.  Upstream wrote some files CRLF and some LF and
-- there is no value in normalising them -- only in noticing when one flips.
local EXPECTED = {
	["Compat.lua"] = "lf",
	["Deprecated.lua"] = "lf",
	["Outfitter.lua"] = "lf",
	["OutfitterAbout.lua"] = "crlf",
	["OutfitterBar.lua"] = "lf",
	["OutfitterEquipment.lua"] = "lf",
	["OutfitterInventory.lua"] = "lf",
	["OutfitterItemStats.lua"] = "crlf",
	["OutfitterLDB.lua"] = "crlf",
	["OutfitterMinimapButton.lua"] = "crlf",
	["OutfitterOptimize.lua"] = "crlf",
	["OutfitterOutfits.lua"] = "crlf",
	["OutfitterPrefix.lua"] = "crlf",
	["OutfitterQuickSlots.lua"] = "crlf",
	["OutfitterScriptDialog.lua"] = "crlf",
	["OutfitterScripting.lua"] = "crlf",
	["OutfitterStrings.lua"] = "crlf",
	["OutfitterStrings_cn.lua"] = "crlf",
	["OutfitterStrings_de.lua"] = "crlf",
	["OutfitterStrings_fr.lua"] = "crlf",
	["OutfitterStrings_kr.lua"] = "crlf",
	["OutfitterStrings_ru.lua"] = "crlf",
	["OutfitterStrings_tw.lua"] = "crlf",
	["OutfitterUITools.lua"] = "crlf",
}

local function styleOf(src)
	local crlf = select(2, src:gsub("\r\n", ""))
	local lf = select(2, src:gsub("\n", "")) - crlf
	if crlf > 0 and lf > 0 then return "mixed" end
	if crlf > 0 then return "crlf" end
	return "lf"
end

Kit.test("each addon file keeps the line endings it shipped with", function()
	local wrong = {}
	for rel, want in pairs(EXPECTED) do
		local got = styleOf(Ctx.read(rel))
		if got ~= want then wrong[#wrong + 1] = ("%s is %s, expected %s"):format(rel, got, want) end
	end
	table.sort(wrong)
	Kit.equal(#wrong, 0, table.concat(wrong, "; "))
end)

Kit.test("no addon file mixes both endings", function()
	local mixed = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if styleOf(Ctx.read(rel)) == "mixed" then mixed[#mixed + 1] = rel end
	end
	Kit.equal(#mixed, 0, "files with mixed line endings: " .. table.concat(mixed, ", "))
end)

Kit.test("the pinned list covers every root-level addon file", function()
	local onDisk = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if not rel:match("/") then onDisk[#onDisk + 1] = rel end
	end
	local pinned = {}
	for rel in pairs(EXPECTED) do pinned[#pinned + 1] = rel end
	Kit.sameSet(onDisk, pinned, "root-level .lua files")
end)
