-- Secret values.  A comparison against one raises, which aborts the handler --
-- and several handlers call BeginEquipmentUpdate before the risky line, leaving
-- EquipmentUpdateCount stuck above zero so equipment updates stop firing
-- altogether.  That is the bug this suite exists to keep out.
local Ctx = ...
local Kit, Mock, Outfitter = Ctx.Kit, Ctx.Mock, Ctx.Outfitter

Kit.suite("secrets: PlayerIsFull")

local function withState(t, fn)
	Mock.reset()
	for k, v in pairs(t) do Mock.state[k] = v end
	local r = fn()
	Mock.reset()
	return r
end

Kit.test("full health and power reads as full", function()
	local r = withState({health = 100, healthMax = 100, power = 100, powerMax = 100}, function()
		return Outfitter:PlayerIsFull()
	end)
	Kit.isTrue(r, "PlayerIsFull at 100/100")
end)

Kit.test("low health reads as not full", function()
	local r = withState({health = 10, healthMax = 100}, function()
		return Outfitter:PlayerIsFull()
	end)
	Kit.isFalse(r, "PlayerIsFull at 10/100 health")
end)

Kit.test("low mana reads as not full for a mana user", function()
	local r = withState({health = 100, healthMax = 100, power = 10, powerMax = 100, powerType = 0}, function()
		return Outfitter:PlayerIsFull()
	end)
	Kit.isFalse(r, "PlayerIsFull at 10/100 mana")
end)

Kit.test("a non-mana class ignores power entirely", function()
	local r = withState({health = 100, healthMax = 100, power = 0, powerMax = 100, powerType = 1}, function()
		return Outfitter:PlayerIsFull()
	end)
	Kit.isTrue(r, "a rage user at full health is full")
end)

Kit.test("the 85% threshold is where it says it is", function()
	Kit.isTrue(withState({health = 86, healthMax = 100}, function() return Outfitter:PlayerIsFull() end),
		"86/100 is full")
	Kit.isFalse(withState({health = 84, healthMax = 100}, function() return Outfitter:PlayerIsFull() end),
		"84/100 is not full")
end)

Kit.test("a secret health value does not raise", function()
	Kit.noError(function()
		withState({secret = {UnitHealth = true}}, function() return Outfitter:PlayerIsFull() end)
	end, "PlayerIsFull with secret health")
end)

Kit.test("every secret combination is survivable", function()
	local apis = {"UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType"}
	for i = 1, #apis do
		for j = i, #apis do
			local secret = {[apis[i]] = true, [apis[j]] = true}
			Kit.noError(function()
				withState({secret = secret}, function() return Outfitter:PlayerIsFull() end)
			end, "PlayerIsFull with " .. apis[i] .. " and " .. apis[j] .. " secret")
		end
	end
end)

Kit.test("an unreadable health value reports not-full rather than guessing", function()
	local r = withState({secret = {UnitHealth = true}}, function()
		return Outfitter:PlayerIsFull()
	end)
	-- Not-full leaves the dining outfit alone, which is the safe direction.
	Kit.isFalse(r, "PlayerIsFull with secret health")
end)

Kit.suite("secrets: equipment update balance")

Kit.test("a secret health value leaves the update count balanced", function()
	-- The regression that broke equipment updates: PlayerIsFull raised between
	-- BeginEquipmentUpdate and EndEquipmentUpdate, so the count never came back down.
	Mock.reset()
	Outfitter.EquipmentUpdateCount = 0
	Mock.state.secret.UnitHealth = true
	Mock.state.secret.UnitPower = true
	Outfitter.SpecialState = Outfitter.SpecialState or {}
	Kit.noError(function() Outfitter:UnitHealthOrManaChanged("player") end,
		"UnitHealthOrManaChanged with secret values")
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "EquipmentUpdateCount after the handler")
	Mock.reset()
end)

Kit.test("UpdateAuraStates leaves the update count balanced", function()
	Mock.reset()
	Outfitter.EquipmentUpdateCount = 0
	Mock.state.secret.UnitHealth = true
	Kit.noError(function() Outfitter:UpdateAuraStates() end, "UpdateAuraStates with secret health")
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "EquipmentUpdateCount after UpdateAuraStates")
	Mock.reset()
end)

Kit.suite("secrets: source discipline")

Kit.test("no live file reads a securable API outside the OutfitterAPI seam", function()
	-- The previous version looked for a call sitting NEXT TO a comparison operator,
	-- which is not how this codebase is written: it binds first and compares later
	-- (`local vHealth = UnitHealth("player")` ... `if vHealth < x`), so the check
	-- was near-inert.
	--
	-- This looks for the binding instead. Every live read of a securable API must
	-- pass through OutfitterAPI on the SAME line -- that is the seam, and a value
	-- that skips it is one comparison away from raising.
	--
	-- Exempt: Compat.lua, which IS the seam, and Deprecated.lua, where nothing runs.
	local RISKY = {
		"UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType",
		"UnitLevel", "UnitStat", "GetInventoryItemLink",
	}
	-- A call returning several values cannot be wrapped inline, so the codebase
	-- binds and then routes each local through the seam on the following lines
	-- (Outfitter:GetPlayerStat does exactly this). A short lookahead accepts that
	-- idiom; anything with no seam within it is a genuine unguarded read.
	local SEAM = "OutfitterAPI[:%.]%w*[Ss]ecret%w*"
	local LOOKAHEAD = 6

	local bad = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if rel ~= "Deprecated.lua" and rel ~= "Compat.lua" then
			local lines = {}
			for line in Ctx.readLF(rel):gmatch("([^\n]*)\n?") do lines[#lines + 1] = line end
			for lineNo, line in ipairs(lines) do
				local code = line:gsub("%-%-.*$", "")
				if not line:match("^%s*%-%-") then
					for _, api in ipairs(RISKY) do
						if code:match("[^%w_.:]" .. api .. "%s*%(") then
							local seamed = code:match(SEAM .. "%b()") ~= nil
							for ahead = lineNo + 1, math.min(lineNo + LOOKAHEAD, #lines) do
								if lines[ahead]:match(SEAM) then seamed = true; break end
							end
							if not seamed then
								bad[#bad + 1] = ("%s:%d  %s"):format(rel, lineNo, line:gsub("^%s+", ""))
							end
						end
					end
				end
			end
		end
	end
	table.sort(bad)
	Kit.equal(#bad, 0, "securable API read without the OutfitterAPI seam:\n      " ..
		table.concat(bad, "\n      "))
end)

Kit.test("the seam check would catch a regression", function()
	-- A check this shape is only worth having if it fails on the thing it names.
	-- Rather than trust that, exercise the matcher itself on a known-bad line.
	local bad = "\tif UnitHealth(\"player\") < vThreshold then"
	local code = bad:gsub("%-%-.*$", "")
	Kit.isTrue(code:match("[^%w_.:]UnitHealth%s*%(") ~= nil, "matcher sees the raw call")
	Kit.isFalse(code:match("OutfitterAPI[:%.]%w*[Ss]ecret%w*%b()") ~= nil, "and no seam on the line")

	local good = "\tlocal vHealth = OutfitterAPI:UnsecretNumber(UnitHealth(\"player\"))"
	Kit.isTrue(good:match("OutfitterAPI[:%.]%w*[Ss]ecret%w*%b()") ~= nil, "matcher accepts the seam")
end)

Kit.suite("secrets: fallback direction")

-- F-010.  PlayerIsFull returned true when power was unreadable, reporting the
-- player as full and taking the dining outfit off mid-meal -- the opposite of what
-- the function's own comment says. Health already fell back the documented way;
-- this pins both, so the pair cannot drift apart again.

local function fullWith(secret)
	Mock.reset()
	Mock.state.secret = secret
	local r = Outfitter:PlayerIsFull()
	Mock.reset()
	return r
end

Kit.test("unreadable health reports not-full", function()
	Kit.isFalse(fullWith({UnitHealth = true}), "secret health")
end)

Kit.test("unreadable power reports not-full, the same direction as health", function()
	Kit.isFalse(fullWith({UnitPower = true}), "secret power")
	Kit.isFalse(fullWith({UnitPowerMax = true}), "secret power max")
end)

Kit.test("an unreadable value never reports the player as full", function()
	for _, api in ipairs({"UnitHealth", "UnitHealthMax", "UnitPower",
	                      "UnitPowerMax", "UnitPowerType"}) do
		Kit.isFalse(fullWith({[api] = true}),
			api .. " secret should never report full -- that removes the dining outfit")
	end
end)

Kit.suite("secrets: mana history")

-- F-011.  A secret reading wiped PreviousManaLevel, so the next real sample read
-- as a drop and could cancel the Spirit outfit with no drop having happened.

Kit.test("a secret power reading does not wipe the last known level", function()
	Mock.reset()
	Outfitter.EquipmentUpdateCount = 0
	Mock.state.power = 500
	Outfitter:UnitHealthOrManaChanged("player")
	Kit.equal(Outfitter.PreviousManaLevel, 500, "a real sample is recorded")

	Mock.state.secret.UnitPower = true
	Outfitter:UnitHealthOrManaChanged("player")
	Kit.equal(Outfitter.PreviousManaLevel, 500,
		"the last known level should survive a secret window")
	Mock.reset()
end)

Kit.suite("equipment update count")

-- F-009.  The Begin/End pair is manual at seventeen sites; an error between them
-- stranded the count and stopped equipment updates for the session.

Kit.test("a balanced pair returns to zero", function()
	Outfitter.EquipmentUpdateCount = 0
	Outfitter:BeginEquipmentUpdate()
	Kit.equal(Outfitter.EquipmentUpdateCount, 1, "after Begin")
	Outfitter:EndEquipmentUpdate()
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "after End")
end)

Kit.test("an unmatched End refuses to go negative", function()
	-- Going negative was worse than the unmatched call: the `== 0` test would then
	-- never fire again and every later balanced pair was silently ignored.
	Outfitter.EquipmentUpdateCount = 0
	Outfitter:EndEquipmentUpdate("test")
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "clamped at zero")
	Outfitter:BeginEquipmentUpdate()
	Outfitter:EndEquipmentUpdate()
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "a later pair still balances")
end)

Kit.test("a stranded count can be cleared", function()
	Outfitter.EquipmentUpdateCount = 3
	Outfitter:ResetEquipmentUpdateCount()
	Kit.equal(Outfitter.EquipmentUpdateCount, 0, "after a reset")
end)

Kit.test("the reset is quiet when nothing is stranded", function()
	Outfitter.EquipmentUpdateCount = 0
	Ctx.Mock.calls.chat = nil
	Outfitter:ResetEquipmentUpdateCount()
	Kit.isNil(Ctx.Mock.calls.chat, "reset should say nothing when the count is clean")
end)
