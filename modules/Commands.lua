local _, NS = ...
-- modules/Commands.lua — NS.Commands: the slash outfit verbs' handlers (design §4.3.2; INV §4). The
-- verb table and the dispatcher are settings/Slash.lua's; each row there calls one function here,
-- behind the stand-down refusal (feature verbs) or not (`zone`, read-only and live).
--
-- THE OUTFIT ARGUMENT (INV §4). `rest` keeps its case and inner spacing; the name is matched
-- case-insensitively by NS.Outfits.FindByName. An argument opening with `[` is a macro conditional the
-- client's parser decides alone (NS.Slash.ParseArgument, H25); no clause matched is a silent no-op, as
-- it was. An empty argument names the current Complete outfit. Every wear, unwear, toggle and update
-- is a hardware event (`hw = true`, INV §16 quirk 22): the legacy verbs ran inside HasHWEvent.
--
-- CALLS (at call time, no nil guard; design §12): NS.Slash.ParseArgument, NS.Outfits, NS.Stack,
-- NS.Bank, NS.States.ZoneInfo, NS.Equip.Diagnostic.

local Commands = {}
NS.Commands = Commands

local L = NS.L

local function out(line) NS.Print(line) end

local function printAll(lines)
    for _, line in ipairs(lines) do out(line) end
end

--- The outfit a verb's argument names, or nil. Prints the one line for no Complete outfit and for an
--- unknown name; says nothing when a conditional chose no clause.
--- @param rest string|nil
--- @return string|nil id
function Commands.ResolveOutfit(rest)
    local arg = NS.Slash.ParseArgument(rest)
    if arg == nil then return nil end
    arg = arg:match("^%s*(.-)%s*$")
    if arg == "" then
        local id = NS.Stack.CurrentComplete()
        if not id then out(L["No Complete outfit is equipped."]) end
        return id
    end
    local id = NS.Outfits.FindByName(arg)
    if not id then out(L["Couldn't find an outfit named %s."]:format(arg)) end
    return id
end

-- A verb that acts on one resolved outfit.
local function outfitVerb(act)
    return function(rest)
        local id = Commands.ResolveOutfit(rest)
        if id then return act(id) end
    end
end

-- A fresh opts table per call: the stack keeps no reference, but a shared one could be written through.
local function hw() return { now = true, hw = true } end

Commands.Wear = outfitVerb(function(id) return NS.Stack.Wear(id, hw()) end)
Commands.Unwear = outfitVerb(function(id) return NS.Stack.Remove(id, hw()) end)
Commands.Toggle = outfitVerb(function(id) return NS.Stack.Toggle(id, hw()) end)

--- Snapshot the worn items into the outfit (SetToCurrent prints its own success line), then set the
--- title as the hardware wear would.
Commands.Update = outfitVerb(function(id)
    local ok, msg = NS.Outfits.SetToCurrent(id)
    if not ok then return out(msg) end
    NS.Stack.UpdateTitle(true)
    return ok
end)

-- The five bank verbs onto NS.Bank (INV §3.7); each answers `ok, why`.
local BANK = {
    Deposit        = function(id) return NS.Bank.Deposit(id) end,
    DepositUnique  = function(id) return NS.Bank.Deposit(id, true) end,
    DepositOthers  = function(id) return NS.Bank.DepositOthers(id) end,
    Withdraw       = function(id) return NS.Bank.Withdraw(id) end,
    WithdrawOthers = function(id) return NS.Bank.WithdrawOthers(id) end,
}

--- One bank verb on the outfit `rest` names; a refused move prints its reason.
--- @param method string  a BANK key
--- @param rest string|nil
--- @return boolean|nil ok
function Commands.Bank(method, rest)
    local id = Commands.ResolveOutfit(rest)
    if not id then return nil end
    local ok, why = BANK[method](id)
    if not ok and why then out(why) end
    return ok
end

--- /of missing: the report's lines, or the one refusal line while the bank is closed.
function Commands.Missing()
    local lines, why = NS.Bank.MissingReport()
    if not lines then return out(why) end
    printAll(lines)
end

--- /of zone (ShowZoneInfo, Outfitter.lua:5008-5042): what the zone detection sees, then the equipment
--- bracket's state with its STUCK tripwire.
function Commands.Zone()
    printAll(NS.States.ZoneInfo())
    printAll(NS.Equip.Diagnostic())
end

--- /of iteminfo <link>: every field, through the secret-safe reader.
function Commands.ItemInfo(rest)
    printAll(NS.ItemInfo.LinkInfoLines(rest))
end
