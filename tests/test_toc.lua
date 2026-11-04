-- tests/test_toc.lua — the TOC header (toc-file-§1/§2): the fields in their order, the Title, the
-- version the namespace falls back to, an IconTexture that is on disk, the SavedVariables names, the
-- kept CurseForge project, and none of the fields this release drops (H20).

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The `## Field: value` lines, in order, and the same as a map.
local function header()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    local order, fields = {}, {}
    for line in f:lines() do
        line = line:gsub("\r$", "")
        local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if k then
            order[#order + 1] = k
            fields[k] = v
        end
    end
    f:close()
    return order, fields
end

test("toc: the header fields are written in the standard's order", function()
    local order = header()
    local want = { "Interface", "Title", "Notes", "Author", "Version", "IconTexture", "SavedVariables",
                   "OptionalDeps", "DefaultState", "Category-enUS", "X-License", "X-Standard",
                   "X-Curse-Project-ID" }
    assertEqual(#order, #want, "header field count")
    for i, k in ipairs(want) do assertEqual(order[i], k, "field " .. i) end
end)

test("toc: Title, Version and the brand agree", function()
    local _, f = header()
    assertEqual(f.Title, "Ka0s Outfitter Reborn")
    assertEqual(f.Title, NS.BRAND)
    assertEqual(f.Version, "1.1.0")
    assertEqual(f.Version, NS.FALLBACK_VERSION)
    assertEqual(f["X-License"], "MIT")
    assertEqual(f["X-Standard"], "https://github.com/tusharsaxena/WowAddonStandards")
    assertEqual(f["X-Curse-Project-ID"], "1698220")
    assertTrue(f.Interface:match("^%d+$") ~= nil, "Interface is a number: " .. tostring(f.Interface))
end)

test("toc: the IconTexture is the shipped 128 logo, under the folder name", function()
    local _, f = header()
    local prefix = "Interface\\AddOns\\OutfitterReborn\\"
    assertEqual(f.IconTexture:sub(1, #prefix), prefix)
    assertEqual(f.IconTexture, NS.Constants.LOGO_128)
    local rel = f.IconTexture:sub(#prefix + 1):gsub("\\", "/")
    local file = io.open(T.root .. "/" .. rel, "rb")
    assertTrue(file ~= nil, rel .. " is on disk")
    if file then file:close() end
end)

test("toc: the SavedVariables are the addon's two, derived from the folder name", function()
    local _, f = header()
    assertEqual(f.SavedVariables, "OutfitterRebornDB, OutfitterRebornPerfDB")
    assertTrue(f.SavedVariables:find(NS.name .. "DB", 1, true) == 1)
end)

test("toc: none of the dropped fields is back", function()
    local _, f = header()
    for _, k in ipairs({ "X-ReloadTag", "AddonCompartmentFunc", "AddonCompartmentFuncOnEnter",
                         "RequiredDeps", "Dependencies", "SavedVariablesPerCharacter" }) do
        assertEqual(f[k], nil, k)
    end
    for dep in (f.OptionalDeps or ""):gmatch("[^,%s]+") do
        assertTrue(dep ~= "LibKa0s", "LibKa0s is vendored, never a dependency")
    end
end)
