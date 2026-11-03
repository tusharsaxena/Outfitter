-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-§5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repository edits.
-- Nothing is waived yet; a waiver arrives with the file that needs it, and its reason with it.

return {
    waived = {},
}
