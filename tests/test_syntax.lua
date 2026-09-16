-- Every Lua file in the repo parses.
--
-- This is the check that was being run by hand all along, with one silent hole:
-- Libraries/MC2DebugLib/MC2DebugLib.lua opens with a UTF-8 BOM, which the client
-- accepts and luac rejects, so a `for f in *.lua; do luac -p $f; done` loop
-- reported an error for it that was easy to read as noise and skip.
local Ctx = ...
local Kit, Loader = Ctx.Kit, Ctx.Loader

Kit.suite("syntax")

Kit.test("every .lua file parses, BOM or not", function()
	local bad = {}
	for _, rel in ipairs(Ctx.luaFiles(true)) do
		local src = Loader.readSource(Ctx.root .. "/" .. rel)
		local chunk, err = loadstring(src, "@" .. rel)
		if not chunk then bad[#bad + 1] = rel .. ": " .. tostring(err) end
	end
	Kit.equal(#bad, 0, "files that do not parse: " .. table.concat(bad, "; "))
end)

Kit.test("the BOM file list is exactly what we know about", function()
	local withBOM = {}
	for _, rel in ipairs(Ctx.luaFiles(true)) do
		local _, hadBOM = Loader.readSource(Ctx.root .. "/" .. rel)
		if hadBOM then withBOM[#withBOM + 1] = rel end
	end
	-- Pinned rather than merely tolerated.  A new BOM file is worth knowing about:
	-- it means whatever produced it will trip luac for the next person too.
	Kit.sameSet(withBOM, {"Libraries/MC2DebugLib/MC2DebugLib.lua"}, "files with a UTF-8 BOM")
end)

Kit.test("no file uses a Lua 5.2+ construct the client rejects", function()
	local bad = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		local src = Ctx.read(rel)
		if src:match("[^%w_]goto%s") then bad[#bad + 1] = rel .. " (goto)" end
		if src:match("::%w+::") then bad[#bad + 1] = rel .. " (label)" end
	end
	Kit.equal(#bad, 0, "5.2-only syntax: " .. table.concat(bad, ", "))
end)
