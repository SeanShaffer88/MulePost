-- MulePost - Review window
-- THE window: the plan lives here, in full, before anything sends.
-- Every mail is a row (recipient, stacks, estimated postage, first
-- items) with a remove/restore toggle. The Send button states its
-- count. Postage is always labelled an estimate. House Forever UI
-- rules: BackdropTemplate frame, opaque WHITE8x8 panels, text
-- parented to its panel.
local _, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI
local MAX_ROWS = 10

local function MailSummary(mail)
    local names = {}
    for i = 1, math.min(#mail.stacks, 3) do
        names[#names + 1] = mail.stacks[i].name
    end
    local extra = #mail.stacks > 3 and (" (+" .. (#mail.stacks - 3) .. " more)") or ""
    return table.concat(names, ", ") .. extra
end
UI.MailSummary = MailSummary

local function Refresh()
    if not UI.frame then return end
    local plan = ns.currentPlan
    if UI.statusLabel then
        if ns.sending then
            UI.statusLabel:SetText("|cffffc266Sending...|r one mail at a time; a failure stops the pass.")
        elseif not ns.atMailbox then
            UI.statusLabel:SetText("Not at a mailbox - plans can be built and reviewed anywhere, sending cannot.")
        elseif plan then
            local t = ns.PlanTotals(plan)
            local cap = ns.db and ns.db.settings and ns.db.settings.postageCapCopper or 0
            local guard = ""
            if cap > 0 and t.postage > cap then
                guard = "  |cffff6666POSTAGE GUARD: total estimate " .. ns.CopperText(t.postage) ..
                    " exceeds your cap " .. ns.CopperText(cap) .. "|r"
            end
            UI.statusLabel:SetText("Plan: " .. t.mails .. " mail(s), " .. t.stacks ..
                " stacks, est. postage " .. ns.CopperText(t.postage) .. " (estimate)." .. guard)
        else
            UI.statusLabel:SetText("No plan yet - Route my bags scans your bags against your rules.")
        end
    end
    if UI.sendLabel then
        local t = plan and ns.PlanTotals(plan) or { mails = 0 }
        UI.sendLabel:SetText("Send " .. t.mails .. " mail(s)")
    end
    for i = 1, MAX_ROWS do
        local row = UI.rows[i]
        local mail = plan and plan.mails[i] or nil
        if mail then
            row.mail = mail
            local head
            if mail.sent then
                head = "|cff999999SENT|r "
            elseif mail.removed then
                head = "|cff666666REMOVED|r "
            else
                head = ""
            end
            row.fs:SetText(head .. "|cffffffff-> " .. mail.recipient .. "|r  " ..
                #mail.stacks .. " stacks  ~" .. ns.CopperText(mail.postage) .. "  " ..
                "|cffaaaaaa" .. MailSummary(mail) .. "|r")
            row.btnLabel:SetText(mail.removed and "restore" or "remove")
            row.button:Show()
            row.fs:Show()
        else
            row.mail = nil
            row.button:Hide()
            row.fs:Hide()
        end
    end
end
UI.Refresh = Refresh

local function Show()
    if not UI.frame then UI.Build() end
    if UI.frame then UI.frame:Show() Refresh() end
end
UI.Show = Show

local function Hide()
    if UI.frame then UI.frame:Hide() end
end
UI.Hide = Hide

local function Toggle()
    if UI.frame and UI.frame:IsShown() then Hide() else Show() end
end
UI.Toggle = Toggle

local function Build()
    if UI.frame then return end
    local f = CreateFrame("Frame", "MulePostFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 360)
    f:SetPoint("CENTER")
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.06, 0.05, 0.04, 0.97)
        f:SetBackdropBorderColor(0.5, 0.42, 0.3, 1)
    end
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:Hide()
    UI.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("|cffffc266MulePost|r - review before anything sends")
    UI.title = title

    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 20)
    close:SetPoint("TOPRIGHT", -8, -8)
    local cl = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cl:SetPoint("CENTER")
    cl:SetText("x")
    close:SetScript("OnClick", Hide)

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 14, -34)
    status:SetPoint("TOPRIGHT", -14, -34)
    status:SetJustifyH("LEFT")
    if status.SetWordWrap then status:SetWordWrap(true) end
    UI.statusLabel = status

    local routeBtn = CreateFrame("Button", nil, f)
    routeBtn:SetSize(150, 24)
    routeBtn:SetPoint("TOPLEFT", 14, -58)
    local rl = routeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rl:SetPoint("CENTER")
    rl:SetText("Route my bags")
    routeBtn:SetScript("OnClick", function()
        if ns.RouteCommand then ns.RouteCommand() end
    end)
    UI.routeBtn = routeBtn

    local sendBtn = CreateFrame("Button", nil, f)
    sendBtn:SetSize(150, 24)
    sendBtn:SetPoint("TOPLEFT", 172, -58)
    local sl = sendBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sl:SetPoint("CENTER")
    sl:SetText("Send 0 mail(s)")
    sendBtn:SetScript("OnClick", function()
        if ns.StartSend then ns.StartSend(ns.currentPlan) end
    end)
    UI.sendLabel = sl

    UI.rows = {}
    for i = 1, MAX_ROWS do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 14, -92 - (i - 1) * 22)
        fs:SetJustifyH("LEFT")
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(64, 18)
        btn:SetPoint("TOPRIGHT", -14, -92 - (i - 1) * 22)
        local bl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bl:SetPoint("CENTER")
        bl:SetText("remove")
        btn:SetScript("OnClick", function()
            local row = UI.rows[i]
            if row and row.mail and not row.mail.sent then
                row.mail.removed = not row.mail.removed
                Refresh()
            end
        end)
        btn:Hide()
        fs:Hide()
        UI.rows[i] = { fs = fs, button = btn, btnLabel = bl, mail = nil }
    end

    local foot = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    foot:SetPoint("BOTTOMLEFT", 14, 10)
    foot:SetJustifyH("LEFT")
    foot:SetText("Postage is an estimate (30c per stack) - the mailbox has the final word. Quest items are never routed. Gold is never attached: no code path exists that could do it.")
    UI.foot = foot

    Refresh()
end
UI.Build = Build
