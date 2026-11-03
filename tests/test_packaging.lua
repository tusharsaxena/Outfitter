-- tests/test_packaging.lua — what reaches players (packaging, §1.6): the package folder is the TOC's
-- basename, every maintainer file is ignored, nothing ignored is loaded, and every media path the
-- addon names resolves under Interface\AddOns\OutfitterReborn\ to a shipped file.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- `.pkgmeta`: `package-as` and the `ignore:` list, comments and quotes stripped.
local function pkgmeta()
    local f = assert(io.open(T.root .. "/.pkgmeta", "r"))
    local packageAs, ignore, inIgnore = nil, {}, false
    for line in f:lines() do
        line = line:gsub("\r$", ""):gsub("%s+#.*$", "")
        local v = line:match("^package%-as:%s*(%S+)")
        if v then packageAs = v end
        if line:match("^ignore:") then
            inIgnore = true
        elseif line:match("^%S") then
            inIgnore = false
        elseif inIgnore then
            local entry = line:match("^%s*%-%s*(.-)%s*$")
            if entry and entry ~= "" then ignore[#ignore + 1] = (entry:gsub('^"(.*)"$', "%1")) end
        end
    end
    f:close()
    return packageAs, ignore
end

-- True when the packager's ignore `entry` (a path, a folder, or a `*` glob) covers `path`.
local function covers(entry, path)
    if entry:find("*", 1, true) then
        local pat = "^" .. entry:gsub("[%.%-%+%?%(%)%[%]%^%$]", "%%%0"):gsub("%*", "[^/]*") .. "$"
        return path:match(pat) ~= nil
    end
    return path == entry or path:sub(1, #entry + 1) == entry .. "/"
end

local function ignored(path, list)
    for _, entry in ipairs(list) do
        if covers(entry, path) then return entry end
    end
    return nil
end

test("packaging: the package folder is the TOC basename and the addon's folder name", function()
    local packageAs = pkgmeta()
    assertEqual(packageAs, "OutfitterReborn")
    assertEqual(packageAs, NS.name)
    local f = io.open(T.root .. "/" .. packageAs .. ".toc", "r")
    assertTrue(f ~= nil, packageAs .. ".toc is on disk")
    if f then f:close() end
end)

test("packaging: every maintainer file and folder is ignored", function()
    local _, list = pkgmeta()
    for _, path in ipairs({ ".luacheckrc", ".pkgmeta", ".gitignore", ".gitattributes", "docs/ARCHITECTURE.md",
                            "tests/run.lua", "tools/legacy_capture.lua", "CLAUDE.md", "DEPENDENCIES.md",
                            "media/logos/outfitterreborn.logo.png", "media/logos/outfitterreborn.logo.jpg",
                            "media/screenshots/outfitterreborn.screenshot.01.png", "_dev/x.lua", "a.bak" }) do
        assertTrue(ignored(path, list) ~= nil, path .. " would ship")
    end
end)

test("packaging: the player-facing files and the runtime logos ship", function()
    local _, list = pkgmeta()
    for _, path in ipairs({ "OutfitterReborn.toc", "README.md", "LICENSE", "Bindings.xml",
                            "media/logos/outfitterreborn.logo.tga", "media/logos/outfitterreborn.logo.128.tga",
                            "core/Namespace.lua", "libs/LibKa0s/LibKa0s.xml" }) do
        assertFalse(ignored(path, list) ~= nil, path .. " is ignored by " .. tostring(ignored(path, list)))
    end
end)

test("packaging: nothing the TOC loads is ignored", function()
    local _, list = pkgmeta()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    for line in f:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" and not line:find("^#") then
            local path = line:gsub("\\", "/")
            assertFalse(ignored(path, list) ~= nil, path .. " is loaded but ignored")
        end
    end
    f:close()
end)

test("packaging: every media path the addon names resolves to a shipped file", function()
    local _, list = pkgmeta()
    local prefix = "Interface\\AddOns\\OutfitterReborn\\"
    for _, full in ipairs({ NS.Constants.LOGO, NS.Constants.LOGO_128 }) do
        assertEqual(full:sub(1, #prefix), prefix, full)
        local rel = full:sub(#prefix + 1):gsub("\\", "/")
        local file = io.open(T.root .. "/" .. rel, "rb")
        assertTrue(file ~= nil, rel .. " is on disk")
        if file then file:close() end
        assertFalse(ignored(rel, list) ~= nil, rel .. " is named at run time but not shipped")
    end
end)

-- A path the addon hands the client, made relative to the package root: nil when it does not sit
-- under Interface\AddOns\OutfitterReborn\. Icon paths are extensionless (LibKa0s-Media `Icon`: the
-- client appends `.tga`), so `ext` names the file the client then opens.
local PREFIX = "Interface\\AddOns\\OutfitterReborn\\"
local function packaged(full, ext)
    if type(full) ~= "string" or full:sub(1, #PREFIX) ~= PREFIX then return nil end
    return full:sub(#PREFIX + 1):gsub("\\", "/") .. (ext or "")
end

local function onDisk(rel)
    local file = io.open(T.root .. "/" .. rel, "rb")
    if file then file:close() end
    return file ~= nil
end

-- The names of root CLAUDE.md's `LibKa0s icons:` line, read by the kit's own parser.
local function declaredIcons()
    local VendorSync = dofile(T.root .. "/tests/_kit/vendor_sync.lua")
    local f = assert(io.open(T.root .. "/CLAUDE.md", "rb"))
    local doc = f:read("*a")
    f:close()
    local decl = assert(VendorSync.iconDeclaration(doc), "CLAUDE.md declares its icons")
    return decl.names or {}
end

test("packaging: every declared icon resolves to a shipped file under the package folder", function()
    local _, list = pkgmeta()
    local names = declaredIcons()
    assertTrue(#names > 0, "the declaration names icons")
    for _, name in ipairs(names) do
        local rel = packaged(NS.Icon(name), ".tga")
        assertTrue(rel ~= nil, name .. " resolves under " .. PREFIX .. " (got " .. tostring(NS.Icon(name)) .. ")")
        if rel then
            assertTrue(onDisk(rel), rel .. " is on disk")
            -- red under: `- libs/LibKa0s/media/icons` added to the .pkgmeta ignores
            assertFalse(ignored(rel, list) ~= nil, rel .. " is drawn at run time but not shipped")
        end
    end
end)

test("packaging: each shipped icon set ships its license file beside it", function()
    local _, list = pkgmeta()
    local LICENSES = {
        [""] = "libs/LibKa0s/media/icons/LICENSE-open-iconic.txt",
        ph   = "libs/LibKa0s/media/icons/phosphor/LICENSE-phosphor.txt",
        gi   = "libs/LibKa0s/media/icons/game-icons/LICENSE-game-icons.txt",
    }
    local sets = {}
    for _, name in ipairs(declaredIcons()) do sets[name:match("^(%a+):") or ""] = true end
    for prefix in pairs(sets) do
        local rel = assert(LICENSES[prefix], "a license is known for the `" .. prefix .. "` set")
        assertTrue(onDisk(rel), rel .. " is on disk")
        -- red under: `- libs/LibKa0s/media/icons/LICENSE-open-iconic.txt` added to the .pkgmeta ignores
        assertFalse(ignored(rel, list) ~= nil, rel .. " is ignored by " .. tostring(ignored(rel, list)))
    end
end)

test("packaging: the debug console's face resolves to a shipped font", function()
    local _, list = pkgmeta()
    local rel = packaged(NS.Constants.FONT_MONO)
    assertTrue(rel ~= nil, "FONT_MONO resolves under " .. PREFIX .. " (got " .. tostring(NS.Constants.FONT_MONO) .. ")")
    if rel then
        assertTrue(onDisk(rel), rel .. " is on disk")
        -- red under: `- libs/LibKa0s/media/fonts` added to the .pkgmeta ignores
        assertFalse(ignored(rel, list) ~= nil, rel .. " is named at run time but not shipped")
    end
end)
