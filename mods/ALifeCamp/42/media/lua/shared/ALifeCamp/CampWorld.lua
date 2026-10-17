require "ALifeCamp/CampConfig"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config

local World = {}
ALifeCamp.World = World

function World.square(x, y, z)
    local square
    pcall(function() square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0)) end)
    return square
end

function World.loaded(x, y, z)
    local square = World.square(x, y, z)
    if square == nil then return false end
    local chunkOk = true
    pcall(function()
        if square.getChunk ~= nil and square:getChunk() == nil then chunkOk = false end
    end)
    return chunkOk
end

local function flagWater(props)
    if props == nil then return false end
    local hit = false
    pcall(function() if props:has(IsoFlagType.water) then hit = true end end)
    if not hit then
        pcall(function() if props:has(IsoFlagType.taintedWater) then hit = true end end)
    end
    return hit
end
World.flagWater = flagWater

function World.isWaterSquare(square)
    if square == nil then return false end
    local water = false
    pcall(function()
        if flagWater(square:getProperties()) then water = true end
    end)
    if water then return true end
    pcall(function()
        local floor = square:getFloor()
        if floor == nil then return end
        local sprite = floor:getSprite()
        if sprite == nil then return end
        if flagWater(sprite:getProperties()) then water = true return end
        local name = sprite:getName() or ""
        if string.sub(name, 1, 6) == "water_" then water = true end
    end)
    if water then return true end
    pcall(function()
        local objects = square:getObjects()
        if objects == nil then return end
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj ~= nil then
                local sp = obj:getSprite()
                if sp ~= nil and flagWater(sp:getProperties()) then water = true return end
            end
        end
    end)
    return water
end

function World.isWater(x, y, z)
    local square = World.square(x, y, z)
    if square == nil then return nil end
    return World.isWaterSquare(square)
end

function World.each(list, fn)
    if list == nil then return end
    local function member(name)
        local found
        pcall(function() found = list[name] end)
        if type(found) == "function" then return found end
        return nil
    end
    local size, get, iterator = member("size"), member("get"), member("iterator")
    if size ~= nil and get ~= nil then
        local count = 0
        pcall(function() count = size(list) end)
        for i = 0, (tonumber(count) or 0) - 1 do
            local item
            pcall(function() item = get(list, i) end)
            if item ~= nil then fn(item) end
        end
        return
    end
    if iterator ~= nil then
        pcall(function()
            local walker = iterator(list)
            while walker:hasNext() do fn(walker:next()) end
        end)
    end
end

function World.sprite(object)
    local sprite
    if object == nil then return nil end
    pcall(function() sprite = object:getSprite() end)
    return sprite
end

function World.props(object)
    local sprite = World.sprite(object)
    if sprite == nil then return nil end
    local props
    pcall(function() props = sprite:getProperties() end)
    return props
end

function World.tag(object)
    local tag
    pcall(function()
        local data = object:getModData()
        if data ~= nil then tag = data.ALC end
    end)
    return tag
end

function World.find(square, kind, campId)
    if square == nil then return nil end
    local found
    pcall(function()
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            local tag = World.tag(object)
            if type(tag) == "table" and tag.kind == kind and (campId == nil or tag.camp == campId or tag.camp == nil) then
                found = object
                return
            end
        end
    end)
    return found
end

function World.addTagged(x, y, z, sprite, tag)
    local square = World.square(x, y, z)
    if square == nil then return nil end
    local placed
    pcall(function()
        local texture = getSprite(sprite)
        if texture == nil then return end
        local object = IsoObject.new(getCell(), square, texture)
        if object == nil then return end
        object:getModData().ALC = tag
        square:AddTileObject(object)
        pcall(function() square:RecalcProperties() end)
        pcall(function() square:RecalcAllWithNeighbours(true) end)
        placed = object
    end)
    return placed
end

function World.putFlag(x, y, z, tag)
    return World.addTagged(x, y, z, Config.flagSprite, tag)
end

function World.putCrate(x, y, z, tag, sprite)
    local square = World.square(x, y, z)
    if square == nil then return nil end
    local placed
    pcall(function()
        local texture = getSprite(sprite or Config.crateSprite)
        if texture == nil then return end
        local object = IsoObject.new(getCell(), square, texture)
        if object == nil then return end
        local container = ItemContainer.new("crate", square, object)
        object:setContainer(container)
        container = object:getContainer() or container
        pcall(function() container:setType("crate") end)
        pcall(function() container:setCapacity(Config.crateCapacity) end)
        pcall(function() container:setExplored(true) end)
        object:getModData().ALC = tag
        square:AddTileObject(object)
        pcall(function() square:RecalcProperties() end)
        pcall(function() square:RecalcAllWithNeighbours(true) end)
        placed = object
    end)
    return placed
end

local function onSquare(square, object)
    local found = false
    pcall(function()
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            if objs:get(i) == object then found = true break end
        end
    end)
    return found
end

function World.removeHard(square, object)
    if square == nil or object == nil then return false end
    pcall(function() square:transmitRemoveItemFromSquare(object) end)
    if onSquare(square, object) then pcall(function() square:RemoveTileObject(object, false) end) end
    if onSquare(square, object) then pcall(function() square:RemoveTileObject(object) end) end
    return not onSquare(square, object)
end

function World.remove(object)
    if object == nil then return false end
    local square
    pcall(function() square = object:getSquare() end)
    if square == nil then return false end
    return World.removeHard(square, object)
end

function World.free(x, y, z)
    local square = World.square(x, y, z)
    if square == nil then return false end
    local free = false
    pcall(function() free = square:isFree(false) == true and square:isOutside() == true end)
    return free
end

function World.freeAround(cx, cy, z, radius)
    for r = 0, radius do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    if World.free(cx + dx, cy + dy, z) then return cx + dx, cy + dy end
                end
            end
        end
    end
    return nil
end

return World
