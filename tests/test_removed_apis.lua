-- tests/test_removed_apis.lua — no live file names an API, event or library the game or this rewrite
-- retired (design §9.3; feature inventory §18, "Retired and dead: do NOT carry over"):
--
--   GetContainerItemGems, GetInventoryItemGems   gem capture, gone from the client
--   BankButtonIDToInvSlotID                      the banked-item row tooltip, gone from the client
--   CallCompanion*                               CallCompanion / CallCompanionByName; pets are C_PetJournal
--   UnitDebuff                                   gone; auras are C_UnitAuras through the Secrets seam
--   GetMapNameByID                               gone; zone detection is map-ID based (design §6.5)
--   VoidStorage*, VoidTransfer*, GetVoidItem*,   void storage, removed by the game
--     VOID_STORAGE_*, VOID_TRANSFER_*
--   UNIT_MANA, CHARACTER_POINTS_CHANGED          events the client no longer fires
--   LibBabble                                    the deleted Libraries/ locale libs (H15)
--
-- Live means what the client loads: every file the TOC lists (walked from the TOC, never a hand list),
-- the TOC itself and Bindings.xml. A Lua comment may name a retired API to say why it is not called;
-- code and strings may not.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- { pattern, what }: identifiers anchored at a frontier unless the name is a whole family.
local REMOVED = {
    { "%f[%w_]GetContainerItemGems%f[^%w_]", "GetContainerItemGems" },
    { "%f[%w_]GetInventoryItemGems%f[^%w_]", "GetInventoryItemGems" },
    { "%f[%w_]BankButtonIDToInvSlotID%f[^%w_]", "BankButtonIDToInvSlotID" },
    { "%f[%w_]CallCompanion", "CallCompanion" },
    { "%f[%w_]UnitDebuff%f[^%w_]", "UnitDebuff" },
    { "%f[%w_]GetMapNameByID%f[^%w_]", "GetMapNameByID" },
    { "VoidStorage", "a void-storage API" },
    { "VoidTransfer", "a void-storage API" },
    { "%f[%w_]GetVoidItem", "a void-storage API" },
    { "VOID_STORAGE", "a void-storage event" },
    { "VOID_TRANSFER", "a void-storage event" },
    { "%f[%w_]UNIT_MANA%f[^%w_]", "UNIT_MANA" },
    { "%f[%w_]CHARACTER_POINTS_CHANGED%f[^%w_]", "CHARACTER_POINTS_CHANGED" },
    { "LibBabble", "LibBabble" },
}

--- Lua source with its comments removed: long comments first, then line comments.
local function stripLuaComments(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

--- The TOC with its `#` comment lines removed; the `##` header lines are kept and scanned.
local function stripTocComments(text)
    local out = {}
    for line in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
        if not line:find("^#[^#]") and line ~= "#" then out[#out + 1] = line end
    end
    return table.concat(out, "\n")
end

--- The retired names a text carries, as "what" strings, one per hit.
local function retiredNames(text)
    local hits = {}
    for _, row in ipairs(REMOVED) do
        if text:find(row[1]) then hits[#hits + 1] = row[2] end
    end
    return hits
end

local function read(rel)
    local f = io.open(T.root .. "/" .. rel, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

test("removed APIs: the scanner catches a retired name in code and lets a comment through (mutation self-test)", function()
    -- red under: retiredNames returning {} (every case below that expects a hit), or a pattern
    -- without its frontier (the near-miss names would hit).
    assertEqual(#retiredNames("local g = GetContainerItemGems(bag, slot)"), 1)
    assertEqual(#retiredNames("CallCompanionByName('x')"), 1, "the CallCompanion family")
    assertEqual(#retiredNames("frame:RegisterEvent(\"UNIT_MANA\")"), 1)
    assertEqual(#retiredNames("if VoidStorageFrame then ClickVoidTransferDepositSlot(1) end"), 2)
    assertEqual(#retiredNames("local LBI = LibStub('LibBabble-Inventory-3.0')"), 1)
    assertEqual(#retiredNames("UNIT_MANA_FREQUENT, UnitDebuffs, MyGetMapNameByID"), 0, "near-misses are not hits")
    assertEqual(#retiredNames("C_UnitAuras.GetAuraDataByIndex(unit, i, 'HARMFUL')"), 0)
    assertEqual(#retiredNames(stripLuaComments("-- UnitDebuff is gone\nlocal x = 1 --[[ GetMapNameByID ]]\n")), 0,
        "a comment may name a retired API")
    assertEqual(#retiredNames(stripLuaComments("local s = \"UnitDebuff\" -- why\n")), 1, "a string may not")
    assertEqual(#retiredNames(stripTocComments("# LibBabble was deleted\r\n## OptionalDeps: LibBabble-3.0\r\n")), 1,
        "a TOC comment line is dropped, a ## header line is scanned")
end)

test("removed APIs: no live file names a retired API, event or library", function()
    local files = { "OutfitterReborn.toc", "Bindings.xml" }
    for _, rel in ipairs(T.loadedAddonFiles) do files[#files + 1] = (rel:gsub("\\", "/")) end
    assertTrue(#files > 20, "the TOC walk listed almost nothing; nothing below can fail")
    local found = {}
    for _, rel in ipairs(files) do
        local text = assert(read(rel), rel .. " is live but not on disk")
        if rel:find("%.lua$") then
            text = stripLuaComments(text)
        elseif rel:find("%.toc$") then
            text = stripTocComments(text)
        end
        for _, what in ipairs(retiredNames(text)) do found[#found + 1] = rel .. ": " .. what end
    end
    assertEqual(#found, 0, table.concat(found, "; "))
end)
