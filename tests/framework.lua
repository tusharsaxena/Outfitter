-- tests/framework.lua -- registry, assertions and reporting.
--
-- COLLECT THEN RUN.  test() only records; nothing executes until Kit.run.  A case
-- body that ran at registration time would execute while its own suite file was
-- still being loaded, which makes "what has already happened when this runs?"
-- depend on where in the file the case sits -- and it would give --list a second
-- code path through the same function, so the inventory could disagree with the
-- run it claims to describe.

local Kit = {suites = {}, order = {}}

local currentSuite

function Kit.suite(name)
	currentSuite = {name = name, cases = {}}
	Kit.suites[name] = currentSuite
	Kit.order[#Kit.order + 1] = name
end

function Kit.test(name, body)
	assert(currentSuite, "test() before suite(): " .. tostring(name))
	assert(type(body) == "function", "test body must be a function: " .. tostring(name))
	for _, c in ipairs(currentSuite.cases) do
		assert(c.name ~= name, "duplicate case name in " .. currentSuite.name .. ": " .. name)
	end
	currentSuite.cases[#currentSuite.cases + 1] = {name = name, body = body}
end

-- ---------------------------------------------------------------------------
-- Assertions.  Each raises a table so run() can tell an assertion failure from a
-- crash in the code under test -- the difference between a red test and a broken
-- one, and worth keeping visible.
-- ---------------------------------------------------------------------------

local function fail(msg)
	error({__assert = true, msg = msg}, 2)
end
Kit.fail = fail

local function show(v)
	if type(v) == "string" then return string.format("%q", v) end
	if type(v) == "table" then
		local parts = {}
		for _, x in ipairs(v) do parts[#parts + 1] = tostring(x) end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end
Kit.show = show

function Kit.isTrue(v, what)
	if not v then fail((what or "value") .. ": expected truthy, got " .. show(v)) end
end

function Kit.isFalse(v, what)
	if v then fail((what or "value") .. ": expected falsy, got " .. show(v)) end
end

function Kit.equal(got, want, what)
	if got ~= want then
		fail((what or "value") .. ": expected " .. show(want) .. ", got " .. show(got))
	end
end

function Kit.notEqual(got, unwanted, what)
	if got == unwanted then
		fail((what or "value") .. ": expected anything but " .. show(unwanted))
	end
end

function Kit.isNil(v, what)
	if v ~= nil then fail((what or "value") .. ": expected nil, got " .. show(v)) end
end

function Kit.notNil(v, what)
	if v == nil then fail((what or "value") .. ": expected non-nil") end
end

function Kit.sameSet(got, want, what)
	local g, w = {}, {}
	for _, v in ipairs(got) do g[v] = true end
	for _, v in ipairs(want) do w[v] = true end
	local missing, extra = {}, {}
	for v in pairs(w) do if not g[v] then missing[#missing + 1] = tostring(v) end end
	for v in pairs(g) do if not w[v] then extra[#extra + 1] = tostring(v) end end
	table.sort(missing); table.sort(extra)
	if #missing > 0 or #extra > 0 then
		fail((what or "set") .. ": missing " .. show(missing) .. ", unexpected " .. show(extra))
	end
end

function Kit.raises(fn, what)
	local ok = pcall(fn)
	if ok then fail((what or "call") .. ": expected an error, got none") end
end

function Kit.noError(fn, what)
	local ok, err = pcall(fn)
	if not ok then
		if type(err) == "table" and err.__assert then error(err, 0) end
		fail((what or "call") .. ": unexpected error: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------------------

--- Emit the inventory: every suite and case, in registration order.
function Kit.list()
	local total = 0
	for _, suiteName in ipairs(Kit.order) do
		local s = Kit.suites[suiteName]
		print("")
		print("## " .. suiteName)
		print("")
		for _, c in ipairs(s.cases) do
			print("- " .. c.name)
			total = total + 1
		end
	end
	print("")
	print(("%d cases in %d suites"):format(total, #Kit.order))
	return total
end

--- Run everything.  Returns passed, failed.
function Kit.run(opts)
	opts = opts or {}
	local passed, failed, failures = 0, 0, {}
	for _, suiteName in ipairs(Kit.order) do
		local s = Kit.suites[suiteName]
		io.write(("%-34s "):format(suiteName))
		for _, c in ipairs(s.cases) do
			local ok, err = pcall(c.body)
			if ok then
				passed = passed + 1
				io.write(".")
			else
				failed = failed + 1
				io.write("F")
				local msg
				if type(err) == "table" and err.__assert then
					msg = err.msg
				else
					msg = "ERROR: " .. tostring(err)
				end
				failures[#failures + 1] = {suite = suiteName, case = c.name, msg = msg}
			end
		end
		io.write("\n")
	end
	if #failures > 0 then
		print("")
		for _, f in ipairs(failures) do
			print(("FAIL  %s / %s\n      %s"):format(f.suite, f.case, f.msg))
		end
	end
	print("")
	print(("%d passed, %d failed"):format(passed, failed))
	return passed, failed
end

return Kit
