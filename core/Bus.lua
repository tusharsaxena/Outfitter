local addonName, NS = ...
-- core/Bus.lua — every message name declared ONCE (design §2.3), and the record of the addon's bus receivers.

-- A misspelled literal is a message nobody receives, and nothing goes red. Through a constant the
-- same typo is a nil name at the call site (architecture-§4). The wire name is
-- Ka0s_OutfitterReborn_<Pascal of the key>; the SCREAMING_SNAKE key never leaks into it, and these
-- literals appear in this file only (design §1.6 #11). Every message has exactly one sending file,
-- named on its `Sender:` line; tests/test_bus.lua holds every SendBus call site to it.
local MSG = {
    -- Sender: settings/Schema.lua (the announce). Payload: (path, value); profile and global paths
    -- only -- instance rows announce through NS.OutfitSchema (design §3.5).
    SETTINGS_CHANGED     = "Ka0s_OutfitterReborn_SettingsChanged",
    -- Sender: core/Database.lua. Payload: (key).
    PROFILE_CHANGED      = "Ka0s_OutfitterReborn_ProfileChanged",
    -- Sender: modules/Outfits.lua. Payload: (id).
    OUTFIT_ADDED         = "Ka0s_OutfitterReborn_OutfitAdded",
    -- Sender: modules/Outfits.lua. Payload: (id, name).
    OUTFIT_DELETED       = "Ka0s_OutfitterReborn_OutfitDeleted",
    -- Sender: modules/Outfits.lua, also for the instance-row writes the NS.OutfitSchema announce makes.
    -- Payload: (id, what).
    OUTFIT_EDITED        = "Ka0s_OutfitterReborn_OutfitEdited",
    -- Sender: modules/Outfits.lua. Payload: (id, oldName, newName).
    OUTFIT_RENAMED       = "Ka0s_OutfitterReborn_OutfitRenamed",
    -- Sender: modules/OutfitStack.lua. Payload: (id, layer, byTrigger).
    OUTFIT_WORN          = "Ka0s_OutfitterReborn_OutfitWorn",
    -- Sender: modules/OutfitStack.lua. Payload: (id, byTrigger).
    OUTFIT_REMOVED       = "Ka0s_OutfitterReborn_OutfitRemoved",
    -- Sender: modules/OutfitStack.lua. Payload: (id or nil).
    SELECTION_CHANGED    = "Ka0s_OutfitterReborn_SelectionChanged",
    -- Sender: modules/Equip.lua (on bracket close). Payload: none.
    STACK_CHANGED        = "Ka0s_OutfitterReborn_StackChanged",
    -- Sender: modules/Inventory.lua. Payload: (equippedChanged, bagsChanged).
    INVENTORY_CHANGED    = "Ka0s_OutfitterReborn_InventoryChanged",
    -- Sender: modules/OutfitStack_Watch.lua. Payload: none.
    SWAP_COMPLETE        = "Ka0s_OutfitterReborn_SwapComplete",
    -- Sender: modules/EquipmentManager.lua. Payload: none.
    EM_SYNCED            = "Ka0s_OutfitterReborn_EmSynced",
    -- Sender: modules/Optimize.lua. Payload: (job).
    OPTIMIZE_STARTED     = "Ka0s_OutfitterReborn_OptimizeStarted",
    -- Sender: modules/Optimize.lua. Payload: (job, noChangeCount, maxNoChange, bestText).
    OPTIMIZE_PROGRESS    = "Ka0s_OutfitterReborn_OptimizeProgress",
    -- Sender: modules/Optimize.lua. Payload: (job, ok, reason).
    OPTIMIZE_DONE        = "Ka0s_OutfitterReborn_OptimizeDone",
    -- Sender: modules/PlayerState.lua. Payload: (key, value), key one of combat, dead, casting, spec.
    PLAYER_STATE_CHANGED = "Ka0s_OutfitterReborn_PlayerStateChanged",
    -- Sender: modules/States.lua (NS.States.Set, shared by States.lua and States_Zone.lua).
    -- Payload: (stateId, isActive).
    STATE_CHANGED        = "Ka0s_OutfitterReborn_StateChanged",
    -- Sender: modules/States.lua. Payload: none.
    AURAS_SCANNED        = "Ka0s_OutfitterReborn_AurasScanned",
    -- Sender: modules/States.lua. Payload: none.
    TOOLTIP_SHOWN        = "Ka0s_OutfitterReborn_TooltipShown",
    -- Sender: modules/States.lua. Payload: none.
    TOOLTIP_HIDDEN       = "Ka0s_OutfitterReborn_TooltipHidden",
    -- Sender: modules/Triggers_Binder.lua. Payload: (count).
    TRIGGERS_REBOUND     = "Ka0s_OutfitterReborn_TriggersRebound",
    -- Sender: modules/Preview.lua. Payload: (active).
    PREVIEW_CHANGED      = "Ka0s_OutfitterReborn_PreviewChanged",
}

local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    -- Degrade, never error. The latch's standDown unregisters only on NS.addon, so the record MUST
    -- track every target it hands out: each target's message registrations are remembered, dropped
    -- at StandDown and replayed at StandUp; one registered while down is remembered and waits.
    -- Each handler stays isolated on this arm too: AceEvent dispatches through CallbackHandler,
    -- which calls every handler through securecallfunction, so one that raises cannot stop the rest.
    local function newRecord(d)
        local targets, down = {}, false        -- array: the replay order is the creation order
        local rec = { name = d and d.name }
        function rec.NewTarget()
            local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
            if not AceEvent then return nil end
            local t, held = {}, {}
            AceEvent:Embed(t)
            local reg, unreg, all = t.RegisterMessage, t.UnregisterMessage, t.UnregisterAllMessages
            t.RegisterMessage = function(self, name, handler)
                held[name] = handler or false
                if not down then return reg(self, name, handler) end
            end
            t.UnregisterMessage = function(self, name)
                held[name] = nil
                return unreg(self, name)
            end
            t.UnregisterAllMessages = function(self)
                for name in pairs(held) do held[name] = nil end
                return all(self)
            end
            targets[#targets + 1] = { t = t, held = held, reg = reg, all = all }
            return t
        end
        function rec.StandDown()
            if down then return 0 end
            down = true
            local n = 0
            for _, e in ipairs(targets) do
                for _ in pairs(e.held) do n = n + 1 end
                e.all(e.t)
            end
            return n
        end
        function rec.StandUp()
            if not down or (d and d.isDown and d.isDown()) then return 0, {} end
            down = false
            local n = 0
            for _, e in ipairs(targets) do
                for name, handler in pairs(e.held) do
                    e.reg(e.t, name, handler or nil)
                    n = n + 1
                end
            end
            return n, {}
        end
        return rec
    end
    Bus = {
        New = function(_, d) return newRecord(d) end,
        Catalog = function(_, messages) return messages end,
    }
end
NS.BusLib = Bus

-- The library validates the declaration at load and answers a STRICT copy, so a mistyped key raises
-- at the call site for a publisher as well as a subscriber. The stub hands back the plain table.
NS.MSG = Bus.Catalog(addonName, MSG)

-- One record per addon, beside its latch: it remembers every receiver it hands out, so the latch can
-- drop their message registrations at stand-down and replay them at stand-up (slash-commands-§7).
-- isDown resolves NS.IsStoodDown at call time: core/LifecycleSetup.lua loads after this file.
NS.busRecord = Bus:New({
    name   = addonName,
    isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
})

--- A receiver of the module's OWN (CallbackHandler keys callbacks by (message, target), so two
--- modules sharing one target clobber each other -- architecture-§4). nil when AceEvent is absent.
function NS.NewBusTarget()
    return NS.busRecord:NewTarget()
end

function NS.BusStandDown()
    return (NS.busRecord:StandDown())
end

--- Answers the replayed count and the rejected names (an array; always empty on the degraded arm).
function NS.BusStandUp()
    local replayed, rejected = NS.busRecord:StandUp()
    return replayed, rejected
end

--- The one sender: every message leaves through the addon object, so a receiver on any target hears
--- it. Called as NS.SendBus(NS.MSG.KEY, ...). Resolved at call time, because core/OutfitterReborn.lua
--- builds NS.addon after this file loads.
function NS.SendBus(name, ...)
    local addon = NS.addon
    if addon and addon.SendMessage then addon:SendMessage(name, ...) end
end
