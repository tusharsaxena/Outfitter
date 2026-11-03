-- tools/rekey-locales.lua — writes the six locale overlays from the legacy translations (design
-- §4.6 Re-key, H8; INV §15). Never loaded by the client, never shipped (.pkgmeta ignores tools/).
--
--   lua tools/rekey-locales.lua           (from the repo root) rewrite locales/{deDE,...}.lua
--   lua tools/rekey-locales.lua --check   write nothing; exit 1 if an overlay differs from its output
--
-- The legacy strings are keyed by Outfitter fields (cNewOutfit), the port's by the English string
-- itself (localization-§2). For every legacy locale file it:
--   1. reads OutfitterStrings.lua and the locale's file out of git at the conversion base (git show
--      7ea3dc3:<file>), runs each in a sandbox that records every field it assigns, and unfolds a
--      table field to one key per entry (cScriptCategoryName.PVP);
--   2. keeps a translation when its legacy field's English is a key of the enUS union (the TOC's
--      locales\enUS*.lua lines, read raw). Everything the port dropped, re-homed or rewrote (design
--      §4.6) has English no enUS file carries, so its translation falls away here and the string
--      falls back to the port's English;
--   3. holds back a translation equal to its English (the key's own fallback already answers it)
--      and one whose format directives (%s, %d, %.1f ...), read in order, are not a prefix of its
--      English's: the port formats the translation with the English's arguments, and string.format
--      raises on a directive the arguments do not answer (one more, or one of another type at its
--      place) but ignores arguments left over, so a translation that uses fewer is safe;
--   4. writes L["<English>"] = "<translation>" sorted by key, each line ending in a `-- legacy:`
--      note naming the field(s) it came from, and closes with `-- untranslated:` and
--      `-- format mismatch:` notes naming the fields step 3 held back (tests/test_locale.lua reads
--      every note for coverage).
-- Two fields with the same English and different translations keep the first field's in sorted
-- order; the report names the loser.
--
-- The report goes to stdout for the commit text (design §4.6 step 5), never to a file:
--   kept      the translations written
--   dropped   legacy fields whose English the port no longer carries
--   orphaned  fields the locale translated that the legacy English file no longer had
--
-- The legacy files are run, not parsed: they build strings with `..` and tables. Running text is
-- banned in everything the client loads or the suite runs (tests/test_no_loadstring.lua); tools/ is
-- outside that rule, as tools/legacy_capture.lua is, and the suite reaches this file's pure half
-- only (M.rekey, M.render, M.formats, M.formatSafe). `dofile`d, it runs nothing and returns M.

local M = {}

M.BASE = "7ea3dc3"
M.ENGLISH = "OutfitterStrings.lua"
M.LOCALES = {
    { locale = "deDE", file = "OutfitterStrings_de.lua" },
    { locale = "frFR", file = "OutfitterStrings_fr.lua" },
    { locale = "zhCN", file = "OutfitterStrings_cn.lua" },
    { locale = "zhTW", file = "OutfitterStrings_tw.lua" },
    { locale = "koKR", file = "OutfitterStrings_kr.lua" },
    { locale = "ruRU", file = "OutfitterStrings_ru.lua" },
}

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- ── capture (runs legacy text; the suite never calls it) ────────────────────────────────────

--- A proxy that records each string a chunk assigns through it into `seen`, keyed "a.b". Reads fall
--- through to what the chunk wrote, then to `base` (the English, which a locale file reads back).
local function recorder(path, base, seen)
    local store = {}
    return setmetatable({}, {
        __index = function(_, k)
            local v = store[k]
            if v == nil and type(base) == "table" then v = base[k] end
            if type(v) == "table" then return recorder(path .. k .. ".", v, seen) end
            return v
        end,
        __newindex = function(_, k, v)
            if type(v) == "table" then
                for sub, sv in pairs(v) do
                    if type(sv) == "string" then seen[path .. k .. "." .. tostring(sub)] = sv end
                end
            elseif type(v) == "string" then
                seen[path .. k] = v
            end
            store[k] = v
        end,
    })
end

--- The flat English table back as nested fields, for a locale file that reads Outfitter.cTitle.
local function nest(flat)
    local out = {}
    for path, v in pairs(flat) do
        local head, sub = path:match("^([^%.]+)%.(.+)$")
        if head and head ~= "_G" then
            out[head] = type(out[head]) == "table" and out[head] or {}
            out[head][sub] = v
        elseif not head then
            out[path] = v
        end
    end
    return out
end

--- Every string field one legacy strings file assigns: { [field] = string }; a global is "_G.NAME".
function M.capture(src, chunkname, locale, english)
    local seen = {}
    local env = setmetatable({
        Outfitter = recorder("", english and nest(english) or {}, seen),
        GetLocale = function() return locale end,
        C_AddOns = { GetAddOnMetadata = function() return "0" end },
    }, {
        __index = _G,
        __newindex = function(_, k, v) if type(v) == "string" then seen["_G." .. k] = v end end,
    })
    local chunk = assert(loadstring(src, "@" .. chunkname))
    setfenv(chunk, env)
    chunk("Outfitter", {})
    return seen
end

-- ── the pure half ───────────────────────────────────────────────────────────────────────────

--- A string's format directives as its conversion letters in order, comma-joined, `%%` left out.
function M.formats(s)
    local out = {}
    for conv in s:gsub("%%%%", ""):gmatch("%%[%d%$]*[-+ #0]*%d*%.?%d*([sdifgGeExXcoqu])") do out[#out + 1] = conv end
    return table.concat(out, ",")
end

--- True when `text` can be formatted with the arguments `en` takes: its directives, in order, are a
--- prefix of `en`'s (each is one letter, so a string prefix is a list prefix). string.format
--- ignores arguments left over, so fewer is safe; one more, or one of another type at its place,
--- would raise or misread an argument.
function M.formatSafe(en, text)
    local want, have = M.formats(en), M.formats(text)
    return want:sub(1, #have) == have
end

--- Re-keys one locale. `english` is the legacy English { [field] = string }, `isKey(s)` answers
--- whether `s` is an enUS key, `overlay` the locale's { [field] = string }. Returns
--- { entries = { [English] = { text, fields } }, dropped, orphaned, conflicts, formats, untranslated },
--- every list sorted. A translation equal to its English is `untranslated`: the key's own fallback
--- answers it, so it gets no line.
function M.rekey(english, isKey, overlay)
    local r = { entries = {}, dropped = {}, orphaned = {}, conflicts = {}, formats = {}, untranslated = {} }
    for _, field in ipairs(sortedKeys(overlay)) do
        local en, text = english[field], overlay[field]
        if en == nil then
            r.orphaned[#r.orphaned + 1] = field
        elseif not isKey(en) then
            r.dropped[#r.dropped + 1] = field
        elseif text == en then
            r.untranslated[#r.untranslated + 1] = field
        elseif not M.formatSafe(en, text) then
            r.formats[#r.formats + 1] = field
        else
            local e = r.entries[en]
            if not e then
                r.entries[en] = { text = text, fields = { field } }
            else
                e.fields[#e.fields + 1] = field
                if e.text ~= text then r.conflicts[#r.conflicts + 1] = field .. " (kept " .. e.fields[1] .. ")" end
            end
        end
    end
    return r
end

local ESCAPES = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

--- A double-quoted Lua literal; bytes at and over 0x80 (UTF-8) stay as they are.
function M.quote(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESCAPES[c] or ("\\%03d"):format(c:byte()) end) .. '"'
end

--- `-- <label>: a, b, ...` comment lines, wrapped near 100 columns; none for an empty list.
local function noteLines(lines, label, fields)
    local line = nil
    for _, field in ipairs(fields) do
        if line and #line + #field + 2 > 100 then
            lines[#lines + 1] = line
            line = nil
        end
        line = line and (line .. ", " .. field) or ("-- " .. label .. ": " .. field)
    end
    if line then lines[#lines + 1] = line end
end

--- One overlay file's text, CRLF, its gate the first line. `r` is M.rekey's result.
function M.render(locale, legacyFile, r)
    local lines = {
        'if GetLocale() ~= "' .. locale .. '" then return end',
        "-- locales/" .. locale .. ".lua — the " .. locale .. " overlay (design §4.6, H8). GENERATED by",
        "-- tools/rekey-locales.lua from the legacy " .. legacyFile .. " at " .. M.BASE .. "; regenerate,",
        "-- never hand-edit. A key the port rewrote has no line here and falls back to its English. Each",
        "-- line's `legacy:` note names the old field(s) it came from; the notes at the end name the",
        "-- fields that kept their English or failed the format check (tests/test_locale.lua, coverage).",
        "",
        "local _, NS = ...",
        "local L = NS.L",
        "",
    }
    for _, en in ipairs(sortedKeys(r.entries)) do
        local e = r.entries[en]
        lines[#lines + 1] = "L[" .. M.quote(en) .. "] = " .. M.quote(e.text) .. " -- legacy: " .. table.concat(e.fields, ", ")
    end
    if #r.untranslated + #r.formats > 0 then lines[#lines + 1] = "" end
    noteLines(lines, "untranslated", r.untranslated)
    noteLines(lines, "format mismatch", r.formats)
    return table.concat(lines, "\r\n") .. "\r\n"
end

-- ── the run ─────────────────────────────────────────────────────────────────────────────────

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function gitShow(file)
    local pipe = assert(io.popen("git show " .. M.BASE .. ":" .. file))
    local s = pipe:read("*a")
    pipe:close()
    assert(s ~= "", "git show " .. M.BASE .. ":" .. file .. " is empty (run from the repo root)")
    return s
end

--- The enUS union, read raw: every locales\enUS*.lua line of the TOC, in its order.
local function enUS()
    local NS = {}
    for line in assert(readFile("OutfitterReborn.toc"), "run from the repo root"):gmatch("[^\r\n]+") do
        local rel = line:gsub("\\", "/")
        if rel:match("^locales/enUS[%w_]*%.lua$") then assert(loadfile(rel))("OutfitterReborn", NS) end
    end
    return NS.L
end

local function main(check)
    local L = enUS()
    local function isKey(s) return rawget(L, s) ~= nil end
    local english = M.capture(gitShow(M.ENGLISH), M.ENGLISH, "enUS")
    local drift = 0
    for _, spec in ipairs(M.LOCALES) do
        local overlay = M.capture(gitShow(spec.file), spec.file, spec.locale, english)
        local r = M.rekey(english, isKey, overlay)
        local path = "locales/" .. spec.locale .. ".lua"
        local text = M.render(spec.locale, spec.file, r)
        if check then
            if readFile(path) ~= text then drift = drift + 1; print(path .. " differs from the re-key") end
        else
            local f = assert(io.open(path, "wb"))
            f:write(text)
            f:close()
        end
        local kept = 0
        for _ in pairs(r.entries) do kept = kept + 1 end
        print(("%s: kept %d, untranslated %d, dropped %d, orphaned %d, format mismatch %d, conflicts %d"):format(
            spec.locale, kept, #r.untranslated, #r.dropped, #r.orphaned, #r.formats, #r.conflicts))
        for _, k in ipairs({ "untranslated", "dropped", "orphaned", "formats", "conflicts" }) do
            if #r[k] > 0 then print("  " .. k .. ": " .. table.concat(r[k], ", ")) end
        end
    end
    return drift == 0 and 0 or 1
end

if arg and type(arg[0]) == "string" and arg[0]:match("rekey%-locales%.lua$") then
    os.exit(main(arg[1] == "--check"))
end

return M
