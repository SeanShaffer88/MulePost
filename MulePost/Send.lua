-- MulePost - Send executor
--
-- SAFETY DESIGN (this file moves the player's items; read it like it):
-- * It runs ONLY on a plan the player saw in the review window and
--   confirmed with the Send button. Building a plan sends nothing.
-- * It never attaches money or sets a COD. There is deliberately no
--   call to any money API anywhere in this addon (the gate greps
--   for them), so "gold is never mailed" is a structural fact, not
--   a settings promise.
-- * It is EVENT-DRIVEN: one mail is attached and sent, then the
--   executor waits for MAIL_SEND_SUCCESS before touching the next.
--   MAIL_FAILED stops the pass immediately - remaining mails stay
--   in the review plan, unsent, for the player to inspect. No timer
--   loops, no blind retries.
-- * It refuses to start away from a mailbox (MAIL_SHOW state) or
--   while a pass is already running. MAIL_CLOSED mid-pass aborts.
-- * Bag/slot references stay valid across a pass because sending
--   removes only the attached stacks; WoW bags do not compact.
--   (Assumption flagged for the live-build spike test.)
local _, ns = ...

ns.atMailbox = false
ns.sending = false
local queue = {}
local queueIndex = 0
local hintShown = false

local function SendCurrent()
    local mail = queue[queueIndex]
    if not mail then return end
    for i = 1, #mail.stacks do
        local stack = mail.stacks[i]
        if PickupContainerItem and ClickSendMailItemButton then
            PickupContainerItem(stack.bag, stack.slot)
            ClickSendMailItemButton(i)
        end
    end
    if SendMail then
        SendMail(mail.recipient, "MulePost delivery (" .. #mail.stacks .. " stacks)", "")
    end
end

local function FinishPass(sentCount)
    ns.sending = false
    queue = {}
    queueIndex = 0
    ns.Print("send pass complete: " .. sentCount .. " mail(s) sent.")
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

local function OnMailEvent(event)
    if event == "MAIL_SHOW" then
        ns.atMailbox = true
        if not hintShown then
            hintShown = true
            ns.Print("mailbox open. /mp route builds your routing plan - nothing sends until you review it and press Send.")
        end
    elseif event == "MAIL_CLOSED" then
        ns.atMailbox = false
        if ns.sending then
            ns.sending = false
            queue = {}
            ns.Print("mailbox closed mid-pass - sending stopped. Sent mails are gone; the rest never left your bags.")
        end
    elseif event == "MAIL_SEND_SUCCESS" then
        if not ns.sending then return end
        local mail = queue[queueIndex]
        if mail then mail.sent = true end
        local sentCount = queueIndex
        queueIndex = queueIndex + 1
        if queueIndex > #queue then
            FinishPass(sentCount)
        else
            SendCurrent()
        end
    elseif event == "MAIL_FAILED" then
        if not ns.sending then return end
        ns.sending = false
        local remaining = #queue - queueIndex
        queue = {}
        queueIndex = 0
        ns.Print("a mail FAILED - the pass stopped. " .. remaining ..
            " mail(s) were not sent and are still in your review plan and your bags.")
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    end
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end
ns.OnMailEvent = OnMailEvent

local function StartSend(plan)
    if ns.sending then
        ns.Print("a send pass is already running.")
        return false
    end
    if not ns.atMailbox then
        ns.Print("open a mailbox first - MulePost only sends at a mailbox.")
        return false
    end
    if not plan then
        ns.Print("no plan to send. /mp route first, review it, then Send.")
        return false
    end
    queue = {}
    for i = 1, #plan.mails do
        local m = plan.mails[i]
        if not m.removed and not m.sent then queue[#queue + 1] = m end
    end
    if #queue == 0 then
        ns.Print("every mail in the plan is removed or already sent - nothing to do.")
        return false
    end
    ns.sending = true
    queueIndex = 1
    ns.Print("sending " .. #queue .. " mail(s). This stops instantly if any mail fails.")
    SendCurrent()
    return true
end
ns.StartSend = StartSend

local attached = false
local function Attach()
    if attached then return end
    attached = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:RegisterEvent("MAIL_CLOSED")
    f:RegisterEvent("MAIL_SEND_SUCCESS")
    f:RegisterEvent("MAIL_FAILED")
    f:SetScript("OnEvent", function(_, event) OnMailEvent(event) end)
    ns.sendAttached = true
end
ns.AttachSend = Attach
