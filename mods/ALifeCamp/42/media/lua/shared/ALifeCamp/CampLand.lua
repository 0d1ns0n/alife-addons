require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampWorld"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local World = ALifeCamp.World

local Land = {}
ALifeCamp.Land = Land

Land.junkPrefixes = { "d_trash", "trash_", "street_trash", "overlay_blood", "overlay_grime", "constructedobjects_trash" }
Land.plantPrefixes = { "vegetation_", "e_", "f_", "foliage" }
Land.keepPrefixes = { "blends_", "floors_", "carpentry_02_5", "walls_", "roofs_" }

local function startsWith(text, prefixes)
    for i = 1, #prefixes do
        if string.sub(text, 1, #prefixes[i]) == prefixes[i] then return true end
    end
    return false
end

local function spriteName(object)
    local name = ""
    pcall(function()
        local sprite = object:getSprite()
        if sprite ~= nil then name = sprite:getName() or "" end
    end)
    return name
end

local function flag(object, name)
    local props = World.props(object)
    if props == nil then return false end
    local on = false
    pcall(function()
        local key = IsoFlagType ~= nil and IsoFlagType[name] or nil
        if key ~= nil and props:has(key) == true then on = true end
        if not on then on = props:has(name) == true end
    end)
    return on
end

function Land.classify(object)
    if object == nil then return nil end
    local kind
    pcall(function()
        if instanceof(object, "IsoTree") then kind = "tree" return end
        if instanceof(object, "IsoWorldInventoryObject") then kind = "item" return end
        if instanceof(object, "IsoDeadBody") then kind = "corpse" return end
        if instanceof(object, "IsoMovingObject") then return end
        local tag = World.tag(object)
        if type(tag) == "table" then return end
        if instanceof(object, "IsoThumpable") or instanceof(object, "IsoDoor") or instanceof(object, "IsoWindow")
                or instanceof(object, "IsoWindowFrame") then
            kind = "structure"
            return
        end
        if flag(object, "solidfloor") then return end
        local name = spriteName(object)
        if name == "" then return end
        if startsWith(name, Land.junkPrefixes) then kind = "junk" return end
        if ProjectALife ~= nil and ProjectALife.Foliage ~= nil and type(ProjectALife.Foliage.clearable) == "function"
                and ProjectALife.Foliage.clearable(name) == true then
            kind = "plant"
            return
        end
        if startsWith(name, Land.plantPrefixes) and not flag(object, "solid") then kind = "plant" return end
        if flag(object, "WallN") or flag(object, "WallW") or flag(object, "WallNW") or flag(object, "WallSE")
                or flag(object, "WallNTrans") or flag(object, "WallWTrans") or flag(object, "DoorWallN")
                or flag(object, "DoorWallW") or flag(object, "WindowN") or flag(object, "WindowW")
                or flag(object, "windowN") or flag(object, "windowW")
                or flag(object, "HoppableN") or flag(object, "HoppableW") or flag(object, "doorN") or flag(object, "doorW") then
            kind = "structure"
            return
        end
        if flag(object, "solid") or flag(object, "solidtrans") then
            local container = false
            pcall(function() container = object:getContainer() ~= nil end)
            kind = container and "furniture" or "structure"
            return
        end
        if startsWith(name, Land.keepPrefixes) then return end
        kind = "misc"
    end)
    return kind
end

function Land.squareOf(camp, x, y)
    return World.square(x, y, camp.z)
end

Land.counted = { "tree", "plant", "junk", "item", "corpse", "structure", "furniture", "misc", "vehicles", "loaded", "water" }

function Land.stride(rect, samples)
    return math.max(1, math.ceil(math.sqrt(Geo.area(rect) / (samples or 4000))))
end

function Land.survey(rect, stride, camp)
    stride = math.max(1, math.floor(stride or 1))
    local adopt = camp ~= nil and ALifeCamp.Adopt or nil
    local out = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, misc = 0,
        buildings = 0, vehicles = 0, loaded = 0, water = 0, total = Geo.area(rect), stride = stride }
    local seenBuildings = {}
    for x = rect.x1, rect.x2, stride do
        for y = rect.y1, rect.y2, stride do
            local square = World.square(x, y, rect.z or 0)
            if square ~= nil and adopt ~= nil and adopt.covered(camp, x, y) ~= nil then
                out.loaded = out.loaded + 1
                square = nil
            end
            if square ~= nil then
                out.loaded = out.loaded + 1
                if World.isWaterSquare(square) then out.water = out.water + 1 end
                pcall(function()
                    local objects = square:getObjects()
                    for i = 0, objects:size() - 1 do
                        local kind = Land.classify(objects:get(i))
                        if kind ~= nil then out[kind] = (out[kind] or 0) + 1 end
                    end
                    local items = square:getWorldObjects()
                    if items ~= nil then out.item = out.item + items:size() end
                    local bodies = square:getDeadBodys()
                    if bodies ~= nil then out.corpse = out.corpse + bodies:size() end
                    local building = square:getBuilding()
                    if building ~= nil and not seenBuildings[building] then
                        seenBuildings[building] = true
                        out.buildings = out.buildings + 1
                    end
                    if square:getVehicleContainer() ~= nil then out.vehicles = out.vehicles + 1 end
                end)
            end
        end
    end
    if stride > 1 then
        local weight = stride * stride
        for _, key in ipairs(Land.counted) do out[key] = math.floor(out[key] * weight + 0.5) end
        out.loaded = math.min(out.total, out.loaded)
    end
    return out
end

function Land.dirty(rect, stride, camp)
    local s = Land.survey(rect, stride, camp)
    return s.tree + s.plant + s.junk + s.item + s.corpse + s.structure + s.furniture + s.misc + s.vehicles, s
end

return Land
