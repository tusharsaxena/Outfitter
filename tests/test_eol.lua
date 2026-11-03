-- Line endings are CRLF in every addon file, pinned by .gitattributes
-- (`* text=auto eol=crlf`; only *.sh and *.py are LF).  The index stores LF
-- and checkout writes CRLF, so an LF or mixed file on disk is a straggler that
-- bypassed git's filters.
local Ctx = ...
local Kit = Ctx.Kit

Kit.suite("line endings")

-- The pinned state: every root-level addon file is CRLF on disk.
local EXPECTED = {
	["Compat.lua"] = "crlf",
	["Deprecated.lua"] = "crlf",
	["Outfitter.lua"] = "crlf",
	["OutfitterAbout.lua"] = "crlf",
	["OutfitterBar.lua"] = "crlf",
	["OutfitterEquipment.lua"] = "crlf",
	["OutfitterInventory.lua"] = "crlf",
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

Kit.test("each addon file is CRLF on disk", function()
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
