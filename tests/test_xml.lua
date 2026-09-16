-- The XML builds the whole window.  It is never loaded here -- there is no XML
-- engine -- so what is checkable is that it is well formed and that the things it
-- points at exist.
local Ctx = ...
local Kit = Ctx.Kit

Kit.suite("xml")

local XML_FILES = {"Outfitter.xml", "OutfitterBar.xml", "Bindings.xml"}

--- A crude well-formedness check: tags balance, ignoring comments, CDATA,
--- self-closing tags and the declaration.
local function unbalanced(src)
	src = src:gsub("<!%-%-.-%-%->", ""):gsub("<!%[CDATA%[.-%]%]>", ""):gsub("<%?.-%?>", "")
	local stack = {}
	for closing, name, rest in src:gmatch("<(/?)([%w_]+)(.-)>") do
		if closing == "/" then
			local top = table.remove(stack)
			if top ~= name then return ("</%s> closes <%s>"):format(name, tostring(top)) end
		elseif not rest:match("/%s*$") then
			stack[#stack + 1] = name
		end
	end
	if #stack > 0 then return "unclosed <" .. stack[#stack] .. ">" end
	return nil
end

Kit.test("every XML file is well formed", function()
	for _, rel in ipairs(XML_FILES) do
		local err = unbalanced(Ctx.read(rel))
		Kit.isNil(err, rel .. ": " .. tostring(err))
	end
end)

-- Two virtual templates nothing inherits.  Their handlers call methods that do
-- not exist, so instantiating one would raise on the first click -- but nothing
-- ever does.  Listed here so the handler check below stays meaningful for live
-- XML rather than being loosened to accommodate dead XML.
local DEAD_TEMPLATES = {
	Outfitter_ListButtonTemplate = true,
	Outfitter_ScrollFrameTemplate = true,
}

--- Strip the dead templates out of a source so their handlers are not checked.
local function withoutDeadTemplates(src)
	for name in pairs(DEAD_TEMPLATES) do
		src = src:gsub('<(%a+) name="' .. name .. '".-</%1>', "")
	end
	return src
end

Kit.test("no live XML handler calls a method the addon does not define", function()
	local missing = {}
	for _, rel in ipairs(XML_FILES) do
		local src = withoutDeadTemplates(Ctx.read(rel))
		for method in src:gmatch("Outfitter:([%w_]+)%s*%(") do
			if Ctx.Outfitter[method] == nil then
				missing[#missing + 1] = rel .. ": Outfitter:" .. method
			end
		end
	end
	local seen, uniq = {}, {}
	for _, m in ipairs(missing) do if not seen[m] then seen[m] = true; uniq[#uniq + 1] = m end end
	table.sort(uniq)
	Kit.equal(#uniq, 0, "XML calls methods that do not exist: " .. table.concat(uniq, ", "))
end)

Kit.test("the dead templates are still dead", function()
	-- If one of these gains an `inherits`, its missing handlers become a live
	-- crash, so the check above has to start covering it.
	for _, rel in ipairs(XML_FILES) do
		local src = Ctx.read(rel)
		for name in pairs(DEAD_TEMPLATES) do
			Kit.isNil(src:match('inherits="[^"]*' .. name),
				name .. " is now inherited but its handlers do not exist")
		end
	end
end)

Kit.test("every virtual template an element inherits is defined somewhere", function()
	local defined = {}
	for _, rel in ipairs(XML_FILES) do
		for name in Ctx.read(rel):gmatch('name="([%w_$]+)"[^>]-virtual="true"') do
			defined[name] = true
		end
	end
	-- Blizzard's own templates are not ours to verify; only Outfitter's own.
	local missing = {}
	for _, rel in ipairs(XML_FILES) do
		for list in Ctx.read(rel):gmatch('inherits="([^"]+)"') do
			for name in list:gmatch("[^,%s]+") do
				if name:match("^Outfitter") and not defined[name] then
					missing[#missing + 1] = name
				end
			end
		end
	end
	Kit.equal(#missing, 0, "inherits an undefined Outfitter template: " .. table.concat(missing, ", "))
end)

Kit.test("the slot enable checkboxes exist for every slot Outfitter manages", function()
	local src = Ctx.read("Outfitter.xml")
	local missing = {}
	for _, slot in ipairs(Ctx.Outfitter.cSlotNames) do
		if not src:match('name="OutfitterEnable' .. slot .. '"') then
			missing[#missing + 1] = slot
		end
	end
	Kit.equal(#missing, 0, "cSlotNames entries with no checkbox in the XML: " .. table.concat(missing, ", "))
end)

Kit.test("each checkbox anchors to the character sheet button for its slot", function()
	local src = Ctx.read("Outfitter.xml")
	local wrong = {}
	for _, slot in ipairs(Ctx.Outfitter.cSlotNames) do
		local block = src:match('name="OutfitterEnable' .. slot .. '".-</CheckButton>')
		if not block or not block:match('relativeTo="Character' .. slot .. '"') then
			wrong[#wrong + 1] = slot
		end
	end
	Kit.equal(#wrong, 0, "checkboxes not anchored to their slot button: " .. table.concat(wrong, ", "))
end)
