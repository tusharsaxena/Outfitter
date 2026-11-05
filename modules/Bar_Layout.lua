local _, NS = ...
-- modules/Bar_Layout.lua — the outfit bar's geometry as pure functions (smoke round 2 design G6, D8):
-- NS.Bar.Layout. Nothing here reads a frame or a setting; modules/Bar.lua hands every number in and
-- places the frames from the answer, so the suites pin the arithmetic without a client.
--
-- THE SHAPE. A category is a BLOCK: its label (a line `labelH` high, 0 with the labels off) over its
-- icons, `perLine` to a line (0 = one line), `size` px each and `spacing` px apart on both axes;
-- the defaults are 32 and 4 (smoke round 3 E8). Horizontal, a line is a row and the blocks stack
-- downward; vertical (`bar.vertical`), a line is a column and the blocks stand side by side. The bar
-- is the blocks `spacing` apart, `padding` px in from every edge, under `top` px of header band and
-- test strip, and never narrower than `minWidth` (the header's title and controls need the room).
--
-- GROWTH. `gx` is 1 when the bar grows right (its left edge stays put) and -1 when it grows left;
-- `gy` is -1 when it grows down and 1 when it grows up (QUADRANT's signs, modules/Bar.lua). The first
-- icon of a block sits at the corner the bar grows away from, and so does the first block: a bar
-- growing left is right-aligned, one growing up is bottom-aligned. The header stays at the top.
--
-- COORDINATES are the bar's TOPLEFT, x to the right and y DOWN, so a frame is placed with
-- SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y) whatever corner the bar itself is anchored at.

local Bar = NS.Bar
local Layout = {}
Bar.Layout = Layout

--- The narrowest the bar draws while it has a header: the title and two 18 px controls.
Layout.MIN_WIDTH = 110

local function count(v, low)
    v = tonumber(v) or low
    if v < low then return low end
    return math.floor(v)
end

--- One block's shape for `n` icons: icons per line, lines, width and height (the label included).
local function blockShape(n, spec)
    local S, G = spec.size, spec.spacing
    local per = n
    if spec.perLine > 0 and spec.perLine < n then per = spec.perLine end
    local lines = math.ceil(n / per)
    local along = per * S + (per - 1) * G
    local across = lines * S + (lines - 1) * G
    if spec.vertical then
        return { n = n, per = per, lines = lines, w = across, h = along + spec.labelH }
    end
    return { n = n, per = per, lines = lines, w = along, h = across + spec.labelH }
end

--- The content box the blocks need: width and height.
local function contentSize(blocks, spec)
    local G = spec.spacing
    if #blocks == 0 then return spec.size, spec.size end
    local sum, most = 0, 0
    for i, b in ipairs(blocks) do
        local along, across = b.h, b.w
        if spec.vertical then along, across = b.w, b.h end
        sum = sum + along + (i > 1 and G or 0)
        if across > most then most = across end
    end
    if spec.vertical then return sum, most end
    return most, sum
end

--- The offset of the `i`-th (0-based) of a run `extent` long, `step` between starts: counted from
--- the run's start when `fromStart`, else from its end.
local function slot(i, step, extent, size, fromStart)
    if fromStart then return i * step end
    return extent - size - i * step
end

--- Each icon of block `b`, in the block's own coordinates under its label.
local function iconPoints(b, spec)
    local S, step = spec.size, spec.size + spec.spacing
    local areaH = b.h - spec.labelH
    local out = {}
    for j = 1, b.n do
        local col, line = (j - 1) % b.per, math.floor((j - 1) / b.per)
        local x, y
        if spec.vertical then
            x = slot(line, step, b.w, S, spec.gx > 0)
            y = slot(col, step, areaH, S, spec.gy < 0)
        else
            x = slot(col, step, b.w, S, spec.gx > 0)
            y = slot(line, step, areaH, S, spec.gy < 0)
        end
        out[j] = { x = x, y = y + spec.labelH }
    end
    return out
end

--- Normalize the caller's spec: every number present and in range.
local function normalize(spec)
    return {
        size = count(spec.size, 1), spacing = count(spec.spacing, 0), padding = count(spec.padding, 0),
        perLine = count(spec.perLine, 0), labelH = count(spec.labelH, 0), top = count(spec.top, 0),
        minWidth = count(spec.minWidth, 0), vertical = spec.vertical == true,
        gx = (tonumber(spec.gx) or 1) < 0 and -1 or 1, gy = (tonumber(spec.gy) or -1) > 0 and 1 or -1,
        counts = type(spec.counts) == "table" and spec.counts or {},
    }
end

--- Place block `b` (index `i` of `blocks`) in the bar: its TOPLEFT and its label's rect.
local function placeBlock(b, i, blocks, s, W, H, cw)
    local P, G = s.padding, s.spacing
    local before = 0
    for k = 1, i - 1 do before = before + (s.vertical and blocks[k].w or blocks[k].h) + G end
    if s.vertical then
        b.x = s.gx > 0 and (P + before) or (W - P - before - b.w)
        b.y = s.gy < 0 and (s.top + P) or (H - P - b.h)
        b.label = { x = b.x, y = b.y, w = b.w }
    else
        b.x = s.gx > 0 and P or (W - P - b.w)
        b.y = s.gy < 0 and (s.top + P + before) or (H - P - before - b.h)
        b.label = { x = P, y = b.y, w = cw }
    end
end

--- The bar's size and every block's place: { width, height, blocks = { { x, y, w, h, label = { x,
--- y, w }, icons = { { x, y }, ... } }, ... } }, the icons' points in the bar's coordinates.
--- @param spec table  size, spacing, padding, perLine, vertical, labelH, top, minWidth, gx, gy,
---   counts (each category's icon count, in display order; the empty ones left out by the caller)
--- @return table
function Layout.Compute(spec)
    local s = normalize(spec or {})
    local blocks = {}
    for _, n in ipairs(s.counts) do
        n = count(n, 0)
        if n > 0 then blocks[#blocks + 1] = blockShape(n, s) end
    end
    local cw, ch = contentSize(blocks, s)
    local W = math.max(2 * s.padding + cw, s.minWidth)
    local H = s.top + 2 * s.padding + ch
    cw = W - 2 * s.padding
    for i, b in ipairs(blocks) do
        placeBlock(b, i, blocks, s, W, H, cw)
        b.icons = iconPoints(b, s)
        for _, p in ipairs(b.icons) do p.x, p.y = b.x + p.x, b.y + p.y end
    end
    return { width = W, height = H, blocks = blocks }
end
