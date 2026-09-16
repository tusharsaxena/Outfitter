-- tests/run.lua -- the headless runner.
--
--   lua tests/run.lua          -- from the repo root; exits non-zero on any failure
--   lua tests/run.lua --list   -- emit the case inventory and exit 0
--
-- Everything here is Outfitter's own.  There is no vendored kit: the Ka0s
-- collection's harness comes out of LibKa0s, and this addon must never carry
-- LibKa0s (see CLAUDE.md), so the framework, the mock and the loader are local.
--
-- The suite list is the one hand-kept list in the harness.  Adding a file to
-- tests/ without adding it here loads nothing and reads exactly like a clean run,
-- which is why test_harness.lua asserts the two agree.

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/run%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Kit    = dofile(root .. "/tests/framework.lua")
local Loader = dofile(root .. "/tests/loader.lua")
local Mock   = dofile(root .. "/tests/wow_mock.lua")

-- Context every suite gets, so no suite has to work out where the repo is or
-- reload the addon for itself.
local Ctx = {root = root, Kit = Kit, Loader = Loader, Mock = Mock}

--- Read a repo file as text.  Suites that inspect source rather than behaviour
--- (the structural ones) go through this so they all handle CRLF the same way.
function Ctx.read(rel)
	local f = assert(io.open(root .. "/" .. rel, "rb"), "cannot read " .. rel)
	local s = f:read("*a")
	f:close()
	return s
end

function Ctx.readLF(rel)
	return (Ctx.read(rel):gsub("\r\n", "\n"))
end

--- Every .lua file in the repo, repo-relative, sorted.
function Ctx.luaFiles(includeLibraries)
	local out = {}
	-- git ls-files, not find: `find` swept untracked scratch .lua files into the
	-- discipline checks, and the shell quoting broke on a repo path containing a
	-- single quote. This lists exactly what is committed.
	local pipe = io.popen("git -C " .. ("%q"):format(root) .. " ls-files '*.lua'")
	for line in pipe:lines() do
		local rel = line
		-- tests/ is the harness itself, not the addon.
		local skip = rel:match("^tests/") or (not includeLibraries and rel:match("^Libraries/"))
		if not skip then out[#out + 1] = rel end
	end
	pipe:close()
	assert(#out > 0, "found no Lua files")
	return out
end

-- The addon is loaded ONCE, before any suite runs, and every suite shares the
-- result.  Loading it per-suite would be forty seconds of nothing and would hide
-- order-dependent state rather than expose it.
Mock.install(root)
local loadedFiles, bomFiles = Loader.loadAddon(root)
Ctx.loadedFiles, Ctx.bomFiles = loadedFiles, bomFiles
Ctx.Outfitter = _G.Outfitter
Ctx.OutfitterAPI = _G.OutfitterAPI

-- The XML's frames, then the addon's own start-up.  Both are things the client
-- does between loading the files and the addon being usable, and most of the
-- interesting tables (cSlotIDs, the slash commands) do not exist until they have.
Ctx.xmlFrameCount = Mock.buildXMLFrames(root)   -- asserted by test_xml.lua
Ctx.initOK, Ctx.initError = pcall(function()
	Ctx.Outfitter:InitializeInstant()
	Ctx.Outfitter:Initialize()
end)

-- Now that BuiltinEvents exists, the mock can start rejecting event names the
-- client does not have.  Registrations made during load and init are already done
-- by this point, which is deliberate: this guards the addon's runtime behaviour,
-- not its start-up, and tightening it earlier would mean mocking the client's full
-- event registry rather than a broad net.
Ctx.clientEvents = dofile(root .. "/tests/client_events.lua")
local known = {}
for e in pairs(Ctx.clientEvents) do known[e] = true end
for e in pairs(Ctx.Outfitter.BuiltinEvents or {}) do known[e] = true end
Mock.knownEvents = known

local SUITES = {
	"test_harness.lua",
	"test_syntax.lua",
	"test_eol.lua",
	"test_toc.lua",
	"test_xml.lua",
	"test_load.lua",
	"test_compat.lua",
	"test_zones.lua",
	"test_scripts.lua",
	"test_locale.lua",
	"test_deprecated.lua",
	"test_secrets.lua",
	"test_outfits.lua",
	"test_commands.lua",
}
Ctx.SUITES = SUITES

for _, suite in ipairs(SUITES) do
	local chunk = assert(loadfile(root .. "/tests/" .. suite), "missing suite: " .. suite)
	chunk(Ctx)
end

if arg and arg[1] == "--list" then
	Kit.list()
	os.exit(0)
end

local _, failed = Kit.run()
os.exit(failed == 0 and 0 or 1)
