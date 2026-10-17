require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampBuild"
require "ALifeCamp/Camp"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store

local Regen = {}
ALifeCamp.Regen = Regen

Regen.margin = 16
Regen.maxZ = 2
Regen.stepBudget = 24
Regen.ttlHours = 96
Regen.anyPending = false

local function cell()
    local c
    pcall(function() c = getCell() end)
    return c
end

function Regen.chunkSize()
    local size = 8
    pcall(function()
        local s = getChunkSizeInSquares()
        if type(s) == "number" and s > 0 then size = s end
    end)
    return size
end

function Regen.zones()
    local data = Store.data()
    if type(data.regenZones) ~= "table" then data.regenZones = {} end
    return data.regenZones
end

local function hasZones()
    for _ in pairs(Regen.zones()) do return true end
    return false
end

function Regen.regenChunk(c, wx, wy)
    local chunk
    pcall(function() chunk = c:getChunk(wx, wy) end)
    if chunk == nil then return false, false end
    local ok = false
    pcall(function()
        chunk:Blam(wx, wy)
        chunk:LoadChunk(wx, wy, nil)
        ok = true
    end)
    pcall(function() chunk:recalcNeighboursNow() end)
    pcall(function() chunk:setCache() end)
    pcall(function() chunk:invalidateRenderChunkLevels(0) end)
    pcall(function() chunk:checkLightingLater_AllPlayers_AllLevels() end)
    return true, ok
end

function Regen.purgeChunk(c, wx, wy, size, campId, z0)
    local World = ALifeCamp.World
    if World == nil or type(World.tag) ~= "function" then return 0 end
    local x0, y0 = wx * size, wy * size
    local removed = 0
    for z = z0, z0 + Regen.maxZ do
        for x = x0, x0 + size - 1 do
            for y = y0, y0 + size - 1 do
                local square
                pcall(function() square = c:getGridSquare(x, y, z) end)
                if square ~= nil then
                    local hit = false
                    pcall(function()
                        local objects = square:getObjects()
                        for i = objects:size() - 1, 0, -1 do
                            local obj = objects:get(i)
                            local tag = World.tag(obj)
                            if type(tag) == "table" and (tag.camp == campId or tag.project ~= nil) then
                                World.removeHard(square, obj)
                                removed = removed + 1
                                hit = true
                            end
                        end
                    end)
                    if hit then
                        pcall(function() square:RecalcProperties() end)
                        pcall(function() square:RecalcAllWithNeighbours(true) end)
                    end
                end
            end
        end
    end
    return removed
end

function Regen.step(campId, zone, budget)
    local c = cell()
    if c == nil then return 0, true end
    local size = Regen.chunkSize()
    local processed, left = 0, false
    for wx = zone.wx1, zone.wx2 do
        for wy = zone.wy1, zone.wy2 do
            local key = wx .. ":" .. wy
            if not zone.done[key] then
                if processed >= budget then
                    left = true
                else
                    local chunk
                    pcall(function() chunk = c:getChunk(wx, wy) end)
                    if chunk == nil then
                        left = true
                    else
                        -- remove OUR tagged objects (all z) FIRST, while squares are valid,
                        -- then regenerate the chunk to vanilla. Doing it after Blam misses
                        -- objects whose square the Blam orphaned/replaced.
                        Regen.purgeChunk(c, wx, wy, size, campId, zone.z0)
                        Regen.regenChunk(c, wx, wy)
                        zone.done[key] = true
                        processed = processed + 1
                    end
                end
            end
        end
    end
    return processed, left
end

function Regen.queue(camp)
    local size = Regen.chunkSize()
    local m = Regen.margin
    local zone = {
        wx1 = math.floor((camp.x1 - m) / size), wy1 = math.floor((camp.y1 - m) / size),
        wx2 = math.floor((camp.x2 + m) / size), wy2 = math.floor((camp.y2 + m) / size),
        z0 = camp.z or 0, done = {}, expire = Store.hours() + Regen.ttlHours,
    }
    Regen.zones()[tostring(camp.id)] = zone
    Regen.anyPending = true
    return zone
end

function Regen.sweep(budget)
    local zones = Regen.zones()
    local now = Store.hours()
    local remaining = 0
    local drop = {}
    for id, zone in pairs(zones) do
        local _, left = Regen.step(id, zone, budget)
        if not left or (type(zone.expire) == "number" and now > zone.expire) then
            drop[#drop + 1] = id
        else
            remaining = remaining + 1
        end
    end
    for _, id in ipairs(drop) do zones[id] = nil end
    Regen.anyPending = hasZones()
    return remaining
end

function Regen.clearSettlers(camp)
    local count = 0
    if type(camp.settlers) == "table" then
        for _ in pairs(camp.settlers) do count = count + 1 end
    end
    camp.settlers = {}
    camp.population = 0
    local settlers = ALifeCamp.Settlers
    if settlers ~= nil and type(settlers.onReset) == "function" then pcall(settlers.onReset, camp) end
    return count
end

function Regen.wipeState(camp)
    camp.plan = { items = {}, serial = 0 }
    camp.clear = nil
    camp.active = {}
    camp.phase = "plan"
    camp.planIdle = nil
    camp.planClock = nil
    camp.allBuiltNoted = nil
    camp.retiredFence = nil
    camp.storage = {}
    pcall(function() if type(ALifeCamp.Camp.setupStorage) == "function" then ALifeCamp.Camp.setupStorage(camp) end end)
    pcall(function() if ALifeCamp.Stock ~= nil and type(ALifeCamp.Stock.refresh) == "function" then ALifeCamp.Stock.refresh(camp) end end)
end

function Regen.run(camp)
    local result = { settlers = 0, processed = 0, pending = false }
    if camp == nil then return result end
    result.settlers = Regen.clearSettlers(camp)
    local zone = Regen.queue(camp)
    local processed, left = Regen.step(tostring(camp.id), zone, 1000000)
    result.processed = processed
    if not left then Regen.zones()[tostring(camp.id)] = nil end
    Regen.anyPending = hasZones()
    result.pending = left
    Regen.wipeState(camp)
    if ALifeCamp.Reset ~= nil and type(ALifeCamp.Reset.wipeArea) == "function" then
        pcall(ALifeCamp.Reset.wipeArea, camp)
    end
    pcall(function() Store.log(camp, "regen", processed) end)
    print("[ALifeCamp:Regen] processed=" .. processed .. " pending=" .. tostring(left) .. " settlers=" .. result.settlers)
    return result
end

if Events ~= nil then
    pcall(function()
        Events.EveryOneMinute.Add(function()
            if not Regen.anyPending then return end
            if isClient ~= nil and isClient() == true then return end
            pcall(Regen.sweep, Regen.stepBudget)
        end)
    end)
    if Events.OnGameStart ~= nil then
        pcall(function() Events.OnGameStart.Add(function() pcall(function() Regen.anyPending = hasZones() end) end) end)
    end
end

return Regen
