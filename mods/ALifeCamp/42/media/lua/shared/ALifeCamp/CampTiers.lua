require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Build = ALifeCamp.Build
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options

local Tiers = {}
ALifeCamp.Tiers = Tiers

Tiers.ladder = {
    { key = "camp", name = "Tier_camp", popMin = 1, sideMin = 8, builtMin = 0 },
    { key = "outpost", name = "Tier_outpost", popMin = 5, sideMin = 24, builtMin = 12 },
    { key = "village", name = "Tier_village", popMin = 12, sideMin = 48, builtMin = 40 },
    { key = "town", name = "Tier_town", popMin = 25, sideMin = 120, builtMin = 110 },
    { key = "city", name = "Tier_city", popMin = 50, sideMin = 240, builtMin = 280 },
}
Tiers.count = #Tiers.ladder

Tiers.counts = {
    camp = {
        house_s = 4, house_m = 0, house_l = 0, barracks = 1, tents = 1, shed = 1,
        canteen = 1, infirmary = 1, forge = 1, greenhouse = 1, farm = 1, garden = 0, well = 1, market = 1, powerhouse = 1,
        plaza = 1, campfire = 1, lamp = 0, workyard = 0, memorial = 0, driveway = 0,
        checkpoint = 1, tower = 4, post = 0, guardhouse = 1, range = 1, vault = 0, cemetery = 0,
        bay = 0, garage = 1, motorpool = 0,
    },
    outpost = {
        house_s = 4, house_m = 4, house_l = 2, barracks = 1, tents = 1, shed = 1,
        canteen = 1, infirmary = 1, forge = 0, greenhouse = 1, farm = 1, garden = 1, well = 1, market = 1, powerhouse = 1,
        plaza = 1, campfire = 1, lamp = 6, workyard = 0, memorial = 0, driveway = 1,
        checkpoint = 1, tower = 4, post = 1, guardhouse = 1, range = 1, vault = 1, cemetery = 1,
        bay = 1, garage = 1, motorpool = 1,
    },
    village = {
        house_s = 4, house_m = 6, house_l = 2, barracks = 1, tents = 2, shed = 1,
        canteen = 1, infirmary = 1, forge = 1, greenhouse = 2, farm = 2, garden = 2, well = 2, market = 1, powerhouse = 1,
        plaza = 1, campfire = 2, lamp = 0, workyard = 0, memorial = 0, driveway = 1,
        checkpoint = 1, tower = 4, post = 0, guardhouse = 0, range = 1, vault = 1, cemetery = 0,
        bay = 2, garage = 2, motorpool = 1,
    },
    town = {
        house_s = 8, house_m = 6, house_l = 0, barracks = 2, tents = 2, shed = 1,
        canteen = 1, infirmary = 1, forge = 1, greenhouse = 2, farm = 3, garden = 1, well = 0, market = 1, powerhouse = 1,
        plaza = 1, campfire = 2, lamp = 0, workyard = 2, memorial = 1, driveway = 0,
        checkpoint = 1, tower = 4, post = 1, guardhouse = 2, range = 1, vault = 1, cemetery = 0,
        bay = 2, garage = 2, motorpool = 1,
    },
    city = {
        house_s = 12, house_m = 10, house_l = 4, barracks = 3, tents = 2, shed = 2,
        canteen = 2, infirmary = 2, forge = 1, greenhouse = 3, farm = 4, garden = 2, well = 1, market = 2, powerhouse = 2,
        plaza = 1, campfire = 3, lamp = 0, workyard = 3, memorial = 1, driveway = 0,
        checkpoint = 1, tower = 8, post = 2, guardhouse = 3, range = 2, vault = 2, cemetery = 1,
        bay = 3, garage = 3, motorpool = 2,
    },
}

function Tiers.want(camp, kind)
    if not Tiers.on(camp) then return nil end
    local spec = Tiers.spec(camp)
    local row = spec ~= nil and Tiers.counts[spec.key] or nil
    if row == nil then return nil end
    return row[kind] or 0
end

if Options ~= nil and type(Options.define) == "function" then
    Options.define({ key = "tiers", group = "camp", priority = 16, default = true })
end

function Tiers.on(camp)
    if camp == nil or camp.tiersOn ~= true then return false end
    if Options ~= nil and type(Options.get) == "function" and Options.get(camp, "tiers") == false then return false end
    return true
end

function Tiers.builtCount(camp)
    local n = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status == "done" and project.kind ~= "fence" and not project.retired then n = n + 1 end
    end
    return n
end

function Tiers.people(camp)
    local people = 0
    pcall(function() people = Store.settlerCount(camp) end)
    return people
end

function Tiers.metrics(camp)
    local side = math.min(Geo.width(camp), Geo.height(camp))
    return side, Tiers.people(camp), Tiers.builtCount(camp)
end

function Tiers.compute(camp)
    local side, people, built = Tiers.metrics(camp)
    local idx = 1
    for i = 1, Tiers.count do
        local t = Tiers.ladder[i]
        if side >= t.sideMin and people >= t.popMin and built >= t.builtMin then idx = i end
    end
    return idx, side, people, built
end

function Tiers.index(camp)
    if type(camp.tier) == "number" then return camp.tier end
    if Tiers.on(camp) then return (Tiers.compute(camp)) end
    return 1
end

function Tiers.spec(camp)
    return Tiers.ladder[Tiers.index(camp)] or Tiers.ladder[1]
end

function Tiers.name(camp)
    return ALifeCamp.T(Tiers.spec(camp).name)
end

function Tiers.update(camp)
    if not Tiers.on(camp) then return camp.tier or 1, false end
    local idx = Tiers.compute(camp)
    local peak = camp.tierPeak or 1
    local target = idx
    if peak > target then target = peak end
    local changed = target > (camp.tier or 1)
    camp.tier = target
    camp.tierPeak = target
    return target, changed
end

if Hooks ~= nil and type(Hooks.add) == "function" then
    Hooks.add("overview", function(camp)
        if not Tiers.on(camp) then return {} end
        local index = Tiers.index(camp)
        local lines = { Hooks.line(ALifeCamp.T("Tier_overview", Tiers.name(camp)), 0.75, 0.85, 1) }
        if index < Tiers.count then
            local nx = Tiers.ladder[index + 1]
            local side, people, built = Tiers.metrics(camp)
            lines[#lines + 1] = Hooks.line(
                ALifeCamp.T("Tier_next", ALifeCamp.T(nx.name),
                    tostring(side), tostring(nx.sideMin),
                    tostring(people), tostring(nx.popMin),
                    tostring(built), tostring(nx.builtMin)),
                0.6, 0.6, 0.66)
        end
        return lines
    end, 2)
end

return Tiers
