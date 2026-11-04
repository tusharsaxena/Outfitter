local addonName, NS = ...
-- core/Constants.lua — fixed values resolved at load: the monospace face, the logo paths, the
-- frame-layering table and the hotkey message color.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's face, from the shared catalog (library-stack-§8). The fallback is a REAL
-- client font, never nil: SetFont on a bad path draws nothing and raises nothing.
C.FONT_MONO = (NS.MediaFont and NS.MediaFont("JetBrains Mono")) or STANDARD_TEXT_FONT

-- The logo paths (layout-§4), derived from the folder name: `<addon>` is the folder, lower-cased.
-- The 128x128 uncompressed 32-bit logo is the TOC IconTexture, the minimap button and the broker
-- icon. Never a Blizzard icon or a file id (anti-pattern #82).
C.LOGO_128 = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga"):format(addonName, addonName:lower())

-- The settings landing page's logo: the separate, larger file in the same folder (options-ui-§5).
C.LOGO = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())

-- THE LAYERS (frame-layering-§5). Every SetFrameStrata and SetFrameLevel in this addon reads this
-- table; no strata string and no bare level number sits at a call site. The whole stack, low to high:
--
--   Host-matched       CharacterFrame is the host of the two docked surfaces: the outfit window
--                      (the sheet holder's strata, its level + DOCK_OVER_HOST) and the slot
--                      checkboxes (the sheet's strata, the highest descendant + SLOT_ENABLES_OVER_HOST)
--   MEDIUM             HUD       the outfit bar: movable, clamped, toplevel
--   DIALOG             MODAL     the outfit, trigger, rebuild and progress dialogs; the LibKa0s icon
--                                browser (modules/IconBrowserSetup.lua), a modal over them in a band
--                                based UIParent + ICON_BROWSER (catcher +0, window +2, page +3, X +5)
--   DIALOG             (library) the LibKa0s debug console, which the icon browser and a dialog can
--                                cover; Blizzard StaticPopups, raised by NS.RaiseStaticPopups
--   FULLSCREEN         (library) the LibKa0s copy window the debug console's Copy opens
--   FULLSCREEN_DIALOG  POPUP     the LibKa0s menus, the icon browser's Wowhead link window; AceGUI's
--                                pullouts and the color picker the browser's toolbar opens share it
--   TOOLTIP            CURSOR    the compare tooltips; GameTooltip and ShoppingTooltip1/2 (Blizzard)
--
-- Levels inside a surface (base W): chrome W+1, content W+2, the scroll bar W+3, the row's secure
-- child row + ROW_SECURE, a cover W+30, the test strip W+40, the drag handle W+50 (its grip +10).
C.LAYERS = {
    STRATA = { HUD = "MEDIUM", MODAL = "DIALOG", POPUP = "FULLSCREEN_DIALOG", CURSOR = "TOOLTIP" },
    LEVEL  = {
        DOCK_OVER_HOST = 1, SLOT_ENABLES_OVER_HOST = 1, SLOT_CHECKBOX = 1, SHEET_BUTTON_OVER_CLOSE = 1,
        CHROME = 1, CONTENT = 2, ROW_CONTROLS = 1, ROW_SECURE = 2, SCROLL = 3,
        BAR_ROW = 1, BAR_BUTTON = 2, COVER = 30, MARKER = 40, HANDLE = 50,
        ICON_BROWSER = 1200,
    },
}

-- The default outfit icon (smoke round 2 design G1, D1): Blizzard's chest-armor art, fileID 132724,
-- untinted and zoom-cropped like any item icon. The last rung of NS.OutfitIcon (computed, never
-- stored), the broker's idle icon and the sheet button's icon. Game art, so the library's absence
-- does not take it away.
C.DEFAULT_OUTFIT_ICON = 132724

-- The hotkey "equipped / unequipped" line's color on UIErrorsFrame (INV §14): today's value.
C.OUTFIT_MESSAGE_COLOR = { r = 0.2, g = 0.75, b = 0.3 }
