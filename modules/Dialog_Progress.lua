local _, NS = ...
-- modules/Dialog_Progress.lua — NS.ProgressDialog: the optimizer's progress window (design §7.6, §5.14).
--
-- DRIVEN BY THE BUS. The genetic search brackets itself with OPTIMIZE_STARTED (job), OPTIMIZE_PROGRESS
-- (job, noChange, maxNoChange, bestText) and OPTIMIZE_DONE (job, ok, reason); the simple search sends
-- none, so this window is the genetic search's only. STARTED shows "Optimizing <outfit> for <stat>"
-- and an empty bar, PROGRESS fills the bar by the unchanged-generation count against the limit and
-- writes "Best score: <text>", DONE of the shown job hides it. "High speed" flips `job.highSpeed`
-- (the search reads it per resume); Cancel is NS.Optimize.Cancel(job) for the shown job only, so it
-- can never end another search.
--
-- The receivers are installed once, by Install (NS.Dialogs.Resume, and every dialog that starts a
-- search); the bus record replays them across a stand-down. The frame is a `keep` dialog: CloseAll
-- passes it by, the stand-down closes it.
--
-- CALLS (at call time, no nil guard; design §12): NS.Optimize.Cancel.

local Pg = {}
NS.ProgressDialog = Pg

local L = NS.L
local D = NS.Dialogs

local WIDTH, HEIGHT = 320, 130

local frame, job, installed

local function build()
    if frame then return frame end
    local f = D.New({ name = "OutfitterRebornOptimizeProgress", key = "progress", width = WIDTH, height = HEIGHT,
                      title = "", keep = true, onHide = function() job = nil end })
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetSize(WIDTH - 28, 14)
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)
    NS.Skin.ApplyBarFill(f.bar)
    f.best = D.Label(f, "", "muted")
    f.best:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -8)
    f.highSpeed = D.Check(f, L["High speed"])
    f.highSpeed:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    f.highSpeed:SetScript("OnClick", function(self) if job then job.highSpeed = self:GetChecked() == true end end)
    f.cancel = D.Button(f, 80, 22, L["Cancel"])
    f.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.cancel:SetScript("OnClick", function() if job then NS.Optimize.Cancel(job) end end)
    frame = f
    return f
end

local function onStarted(_, j)
    if type(j) ~= "table" then return end
    build()
    job = j
    frame.title:SetText(L["Optimizing %s for %s"]:format(tostring(j.name or ""), tostring(j.statName or "")))
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    frame.best:SetText("")
    frame.highSpeed:SetChecked(j.highSpeed == true)
    D.Show(frame)
end

local function onProgress(_, j, noChange, maxNoChange, text)
    if not frame or j ~= job then return end
    frame.bar:SetMinMaxValues(0, NS.SafeNumber(maxNoChange, 1))
    frame.bar:SetValue(NS.SafeNumber(noChange, 0))
    frame.best:SetText(L["Best score: %s"]:format(tostring(text or "")))
end

local function onDone(_, j)
    if frame and j == job then frame:Hide() end
end

--- Install the three receivers, once.
function Pg.Install()
    if installed then return end
    installed = true
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.OPTIMIZE_STARTED, onStarted)
    target:RegisterMessage(NS.MSG.OPTIMIZE_PROGRESS, onProgress)
    target:RegisterMessage(NS.MSG.OPTIMIZE_DONE, onDone)
end

function Pg.IsOpen() return frame ~= nil and frame:IsShown() == true end

--- The job the window shows, or nil.
function Pg.Job() return job end

function Pg.Frame() return build() end
