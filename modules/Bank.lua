local _, NS = ...
-- modules/Bank.lua — NS.Bank: deposit, withdraw and the missing-items report (design §5.13; INV §3.7;
-- Outfitter.lua:6912-7068, 7718-7747 at 7ea3dc3).
--
-- Every move refuses while stood down, unless the bank frame is open (NS.Inventory.BankOpen), and in
-- combat; it runs inside one equipment bracket (NS.Equip.Batch) and ends with
-- NS.Outfits.Changed(id, "bank"). The moves are NS.Changes.ForMoves lists carried out by
-- NS.Equip.Execute: a deposit into the bank's empty slots with the "bankFull" line, a withdraw into
-- the carried bags' with "withdrawFull". A deposit clears the window's selection first, so the items
-- it puts away are not recorded into the selected outfit (INV §3.7).
--
-- THE OTHERS. Deposit-others claims this outfit's items in the pass first, so an item it shares with
-- another outfit stays; one item two others share moves once. Withdraw-others is implemented (the
-- legacy one called an undefined ExecuteEquipmentChangeList2 and passed an undefined cache; INV §3.7
-- Fix): every other outfit's banked items come to the bags.
--
-- The warband bank is not scanned (O19; docs/known-limitations.md).
--
-- CALLS (at call time, no nil guard; design §12): NS.Inventory.BankOpen/IsBankBag/Cache/Missing,
-- NS.Outfits, NS.Stack.Select, NS.Equip.Batch/Execute, NS.Changes.ForMoves, NS.Moves and
-- NS.PlayerState.InCombat.

local Bank = {}
NS.Bank = Bank

local L = NS.L
local ID = NS.ItemData

--- Whether the bank frame is open.
--- @return boolean
function Bank.IsOpen()
    return NS.Inventory.BankOpen()
end

-- The refusal line for a move now, or nil.
local function refusal()
    local down = NS.StoodDownRefusal()
    if down then return down end
    if not NS.Inventory.BankOpen() then return L["The bank must be open"] end
    if NS.PlayerState.InCombat() then return L["Bank items can't be moved in combat."] end
    return nil
end

local function inBank(info) return info.loc ~= nil and NS.Inventory.IsBankBag(info.loc.bag) end
local function notInBank(info) return not inBank(info) end
local function never() return false end

-- Every outfit but `id`, in display order.
local function others(id)
    local O, out = NS.Outfits, {}
    for _, category in ipairs(O.Categories()) do
        for _, other in ipairs(O.Ids(category)) do
            if other ~= id then out[#out + 1] = O.Get(other) end
        end
    end
    return out
end

local function append(into, list)
    for _, c in ipairs(list) do into[#into + 1] = c end
end

local function execute(changes, toBank)
    if toBank then return NS.Equip.Execute(changes, NS.Moves.EmptyBankSlots(), "bankFull") end
    return NS.Equip.Execute(changes, NS.Moves.EmptyBagSlots(), "withdrawFull")
end

-- Refuse or run `body(rec)` inside one bracket, then announce the edit.
local function run(id, body)
    local why = refusal()
    if why then return false, why end
    local rec = NS.Outfits.Get(id)
    if not rec then return false end
    NS.Equip.Batch(body, rec)
    NS.Outfits.Changed(id, "bank")
    return true
end

-- ── deposit ───────────────────────────────────────────────────────────────────────────────────

-- Take out of `items` what `other` uses in the same slot or its alternate (the legacy SubtractOutfit
-- with alternate slots, Outfitter.lua:4381).
local function subtract(items, other, cache)
    local theirs = NS.Outfits.Items(other)
    for slot, item in pairs(items) do
        local alt = ID.FULL_ALT_SLOT[slot]
        if cache:Same(item, theirs[slot]) or (alt ~= nil and cache:Same(item, theirs[alt])) then
            items[slot] = nil
        end
    end
end

-- Unique: subtract the items of every other outfit that has nothing banked.
local function subtractShared(rec, items, cache)
    for _, other in ipairs(others(rec.id)) do
        local _, banked = NS.Inventory.Missing(other)
        if #banked == 0 then subtract(items, other, cache) end
    end
end

--- Put the outfit's items that are not in the bank into it. `uniqueOnly` keeps the items another
--- outfit with nothing banked also uses (INV §3.7).
--- @param id string
--- @param uniqueOnly boolean|nil
--- @return boolean ok, string|nil why
function Bank.Deposit(id, uniqueOnly)
    return run(id, function(rec)
        NS.Stack.Select(nil)
        local cache = NS.Inventory.Cache()
        local items = {}
        for slot, item in pairs(NS.Outfits.Items(rec)) do items[slot] = item end
        if uniqueOnly then subtractShared(rec, items, cache) end
        execute((NS.Changes.ForMoves(items, cache, notInBank)), true)
    end)
end

-- The moves of every other outfit's items `filter` keeps; with `claimKept`, the outfit's own items
-- are claimed in the pass first, so none of them moves.
local function othersMoves(rec, filter, claimKept)
    local cache, pass = NS.Inventory.Cache(), nil
    if claimKept then
        local _
        _, pass = NS.Changes.ForMoves(NS.Outfits.Items(rec), cache, never)
    end
    local all = {}
    for _, other in ipairs(others(rec.id)) do
        local changes
        changes, pass = NS.Changes.ForMoves(NS.Outfits.Items(other), cache, filter, pass)
        append(all, changes)
    end
    return all
end

--- Put every other outfit's items in the bank, except the ones this outfit uses.
--- @param id string
--- @return boolean ok, string|nil why
function Bank.DepositOthers(id)
    return run(id, function(rec)
        NS.Stack.Select(nil)
        execute(othersMoves(rec, notInBank, true), true)
    end)
end

-- ── withdraw ──────────────────────────────────────────────────────────────────────────────────

--- Bring the outfit's banked items to the bags.
--- @param id string
--- @return boolean ok, string|nil why
function Bank.Withdraw(id)
    return run(id, function(rec)
        execute((NS.Changes.ForMoves(NS.Outfits.Items(rec), NS.Inventory.Cache(), inBank)), false)
    end)
end

--- Bring every other outfit's banked items to the bags (INV §3.7 Fix).
--- @param id string
--- @return boolean ok, string|nil why
function Bank.WithdrawOthers(id)
    return run(id, function(rec)
        execute(othersMoves(rec, inBank, false), false)
    end)
end

-- ── the missing-items report ──────────────────────────────────────────────────────────────────

local function itemLine(item)
    return item.link or item.name or ("item:" .. tostring(item.id))
end

--- The /of missing report (Outfitter.lua:7718-7747): the intro and one line per missing item of every
--- outfit (an item two outfits miss is listed twice, as the intro says), or the none-missing line.
--- Nil and the refusal line while the bank is closed: a banked item would read as missing.
--- @return string[]|nil lines
--- @return string|nil why
function Bank.MissingReport()
    if not NS.Inventory.BankOpen() then
        return nil, L["You must have your bank open to generate a missing items report"]
    end
    local lines = {}
    local O = NS.Outfits
    for _, category in ipairs(O.Categories()) do
        for _, id in ipairs(O.Ids(category)) do
            for _, item in ipairs((NS.Inventory.Missing(O.Get(id)))) do
                if #lines == 0 then
                    lines[1] = L["Missing items (note that a missing item will be listed multiple times if it was used by multiple outfits):"]
                end
                lines[#lines + 1] = itemLine(item)
            end
        end
    end
    if #lines == 0 then lines[1] = L["No items are missing"] end
    return lines
end
