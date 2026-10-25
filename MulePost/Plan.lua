-- MulePost - Categories, bag scan, and the mail plan
--
-- The plan is a pure function of (inventory, rules): every stack is
-- classified, matched to the first rule that claims its category
-- (falling through to the "other" rule), grouped by recipient, and
-- chunked into mails of at most 12 stacks (the game's attachment
-- limit). Nothing in this file touches the mail frame - building a
-- plan can never send anything. Sending lives in Send.lua and only
-- ever runs on a plan the player reviewed in the window.
--
-- Classification works on the item TYPE NAMES the client itself
-- displays ("Trade Goods" / "Cloth" / "Herb" / "Metal & Stone"...),
-- read via C_Item.GetItemInfoInstant - not on numeric subclass IDs,
-- whose per-class tables are exactly the kind of detail that must be
-- confirmed on the live build, not assumed. Safety rails:
-- * Quest-class items are NEVER routed (classify returns nil).
-- * Poor quality (grey) is "junk" - checked after Quest, so a grey
--   quest item is still excluded, and before the material types.
-- * An item whose data the client hasn't cached yet is skipped and
--   COUNTED; the scan reports the count instead of guessing.
local _, ns = ...

ns.CATEGORIES = {
    { key = "cloth",      label = "Cloth" },
    { key = "herb",       label = "Herbs" },
    { key = "ore",        label = "Ore & stone (Metal & Stone)" },
    { key = "leather",    label = "Leather" },
    { key = "enchanting", label = "Enchanting materials" },
    { key = "consumable", label = "Consumables" },
    { key = "junk",       label = "Junk (grey items)" },
    { key = "other",      label = "Everything else" },
}
ns.CategoryKeys = {}
for i = 1, #ns.CATEGORIES do ns.CategoryKeys[ns.CATEGORIES[i].key] = true end

local SUBTYPE_CATEGORY = {
    ["Cloth"] = "cloth",
    ["Herb"] = "herb",
    ["Metal & Stone"] = "ore",
    ["Leather"] = "leather",
    ["Enchanting"] = "enchanting",
}

-- Returns a category key, or nil when the item must not be routed.
local function Classify(typeName, subTypeName, quality)
    if typeName == "Quest" then return nil end
    if quality == 0 then return "junk" end
    if subTypeName and SUBTYPE_CATEGORY[subTypeName] then
        return SUBTYPE_CATEGORY[subTypeName]
    end
    if typeName == "Consumable" then return "consumable" end
    return "other"
end
ns.Classify = Classify

-- Postage ESTIMATE in copper: the classic schedule is 30c per
-- attached stack. This is labelled an estimate everywhere it is
-- shown; the live build's real price (GetSendMailPrice on the send
-- frame) is a spike-list item, and the review screen says so.
ns.POSTAGE_PER_STACK = 30
local function EstimatePostage(stackCount)
    return ns.POSTAGE_PER_STACK * math.max(1, stackCount)
end
ns.EstimatePostage = EstimatePostage

-- Scan bags 0..NUM_BAG_SLOTS into a flat inventory list. Each entry:
-- { bag, slot, itemID, name, count, category } - category is the
-- Classify result (possibly nil for quest items). Uncached items
-- (GetItemInfoInstant returns nothing yet on this API generation)
-- are skipped and counted in the second return value.
local function ScanBags()
    local inventory, skipped = {}, 0
    if not (C_Container and C_Container.GetContainerNumSlots
        and C_Container.GetContainerItemInfo) then
        return inventory, skipped
    end
    local lastBag = (NUM_BAG_SLOTS and NUM_BAG_SLOTS) or 4
    for bag = 0, lastBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local instant = nil
                if C_Item and C_Item.GetItemInfoInstant then
                    instant = { C_Item.GetItemInfoInstant(info.itemID) }
                end
                -- GetItemInfoInstant returns: itemID, typeName,
                -- subTypeName, equipLoc, icon, classID, subclassID.
                if instant and instant[2] then
                    local name = nil
                    if C_Item and C_Item.GetItemInfo then
                        name = C_Item.GetItemInfo(info.itemID)
                    end
                    inventory[#inventory + 1] = {
                        bag = bag, slot = slot, itemID = info.itemID,
                        name = name or ("item " .. info.itemID),
                        count = info.stackCount or 1,
                        category = Classify(instant[2], instant[3], info.quality),
                    }
                else
                    skipped = skipped + 1
                end
            end
        end
    end
    return inventory, skipped
end
ns.ScanBags = ScanBags

local MAX_ATTACH = 12

-- Build the plan. rules: ordered { {category=key, recipient=name} }.
-- Returns { mails = { {recipient, stacks, postage, removed=false} },
-- unrouted = n, excluded = n } with recipients in first-match order.
local function BuildPlan(inventory, rules)
    local byRecipient, order = {}, {}
    local unrouted, excluded = 0, 0
    local function recipientFor(category)
        local otherRecipient = nil
        for i = 1, #rules do
            if rules[i].category == category then return rules[i].recipient end
            if rules[i].category == "other" then otherRecipient = rules[i].recipient end
        end
        return otherRecipient
    end
    for i = 1, #inventory do
        local item = inventory[i]
        if item.category == nil then
            excluded = excluded + 1
        else
            local recipient = recipientFor(item.category)
            if not recipient or recipient == "" then
                unrouted = unrouted + 1
            else
                if not byRecipient[recipient] then
                    byRecipient[recipient] = {}
                    order[#order + 1] = recipient
                end
                local bucket = byRecipient[recipient]
                bucket[#bucket + 1] = item
            end
        end
    end
    local mails = {}
    for r = 1, #order do
        local recipient = order[r]
        local bucket = byRecipient[recipient]
        local i = 1
        while i <= #bucket do
            local stacks = {}
            for j = i, math.min(i + MAX_ATTACH - 1, #bucket) do
                stacks[#stacks + 1] = bucket[j]
            end
            mails[#mails + 1] = {
                recipient = recipient, stacks = stacks,
                postage = EstimatePostage(#stacks), removed = false,
            }
            i = i + MAX_ATTACH
        end
    end
    return { mails = mails, unrouted = unrouted, excluded = excluded }
end
ns.BuildPlan = BuildPlan

local function PlanTotals(plan)
    local stacks, postage, active = 0, 0, 0
    for i = 1, #plan.mails do
        local m = plan.mails[i]
        if not m.removed and not m.sent then
            active = active + 1
            stacks = stacks + #m.stacks
            postage = postage + m.postage
        end
    end
    return { mails = active, stacks = stacks, postage = postage }
end
ns.PlanTotals = PlanTotals

local function CopperText(copper)
    copper = copper or 0
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    parts[#parts + 1] = c .. "c"
    return table.concat(parts, " ")
end
ns.CopperText = CopperText
