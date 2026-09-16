-- The TOC is the load order and the shipping manifest.  Both directions matter:
-- a listed file that is missing breaks the addon at startup, and an unlisted file
-- that exists is dead weight nobody notices.
local Ctx = ...
local Kit = Ctx.Kit

Kit.suite("toc")

local function tocLines()
	local out = {}
	for line in Ctx.readLF("Outfitter.toc"):gmatch("[^\n]*") do out[#out + 1] = line end
	return out
end

Kit.test("every file the TOC lists exists on disk", function()
	local missing = {}
	for _, line in ipairs(tocLines()) do
		local rel = line:match("^%s*([%w_/%-%.]+%.[lx][um][al])%s*$")
		if rel and not line:match("^#") then
			local f = io.open(Ctx.root .. "/" .. rel, "r")
			if f then f:close() else missing[#missing + 1] = rel end
		end
	end
	Kit.equal(#missing, 0, "listed but missing: " .. table.concat(missing, ", "))
end)

Kit.test("every addon .lua on disk is in the TOC", function()
	local listed = {}
	for _, rel in ipairs(Ctx.loadedFiles) do listed[rel] = true end
	local orphans = {}
	for _, rel in ipairs(Ctx.luaFiles(true)) do
		-- tests/ is deliberately not shipped, and neither is anything under it.
		if not rel:match("^tests/") and not listed[rel] then orphans[#orphans + 1] = rel end
	end
	Kit.equal(#orphans, 0, "on disk but not in the TOC: " .. table.concat(orphans, ", "))
end)

Kit.test("the TOC declares the headers the client needs", function()
	local toc = Ctx.readLF("Outfitter.toc")
	for _, key in ipairs({"Interface", "Version", "Title", "Notes",
	                      "SavedVariables", "SavedVariablesPerCharacter"}) do
		Kit.notNil(toc:match("##%s*" .. key .. ":"), "## " .. key)
	end
end)

Kit.test("every declared interface version is a plausible retail build", function()
	local ifaces = Ctx.readLF("Outfitter.toc"):match("##%s*Interface:%s*([^\n]+)")
	Kit.notNil(ifaces, "## Interface")
	local n = 0
	for part in ifaces:gmatch("[^,%s]+") do
		local v = tonumber(part)
		Kit.notNil(v, "interface value " .. part .. " is a number")
		-- Six digits, expansion 10 or later: catches a transposed or truncated bump.
		Kit.isTrue(v >= 100000 and v <= 999999, "interface " .. part .. " in range")
		n = n + 1
	end
	Kit.isTrue(n > 0, "at least one interface version")
end)

Kit.test("the CurseForge project ID is present and numeric", function()
	-- The packager uploads to whatever project this names. A missing one fails the
	-- upload; a mistyped one succeeds against somebody else's project, which is
	-- the worse outcome and the quiet one.
	local id = Ctx.readLF("Outfitter.toc"):match("##%s*X%-Curse%-Project%-ID:%s*(%d+)")
	Kit.notNil(id, "## X-Curse-Project-ID")
	Kit.equal(id, "1698220", "the project ID")
end)

Kit.test("Deprecated.lua loads after Outfitter.lua", function()
	local seenOutfitter = false
	for _, rel in ipairs(Ctx.loadedFiles) do
		if rel == "Outfitter.lua" then seenOutfitter = true end
		if rel == "Deprecated.lua" then
			-- It hangs off the Outfitter table, so it cannot load first.
			Kit.isTrue(seenOutfitter, "Outfitter.lua loads before Deprecated.lua")
			return
		end
	end
	Kit.fail("Deprecated.lua is not in the TOC")
end)
