-- tests/test_loadorder.lua — the runner's load list IS the TOC's (testing-§9): fed exactly the TOC's
-- files in the TOC's order, every derived path on disk, no libs/ path leaked in, the folders in the
-- layout-§1 order, and none of the legacy files back.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- Every TOC line, CR stripped.
local function tocLines()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = (line:gsub("\r$", "")) end
    f:close()
    return lines
end

test("load order: the runner loaded exactly the TOC's files, in the TOC's order", function()
    local fresh = T.Loader.tocFiles(T.root .. "/OutfitterReborn.toc")
    local loaded = T.loadedAddonFiles
    assertTrue(#fresh > 0, "the TOC derivation is empty; nothing below can fail")
    assertEqual(#loaded, #fresh, "the runner's list and the TOC differ in length")
    for i, path in ipairs(fresh) do assertEqual(loaded[i], path, "position " .. i) end
end)

test("load order: every derived path exists on disk", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        local f = io.open(T.root .. "/" .. path, "rb")
        assertTrue(f ~= nil, path .. " is in the TOC but not on disk")
        if f then f:close() end
    end
end)

test("load order: no libs/ path leaked into the addon's own list", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        assertFalse(path:find("^libs[/\\]") ~= nil, path .. " is a library file in the addon's list")
    end
end)

-- The folder rank of each TOC file line; nil for a comment, a blank or a header.
local RANK = { libs = 1, locales = 2, core = 3, defaults = 4, modules = 5, settings = 6 }

test("load order: the folders load libs, locales, core, defaults, modules, settings", function()
    local last, seen = 0, 0
    for _, line in ipairs(tocLines()) do
        if line ~= "" and not line:find("^#") then
            local folder = line:match("^([%w_]+)[\\/]")
            local rank = folder and RANK[folder]
            assertTrue(rank ~= nil, "a TOC line outside the six folders: " .. line)
            assertTrue(rank >= last, line .. " loads after a later folder")
            last, seen = rank, seen + 1
        end
    end
    assertTrue(seen > 0, "no file lines read")
end)

test("load order: each LOAD-BEARING note sits directly above a file line", function()
    local lines, notes = tocLines(), 0
    for i, line in ipairs(lines) do
        if line:find("^# LOAD%-BEARING:") then
            notes = notes + 1
            local j = i + 1
            -- A note may wrap onto further comment lines; the file line follows them.
            while lines[j] and lines[j]:find("^#") and not lines[j]:find("^# LOAD%-BEARING:") do j = j + 1 end
            local nextLine = lines[j] or ""
            assertTrue(nextLine ~= "" and not nextLine:find("^#"), "the note at line " .. i .. " is above no file")
        end
    end
    assertTrue(notes > 0, "the TOC carries no LOAD-BEARING note")
end)

test("load order: Bindings.xml, Deprecated.lua and the legacy files are not in the TOC", function()
    for _, line in ipairs(tocLines()) do
        if not line:find("^#") then
            assertFalse(line:find("Bindings%.xml") ~= nil, "Bindings.xml loads itself; it is never listed")
            assertFalse(line:find("Deprecated%.lua") ~= nil, "Deprecated.lua is dropped (R6)")
            assertFalse(line:find("^Libraries[\\/]") ~= nil, "Libraries/ is deleted (H15)")
            assertFalse(line == "Compat.lua", "the compat family is core/Compat.lua")
        end
    end
end)

test("load order: the namespace loads first in core and the printer before the addon object", function()
    local at = {}
    for i, path in ipairs(T.loadedAddonFiles) do at[(path:gsub("\\", "/"))] = i end
    assertTrue(at["locales/enUS.lua"] < at["core/Namespace.lua"], "NS.L before core")
    assertTrue(at["core/Namespace.lua"] < at["core/MediaSetup.lua"])
    assertTrue(at["core/MediaSetup.lua"] < at["core/Constants.lua"], "FONT_MONO resolves at file scope")
    assertTrue(at["core/CoreSetup.lua"] < at["core/OutfitterReborn.lua"], "the NS.Print reclaim")
    assertTrue(at["core/OutfitterReborn.lua"] < at["core/Database.lua"])
end)

-- core/Compat.lua loads BEFORE core/Secrets.lua (Secrets binds Compat's guards at file scope), so a
-- file-scope read of NS.Secrets in Compat would capture nil. A read is at file scope when it sits on
-- an unindented code line: every function body in this codebase is indented.
local function fileScopeSecretsReads(text)
    local hits = {}
    local n = 0
    for line in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        if code:find("^[^%s]") and code:find("NS%.Secrets") then hits[#hits + 1] = n end
    end
    return hits
end

test("load order: core/Compat.lua precedes core/Secrets.lua and never captures NS.Secrets at file scope", function()
    -- Mutation self-test: the rule catches a capture and lets a call-time read through.
    assertEqual(#fileScopeSecretsReads("local S = NS.Secrets\r\n"), 1)
    assertEqual(#fileScopeSecretsReads("local P = NS.Secrets.PlainNumber\n"), 1)
    assertEqual(#fileScopeSecretsReads("function X()\n    return NS.Secrets.PlainNumber(1)\nend\n"), 0)
    assertEqual(#fileScopeSecretsReads("-- NS.Secrets is reached at call time\n"), 0)

    local at = {}
    for i, path in ipairs(T.loadedAddonFiles) do at[(path:gsub("\\", "/"))] = i end
    assertTrue(at["core/Compat.lua"] ~= nil and at["core/Secrets.lua"] ~= nil, "both seams are in the TOC")
    assertTrue(at["core/CoreSetup.lua"] < at["core/Compat.lua"])
    assertTrue(at["core/Compat.lua"] < at["core/Secrets.lua"], "Secrets binds Compat's guards at file scope")
    assertTrue(at["core/Secrets.lua"] < at["core/OutfitterReborn.lua"])

    local f = assert(io.open(T.root .. "/core/Compat.lua", "r"))
    local hits = fileScopeSecretsReads(f:read("*a"))
    f:close()
    assertEqual(#hits, 0, "core/Compat.lua reads NS.Secrets at file scope, line " .. tostring(hits[1]))
end)

test("load order: the compat family is exactly core/Compat.lua", function()
    local family = {}
    for _, path in ipairs(T.loadedAddonFiles) do
        local rel = path:gsub("\\", "/")
        if rel:find("Compat[%w_]*%.lua$") then family[#family + 1] = rel end
    end
    assertEqual(#family, 1, "compat files in the TOC: " .. table.concat(family, ", "))
    assertEqual(family[1], "core/Compat.lua")
end)

-- ── the full P4 load list (design §1.2, laid down whole in P4.0) ───────────────────────────────────

-- Design §1.2's defaults/, modules/ and settings/ lines, in order. P4.0 writes every one of them (each
-- planned file a stub until its task lands it), so no parallel task ever edits the TOC's file lines.
local PLANNED = {
    "defaults/Profile.lua", "defaults/Items.lua", "defaults/Zones.lua", "defaults/TriggerData.lua",
    "defaults/Triggers.lua", "defaults/PreviewOutfits.lua",
    "modules/PlayerState.lua", "modules/ItemInfo.lua", "modules/Inventory.lua", "modules/Inventory_Lists.lua",
    "modules/IconBrowserSetup.lua", "modules/Outfits.lua", "modules/Outfits_Seed.lua", "modules/Outfits_Schema.lua",
    "modules/OutfitStack.lua", "modules/OutfitStack_Watch.lua",
    "modules/Equip.lua", "modules/Equip_Changes.lua", "modules/Equip_Moves.lua",
    "modules/EquipmentManager.lua", "modules/Bank.lua", "modules/ItemStats.lua", "modules/ItemStats_Sources.lua",
    "modules/Optimize.lua", "modules/Optimize_Genetic.lua", "modules/Companion.lua",
    "modules/Triggers_Params.lua", "modules/Triggers_Families.lua", "modules/Triggers_CondGeneral.lua",
    "modules/Triggers_CondTrade.lua", "modules/Triggers_CondQuest.lua", "modules/Triggers_Effects.lua",
    "modules/Triggers.lua", "modules/Triggers_Binder.lua", "modules/States.lua", "modules/States_Zone.lua",
    "modules/Commands.lua", "modules/Popups.lua", "modules/Tooltips.lua", "modules/Tooltips_Compare.lua",
    "modules/OutfitTooltip.lua", "modules/Sheet.lua", "modules/Dock.lua", "modules/Window.lua", "modules/Window_ListModel.lua",
    "modules/Window_Rows.lua", "modules/SlotEnables.lua", "modules/OutfitMenu.lua", "modules/UIDialogs.lua",
    "modules/Dialog_Outfit.lua", "modules/Dialog_Trigger.lua", "modules/Dialog_TriggerFields.lua",
    "modules/Dialog_Rebuild.lua", "modules/Dialog_Progress.lua",
    "modules/Bar.lua", "modules/Bar_Layout.lua", "modules/Bar_Chrome.lua",
    "modules/Bar_Buttons.lua", "modules/Broker.lua", "modules/QuickSlots.lua", "modules/QuickSlots_Sort.lua",
    "modules/Preview.lua", "modules/Api.lua", "modules/Diagnostics.lua",
    "settings/Schema.lua", "settings/Slash.lua", "settings/OptionsSetup.lua", "settings/General.lua",
    "settings/OutfitBar.lua", "settings/Profiles.lua",
}

--- Load position of each TOC file, by forward-slash path.
local function positions()
    local at = {}
    for i, path in ipairs(T.loadedAddonFiles) do at[(path:gsub("\\", "/"))] = i end
    return at
end

test("load order: the defaults, modules and settings lines are design §1.2's, in its order", function()
    local got = {}
    for _, path in ipairs(T.loadedAddonFiles) do
        local rel = path:gsub("\\", "/")
        if rel:find("^defaults/") or rel:find("^modules/") or rel:find("^settings/") then got[#got + 1] = rel end
    end
    assertEqual(#got, #PLANNED, "defaults/modules/settings lines in the TOC")
    for i, rel in ipairs(PLANNED) do assertEqual(got[i], rel, "position " .. i) end
end)

--- The addon folders' .lua on disk (tracked, or new and not yet added) that the TOC does not list.
local function orphans(listed)
    local out = {}
    local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard -- '
        .. '"locales/*.lua" "core/*.lua" "defaults/*.lua" "modules/*.lua" "settings/*.lua" 2>/dev/null')
    if p then
        for line in p:lines() do
            local f = io.open(T.root .. "/" .. line, "rb")
            if f then
                f:close()
                if not listed[line] then out[#out + 1] = line end
            end
        end
        p:close()
    end
    return out
end

test("load order: every .lua in the addon's folders is in the TOC (no orphan the client never loads)", function()
    local at = positions()
    -- red under: orphans() returning {} unconditionally (an empty listing reads as a clean tree).
    local probe = orphans({})
    assertTrue(#probe >= #T.loadedAddonFiles, "the walk found fewer files than the TOC lists; is git missing?")
    local lost = orphans(at)
    assertEqual(#lost, 0, "on disk, not in the TOC: " .. table.concat(lost, ", "))
end)

test("load order: the domain files load data first, then parameters, families, conditions, registry, binder", function()
    local at = positions()
    local chain = {
        "core/Secrets.lua", "defaults/Items.lua", "defaults/Zones.lua", "defaults/TriggerData.lua",
        "defaults/Triggers.lua", "modules/Triggers_Params.lua", "modules/Triggers_Families.lua",
    }
    for i = 2, #chain do
        assertTrue(at[chain[i - 1]] and at[chain[i]] and at[chain[i - 1]] < at[chain[i]],
            chain[i - 1] .. " loads before " .. chain[i])
    end
    for _, cond in ipairs({ "modules/Triggers_CondGeneral.lua", "modules/Triggers_CondTrade.lua",
                            "modules/Triggers_CondQuest.lua" }) do
        assertTrue(at["modules/Triggers_Families.lua"] < at[cond], "the families before " .. cond)
        assertTrue(at[cond] < at["modules/Triggers.lua"], cond .. " before the registry")
    end
    assertTrue(at["modules/Triggers.lua"] < at["modules/Triggers_Binder.lua"], "the registry before the binder")
    -- The three file-scope captures of NS.Secrets (the core\Secrets.lua note) follow it.
    for _, rel in ipairs({ "modules/ItemInfo.lua", "modules/States.lua", "modules/Inventory.lua" }) do
        assertTrue(at["core/Secrets.lua"] < at[rel], "core/Secrets.lua before " .. rel)
    end
end)

-- The LOAD-BEARING notes P4.0 adds above the domain lines (design §1.2): file line -> a fragment its
-- note must carry.
local NOTES = {
    ["defaults\\Triggers.lua"]        = "reads NS.L at FILE SCOPE",
    ["modules\\Triggers_Params.lua"]   = "NS.TriggerParams.TYPES",
    ["modules\\Triggers_Families.lua"] = "NS.TriggerFamilies",
}

test("load order: the domain lines carry their LOAD-BEARING notes", function()
    local lines = tocLines()
    local seen = 0
    for i, line in ipairs(lines) do
        local fragment = NOTES[line]
        if fragment then
            seen = seen + 1
            -- The note block directly above: its first line is the LOAD-BEARING one.
            local j = i - 1
            while lines[j - 1] and lines[j - 1]:find("^#") and not lines[j]:find("^# LOAD%-BEARING:") do j = j - 1 end
            local block = {}
            for k = j, i - 1 do block[#block + 1] = lines[k] end
            local text = table.concat(block, " ")
            assertTrue(text:find("^# LOAD%-BEARING:") ~= nil, line .. " has no LOAD-BEARING note above it")
            assertTrue(text:find(fragment, 1, true) ~= nil, line .. "'s note does not name " .. fragment)
        end
    end
    assertEqual(seen, 3, "the three annotated domain lines are in the TOC")
end)
