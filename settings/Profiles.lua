local _, NS = ...
-- settings/Profiles.lua — the Profiles sub-page, registered LAST: AceDBOptions' own table, drawn by
-- AceConfigDialog into the library's panel, under one line saying what a profile does not hold.

local L = NS.L
local PAGE = "profiles"
local APP = "OutfitterReborn-Profiles"

-- Outfits are per character (H30, Q3): switching, copying or resetting a profile never touches them
-- (H7), and the page says so above AceDBOptions' own controls.
NS.PROFILES_NOTE = L["Profiles hold settings only. Outfits belong to each character and are not changed by switching, copying or resetting a profile."]

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    if not LibStub then return nil end
    local H = NS.Helpers
    if not (H and H.CreatePanel) then return nil end
    local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = NS.AceGUI or LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end
    if not (NS.db and NS.db.profile) then return nil end

    local options = AceDBOptions:GetOptionsTable(NS.db)
    options.args = options.args or {}
    options.args.outfitsNote = { type = "description", name = NS.PROFILES_NOTE, order = 0, fontSize = "medium" }
    AceConfig:RegisterOptionsTable(APP, options)
    -- No Defaults button: a profile page has no defaults of its own to restore.
    local ctx = H.CreatePanel("OutfitterRebornProfilesPanel", L["Profiles"], {
        pageKey        = PAGE,
        defaultsButton = false,
    })
    -- One container for the panel's life, parented onto the library's body (never onto an AceGUI
    -- widget's own frame -- options-ui-§19).
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.frame:SetParent(ctx.body)
    container.frame:ClearAllPoints()
    container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
    container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
    -- AceConfigDialog acquires the manager's widgets from AceGUI itself, past the Options instance's
    -- owner proxy, so the tree is painted for this addon's skin right after it is drawn (skinning-§3;
    -- nothing while the settings panel is left the client's). A skin switch re-renders the page.
    H.SetRenderer(ctx, function()
        container.frame:Show()
        AceConfigDialog:Open(APP, container)
        NS.SkinPaintAceTree(container)
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Profiles"])
end

NS.RegisterOptionsPage(PAGE, L["Profiles"], build)
