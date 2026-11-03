-- tests/skin_surfaces.lua — this addon's painted surfaces, declared for the kit's skin-switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). tests/run.lua sets Kit.skinSwitch
-- from it. Loaded with dofile (it registers no case of its own).
--
-- THE SKELETON (P3 C8). No module that builds a frame exists yet, so the one surface declared is the
-- seam every owned window is painted through: a frame handed to NS.ApplySkin, which Core paints with
-- this owner's Shell and repaints on a switch (design §7.1: the window, the dialogs and the icon
-- chooser all take it). P4.30 replaces it with the design §9.5 builders, one per painted object: the
-- sheet button, the window, a row of each kind, a slot checkbox in each state, the footer buttons,
-- the four dialogs, a trigger field of each type, the icon chooser, the bar and a bar button, the
-- drag handle, the test strip and a compare tooltip.
--
-- THE GRAIN IS ONE PAINTED OBJECT. The kit spies on what `build` answers and on its regions and
-- children, and a surface passes when anything under it changes, so each entry answers the object
-- that draws, never a whole window.
--
-- ONE RUNNING INSTANCE, with the kit's paint recorder installed before anything loads, so the frames
-- remember how they were painted. Built on the first `build` and shared: the skin library belongs to
-- one instance.

return function(T)
    local inst

    local function live()
        if inst then return inst end
        local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")
        inst = T.load{ mutate = function(m)
            installPaint(m)
            m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
        end }
        return inst
    end

    --- A fresh backdrop frame painted through the shared window edge, as every owned window is.
    local function shell()
        local i = live()
        local f = i.mocks.CreateFrame("Frame", nil, i.mocks.UIParent, "BackdropTemplate")
        i.NS.ApplySkin(f)
        return f
    end

    return {
        owner = "OutfitterReborn",
        skin = function() return live().mocks.LibStub("LibKa0s-Skin-1.0") end,
        surfaces = {
            { name = "an owned window's edge (NS.ApplySkin)", build = shell },
        },
    }
end
