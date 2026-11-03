local _, NS = ...
-- modules/Dialog_TriggerFields.lua — NS.TriggerFields: the trigger parameter editors, nine field
-- types (design §7.6, §6.4, H13).
--
-- `TYPES[type] = { height, build(parent), set(editor, value, param), get(editor) }`, one per C20 type:
-- bool, number, string, the five lists (spelllist, itemlist, maplist, subzonelist, unitlist) and pet.
-- `get` answers the value in its stored shape and never the table `set` was handed, so an edit cannot
-- leak into the outfit before Done. Every editor carries `label` (NS.TriggerParams.Label) and `error`,
-- the line the dialog writes a refused value's reason into.
--
-- POOLED PER TYPE (INV §9.8). One array pool per type (NS.Pool.New / Acquire / ReleaseAll): a
-- trigger can have several params of one type (Swimming has four bools), so an editor is handed out
-- per field, and the keyed pool's one-object-per-key does not fit. The dialog releases them all on
-- every rebuild and close.
--
-- THE LISTS hold IDs and are shown as names, one entry per line with its own remove mark; a list
-- grows only through its capture buttons (NS.TriggerParams.Capture*), each a word, never an arrow
-- (localization-§7): names never flow back into a stored value (localization-§4). "Add a buff..." and
-- "Add equipped item..." open a menu of what there is to add.
--
-- THE PET field is a dropdown of None, the stored pet and the summoned one, plus "Use summoned pet".
-- The owned-pet list needs a journal walk Compat does not publish yet (core/Compat.lua stands at its
-- 1000-line budget), so it is not offered (deviation, P4.21 row).
--
-- CALLS (at call time, no nil guard; design §12): NS.TriggerParams (Label, Display, Normalize, MAX_LIST,
-- Capture*), NS.Dialogs (the controls), NS.OpenMenu, NS.MakeDropdown, NS.Pool.

local TF = {}
NS.TriggerFields = TF

local L = NS.L

local WIDTH = 360
local LINE_H = 16
local LIST_W, LIST_H = 300, 80

local function P() return NS.TriggerParams end

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- An editor's frame: its label on top, its error line at the bottom.
local function base(parent, height)
    local ed = CreateFrame("Frame", nil, parent)
    ed:SetSize(WIDTH, height)
    ed.label = NS.Dialogs.Label(ed, "")
    ed.label:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, 0)
    ed.error = NS.Dialogs.ErrorLine(ed)
    ed.error:SetPoint("BOTTOMLEFT", ed, "BOTTOMLEFT", 0, 0)
    return ed
end

local function setCommon(ed, param)
    ed.param = param
    ed.label:SetText(P().Label(param) or "")
    ed.error:SetText("")
end

-- ── bool, number, string ──────────────────────────────────────────────────────────────────────

local function buildBool(parent)
    local ed = base(parent, 24)
    ed.check = NS.Dialogs.Check(ed, "")
    ed.check:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, 0)
    return ed
end

local function setBool(ed, v, param)
    setCommon(ed, param)
    ed.label:SetText("")
    ed.check.label:SetText(P().Label(param) or "")
    ed.check:SetChecked(v == true)
end

local function buildInput(width)
    return function(parent)
        local ed = base(parent, 44)
        ed.input = NS.Dialogs.Edit(ed, width, 20)
        ed.input:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -14)
        ed.suffix = NS.Dialogs.Label(ed, "", "muted")
        ed.suffix:SetPoint("LEFT", ed.input, "RIGHT", 6, 0)
        return ed
    end
end

local function setInput(ed, v, param)
    setCommon(ed, param)
    ed.input:SetText(v == nil and "" or tostring(v))
    ed.suffix:SetText(param.suffix or "")
end

-- A number field answers the number typed, or the text itself, which the number type refuses.
local function getNumber(ed)
    local text = ed.input:GetText()
    return tonumber(text) or text
end

-- ── the lists ─────────────────────────────────────────────────────────────────────────────────

local refreshList

local function removeAt(ed, i)
    table.remove(ed.value, i)
    refreshList(ed)
end

local function newLine(ed, i)
    local line = CreateFrame("Frame", nil, ed.child)
    line:SetSize(LIST_W - 16, LINE_H)
    line:SetPoint("TOPLEFT", ed.child, "TOPLEFT", 2, -(i - 1) * LINE_H)
    line.text = NS.Dialogs.Label(line, "")
    line.text:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.remove = CreateFrame("Button", nil, line)
    line.remove:SetSize(12, 12)
    line.remove:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.remove.icon = line.remove:CreateTexture(nil, "ARTWORK")
    line.remove.icon:SetAllPoints(line.remove)
    line.remove.icon:SetTexture(NS.Icon("cancel"))
    NS.Skin.Mark(line.remove.icon)
    line.remove:SetScript("OnClick", function() removeAt(ed, i) end)
    ed.lines[i] = line
    return line
end

refreshList = function(ed)
    for i, entry in ipairs(ed.value) do
        local line = ed.lines[i] or newLine(ed, i)
        line.text:SetText(P().Display(ed.param, { entry }))
        line:Show()
    end
    for i = #ed.value + 1, #ed.lines do ed.lines[i]:Hide() end
    ed.child:SetHeight(math.max(1, #ed.value) * LINE_H)
    ed.bar:SetMinMaxValues(0, math.max(0, #ed.value * LINE_H - LIST_H))
end

--- Append a captured entry: nothing captured, or a full list, is the field's error line instead.
local function add(ed, entry)
    if entry == nil then
        ed.error:SetText(L["Nothing to add."])
        return
    end
    if #ed.value >= P().MAX_LIST then
        ed.error:SetText(L["The list is full."])
        return
    end
    local grown = copy(ed.value)
    grown[#grown + 1] = entry
    ed.value = P().Normalize(ed.param, grown)
    ed.error:SetText("")
    refreshList(ed)
end

-- A menu of what a capture could add: `each(addRow)` calls addRow(value) per candidate.
local function captureMenu(ed, button, each)
    NS.OpenMenu(button, function(root)
        local any = false
        each(function(value)
            any = true
            root:CreateButton(P().Display(ed.param, { value }), function() add(ed, value) end)
        end)
        if not any then root:CreateTitle(L["Nothing to add."]) end
    end)
end

local MAX_AURAS = 40

local function eachAura(addRow)
    for i = 1, MAX_AURAS do
        local id = P().CapturePlayerAura(i)
        if not id then return end
        addRow(id)
    end
end

local function eachWornItem(addRow)
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local id = P().CaptureSlotItem(slot)
        if id then addRow(id) end
    end
end

-- Each list type's capture buttons: { label, capture } adds what capture() answers; { label, nil, menu }
-- opens the menu `menu(addRow)` fills.
local CAPTURES = {
    spelllist   = { { L["Add last spell cast"], function() return P().CaptureLastCast() end },
                    { L["Add a buff..."], nil, eachAura } },
    itemlist    = { { L["Add item on cursor"], function() return P().CaptureCursorItem() end },
                    { L["Add equipped item..."], nil, eachWornItem } },
    maplist     = { { L["Add current zone"], function() return P().CaptureCurrentMap() end } },
    subzonelist = { { L["Add current subzone"], function() return P().CaptureCurrentSubzone() end } },
    unitlist    = { { L["Add current target"], function() return P().CaptureTarget() end } },
}

local function captureButtons(ed, kind)
    ed.capture = {}
    local x = 0
    for i, c in ipairs(CAPTURES[kind]) do
        local b = NS.Dialogs.Button(ed, 140, 20, c[1])
        b:SetPoint("TOPLEFT", ed.box, "BOTTOMLEFT", x, -4)
        local capture, menu = c[2], c[3]
        b:SetScript("OnClick", function(btn)
            if menu then return captureMenu(ed, btn, menu) end
            add(ed, capture())
        end)
        ed.capture[i] = b
        x = x + 146
    end
end

local function buildList(kind)
    return function(parent)
        local ed = base(parent, 14 + LIST_H + 28 + 14)
        ed.box = CreateFrame("ScrollFrame", nil, ed)
        ed.box:SetSize(LIST_W, LIST_H)
        ed.box:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -14)
        NS.Skin.Panel(ed.box)
        ed.child = CreateFrame("Frame", nil, ed.box)
        ed.child:SetSize(LIST_W - 14, LINE_H)
        ed.box:SetScrollChild(ed.child)
        ed.bar = CreateFrame("Slider", nil, ed)
        ed.bar:SetOrientation("VERTICAL")
        ed.bar:SetSize(10, LIST_H)
        ed.bar:SetPoint("TOPLEFT", ed.box, "TOPRIGHT", 2, 0)
        local track, thumb = ed.bar:CreateTexture(nil, "BACKGROUND"), ed.bar:CreateTexture(nil, "OVERLAY")
        track:SetAllPoints(ed.bar)
        thumb:SetSize(10, 20)
        ed.bar:SetThumbTexture(thumb)
        NS.Skin.ScrollBar(ed.bar, { track = track, thumb = thumb })
        ed.bar:SetScript("OnValueChanged", function(_, v) ed.box:SetVerticalScroll(v) end)
        ed.lines, ed.value = {}, {}
        captureButtons(ed, kind)
        return ed
    end
end

local function setList(ed, v, param)
    setCommon(ed, param)
    ed.value = copy(type(v) == "table" and v or {})
    refreshList(ed)
end

local function getList(ed) return copy(ed.value) end

-- ── pet ───────────────────────────────────────────────────────────────────────────────────────

local function petOptions(ed)
    local opts = { { value = "", label = L["None"] } }
    local summoned = P().CaptureSummonedPet()
    for _, guid in ipairs({ ed.value, summoned }) do
        if guid ~= "" and guid ~= opts[#opts].value then
            opts[#opts + 1] = { value = guid, label = P().Display(ed.param, guid) }
        end
    end
    return opts
end

local function refreshPet(ed)
    if not ed.dd then return end
    ed.dd:SetOptions(petOptions(ed))
    ed.dd:SelectValue(ed.value)
end

local function buildPet(parent)
    local ed = base(parent, 50)
    ed.dd = NS.MakeDropdown(ed, 180)
    if ed.dd then
        ed.dd:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -14)
        ed.dd.onSelect = function(v) ed.value = v end
    end
    ed.use = NS.Dialogs.Button(ed, 130, 20, L["Use summoned pet"])
    ed.use:SetPoint("TOPLEFT", ed, "TOPLEFT", 190, -14)
    ed.use:SetScript("OnClick", function()
        local guid = P().CaptureSummonedPet()
        if guid == "" then return ed.error:SetText(L["Nothing to add."]) end
        ed.value = guid
        refreshPet(ed)
    end)
    ed.value = ""
    return ed
end

local function setPet(ed, v, param)
    setCommon(ed, param)
    ed.value = type(v) == "string" and v or ""
    refreshPet(ed)
end

-- ── the registry ──────────────────────────────────────────────────────────────────────────────

local function inputType(width, get)
    return { height = 44, build = buildInput(width), set = setInput, get = get }
end

local function listType(kind)
    return { height = 14 + LIST_H + 28 + 14, build = buildList(kind), set = setList, get = getList }
end

TF.TYPES = {
    bool        = { height = 24, build = buildBool, set = setBool, get = function(ed) return ed.check:GetChecked() end },
    number      = inputType(60, getNumber),
    string      = inputType(300, function(ed) return ed.input:GetText() end),
    spelllist   = listType("spelllist"),
    itemlist    = listType("itemlist"),
    maplist     = listType("maplist"),
    subzonelist = listType("subzonelist"),
    unitlist    = listType("unitlist"),
    pet         = { height = 50, build = buildPet, set = setPet, get = function(ed) return ed.value end },
}

local pools = {}

--- An editor of `kind`, built into `parent` the first time a pool runs dry.
--- @return table
function TF.Acquire(kind, parent)
    local pool = pools[kind]
    if not pool then
        pool = NS.Pool.New()
        pools[kind] = pool
    end
    return NS.Pool.Acquire(pool, function() return TF.TYPES[kind].build(parent) end)
end

--- Park every editor (the dialog's rebuild and close).
function TF.ReleaseAll()
    for _, pool in pairs(pools) do
        NS.Pool.ReleaseAll(pool, function(ed) ed.param = nil end)
    end
end

--- An editor's value set, through its type.
function TF.Set(ed, v) return TF.TYPES[ed.param.type].set(ed, v, ed.param) end

--- An editor's value, in its stored shape.
function TF.Get(ed) return TF.TYPES[ed.param.type].get(ed) end
