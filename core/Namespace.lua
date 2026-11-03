local addonName, NS = ...
-- core/Namespace.lua — the chat tag, the folder name, the brand and the version fallback.

-- The mandatory cyan bracketed tag (slash-commands-§4). Every tagged line leaves through NS.Print.
NS.PREFIX = "|cff00ffff[OR]|r"

NS.name = addonName

-- The brand in PLAIN TEXT (launcher-§1): the launcher label, the disabled refusal line, the debug
-- console title and the diagnostics markers all take this one spelling.
NS.BRAND = "Ka0s Outfitter Reborn"

-- The primary slash and its long alias, both registered on the one dispatcher (settings/Slash.lua).
NS.SLASH = "/of"
NS.SLASH_LONG = "/outfitter"

-- What NS.version reads when the TOC cannot be asked (a library-absent load, the headless harness
-- without metadata). core/EnvSetup.lua replaces NS.version with the TOC's own value at load.
NS.FALLBACK_VERSION = "1.1.0"
NS.version = NS.FALLBACK_VERSION
