require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampStats"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Place = ALifeCamp.Place
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan
local Stock = ALifeCamp.Stock

local Expand = {}
ALifeCamp.Expand = Expand

Expand.step = 8
Expand.divisor = 6

function Expand.amount(camp)
    return math.max(Expand.step, math.floor(math.min(Geo.width(camp), Geo.height(camp)) / Expand.divisor))
end
Expand.cooldownHours = 36
Expand.sides = { "N", "E", "S", "W" }
Expand.waterVeto = 0.25

function Expand.stripFor(camp, side, amount)
    amount = amount or Expand.amount(camp)
    if side == "N" then return { x1 = camp.x1, y1 = camp.y1 - amount, x2 = camp.x2, y2 = camp.y1 - 1, z = camp.z } end
    if side == "S" then return { x1 = camp.x1, y1 = camp.y2 + 1, x2 = camp.x2, y2 = camp.y2 + amount, z = camp.z } end
    if side == "W" then return { x1 = camp.x1 - amount, y1 = camp.y1, x2 = camp.x1 - 1, y2 = camp.y2, z = camp.z } end
    return { x1 = camp.x2 + 1, y1 = camp.y1, x2 = camp.x2 + amount, y2 = camp.y2, z = camp.z }
end

function Expand.grown(camp, side, amount)
    local rect = Geo.copy(camp)
    local strip = Expand.stripFor(camp, side, amount)
    rect.x1 = math.min(rect.x1, strip.x1)
    rect.y1 = math.min(rect.y1, strip.y1)
    rect.x2 = math.max(rect.x2, strip.x2)
    rect.y2 = math.max(rect.y2, strip.y2)
    return rect, strip
end

function Expand.score(camp, side)
    local rect, strip = Expand.grown(camp, side)
    local ok = Geo.valid(rect, Config)
    if not ok then return nil end
    local other = Store.overlapping({ x1 = strip.x1, y1 = strip.y1, x2 = strip.x2, y2 = strip.y2, z = camp.z })
    if other ~= nil and other.id ~= camp.id then return nil end
    local free, blocked, unknown, water = 0, 0, 0, 0
    for x = strip.x1, strip.x2 do
        for y = strip.y1, strip.y2 do
            local state = Plan.cellState(camp, x, y)
            if state == Plan.UNKNOWN then unknown = unknown + 1
            elseif state == Plan.FREE then free = free + 1
            elseif state == Plan.WATER then water = water + 1 blocked = blocked + 3
            elseif state == Plan.BUILDING then blocked = blocked + 3
            else blocked = blocked + 1 end
        end
    end
    local total = Geo.area(strip)
    if total > 0 and water / total > Expand.waterVeto then return nil end
    return (free + unknown * 0.6 - blocked) / total
end

function Expand.best(camp)
    local best, bestScore
    for _, side in ipairs(Expand.sides) do
        local score = Expand.score(camp, side)
        if score ~= nil and (bestScore == nil or score > bestScore) then best, bestScore = side, score end
    end
    return best, bestScore
end

function Expand.ready(camp, stats)
    if camp.options.expand == false then return false, "off" end
    if camp.phase ~= "plan" then return false, "busy" end
    local counts = stats.counts
    if counts.projects == 0 or counts.done < counts.projects then return false, "unfinished" end
    if counts.houses < 1 then return false, "nohouse" end
    if Store.hours() - (camp.lastExpand or camp.founded or 0) < Expand.cooldownHours then return false, "cooldown" end
    if stats.people < math.max(1, stats.capacity - 1) then return false, "room" end
    return true
end

function Expand.apply(camp, side)
    local rect, strip = Expand.grown(camp, side)
    local ok = Geo.valid(rect, Config)
    if not ok then return false, "limit" end
    local water, total = 0, Geo.area(strip)
    for x = strip.x1, strip.x2 do
        for y = strip.y1, strip.y2 do
            if Plan.cellState(camp, x, y) == Plan.WATER then water = water + 1 end
        end
    end
    if total > 0 and water / total > Expand.waterVeto then return false, "water" end
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and not project.retired then
            if project.status == "done" then
                project.retired = true
                camp.retiredFence = project.id
            else
                Expand.dismantle(camp, project)
            end
        end
    end
    camp.x1, camp.y1, camp.x2, camp.y2 = rect.x1, rect.y1, rect.x2, rect.y2
    camp.expand = { side = side, strip = strip }
    camp.expansions = (camp.expansions or 0) + 1
    camp.lastExpand = Store.hours()
    camp.phase = "clear"
    camp.clear = nil
    Store.log(camp, "expand", side)
    return true
end

function Expand.cornerSquare(op)
    if op.north then return op.x + 1, op.y end
    return op.x, op.y + 1
end

function Expand.finish(camp)
    local old = camp.retiredFence ~= nil and Build.get(camp, camp.retiredFence) or nil
    camp.expand = nil
    camp.phase = "plan"
    camp.clear = nil
    local added = 0
    if camp.options.autoPlan ~= false then added = Plan.generate(camp) end
    if old ~= nil then
        for _, project in pairs(Build.plan(camp).items) do
            if project.kind == "fence" and not project.retired then Expand.adopt(camp, old, project) end
        end
    end
    Store.log(camp, "expanded", added)
end

function Expand.adopt(camp, old, fresh)
    local built = {}
    for _, stage in ipairs(Bp.stages(old)) do
        for _, op in ipairs(stage.ops) do
            if old.done[stage.id .. "/" .. op.slot] then built[op.slot] = op end
        end
    end
    local adopted = 0
    for _, stage in ipairs(Bp.stages(fresh)) do
        for _, op in ipairs(stage.ops) do
            local prior = built[op.slot]
            if prior ~= nil and prior.t == op.t and prior.e == op.e then
                local square = World.square(op.x, op.y, op.z or 0)
                if square ~= nil and Place.retag(square, op.slot, old.id, fresh.id) > 0 then
                    if op.corner then
                        local cx, cy = Expand.cornerSquare(op)
                        Place.retag(World.square(cx, cy, op.z or 0), "C" .. op.slot, old.id, fresh.id)
                    end
                    fresh.done[stage.id .. "/" .. op.slot] = true
                    adopted = adopted + 1
                end
            end
        end
    end
    return adopted
end

function Expand.dismantle(camp, project)
    local removed = 0
    for _, stage in ipairs(Bp.stages(project)) do
        for _, op in ipairs(stage.ops) do
            if project.done[stage.id .. "/" .. op.slot] then
                removed = removed + Place.removeSlot(World.square(op.x, op.y, op.z or 0), op.slot, project.id)
                if op.corner then
                    local cx, cy = Expand.cornerSquare(op)
                    removed = removed + Place.removeSlot(World.square(cx, cy, op.z or 0), "C" .. op.slot, project.id)
                end
            end
        end
    end
    if removed > 0 then Stock.deposit(camp, "Base.Plank", math.floor(removed / 2)) end
    Build.remove(camp, project.id)
    return removed
end

function Expand.cleanupFence(camp)
    if camp.retiredFence == nil then return false end
    local old = Build.get(camp, camp.retiredFence)
    if old == nil then
        camp.retiredFence = nil
        return false
    end
    local replaced = false
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and not project.retired and project.status == "done" then replaced = true end
    end
    if not replaced then return false end
    Expand.dismantle(camp, old)
    camp.retiredFence = nil
    Store.log(camp, "fencemoved")
    return true
end

function Expand.request(camp, side)
    if camp.phase == "clear" then return false, "busy" end
    if side == nil then side = Expand.best(camp) end
    if side == nil then return false, "nospace" end
    return Expand.apply(camp, side)
end

return Expand
