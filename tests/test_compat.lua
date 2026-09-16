-- Compat.lua is the seam every risky client call goes through.  Its secret-value
-- helpers are the difference between a handler completing and a handler aborting
-- with EquipmentUpdateCount stuck above zero.
local Ctx = ...
local Kit, API, Mock = Ctx.Kit, Ctx.OutfitterAPI, Ctx.Mock

Kit.suite("compat: secret values")

Kit.test("IsSecret is true for a secret and false for ordinary values", function()
	Kit.isTrue(API:IsSecret(Mock.SECRET), "IsSecret(secret)")
	for _, v in ipairs({1, "x", true}) do
		Kit.isFalse(API:IsSecret(v), "IsSecret(" .. tostring(v) .. ")")
	end
	Kit.isFalse(API:IsSecret(nil), "IsSecret(nil)")
	Kit.isFalse(API:IsSecret({}), "IsSecret(table)")
end)

Kit.test("Unsecret passes ordinary values through untouched", function()
	Kit.equal(API:Unsecret(42), 42, "Unsecret(42)")
	Kit.equal(API:Unsecret("link"), "link", "Unsecret(string)")
	Kit.equal(API:Unsecret(false), false, "Unsecret(false)")
end)

Kit.test("Unsecret swaps a secret for the default", function()
	Kit.isNil(API:Unsecret(Mock.SECRET), "Unsecret(secret) with no default")
	Kit.equal(API:Unsecret(Mock.SECRET, "fallback"), "fallback", "Unsecret(secret, default)")
end)

Kit.test("UnsecretNumber rejects a secret and anything non-numeric", function()
	Kit.equal(API:UnsecretNumber(7), 7, "UnsecretNumber(7)")
	Kit.isNil(API:UnsecretNumber(Mock.SECRET), "UnsecretNumber(secret)")
	Kit.isNil(API:UnsecretNumber("7"), "UnsecretNumber(string)")
	Kit.isNil(API:UnsecretNumber(nil), "UnsecretNumber(nil)")
	Kit.equal(API:UnsecretNumber(Mock.SECRET, -1), -1, "UnsecretNumber(secret, -1)")
	Kit.equal(API:UnsecretNumber("x", 0), 0, "UnsecretNumber(string, 0)")
end)

Kit.test("the helpers never raise, whatever they are handed", function()
	for _, v in ipairs({{}, print, 0/0, math.huge}) do
		Kit.noError(function() API:IsSecret(v) end, "IsSecret")
		Kit.noError(function() API:UnsecretNumber(v) end, "UnsecretNumber")
	end
end)
