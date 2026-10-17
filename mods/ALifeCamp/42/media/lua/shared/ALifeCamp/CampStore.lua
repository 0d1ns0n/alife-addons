require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Geo = ALifeCamp.Geo

local Store = {}
ALifeCamp.Store = Store

function Store.hours()
    local ok, hours = pcall(function() return getGameTime():getWorldAgeHours() end)
    if ok and type(hours) == "number" then return hours end
    return 0
end

function Store.data()
    local data = ModData.getOrCreate(Config.key)
    data.version = data.version or 1
    data.serial = data.serial or 0
    if type(data.camps) ~= "table" then data.camps = {} end
    if type(data.pending) ~= "table" then data.pending = {} end
    if type(data.pending.flags) ~= "table" then data.pending.flags = {} end
    return data
end

function Store.list()
    local out = {}
    for _, camp in pairs(Store.data().camps) do out[#out + 1] = camp end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Store.count()
    local n = 0
    for _ in pairs(Store.data().camps) do n = n + 1 end
    return n
end

function Store.get(id)
    if id == nil then return nil end
    return Store.data().camps[tostring(id)]
end

function Store.stats()
    return { built = 0, cleared = 0, harvested = 0, days = 0, raids = 0, arrived = 0, left = 0, hauled = 0 }
end

function Store.create(spec)
    local data = Store.data()
    data.serial = data.serial + 1
    local id = data.serial
    local camp = {
        id = id,
        name = spec.name,
        z = spec.z or 0,
        x1 = spec.x1, y1 = spec.y1, x2 = spec.x2, y2 = spec.y2,
        founded = Store.hours(),
        lastHour = Store.hours(),
        level = 1,
        storage = {},
        stock = {},
        settlers = {},
        sites = {},
        plan = { done = {}, queue = {} },
        stats = Store.stats(),
        log = {},
        options = { border = true, adopt = false },
    }
    data.camps[tostring(id)] = camp
    return camp
end

function Store.remove(id)
    Store.data().camps[tostring(id)] = nil
end

function Store.campAt(x, y, z)
    for _, camp in pairs(Store.data().camps) do
        if (z == nil or camp.z == z) and Geo.contains(camp, x, y) then return camp end
    end
    return nil
end

function Store.overlapping(rect)
    for _, camp in pairs(Store.data().camps) do
        if (rect.z == nil or camp.z == rect.z) and Geo.overlaps(camp, rect) then return camp end
    end
    return nil
end

function Store.nearest(x, y, limit)
    local best, bestDistance
    for _, camp in pairs(Store.data().camps) do
        local distance = Geo.distanceTo(camp, x, y)
        if (limit == nil or distance <= limit) and (bestDistance == nil or distance < bestDistance) then
            best, bestDistance = camp, distance
        end
    end
    return best, bestDistance
end

function Store.log(camp, key, a, b)
    if camp == nil then return end
    camp.log[#camp.log + 1] = { h = Store.hours(), k = key, a = a, b = b }
    while #camp.log > Config.logLimit do table.remove(camp.log, 1) end
end

function Store.settlerCount(camp)
    local n = 0
    for _ in pairs(camp.settlers) do n = n + 1 end
    return n
end

function Store.pending()
    return Store.data().pending.flags
end

function Store.clearPending()
    Store.data().pending.flags = {}
end

function Store.day(camp)
    return math.max(0, math.floor((Store.hours() - (camp.founded or 0)) / 24))
end

return Store
