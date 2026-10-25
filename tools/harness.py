#!/usr/bin/env python3
"""MulePost startup + plan/send-simulation harness.

Mocks bags (one bag with cloth x2, herb, ore, leather, enchanting,
a consumable, a grey, a quest item, and one uncached item), the item
APIs, and the mail send functions (which only RECORD calls). Drives
the real code: classification, rules, plan building, review edits,
and the event-driven send pass including the failure stop and the
away-from-mailbox refusal. The mock proves logic; live mailbox
behaviour stays Unverified until a real test after launch.
"""
import pathlib
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MulePost"

PRELUDE = r"""
CHATLOG = {}
PICKUPS = {}
CLICKS = {}
MAILS = {}
NUM_BAG_SLOTS = 0
BAG0 = {
    [1] = { itemID = 2589, stackCount = 20, quality = 1 },
    [2] = { itemID = 2589, stackCount = 7, quality = 1 },
    [3] = { itemID = 2447, stackCount = 5, quality = 1 },
    [4] = { itemID = 2770, stackCount = 12, quality = 1 },
    [5] = { itemID = 2318, stackCount = 3, quality = 1 },
    [6] = { itemID = 10940, stackCount = 4, quality = 1 },
    [7] = { itemID = 13446, stackCount = 2, quality = 1 },
    [8] = { itemID = 1973, stackCount = 1, quality = 0 },
    [9] = { itemID = 30001, stackCount = 1, quality = 1 },
    [10] = { itemID = 99999, stackCount = 1, quality = 1 },
}
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 10 or 0 end,
    GetContainerItemInfo = function(bag, slot) return BAG0[slot] end,
}
INSTANT = {
    [2589] = { "Trade Goods", "Cloth" },
    [2447] = { "Trade Goods", "Herb" },
    [2770] = { "Trade Goods", "Metal & Stone" },
    [2318] = { "Trade Goods", "Leather" },
    [10940] = { "Trade Goods", "Enchanting" },
    [13446] = { "Consumable", "Potion" },
    [1973] = { "Miscellaneous", "Other" },
    [30001] = { "Quest", "Quest" },
}
NAMES = { [2589] = "Linen Cloth", [2447] = "Peacebloom", [2770] = "Copper Ore",
    [2318] = "Light Leather", [10940] = "Strange Dust",
    [13446] = "Major Healing Potion", [1973] = "Chipped Tooth",
    [30001] = "Sealed Quest Vial", [99999] = "Mystery" }
C_Item = {
    GetItemInfoInstant = function(id)
        local t = INSTANT[id]
        if not t then return nil end
        return id, t[1], t[2], "", 0, 7, 0
    end,
    GetItemInfo = function(id) return NAMES[id] end,
}
PickupContainerItem = function(bag, slot) PICKUPS[#PICKUPS + 1] = { bag, slot } end
ClickSendMailItemButton = function(i) CLICKS[#CLICKS + 1] = i end
SendMail = function(to, subject, body) MAILS[#MAILS + 1] = { to = to, subject = subject } end

local function newFS()
    local fs = { _text = "" }
    local methods = {
        GetText = function() return fs._text end,
        SetText = function(_, t) fs._text = tostring(t or "") end,
    }
    return setmetatable(fs, { __index = function(_, k)
        if methods[k] then return methods[k] end
        return function(...) return nil end
    end })
end
FRAMES = {}
local function newFrame(kind, name, parent, template)
    local f = { _name = name or "", _scripts = {}, _events = {}, _shown = true, _text = "" }
    local methods = {
        GetName = function() return f._name end,
        IsShown = function() return f._shown end,
        Show = function() f._shown = true end,
        Hide = function() f._shown = false end,
        SetText = function(_, t) f._text = tostring(t or "") end,
        GetText = function() return f._text end,
        SetScript = function(_, k, fn) f._scripts[k] = fn end,
        GetScript = function(_, k) return f._scripts[k] end,
        HookScript = function(_, k, fn) f._scripts[k] = fn end,
        RegisterEvent = function(_, e) f._events[e] = true end,
        UnregisterEvent = function(_, e) f._events[e] = nil end,
        CreateFontString = function() return newFS() end,
        StartMoving = function() end,
        StopMovingOrSizing = function() end,
    }
    if template and tostring(template):find("BackdropTemplate") then
        methods.SetBackdrop = function() end
        methods.SetBackdropColor = function() end
        methods.SetBackdropBorderColor = function() end
    end
    local CAPGATED = { SetBackdrop = true, SetBackdropColor = true,
                       SetBackdropBorderColor = true }
    setmetatable(f, { __index = function(_, k)
        if methods[k] then return methods[k] end
        if CAPGATED[k] then return nil end
        return function(...) return nil end
    end })
    FRAMES[#FRAMES + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = newFrame
UIParent = newFrame("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) CHATLOG[#CHATLOG + 1] = tostring(msg) end }
SlashCmdList = {}
GetBuildInfo = function() return "1.60.1", "70450", "Oct 2026", 16001 end
"""

DRIVER = r"""
local report = {}
local function note(s) report[#report + 1] = s end
local function try(label, fn)
    local ok, e = pcall(fn)
    note(label .. ": " .. (ok and "ok" or ("FAIL " .. tostring(e))))
    if not ok then error(label) end
end
local NS = {}
for _, item in ipairs(FILES) do
    local fn, err = load(item.code, item.name)
    if not fn then note("LOADFAIL " .. item.name .. ": " .. tostring(err)); return table.concat(report, "\n") end
    local ok, e = pcall(fn, "MulePost", NS)
    if not ok then note("RUNFAIL " .. item.name .. ": " .. tostring(e)); return table.concat(report, "\n") end
end
note("loaded " .. #FILES .. " files, categories=" .. #NS.CATEGORIES)
local function fire(ev, ...)
    for _, f in ipairs(FRAMES) do
        if f._events and f._events[ev] and f._scripts and f._scripts.OnEvent then
            local ok, e = pcall(f._scripts.OnEvent, f, ev, ...)
            if not ok then note("EVENTFAIL " .. ev .. ": " .. tostring(e)) end
        end
    end
end
fire("ADDON_LOADED", "MulePost")
fire("PLAYER_LOGIN")
note("login fired, sendAttached=" .. tostring(NS.sendAttached))

try("classifier: materials, consumable, junk, and the quest exclusion", function()
    assert(NS.Classify("Trade Goods", "Cloth", 1) == "cloth")
    assert(NS.Classify("Trade Goods", "Herb", 1) == "herb")
    assert(NS.Classify("Trade Goods", "Metal & Stone", 1) == "ore")
    assert(NS.Classify("Trade Goods", "Leather", 1) == "leather")
    assert(NS.Classify("Trade Goods", "Enchanting", 1) == "enchanting")
    assert(NS.Classify("Consumable", "Potion", 1) == "consumable")
    assert(NS.Classify("Miscellaneous", "Other", 0) == "junk")
    assert(NS.Classify("Quest", "Quest", 1) == nil, "quest items must never route")
    assert(NS.Classify("Quest", "Quest", 0) == nil, "even a grey quest item must never route")
    assert(NS.Classify("Weapon", "Swords", 2) == "other")
end)
try("rules: add/list, bad category refused, 8-rule cap enforced", function()
    local slash = SlashCmdList["MULEPOST"]
    slash("rule add cloth Tailoralt")
    slash("rule add herb Alchalt")
    slash("rule add junk Bankalt")
    slash("rule add other Bankalt")
    slash("rule add ore Minertalt")
    slash("rule add leather Leatheralt")
    slash("rule add enchanting Enchalt")
    slash("rule add consumable Consalt")
    assert(#NS.db.rules == 8, "expected 8 rules, got " .. #NS.db.rules)
    slash("rule add cloth Ninthalt")
    assert(#NS.db.rules == 8, "9th rule was not refused")
    slash("rule add bogus Someone")
    assert(#NS.db.rules == 8, "bogus category was accepted")
    slash("rule del 8")
    assert(#NS.db.rules == 7, "del failed")
    slash("rule add consumable Consalt")
    assert(#NS.db.rules == 8, "re-add failed")
end)
try("route builds the expected plan: recipients, totals, skipped/excluded counts", function()
    local plan = NS.RouteCommand()
    assert(plan.skipped == 1, "uncached item not counted, skipped=" .. tostring(plan.skipped))
    assert(plan.excluded == 1, "quest item not excluded, excluded=" .. tostring(plan.excluded))
    assert(plan.unrouted == 0, "everything should route, unrouted=" .. plan.unrouted)
    local t = NS.PlanTotals(plan)
    assert(t.mails == 7, "expected 7 mails, got " .. t.mails)
    assert(t.stacks == 8, "expected 8 stacks, got " .. t.stacks)
    assert(t.postage == 240, "expected 240c estimate, got " .. t.postage)
    local clothMail = nil
    for i = 1, #plan.mails do
        if plan.mails[i].recipient == "Tailoralt" then clothMail = plan.mails[i] end
    end
    assert(clothMail and #clothMail.stacks == 2, "cloth stacks not grouped into one mail")
end)
try("plan builder chunks at 12 stacks and falls through to other", function()
    local inv = {}
    for i = 1, 13 do inv[i] = { bag = 0, slot = i, name = "Cloth" .. i, count = 1, category = "cloth" } end
    inv[14] = { bag = 0, slot = 14, name = "Bar", count = 1, category = "ore" }
    local plan = NS.BuildPlan(inv, { { category = "cloth", recipient = "T" }, { category = "other", recipient = "B" } })
    assert(#plan.mails == 3, "expected 2 cloth mails + 1 other mail, got " .. #plan.mails)
    assert(#plan.mails[1].stacks == 12 and #plan.mails[2].stacks == 1, "chunking wrong")
    assert(plan.mails[1].postage == 360 and plan.mails[2].postage == 30, "postage estimate wrong")
    assert(plan.mails[3].recipient == "B", "ore did not fall through to other")
end)
try("review removal changes totals; the window renders the plan", function()
    local plan = NS.currentPlan
    plan.mails[1].removed = true
    local t = NS.PlanTotals(plan)
    assert(t.mails == 6, "removal not reflected in totals")
    NS.UI.Show()
    assert(MulePostFrame and MulePostFrame:IsShown(), "window not shown")
    assert(NS.UI.rows[2].fs:GetText():find("Alchalt", 1, true) or
           NS.UI.rows[1].fs:GetText():find("REMOVED", 1, true), "rows do not render the plan")
    assert(NS.UI.sendLabel:GetText():find("6", 1, true), "send button should say 6 mails: " .. NS.UI.sendLabel:GetText())
end)
try("send pass is event-driven, skips removed, marks sent, completes", function()
    NS.OnMailEvent("MAIL_SHOW")
    assert(NS.atMailbox == true, "mailbox state not set")
    MAILS = {}
    PICKUPS = {}
    assert(NS.StartSend(NS.currentPlan) == true, "send did not start")
    assert(#MAILS == 1, "exactly one mail should be in flight, got " .. #MAILS)
    for _ = 1, 5 do NS.OnMailEvent("MAIL_SEND_SUCCESS") end
    assert(#MAILS == 6, "expected 6 mails sent one-by-one, got " .. #MAILS)
    NS.OnMailEvent("MAIL_SEND_SUCCESS")
    assert(NS.sending == false, "pass should be complete")
    for i = 1, #MAILS do assert(MAILS[i].to ~= "Tailoralt", "removed mail was sent!") end
    local t = NS.PlanTotals(NS.currentPlan)
    assert(t.mails == 0, "all active mails should be marked sent")
end)
try("a failure stops the pass and keeps the rest; no mailbox, no send", function()
    local inv = {
        { bag = 0, slot = 1, name = "A", count = 1, category = "cloth" },
        { bag = 0, slot = 2, name = "B", count = 1, category = "herb" },
    }
    local plan = NS.BuildPlan(inv, { { category = "cloth", recipient = "T" }, { category = "herb", recipient = "H" } })
    NS.currentPlan = plan
    MAILS = {}
    assert(NS.StartSend(plan) == true, "second pass did not start")
    NS.OnMailEvent("MAIL_FAILED")
    assert(NS.sending == false, "failure did not stop the pass")
    assert(#MAILS == 1, "second mail must not be attempted after failure")
    assert(plan.mails[2].sent == nil, "unsent mail was marked sent")
    NS.OnMailEvent("MAIL_CLOSED")
    assert(NS.StartSend(plan) == false, "send started away from a mailbox")
    assert(#MAILS == 1, "a mail left while away from the mailbox")
end)
note("chat lines: " .. #CHATLOG)
note("DONE")
return table.concat(report, "\n")
"""


def toc_files(toc_name):
    lines = (ADDON / toc_name).read_text().splitlines()
    return [ln.strip() for ln in lines if ln.strip().endswith(".lua")]


def main():
    files = toc_files("MulePost_Camelot.toc")
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    rt.execute(PRELUDE)
    rt.globals().FILES = rt.table_from(
        [{"name": n, "code": (ADDON / n).read_text()} for n in files])
    out = rt.execute(DRIVER)
    print(f"--- harness (MulePost_Camelot.toc: {', '.join(files)}) ---")
    print(out)
    bad = [ln for ln in out.splitlines() if "FAIL" in ln]
    if bad or "DONE" not in out:
        print("HARNESS: FAIL")
        sys.exit(1)
    print("HARNESS: PASS")


if __name__ == "__main__":
    main()
