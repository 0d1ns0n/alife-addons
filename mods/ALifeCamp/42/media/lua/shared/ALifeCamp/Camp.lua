require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local T = ALifeCamp.T

local Camp = {}
ALifeCamp.Camp = Camp

function Camp.defaultName()
    local index = Store.data().serial % Config.nameCount + 1
    return T("Name" .. tostring(index))
end

function Camp.rectFrom(points, z)
    local x1, y1, x2, y2 = Geo.bounds(points)
    if x1 == nil then return nil end
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z or 0 }
end

function Camp.check(rect)
    if rect == nil then return false, "empty" end
    local ok, why = Geo.valid(rect, Config)
    if not ok then return false, why end
    if Store.overlapping(rect) ~= nil then return false, "overlap" end
    return true
end

function Camp.tagFlags(camp)
    local tagged = 0
    for _, flag in ipairs(Store.pending()) do
        local square = World.square(flag.x, flag.y, flag.z or camp.z)
        local object = square ~= nil and World.find(square, "flag", nil) or nil
        if object ~= nil then
            pcall(function()
                local data = object:getModData()
                data.ALC = { kind = "flag", camp = camp.id, corner = true }
            end)
            tagged = tagged + 1
        end
    end
    return tagged
end

function Camp.addStorage(camp, x, y, z)
    local object = World.putCrate(x, y, z, { kind = "storage", camp = camp.id }, Config.crateSprite)
    if object == nil then return false end
    camp.storage[#camp.storage + 1] = { x = x, y = y, z = z }
    return true
end

function Camp.setupStorage(camp)
    local cx, cy = Geo.center(camp)
    local placed = 0
    local px, py = cx, cy
    for _ = 1, 1 do
        local fx, fy = World.freeAround(px, py, camp.z, 4)
        if fx ~= nil and Camp.addStorage(camp, fx, fy, camp.z) then
            placed = placed + 1
            px, py = fx + 1, fy
        end
    end
    return placed
end

function Camp.create(rect, name, options)
    local ok, why = Camp.check(rect)
    if not ok then return nil, why end
    local camp = Store.create({
        name = (name ~= nil and name ~= "") and name or Camp.defaultName(),
        z = rect.z or 0, x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2,
    })
    if type(options) == "table" then
        for key, value in pairs(options) do camp.options[key] = value end
    end
    camp.tiersOn = true
    Camp.tagFlags(camp)
    Camp.setupStorage(camp)
    Store.clearPending()
    Store.log(camp, "founded")
    return camp
end

function Camp.rename(camp, name)
    if camp == nil or name == nil or name == "" then return false end
    camp.name = string.sub(name, 1, 40)
    return true
end

function Camp.abandon(camp)
    if camp == nil then return false end
    for _, entry in ipairs(camp.storage) do
        local object = Stock.crate(camp, entry)
        if object ~= nil then pcall(function() object:getModData().ALC = nil end) end
    end
    Store.remove(camp.id)
    return true
end

function Camp.refresh(camp)
    Stock.refresh(camp)
    camp.population = Store.settlerCount(camp)
    return camp
end

return Camp
