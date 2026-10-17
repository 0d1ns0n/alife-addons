require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local World = ALifeCamp.World
local Place = ALifeCamp.Place
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build

local Site = {}
ALifeCamp.Site = Site

Site.sprites = {
    palletBricks = "construction_01_4",
    palletEmpty = "construction_01_5",
    palletOld = "location_military_knox_01_0",
    mixer = "construction_01_6",
    barricadeA = "construction_01_8",
    barricadeB = "construction_01_9",
    sandLarge = "construction_01_64",
    sandMedium = "construction_01_68",
    sandSmall = "construction_01_72",
    beamA = "construction_01_96",
    beamB = "construction_01_97",
    column = "construction_01_88",
}

Site.sets = {
    small = { "palletEmpty", "sandSmall" },
    medium = { "palletBricks", "palletEmpty", "mixer", "sandMedium", "barricadeA" },
    large = { "palletBricks", "palletBricks", "palletEmpty", "mixer", "sandLarge", "barricadeA", "barricadeB", "beamA", "beamB", "palletOld" },
    tower = { "palletEmpty", "beamA", "column" },
    farm = { "sandSmall", "palletEmpty" },
}

Site.buildings = { house_s = true, house_m = true, house_l = true, shed = true }

function Site.class(project)
    if Site.buildings[project.kind] then
        local area = (project.w + 1) * (project.h + 1)
        if area <= 25 then return "small" end
        if area <= 42 then return "medium" end
        return "large"
    end
    if project.kind == "tower" then return "tower" end
    if project.kind == "farm" then return "farm" end
    return nil
end

function Site.set(project)
    local class = Site.class(project)
    if class == nil then return nil end
    return Site.sets[class], class
end

local function inFootprint(camp, project, x, y)
    for _, other in pairs(Build.plan(camp).items) do
        if other.kind ~= "fence" and not other.retired then
            local rect = Bp.footprint(other)
            if x >= rect.x1 and x <= rect.x2 and y >= rect.y1 and y <= rect.y2 then return true end
        end
    end
    return false
end

local function sideOf(rect, x, y)
    if y < rect.y1 then return "N" end
    if y > rect.y2 then return "S" end
    if x < rect.x1 then return "W" end
    return "E"
end

function Site.candidates(camp, project)
    local rect = Bp.footprint(project)
    local out = {}
    for ring = 1, 3 do
        for x = rect.x1 - ring, rect.x2 + ring do
            for y = rect.y1 - ring, rect.y2 + ring do
                if x == rect.x1 - ring or x == rect.x2 + ring or y == rect.y1 - ring or y == rect.y2 + ring then
                    local score = ring * 10 + (x * 7 + y * 13 + project.id * 5) % 6
                    if project.door ~= nil and sideOf(rect, x, y) == project.door then score = score + 40 end
                    out[#out + 1] = { x = x, y = y, score = score }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    return out
end

function Site.free(camp, project, x, y)
    if not Geo.contains(camp, x, y) then return false, "outside" end
    if World.square(x, y, camp.z) == nil then return false, "unloaded" end
    if inFootprint(camp, project, x, y) then return false, "taken" end
    if Place.blocked(x, y, camp.z) then return false, "blocked" end
    local square = World.square(x, y, camp.z)
    local tagged = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            if type(World.tag(objects:get(i))) == "table" then tagged = true end
        end
    end)
    if tagged then return false, "tagged" end
    return true
end

function Site.place(camp, project)
    if project.site ~= nil or project.status == "done" then return 0 end
    local set, class = Site.set(project)
    if set == nil then
        project.site = {}
        return 0
    end
    local candidates = Site.candidates(camp, project)
    local placed = {}
    local index = 1
    local loaded = false
    for n, key in ipairs(set) do
        while index <= #candidates do
            local spot = candidates[index]
            index = index + 1
            local ok, why = Site.free(camp, project, spot.x, spot.y)
            if why ~= "unloaded" and why ~= "outside" then loaded = true end
            if ok then
                local object = Place.prop(Site.sprites[key], spot.x, spot.y, camp.z, Place.tag(project, "Z" .. n, "site"))
                if object ~= nil then
                    placed[#placed + 1] = { x = spot.x, y = spot.y, slot = "Z" .. n }
                    break
                end
            end
        end
    end
    if #placed == 0 and not loaded then return 0 end
    project.site = placed
    project.siteClass = class
    return #placed
end

function Site.clear(camp, project)
    if type(project.site) ~= "table" then return 0 end
    local removed = 0
    local left = {}
    for _, entry in ipairs(project.site) do
        local square = World.square(entry.x, entry.y, camp.z)
        if square == nil then
            left[#left + 1] = entry
        else
            removed = removed + Place.removeSlot(square, entry.slot, project.id)
        end
    end
    if #left == 0 then project.site = nil else project.site = left end
    return removed
end

function Site.sweep(camp)
    local removed = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status == "done" and type(project.site) == "table" then removed = removed + Site.clear(camp, project) end
    end
    return removed
end

return Site
