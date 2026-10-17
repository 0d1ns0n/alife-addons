require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampHooks"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Settlers = ALifeCamp.Settlers
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Hooks = ALifeCamp.Hooks

local Stats = {}
ALifeCamp.Stats = Stats

Stats.beds = { house_s = 2, house_m = 4, house_l = 6, campfire = 2 }

function Stats.counts(camp)
    local out = { house_s = 0, house_m = 0, house_l = 0, shed = 0, campfire = 0, farm = 0, tower = 0, fence = 0, projects = 0, done = 0 }
    for _, project in pairs(Build.plan(camp).items) do
        out.projects = out.projects + 1
        if project.status == "done" then
            out.done = out.done + 1
            out[project.kind] = (out[project.kind] or 0) + 1
        end
    end
    local adopt = ALifeCamp.Adopt ~= nil and ALifeCamp.Adopt.counts(camp) or nil
    out.adopted, out.adoptedAll, out.adoptBeds, out.adoptDefense = 0, 0, 0, 0
    if adopt ~= nil then
        out.adopted, out.adoptedAll, out.adoptBeds, out.adoptDefense = adopt.done, adopt.all, adopt.beds, adopt.defense
        out.projects = out.projects + adopt.all
        out.done = out.done + adopt.done
    end
    out.houses = out.house_s + out.house_m + out.house_l + out.adopted
    return out
end

function Stats.capacity(counts)
    local total = 0
    for kind, beds in pairs(Stats.beds) do total = total + (counts[kind] or 0) * beds end
    return total + (counts.adoptBeds or 0)
end

function Stats.fenceLength(camp)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and project.status == "done" and not project.retired then
            return #Bp.fenceSlots(project)
        end
    end
    return 0
end

function Stats.levelFor(camp, counts, people)
    local fence = Stats.fenceLength(camp) > 0
    if people >= 10 and counts.houses >= 4 and counts.farm >= 1 and counts.tower >= 2 and fence then return 4 end
    if people >= 6 and counts.houses >= 2 and counts.tower >= 1 and fence then return 3 end
    if people >= 3 and fence then return 2 end
    return 1
end

function Stats.nextLevelKey(level)
    return "Next_" .. tostring(math.min(level + 1, 5))
end

function Stats.compute(camp)
    local counts = Stats.counts(camp)
    local people = Store.settlerCount(camp)
    local roles = Settlers.counts(camp)
    local fenceLen = Stats.fenceLength(camp)
    local gate = fenceLen > 0 and 1 or 0
    local guardFactor = ALifeCamp.Skills ~= nil and ALifeCamp.Skills.factor(camp, "guard") or 1
    local armor = camp.motor ~= nil and camp.motor.armor or 0
    local defense = math.floor(fenceLen * 0.3 + gate * 6 + counts.tower * 14 + roles.guard * 9 * guardFactor + people + counts.adoptDefense
        + (counts.post or 0) * 12 + (counts.guardhouse or 0) * 5 + armor + Hooks.sum("defense", camp))
    local hunger = camp.hunger or 0
    local morale = math.max(0, math.min(100, 70 - hunger * 3 + counts.houses * 4 + (counts.campfire > 0 and 6 or 0) - math.max(0, people - Stats.capacity(counts)) * 6 + Hooks.sum("morale", camp)))
    local food = (camp.stock and camp.stock.food) or 0
    local days = people > 0 and food / (people * 2000) or 0
    local level = Stats.levelFor(camp, counts, people)
    return {
        counts = counts, people = people, roles = roles, defense = defense, morale = math.floor(morale),
        capacity = Stats.capacity(counts), foodDays = days, level = level, fence = fenceLen,
    }
end

return Stats
