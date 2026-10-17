require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Needs = {}
ALifeCamp.Needs = Needs

Needs.foodDays = 3
Needs.waterPerPerson = 2
Needs.servingKcal = 600
Needs.kcalPerDay = 2000
Needs.alertHours = 1.5
Needs.alertRange = 150
Needs.checkMinutes = 5
Needs.briefLimit = 4
Needs.order = { "food", "water", "medicine", "planks", "nails", "metal", "rope", "logs" }

Options.define({ key = "needsAlert", group = "camp", priority = 19, default = true })

function Needs.state(camp)
    if type(camp.needs) ~= "table" then camp.needs = { sig = "", at = -1000, clock = 0, count = 0 } end
    return camp.needs
end

local function optional(module, name, camp)
    local target = ALifeCamp[module]
    if target == nil or type(target[name]) ~= "function" then return nil end
    local ok, value = pcall(target[name], camp)
    if ok then return value end
    return nil
end

function Needs.compute(camp)
    local out = {}
    local stock = camp.stock or {}
    local people = Store.settlerCount(camp)
    if people > 0 then
        local daily = people * Needs.kcalPerDay
        local days = (stock.food or 0) / daily
        if days < Needs.foodDays then
            local short = math.ceil((Needs.foodDays - days) * daily / Needs.servingKcal)
            out[#out + 1] = { id = "food", short = short, have = math.floor(days * 10) / 10, urgent = days < 1 }
        end
        local waterTarget = people * Needs.waterPerPerson
        local water = stock.water or 0
        if water < waterTarget then
            out[#out + 1] = { id = "water", short = math.ceil(waterTarget - water), have = math.floor(water * 10) / 10, urgent = water <= 0 }
        end
        local medicineTarget = math.max(2, math.ceil(people / 2))
        local health = optional("Health", "stats", camp)
        if type(health) == "table" and (health.sick or 0) > 0 then medicineTarget = medicineTarget + health.sick * 2 end
        local medicine = stock.medicine or 0
        if medicine < medicineTarget then
            local epidemic = type(health) == "table" and health.epidemic == true
            out[#out + 1] = { id = "medicine", short = medicineTarget - medicine, have = medicine, urgent = epidemic or (type(health) == "table" and (health.sick or 0) > 0 and medicine <= 0) }
        end
    end
    local supply = ALifeCamp.Supply
    if supply ~= nil and camp.phase ~= "clear" then
        local ok, need = pcall(supply.demand, camp)
        if ok and type(need) == "table" then
            for _, kind in ipairs({ "planks", "nails", "metal", "rope", "logs" }) do
                local short = need[kind] or 0
                if short > 0 then
                    out[#out + 1] = { id = kind, short = math.ceil(short), have = stock[kind] or 0, urgent = (stock[kind] or 0) <= 0 }
                end
            end
        end
    end
    local rank = {}
    for index, id in ipairs(Needs.order) do rank[id] = index end
    table.sort(out, function(a, b)
        if a.urgent ~= b.urgent then return a.urgent end
        return (rank[a.id] or 99) < (rank[b.id] or 99)
    end)
    return out
end

function Needs.crate(camp)
    local pick
    for _, entry in ipairs(camp.storage or {}) do
        if entry.warehouse == true then
            pick = entry
            break
        end
    end
    pick = pick or (camp.storage or {})[1]
    if pick == nil then return nil end
    return { x = pick.x, y = pick.y, z = pick.z or camp.z }
end

function Needs.brief(list, limit)
    local parts = {}
    for index, need in ipairs(list) do
        if index > (limit or Needs.briefLimit) then break end
        parts[#parts + 1] = T("NeedShort_" .. need.id, tostring(need.short))
    end
    return table.concat(parts, ", ")
end

local function signature(list)
    local parts = {}
    for _, need in ipairs(list) do
        local bucket = need.short
        if bucket > 10 then bucket = math.floor(bucket / 10) * 10 end
        parts[#parts + 1] = need.id .. ":" .. tostring(bucket)
    end
    return table.concat(parts, "|")
end

local function playerNear(camp)
    if getPlayer == nil then return false end
    local player = getPlayer()
    if player == nil then return false end
    local ok, near = pcall(function()
        return Geo.distanceTo(camp, player:getX(), player:getY()) <= Needs.alertRange
    end)
    return ok and near == true
end

function Needs.alert(camp, list)
    local text = Needs.brief(list)
    local work = ALifeCamp.Work
    if work ~= nil and type(work.notify) == "function" then
        work.notify(camp, "NeedsNew", text)
        return true
    end
    local player = getPlayer ~= nil and getPlayer() or nil
    if player == nil then return false end
    pcall(function() player:setHaloNote(T("NeedsNew", camp.name, text)) end)
    return true
end

function Needs.step(camp, minutes)
    local state = Needs.state(camp)
    state.clock = state.clock + minutes
    if state.clock < Needs.checkMinutes then return end
    state.clock = 0
    local list = Needs.compute(camp)
    state.count = #list
    local sig = signature(list)
    local now = Store.hours()
    if sig == state.sig then return end
    state.sig = sig
    if #list == 0 or not Options.on(camp, "needsAlert") then return end
    if camp.phase == "clear" or Store.settlerCount(camp) == 0 then return end
    if now - state.at < Needs.alertHours or not playerNear(camp) then return end
    if Needs.alert(camp, list) then
        state.at = now
        Store.log(camp, "needs", Needs.brief(list, 3))
    end
end

function Needs.lines(camp)
    local lines = {}
    local list = Needs.compute(camp)
    local crate = Needs.crate(camp)
    if crate ~= nil then
        lines[#lines + 1] = Hooks.line(T("NeedsWhere", tostring(crate.x), tostring(crate.y)), 0.6, 0.85, 1)
    else
        lines[#lines + 1] = Hooks.line(T("NeedsWhereNone"), 0.8, 0.8, 0.85)
    end
    lines[#lines + 1] = { text = "" }
    if #list == 0 then
        lines[#lines + 1] = Hooks.line(T("NeedsNone"), 0.6, 0.9, 0.7)
        return lines
    end
    for _, need in ipairs(list) do
        local r, g, b = 1, 0.85, 0.4
        if need.urgent then r, g, b = 1, 0.5, 0.4 end
        lines[#lines + 1] = Hooks.line(T("NeedRow_" .. need.id, tostring(need.short), tostring(need.have)), r, g, b)
    end
    lines[#lines + 1] = { text = "" }
    lines[#lines + 1] = Hooks.line(T("NeedsHint"), 0.7, 0.7, 0.75)
    return lines
end

function Needs.stats(camp)
    return { count = Needs.state(camp).count or 0 }
end

Hooks.tab("needs", "Tab_needs", 5)
Hooks.section("needs", nil, function(camp) return Needs.lines(camp) end, 10)

Hooks.add("minute", function(camp, minutes)
    Needs.step(camp, minutes)
end, 90)

Hooks.add("overview", function(camp)
    local list = Needs.compute(camp)
    if #list == 0 then return nil end
    return { Hooks.line(T("NeedsOverview", tostring(#list), Needs.brief(list, 3)), 1, 0.65, 0.4) }
end, 8)

return Needs
