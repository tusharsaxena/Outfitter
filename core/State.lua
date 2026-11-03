local _, NS = ...
-- core/State.lua — session-only state: never in SavedVariables, reset by every /reload.

NS.State = NS.State or {
    -- The debug-logging flag (debug-logging-§5): default off, window-independent, never persisted.
    debug = false,
    -- Test mode (preview-mode): the outfit bar shows placeholder outfits. Never persisted.
    testMode = false,
    -- The original Outfitter addon is loaded beside this one (warned once at PLAYER_LOGIN).
    legacyLoaded = false,
}
