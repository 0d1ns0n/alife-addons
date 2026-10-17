require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampEntities"

ALifeCamp = ALifeCamp or {}

local World = ALifeCamp.World
local Entities = ALifeCamp.Entities

local Place = {}
ALifeCamp.Place = Place

function Place.square(x, y, z)
    local square = World.square(x, y, z)
    if square ~= nil then return square end
    if (z or 0) > 0 and World.loaded(x, y, 0) then
        pcall(function()
            local cell = getCell()
            if getWorld():isValidSquare(x, y, z) then square = cell:createNewGridSquare(x, y, z, true) end
        end)
    end
    return square
end

function Place.tag(project, slot, kind)
    return { kind = kind or "built", camp = project.camp, project = project.id, slot = slot }
end

function Place.sprite(entityId, face)
    local entity = Entities[entityId]
    if entity == nil then return nil end
    local rows = entity.faces[face] or entity.faces.W or entity.faces.SINGLE or entity.faces.S
    if rows == nil or rows[1] == nil then return nil end
    return rows[1][1]
end

function Place.info(name, north, extra)
    local info = {
        name = tostring(name or "Camp"), north = north == true, canBarricade = false, canPassThrough = false,
        blockAllTheSquare = true, isThumpable = true, isWallLike = true, hoppable = false,
        dismantable = true, canBePlastered = false, isContainer = false, isDoor = false,
        isDoorFrame = false, isStairs = false, isCorner = false, isFloor = false,
        thumpDmg = 8, crossSpeed = 1.0, modData = {},
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do info[key] = value end
    end
    return info
end

function Place.finish(square, object)
    pcall(function() square:RecalcProperties() end)
    pcall(function() square:RecalcAllWithNeighbours(true) end)
    return object
end

function Place.health(entity)
    local base = tonumber(entity and entity.health) or 0
    local skill = tonumber(entity and entity.skill) or 0
    local bonus = tonumber(entity and entity.bonus) or 0
    local total = base + bonus + skill * 4
    if total <= 0 then total = 300 end
    return total
end

function Place.removeSlot(square, slot, projectId)
    local removed = 0
    if square == nil or slot == nil then return 0 end
    pcall(function()
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            local tag = World.tag(object)
            if type(tag) == "table" and tag.slot == slot and (projectId == nil or tag.project == projectId) then
                World.removeHard(square, object)
                removed = removed + 1
            end
        end
    end)
    return removed
end

function Place.retag(square, slot, fromId, toId)
    local moved = 0
    if square == nil or slot == nil then return 0 end
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local tag = World.tag(objects:get(i))
            if type(tag) == "table" and tag.slot == slot and tag.project == fromId then
                tag.project = toId
                moved = moved + 1
            end
        end
    end)
    return moved
end

function Place.floor(x, y, z, sprite, tag)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local object
    pcall(function()
        object = square:addFloor(sprite)
        if object ~= nil and tag ~= nil then object:getModData().ALC = tag end
    end)
    if object == nil then return nil, "failed" end
    return Place.finish(square, object)
end

function Place.piece(entityId, x, y, z, north, tag, extra)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local entity = Entities[entityId]
    local sprite = Place.sprite(entityId, north and "N" or "W")
    if entity == nil or sprite == nil then return nil, "nosprite" end
    local object
    pcall(function()
        local info = Place.info(entityId, north, extra)
        object = IsoThumpable.new(getCell(), square, sprite, north == true, info)
        local health = Place.health(entity)
        object:setMaxHealth(health)
        object:setHealth(health)
        object:setBreakSound(entity.breakSound or "BreakObject")
        pcall(function() object:setName(entityId) end)
        pcall(function() object:setCanPassThrough(info.canPassThrough == true) end)
        pcall(function() object:setCanBarricade(info.canBarricade == true) end)
        pcall(function() object:setIsThumpable(entity.thumpable ~= false) end)
        pcall(function() object:setIsDoor(info.isDoor == true) end)
        pcall(function() object:setIsDoorFrame(info.isDoorFrame == true) end)
        pcall(function() object:setIsHoppable(info.hoppable == true) end)
        if tag ~= nil then object:getModData().ALC = tag end
        square:AddSpecialObject(object)
    end)
    if object == nil then return nil, "failed" end
    return Place.finish(square, object)
end

function Place.corner(x, y, z, north, entityId, tag)
    local entity = Entities[entityId]
    if entity == nil or entity.corner == nil then return nil end
    local xo, yo, sx, sy = 1, -1, x + 1, y
    if not north then xo, yo, sx, sy = -1, 1, x, y + 1 end
    local near = World.square(x + xo, y + yo, z)
    if near == nil then return nil end
    local found = false
    pcall(function()
        local specials = near:getSpecialObjects()
        for i = 0, specials:size() - 1 do
            local item = specials:get(i)
            if instanceof(item, "IsoThumpable") and item:getNorth() ~= north then
                found = true
                break
            end
        end
    end)
    if not found then return nil end
    local target = World.square(sx, sy, z)
    if target == nil then return nil end
    if World.isWaterSquare(target) then return nil end
    local full = false
    pcall(function() full = target:getWallFull() end)
    if full then return nil end
    local object
    pcall(function()
        object = IsoThumpable.new(getCell(), target, entity.corner, false, nil)
        object:setCorner(true)
        object:setCanBarricade(false)
        object:setCanBePlastered(true)
        if tag ~= nil then object:getModData().ALC = tag end
        target:AddSpecialObject(object)
    end)
    if object ~= nil then Place.finish(target, object) end
    return object
end

function Place.door(entityId, x, y, z, north, tag)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local entity = Entities[entityId]
    local closed = Place.sprite(entityId, north and "N" or "W")
    local open = Place.sprite(entityId, north and "N_OPEN" or "W_OPEN")
    if entity == nil or closed == nil then return nil, "nosprite" end
    local object
    pcall(function()
        local info = Place.info(entityId, north, { isDoor = true, canBarricade = true, thumpDmg = 5 })
        if open ~= nil then
            object = IsoThumpable.new(getCell(), square, closed, open, north == true, info)
        else
            object = IsoThumpable.new(getCell(), square, closed, north == true, info)
        end
        local health = Place.health(entity)
        object:setMaxHealth(health)
        object:setHealth(health)
        object:setBreakSound(entity.breakSound or "BreakDoor")
        pcall(function() object:setIsDoor(true) end)
        pcall(function() object:setCanBarricade(true) end)
        pcall(function() object:setName(entityId) end)
        if tag ~= nil then object:getModData().ALC = tag end
        square:AddSpecialObject(object)
    end)
    if object == nil then return nil, "failed" end
    return Place.finish(square, object)
end

function Place.window(sprite, x, y, z, north, tag)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local object
    pcall(function()
        local texture = getSprite(sprite)
        if texture == nil then return end
        object = IsoWindow.new(getCell(), square, texture, north == true)
        pcall(function() object:setIsLocked(false) end)
        if tag ~= nil then object:getModData().ALC = tag end
        square:AddSpecialObject(object)
    end)
    if object == nil then return nil, "failed" end
    return Place.finish(square, object)
end

function Place.prop(sprite, x, y, z, tag, container)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local object
    pcall(function()
        local texture = getSprite(sprite)
        if texture == nil then return end
        object = IsoObject.new(getCell(), square, texture)
        if container ~= nil then
            local box = ItemContainer.new(container, square, object)
            object:setContainer(box)
            pcall(function() object:getContainer():setExplored(true) end)
        end
        if tag ~= nil then object:getModData().ALC = tag end
        square:AddTileObject(object)
    end)
    if object == nil then return nil, "failed" end
    return Place.finish(square, object)
end

function Place.stairs(x, y, z, north, level, sprite, pillar, tag)
    local square = Place.square(x, y, z)
    if square == nil then return nil, "unloaded" end
    local object
    pcall(function()
        object = square:AddStairs(north == true, level, sprite, pillar, nil)
        if object ~= nil then
            pcall(function() object:setIsStairs(true) end)
            pcall(function() object:setCanBarricade(false) end)
            if tag ~= nil then object:getModData().ALC = tag end
        end
        pcall(function() square:RecalcAllWithNeighbours(true) end)
    end)
    if object == nil then return nil, "failed" end
    return object
end

function Place.blocked(x, y, z)
    local square = World.square(x, y, z)
    if square == nil then return true end
    if World.isWaterSquare(square) then return true end
    local blocked = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local tag = World.tag(object)
            if type(tag) ~= "table" then
                local kind = ALifeCamp.Land and ALifeCamp.Land.classify(object)
                if kind ~= nil then blocked = true return end
            end
        end
        if square:getVehicleContainer() ~= nil then blocked = true end
    end)
    return blocked
end

return Place
