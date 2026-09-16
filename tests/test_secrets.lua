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

Kit.test("no live file compares a Unit API result directly", function()
	-- Deprecated.lua is exempt: nothing in it runs.  Compat.lua is the seam itself.
	local risky = {"UnitHealth", "UnitPower", "UnitLevel", "UnitStat", "UnitHealthMax", "UnitPowerMax"}
	local bad = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if rel ~= "Deprecated.lua" and rel ~= "Compat.lua" and not rel:match("^tests/") then
			for lineNo, line in ipairs((function()
				local t = {}
				for l in Ctx.readLF(rel):gmatch("[^\n]*") do t[#t + 1] = l end
				return t
			end)()) do
				-- A commented-out line is not live code, and a plain `=` is an
				-- assignment -- only a comparison or arithmetic operator inspects
				-- the value, which is what raises on a secret.
				if not line:match("^%s*%-%-") then
					local code = line:gsub("%-%-.*$", "")
					for _, api in ipairs(risky) do
						if code:match(api .. "%b()%s*[<>][=]?")
						or code:match(api .. "%b()%s*[~=][=]")
						or code:match(api .. "%b()%s*[+%-*/]")
						or code:match("[<>~][=]?%s*" .. api .. "%b()")
						or code:match("[+%-*/]%s*" .. api .. "%b()") then
							bad[#bad + 1] = ("%s:%d  %s"):format(rel, lineNo, line:gsub("^%s+", ""))
						end
					end
				end
			end
		end
	end
	Kit.equal(#bad, 0, "unguarded comparison of a possibly-secret value:\n      " ..
		table.concat(bad, "\n      "))
end)
