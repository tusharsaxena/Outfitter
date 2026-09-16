-- The harness checking itself.  A suite file that exists but is not in run.lua's
-- list contributes nothing and reads exactly like a clean run.
local Ctx = ...
local Kit = Ctx.Kit

Kit.suite("harness")

Kit.test("every tests/test_*.lua is in run.lua's suite list", function()
	local onDisk = {}
	local pipe = io.popen("cd '" .. Ctx.root .. "/tests' && ls test_*.lua 2>/dev/null | sort")
	for line in pipe:lines() do onDisk[#onDisk + 1] = line end
	pipe:close()
	Kit.sameSet(onDisk, Ctx.SUITES, "suite files")
end)

Kit.test("tests/ is not shipped in the TOC", function()
	for _, rel in ipairs(Ctx.loadedFiles) do
		if rel:match("^tests/") then
			Kit.fail("TOC loads a test file into the client: " .. rel)
		end
	end
end)

Kit.test("the mock reports the version the TOC declares", function()
	local toc = Ctx.read("Outfitter.toc"):gsub("\r", "")
	local version = toc:match("##%s*Version:%s*([^\n]+)")
	Kit.notNil(version, "## Version in the TOC")
	Kit.equal(Ctx.Outfitter.cVersion, version, "Outfitter.cVersion")
end)

Kit.suite("packaging")

--- The top-level entries .pkgmeta keeps out of the zip.
local function ignored()
	local out, inIgnore = {}, false
	for line in Ctx.readLF(".pkgmeta"):gmatch("[^\n]*") do
		if line:match("^ignore:") then
			inIgnore = true
		elseif line:match("^%a") then
			inIgnore = false
		elseif inIgnore then
			local entry = line:match("^%s+%-%s*([%w%._/%-]+)%s*$")
			if entry then out[entry] = true end
		end
	end
	return out
end

Kit.test(".pkgmeta keeps the harness and the artwork out of the zip", function()
	local skip = ignored()
	-- Media is ~8 MB of source artwork and tests/ never runs in a client; both
	-- would otherwise sit in every player's AddOns folder doing nothing.
	for _, entry in ipairs({"Media", "tests", ".luacheckrc"}) do
		Kit.isTrue(skip[entry], ".pkgmeta should ignore " .. entry)
	end
end)

Kit.test(".pkgmeta names this addon as the package", function()
	Kit.notNil(Ctx.readLF(".pkgmeta"):match("package%-as:%s*Outfitter"), "package-as: Outfitter")
end)

Kit.test("nothing ignored by .pkgmeta is loaded by the TOC", function()
	-- An ignored path that the TOC loads would ship a broken addon: the file is
	-- listed, the client cannot find it, and the addon half-loads.
	local skip = ignored()
	local broken = {}
	for _, rel in ipairs(Ctx.loadedFiles) do
		local top = rel:match("^([^/]+)")
		if skip[top] or skip[rel] then broken[#broken + 1] = rel end
	end
	Kit.equal(#broken, 0, "TOC loads a file .pkgmeta excludes: " .. table.concat(broken, ", "))
end)

Kit.test("the logo artwork is not referenced by any shipped file", function()
	-- It is project artwork, not an in-game texture.  If something starts using
	-- one, excluding Media/ would break it.
	local users = {}
	for _, rel in ipairs(Ctx.luaFiles(true)) do
		if Ctx.readLF(rel):match("Media[\\/]") then users[#users + 1] = rel end
	end
	for _, rel in ipairs({"Outfitter.xml", "OutfitterBar.xml", "Outfitter.toc"}) do
		if Ctx.readLF(rel):match("Media[\\/]") then users[#users + 1] = rel end
	end
	Kit.equal(#users, 0, "shipped files referencing Media/: " .. table.concat(users, ", "))
end)
