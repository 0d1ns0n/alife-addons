require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampLand"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Land = ALifeCamp.Land
local Settlers = ALifeCamp.Settlers
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Supply = {}
ALifeCamp.Supply = Supply

Supply.sawRatio = 3
Supply.treeMinutes = 4
Supply.abstractShare = 0.35
Supply.waitMinutes = 6
Supply.nearRange = 6
Supply.scanBudget = 160
Supply.treeLimit = 12
Supply.maxJacks = 4
Supply.demandProjects = 3
Supply.kinds = { "planks", "nails", "metal", "rope", "logs" }
Supply.jobRoles = { "worker", "scavenger", "sanitary", "builder" }

Options.define({ key = "lumber", group = "camp", priority = 17, default = true })
Options.define({ key = "lumberRange", group = "camp", priority = 18, kind = "cycle", values = { 20, 40, 80 }, default = 40 })

function Supply.state(camp)
    if type(camp.supply) ~= "table" then
        camp.supply = { progress = 0, felled = 0, far = 0, waited = 0, trees = {}, ring = 1, index = 0, jacks = 0 }
    end
    return camp.supply
end

function Supply.demand(camp)
    local Build = ALifeCamp.Build
    local need = {}
    if Build == nil then return need end
    local counted = 0
    for _, project in ipairs(Build.list(camp)) do
        if counted >= Supply.demandProjects then break end
        if project.status ~= "done" and project.kind ~= "fence" then
            local ok, missing = pcall(Build.needs, camp, project)
            if ok and type(missing) == "table" then
                local any = false
                for kind, amount in pairs(missing) do
                    need[kind] = (need[kind] or 0) + amount
                    any = true
                end
                if any then counted = counted + 1 end
            end
        end
    end
    local work = ALifeCamp.Work
    if work ~= nil and type(work.logReserve) == "function" then
        local reserve = work.logReserve(camp)
        local short = reserve - ((camp.stock or {}).logs or 0)
        if short > 0 then need.logs = (need.logs or 0) + short end
    end
    return need
end

function Supply.logsWanted(camp, need)
    local stock = camp.stock or {}
    local planks = need.planks or 0
    local fromPlanks = math.ceil(planks / Supply.sawRatio)
    return math.max(0, fromPlanks + (need.logs or 0) - (stock.logs or 0))
end

local function ringSize(camp, r)
    local w = camp.x2 - camp.x1 + 1 + 2 * r
    local h = camp.y2 - camp.y1 + 1 + 2 * r
    return 2 * w + 2 * (h - 2)
end

local function ringPoint(camp, r, i)
    local x1, y1, x2, y2 = camp.x1 - r, camp.y1 - r, camp.x2 + r, camp.y2 + r
    local w, h = x2 - x1 + 1, y2 - y1 + 1
    if i < w then return x1 + i, y1 end
    i = i - w
    if i < w then return x1 + i, y2 end
    i = i - w
    if i < h - 2 then return x1, y1 + 1 + i end
    i = i - (h - 2)
    if i < h - 2 then return x2, y1 + 1 + i end
    return nil
end

local function treeAt(square)
    local found
    pcall(function()
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            if Land.classify(object) == "tree" then
                found = object
                return
            end
        end
    end)
    return found
end

function Supply.scan(camp, state, budget)
    local range = Options.number(camp, "lumberRange")
    if range <= 0 then range = 40 end
    local spent = 0
    while spent < budget and #state.trees < Supply.treeLimit do
        if state.ring > range then
            state.ring = 1
            state.index = 0
            state.sweeps = (state.sweeps or 0) + 1
            return
        end
        local size = ringSize(camp, state.ring)
        if state.index >= size then
            state.ring = state.ring + 1
            state.index = 0
        else
            local x, y = ringPoint(camp, state.ring, state.index)
            state.index = state.index + 1
            spent = spent + 1
            if x ~= nil then
                local square = World.square(x, y, camp.z)
                if square ~= nil and treeAt(square) ~= nil then
                    state.trees[#state.trees + 1] = { x = x, y = y }
                end
            end
        end
    end
end

function Supply.target(camp)
    local state = camp.supply
    if type(state) ~= "table" or type(state.trees) ~= "table" then return nil end
    local tree = state.trees[1]
    if tree == nil then return nil end
    return { x = tree.x, y = tree.y, z = camp.z }
end

function Supply.fell(camp, state)
    while #state.trees > 0 do
        local tree = table.remove(state.trees, 1)
        local square = World.square(tree.x, tree.y, camp.z)
        local object = square ~= nil and treeAt(square) or nil
        if object ~= nil and World.remove(object) then
            Stock.deposit(camp, "Base.Log", 2)
            Stock.deposit(camp, "Base.Twigs", 3)
            state.felled = state.felled + 1
            return true
        end
    end
    return false
end

function Supply.jacks(camp)
    local list = {}
    for uid, settler in pairs(camp.settlers) do
        if settler.job == "lumber" then list[#list + 1] = uid end
    end
    table.sort(list)
    return list
end

function Supply.assign(camp, wanted)
    local current = Supply.jacks(camp)
    for i = #current, wanted + 1, -1 do
        camp.settlers[current[i]].job = nil
        table.remove(current, i)
    end
    if #current >= wanted then return current end
    local taken = {}
    for _, uid in ipairs(current) do taken[uid] = true end
    for _, role in ipairs(Supply.jobRoles) do
        local pool = {}
        for uid, settler in pairs(camp.settlers) do
            if not taken[uid] and (settler.role or "worker") == role and settler.job == nil then pool[#pool + 1] = uid end
        end
        table.sort(pool)
        for _, uid in ipairs(pool) do
            if #current < wanted then
                camp.settlers[uid].job = "lumber"
                taken[uid] = true
                current[#current + 1] = uid
            end
        end
    end
    return current
end

local function nearTree(camp, jacks, tree)
    for _, uid in ipairs(jacks) do
        local x, y = Settlers.where(uid)
        if x ~= nil and math.abs(x - tree.x) <= Supply.nearRange and math.abs(y - tree.y) <= Supply.nearRange then return true end
    end
    return false
end

function Supply.step(camp, minutes)
    local state = Supply.state(camp)
    local on = Options.on(camp, "lumber")
    local people = Store.settlerCount(camp)
    local need = Supply.demand(camp)
    state.need = need
    local wanted = Supply.logsWanted(camp, need)
    state.wanted = wanted
    if not on or people < 1 or camp.phase == "clear" or wanted <= 0 then
        if #Supply.jacks(camp) > 0 then Supply.assign(camp, 0) end
        state.jacks = 0
        state.progress = 0
        state.waited = 0
        return
    end
    local want = math.max(1, math.min(Supply.maxJacks, math.ceil(wanted / 4), math.floor(people / 2)))
    local jacks = Supply.assign(camp, want)
    state.jacks = #jacks
    if #jacks == 0 then return end
    if #state.trees < Supply.treeLimit then Supply.scan(camp, state, Supply.scanBudget) end
    local physical = #state.trees > 0
    local rate = #jacks / Supply.treeMinutes
    if not physical then rate = rate * Supply.abstractShare end
    state.progress = math.min(1, state.progress + rate * minutes)
    if state.progress < 1 then return end
    if physical then
        local tree = state.trees[1]
        if nearTree(camp, jacks, tree) or state.waited >= Supply.waitMinutes then
            if Supply.fell(camp, state) then
                state.progress = 0
                state.waited = 0
                camp.stats.hauled = camp.stats.hauled + 2
            end
        else
            state.waited = state.waited + minutes
        end
    else
        Stock.deposit(camp, "Base.Log", 2)
        state.far = state.far + 1
        state.progress = 0
        camp.stats.hauled = camp.stats.hauled + 2
    end
end

function Supply.bottleneck(camp)
    local need = Supply.state(camp).need or {}
    local best, bestShort
    for _, kind in ipairs(Supply.kinds) do
        local short = need[kind] or 0
        if short > 0 and (bestShort == nil or short > bestShort) then best, bestShort = kind, short end
    end
    return best, bestShort or 0
end

function Supply.lines(camp)
    local state = Supply.state(camp)
    local need = state.need or {}
    local stock = camp.stock or {}
    local lines = {}
    local kind, short = Supply.bottleneck(camp)
    if kind == nil then
        lines[1] = Hooks.line(T("SupplyOk", tostring(stock.planks or 0), tostring(stock.nails or 0), tostring(stock.metal or 0)), 0.6, 0.9, 0.7)
        return lines
    end
    local parts = {}
    for _, name in ipairs(Supply.kinds) do
        if (need[name] or 0) > 0 then parts[#parts + 1] = T("SupplyShort_" .. name, tostring(math.ceil(need[name]))) end
    end
    lines[1] = Hooks.line(T("SupplyNeed", table.concat(parts, ", ")), 1, 0.7, 0.45)
    local source
    if kind == "planks" or kind == "logs" then
        if state.jacks > 0 then
            source = T("SupplyWood", tostring(state.jacks), tostring(#state.trees), tostring(state.felled), tostring(state.far))
        elseif Options.on(camp, "lumber") then
            source = T("SupplyNoJacks")
        else
            source = T("SupplyLumberOff")
        end
    else
        source = T("SupplyOther_" .. kind)
    end
    lines[2] = Hooks.line(source, 0.85, 0.8, 0.6)
    return lines
end

Hooks.add("minute", function(camp, minutes)
    Supply.step(camp, minutes)
end, 15)

Hooks.add("overview", function(camp)
    return Supply.lines(camp)
end, 12)

return Supply
