require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampLand"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Land = ALifeCamp.Land

local Clear = {}
ALifeCamp.Clear = Clear

Clear.cost = { tree = 6, plant = 1, junk = 1, item = 1, corpse = 3, structure = 3, furniture = 4, misc = 1, vehicle = 8, floor = 2, upper = 2 }
Clear.groundSprite = "blends_natural_01_64"
Clear.maxScan = 500
Clear.exactLimit = 12000
Clear.loadedShare = 0.5
Clear.maxZ = 6

local function removeObject(square, object)
    return ALifeCamp.World.removeHard(square, object)
end

local function yield(camp, list)
    for _, row in ipairs(list) do Stock.deposit(camp, row[1], row[2]) end
end

local function haul(camp, container)
    if container == nil then return 0 end
    local moved = 0
    pcall(function()
        local items = container:getItems()
        for i = items:size() - 1, 0, -1 do
            local item = items:get(i)
            container:Remove(item)
            if ALifeCamp.Recycle ~= nil then ALifeCamp.Recycle.flag(item) end
            local stored = false
            for _, entry in ipairs(camp.storage) do
                local crate = Stock.crate(camp, entry)
                if crate ~= nil then
                    pcall(function()
                        crate:getContainer():AddItem(item)
                        stored = true
                    end)
                    if stored then break end
                end
            end
            if stored then moved = moved + 1 end
        end
    end)
    return moved
end

local function nearBuilding(square)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local neighbour = World.square(x + dx, y + dy, z)
            if neighbour ~= nil then
                local built = false
                pcall(function() built = neighbour:getBuilding() ~= nil end)
                if built then return true end
            end
        end
    end
    return false
end

local function guarded(camp, square)
    local adopt = ALifeCamp.Adopt
    if adopt == nil then return false end
    local ok, result = pcall(adopt.guards, camp, square)
    return ok and result == true
end

local function allowed(kind, demolish, inBuilding, square)
    if kind == "tree" or kind == "plant" or kind == "junk" or kind == "item" or kind == "corpse" or kind == "vehicle" then
        return true
    end
    if demolish then return true end
    if inBuilding then return false end
    if kind == "furniture" or kind == "misc" then return true end
    if kind == "structure" then return not nearBuilding(square) end
    return false
end

function Clear.scanSquare(camp, square, demolish)
    local out = {}
    local z = square:getZ()
    local inBuilding = false
    pcall(function() inBuilding = square:getBuilding() ~= nil end)
    if guarded(camp, square) then
        demolish = false
        inBuilding = true
    end
    local wipe = demolish and (z > camp.z or inBuilding)
    pcall(function()
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            local kind = Land.classify(object)
            if kind == nil and wipe and World.tag(object) == nil and not instanceof(object, "IsoMovingObject") then
                if z > camp.z then
                    kind = "upper"
                else
                    local solidFloor = false
                    local props = World.props(object)
                    if props ~= nil then pcall(function() solidFloor = props:has(IsoFlagType.solidfloor) end) end
                    if solidFloor then
                        local name = ""
                        local sprite = World.sprite(object)
                        if sprite ~= nil then pcall(function() name = sprite:getName() end) end
                        if name ~= Clear.groundSprite then kind = "floor" end
                    end
                end
            end
            if kind ~= nil and allowed(kind, demolish, inBuilding, square) then
                out[#out + 1] = { kind = kind, object = object, square = square }
            end
        end
        local wobjects = square:getWorldObjects()
        for i = wobjects:size() - 1, 0, -1 do
            out[#out + 1] = { kind = "item", wobject = wobjects:get(i), square = square }
        end
        local bodies = square:getDeadBodys()
        for i = bodies:size() - 1, 0, -1 do
            out[#out + 1] = { kind = "corpse", body = bodies:get(i), square = square }
        end
        local vehicle = square:getVehicleContainer()
        if vehicle ~= nil then out[#out + 1] = { kind = "vehicle", vehicle = vehicle, square = square } end
    end)
    return out
end

function Clear.apply(camp, entry)
    local square = entry.square
    local kind = entry.kind
    local ok = false
    local structural = kind == "structure" or kind == "furniture" or kind == "misc" or kind == "floor" or kind == "upper"
    if structural and guarded(camp, square) then return false end
    if kind == "tree" then
        ok = removeObject(square, entry.object)
        if ok then yield(camp, { { "Base.Log", 2 }, { "Base.Twigs", 3 } }) end
    elseif kind == "plant" or kind == "junk" or kind == "misc" or kind == "upper" then
        ok = removeObject(square, entry.object)
    elseif kind == "structure" or kind == "furniture" then
        local container
        pcall(function() container = entry.object:getContainer() end)
        if container ~= nil then haul(camp, container) end
        ok = removeObject(square, entry.object)
        if ok then yield(camp, { { "Base.Plank", 1 } }) end
    elseif kind == "floor" then
        ok = removeObject(square, entry.object)
        if ok then pcall(function() square:addFloor(Clear.groundSprite) end) end
    elseif kind == "item" then
        local wobject = entry.wobject or entry.object
        entry.wobject = wobject
        pcall(function()
            local item = wobject:getItem()
            if ALifeCamp.Recycle ~= nil then ALifeCamp.Recycle.flag(item) end
            for _, crate in ipairs(camp.storage) do
                local object = Stock.crate(camp, crate)
                if object ~= nil then
                    object:getContainer():AddItem(item)
                    square:transmitRemoveItemFromSquare(entry.wobject)
                    pcall(function() entry.wobject:removeFromWorld() end)
                    pcall(function() entry.wobject:removeFromSquare() end)
                    ok = true
                    return
                end
            end
            square:transmitRemoveItemFromSquare(entry.wobject)
            pcall(function() entry.wobject:removeFromWorld() end)
            pcall(function() entry.wobject:removeFromSquare() end)
            ok = true
        end)
    elseif kind == "corpse" then
        pcall(function()
            square:removeCorpse(entry.body, false)
            ok = true
        end)
    elseif kind == "vehicle" then
        pcall(function()
            entry.vehicle:permanentlyRemove()
            ok = true
        end)
        if ok then yield(camp, { { "Base.ScrapMetal", 3 } }) end
    end
    if ok then
        pcall(function() square:RecalcProperties() end)
        pcall(function() square:RecalcAllWithNeighbours(true) end)
        camp.stats.cleared = camp.stats.cleared + 1
        local state = Clear.state(camp)
        state.last = { x = square:getX(), y = square:getY(), z = square:getZ() }
    end
    return ok
end

function Clear.state(camp)
    if type(camp.clear) ~= "table" then camp.clear = { index = 0, passes = 0, removed = 0, lastRemoved = 0 } end
    return camp.clear
end

function Clear.squaresAt(camp, x, y)
    local list = {}
    local square0 = World.square(x, y, camp.z)
    if square0 == nil then return list end
    list[1] = square0
    if camp.options.demolish then
        if not guarded(camp, square0) then
            for z = 1, Clear.maxZ do
                local up = World.square(x, y, camp.z + z)
                if up ~= nil then list[#list + 1] = up end
            end
        end
    end
    return list
end

function Clear.step(camp, budget, limitRect)
    local state = Clear.state(camp)
    local width, height = Geo.width(camp), Geo.height(camp)
    local total = width * height
    local spent, removed, scanned = 0, 0, 0
    local demolish = camp.options.demolish == true
    local guard = 0
    while spent < budget and scanned < Clear.maxScan and guard < total + 1 do
        guard = guard + 1
        local i = state.index
        local x = camp.x1 + i % width
        local y = camp.y1 + math.floor(i / width)
        local inLimit = limitRect == nil or Geo.contains(limitRect, x, y)
        local advance = true
        if inLimit then
            scanned = scanned + 1
            for _, square in ipairs(Clear.squaresAt(camp, x, y)) do
                local entries = Clear.scanSquare(camp, square, demolish)
                for _, entry in ipairs(entries) do
                    if spent >= budget then
                        advance = false
                        break
                    end
                    local cost = Clear.cost[entry.kind] or 1
                    if Clear.apply(camp, entry) then
                        removed = removed + 1
                        spent = spent + cost
                    end
                end
                if not advance then break end
            end
        end
        if advance then
            state.index = i + 1
            if state.index >= total then
                state.index = 0
                state.passes = state.passes + 1
                state.lastRemoved = state.removed
                state.removed = 0
                state.passDone = true
                break
            end
        else
            break
        end
    end
    state.removed = state.removed + removed
    return spent, removed
end

function Clear.finished(camp, rect)
    local state = Clear.state(camp)
    if not state.passDone then return false end
    state.passDone = false
    if state.lastRemoved > 0 then return false end
    rect = rect or camp
    if Geo.area(rect) > Clear.exactLimit then
        local sample = Land.survey(rect, Land.stride(rect, 3000))
        return sample.loaded >= sample.total * Clear.loadedShare
    end
    local survey = Land.survey(rect, 1, camp)
    if survey.loaded < survey.total * Clear.loadedShare then return false end
    local dirty = Land.dirty(rect, 1, camp)
    return dirty == 0
end

function Clear.prepare(camp, rect, budget)
    local spent, ready = 0, true
    local demolish = camp.options.demolish == true
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            if World.square(x, y, camp.z) == nil then
                ready = false
            else
                for _, square in ipairs(Clear.squaresAt(camp, x, y)) do
                    local entries = Clear.scanSquare(camp, square, demolish)
                    for _, entry in ipairs(entries) do
                        if spent >= budget then return false, spent end
                        if Clear.apply(camp, entry) then spent = spent + (Clear.cost[entry.kind] or 1) end
                    end
                end
            end
        end
    end
    return ready, spent
end

return Clear
