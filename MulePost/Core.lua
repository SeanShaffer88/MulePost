-- MulePost - Core
-- WoW: Forever (Interface 16001). Routes bag contents to your alts
-- by category at the mailbox: plan first, review always, send only
-- on your button press. It never touches your inbox and never
-- attaches gold.
local ADDON, ns = ...

ns.VERSION = "0.1.0"
ns.currentPlan = nil

local function Print(msg)
    local chat = DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then
        chat:AddMessage("|cffffc266MulePost:|r " .. tostring(msg))
    end
end
ns.Print = Print

-- SavedVariables: routing rules (ordered; first match wins, the
-- "other" rule is the fall-through), the postage guard cap, and
-- nothing else. Plans are session-only by design.
local DB_VERSION = 1
local function EnsureDB()
    if type(MulePostDB) ~= "table" then MulePostDB = {} end
    local db = MulePostDB
    if type(db.settings) ~= "table" then db.settings = {} end
    if db.settings.postageCapCopper == nil then db.settings.postageCapCopper = 10000 end
    if type(db.rules) ~= "table" then db.rules = {} end
    if type(db.version) ~= "number" then db.version = 0 end
    if db.version < DB_VERSION then db.version = DB_VERSION end
    ns.db = db
end
ns.EnsureDB = EnsureDB

local function RouteCommand()
    local inventory, skipped = ns.ScanBags()
    local plan = ns.BuildPlan(inventory, ns.db.rules)
    plan.skipped = skipped
    ns.currentPlan = plan
    local totals = ns.PlanTotals(plan)
    if #ns.db.rules == 0 then
        Print("you have no routing rules yet. Add one: /mp rule add cloth Tailoralt (categories: cloth, herb, ore, leather, enchanting, consumable, junk, other)")
    end
    Print("plan: " .. totals.mails .. " mail(s), " .. totals.stacks ..
        " stacks, estimated postage " .. ns.CopperText(totals.postage) ..
        " (estimate at 30c/stack - the live price is the mailbox's)." ..
        " Unrouted: " .. plan.unrouted .. " stack(s); quest items excluded: " .. plan.excluded ..
        "; not-yet-cached by the client: " .. skipped .. ".")
    if ns.UI and ns.UI.Show then ns.UI.Show() end
    return plan
end
ns.RouteCommand = RouteCommand

local function RulesList()
    if #ns.db.rules == 0 then
        Print("no rules. /mp rule add <category> <character> - categories: cloth, herb, ore, leather, enchanting, consumable, junk, other")
        return
    end
    for i = 1, #ns.db.rules do
        local r = ns.db.rules[i]
        Print(i .. ". " .. r.category .. " -> " .. r.recipient)
    end
end

local function RuleCommand(rest)
    local sub, a, b = rest:match("^%s*(%S+)%s*(%S*)%s*(%S*)")
    if sub == "list" or rest:gsub("%s", "") == "" then
        RulesList()
    elseif sub == "add" then
        local category = (a or ""):lower()
        local recipient = b or ""
        if not ns.CategoryKeys[category] then
            Print("unknown category '" .. a .. "'. Categories: cloth, herb, ore, leather, enchanting, consumable, junk, other")
            return
        end
        if recipient == "" then
            Print("usage: /mp rule add " .. category .. " <character name>")
            return
        end
        if #ns.db.rules >= 8 then
            Print("rule limit reached (8). Delete one first: /mp rule del <number>")
            return
        end
        ns.db.rules[#ns.db.rules + 1] = { category = category, recipient = recipient }
        Print("rule added: " .. category .. " -> " .. recipient)
    elseif sub == "del" then
        local idx = tonumber(a)
        if idx and ns.db.rules[idx] then
            local gone = table.remove(ns.db.rules, idx)
            Print("rule deleted: " .. gone.category .. " -> " .. gone.recipient)
        else
            Print("no rule number " .. tostring(a) .. ". /mp rules lists them.")
        end
    else
        Print("usage: /mp rule add <category> <character> | /mp rule del <number> | /mp rules")
    end
end

local function SlashHandler(msg)
    EnsureDB()
    local cmd, rest = "", ""
    if type(msg) == "string" then
        cmd = (msg:match("^%s*(%S+)") or ""):lower()
        rest = msg:match("^%s*%S+%s+(.-)%s*$") or ""
    end
    if cmd == "show" or cmd == "" then
        if ns.UI and ns.UI.Toggle then ns.UI.Toggle() end
    elseif cmd == "hide" then
        if ns.UI and ns.UI.Hide then ns.UI.Hide() end
    elseif cmd == "route" then
        RouteCommand()
    elseif cmd == "rules" then
        RulesList()
    elseif cmd == "rule" then
        RuleCommand(rest)
    elseif cmd == "cap" then
        local v = tonumber(rest:match("(%d+)"))
        if rest:find("off") then
            ns.db.settings.postageCapCopper = 0
            Print("postage guard off.")
        elseif v then
            ns.db.settings.postageCapCopper = v
            Print("postage guard: warn when a plan's total estimated postage exceeds " .. ns.CopperText(v) .. ".")
        else
            Print("postage guard cap: " .. (ns.db.settings.postageCapCopper > 0
                and ns.CopperText(ns.db.settings.postageCapCopper) or "off") ..
                " - set with /mp cap <copper>, disable with /mp cap off")
        end
    elseif cmd == "debug" then
        Print("version " .. ns.VERSION .. " | rules=" .. #ns.db.rules ..
            " atMailbox=" .. tostring(ns.atMailbox) ..
            " sending=" .. tostring(ns.sending))
        if GetBuildInfo then
            local v, b = GetBuildInfo()
            Print("client build: " .. tostring(v) .. " (" .. tostring(b) .. ")")
        end
    elseif cmd == "help" then
        Print("Commands: /mp - review window | /mp route - scan bags and build the plan | /mp rules | /mp rule add <category> <character> | /mp rule del <n> | /mp cap <copper>|off - postage guard | /mp debug")
        Print("Nothing sends without the review window and your Send press. Gold is never attached - there is no code path that can do it.")
    else
        Print("unknown command '" .. cmd .. "' - /mp help lists them all.")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        EnsureDB()
    elseif event == "PLAYER_LOGIN" then
        EnsureDB()
        SLASH_MULEPOST1 = "/mulepost"
        SLASH_MULEPOST2 = "/mp"
        SlashCmdList["MULEPOST"] = SlashHandler
        if ns.AttachSend then ns.AttachSend() end
        if ns.UI and ns.UI.Build then ns.UI.Build() end
        Print("loaded v" .. ns.VERSION .. " - /mp route at a mailbox builds your plan.")
    end
end)
