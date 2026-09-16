-- tests/loader.lua -- reads the TOC and loads the addon into this Lua state.

local M = {}

--- The .lua files the TOC lists, in TOC order, repo-relative.
-- Derived rather than typed: a hand-kept copy drifts, and a short list loads
-- fewer files while reading exactly like a clean run.
function M.tocFiles(tocPath)
	local f = assert(io.open(tocPath, "r"), "cannot open " .. tocPath)
	local out = {}
	for line in f:lines() do
		line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:match("^#") and line:match("%.lua$") then
			out[#out + 1] = line
		end
	end
	f:close()
	assert(#out > 0, "no .lua files found in " .. tocPath)
	return out
end

--- Read a Lua source file, stripping a UTF-8 BOM if it has one.
-- Libraries/MC2DebugLib/MC2DebugLib.lua ships with one.  The client accepts it;
-- luac and Lua 5.1 both refuse the file outright, so without this the loader
-- would skip a library and the suite would silently be testing less than it says.
function M.readSource(path)
	local f = assert(io.open(path, "rb"), "cannot open " .. path)
	local src = f:read("*a")
	f:close()
	local hadBOM = src:sub(1, 3) == "\239\187\191"
	if hadBOM then src = src:sub(4) end
	return src, hadBOM
end

--- Load every TOC file, as the client would: chunk("Outfitter", NS).
--
-- ONE namespace table, shared by every file.  The client hands each of an addon's
-- files the same private table as its second vararg, and Outfitter relies on that
-- -- OutfitterPrefix.lua writes into it and OutfitterStrings.lua reads it back.
-- Handing each chunk a fresh table loads every file without error and produces an
-- addon assembled out of unrelated halves.
--
-- Returns the list of files loaded and the BOM files seen.
function M.loadAddon(root)
	local files, boms = M.tocFiles(root .. "/Outfitter.toc"), {}
	local NS = {}
	for _, rel in ipairs(files) do
		local path = root .. "/" .. rel
		local src, hadBOM = M.readSource(path)
		if hadBOM then boms[#boms + 1] = rel end
		local chunk, err = loadstring(src, "@" .. rel)
		if not chunk then error("load failed: " .. rel .. ": " .. tostring(err), 0) end
		local ok, e = pcall(chunk, "Outfitter", NS)
		if not ok then error("run failed: " .. rel .. ": " .. tostring(e), 0) end
	end
	return files, boms
end

return M
