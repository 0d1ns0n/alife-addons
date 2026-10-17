require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampGates"
require "ALifeCamp/CampPlan"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build

local Zones = {}
ALifeCamp.Zones = Zones

Zones.spots = {
    canteen = { 0.42, 0.44, "civic" },
    infirmary = { 0.60, 0.44, "civic" },
    forge = { 0.20, 0.76, "industry" },
    powerhouse = { 0.30, 0.86, "industry" },
    workyard = { 0.14, 0.64, "industry" },
    barracks = { 0.80, 0.58, "residential" },
    tents = { 0.17, 0.52, "residential" },
    greenhouse = { 0.87, 0.72, "agriculture" },
    garden = { 0.74, 0.70, "agriculture" },
    farm = { 0.82, 0.88, "agriculture" },
    market = { 0.80, 0.22, "commercial" },
    range = { 0.45, 0.88, "military" },
    vault = { 0.60, 0.90, "military" },
}

Zones.districtOf = {
    civic = "center", industry = "industry", military = "training",
    residential = "homes", agriculture = "farms", commercial = "market",
}

local function round(value)
    return math.floor(value + 0.5)
end

function Zones.frontSide(camp)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and not project.retired and type(project.gate) == "string" then
            return project.gate
        end
    end
    return "S"
end

function Zones.world(camp, u, v)
    local side = Zones.frontSide(camp)
    local x1, y1, x2, y2 = camp.x1, camp.y1, camp.x2, camp.y2
    local w, h = x2 - x1, y2 - y1
    if side == "N" then return x1 + round(u * w), y1 + round(v * h) end
    if side == "E" then return x2 - round(v * w), y1 + round(u * h) end
    if side == "W" then return x1 + round(v * w), y1 + round(u * h) end
    return x1 + round(u * w), y2 - round(v * h)
end

function Zones.anchorFor(camp, kind, ax, ay, radius)
    local spot = Zones.spots[kind]
    local def = Bp.kinds[kind]
    if spot == nil or def == nil then return nil end
    local wx, wy = Zones.world(camp, spot[1], spot[2])
    local x = math.max(camp.x1, math.min(camp.x2 - def.w + 1, wx - math.floor(def.w / 2)))
    local y = math.max(camp.y1, math.min(camp.y2 - def.h + 1, wy - math.floor(def.h / 2)))
    local want = math.floor(math.max(Geo.width(camp), Geo.height(camp)) * 0.22)
    local out = radius or want
    if want > out then out = want end
    if out < 8 then out = 8 end
    if out > 18 then out = 18 end
    return x, y, out
end

function Zones.purposeOf(kind)
    local spot = Zones.spots[kind]
    return spot ~= nil and spot[3] or nil
end

return Zones
