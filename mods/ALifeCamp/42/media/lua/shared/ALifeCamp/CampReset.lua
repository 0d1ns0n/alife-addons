require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampExpand"
require "ALifeCamp/Camp"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Expand = ALifeCamp.Expand

local Reset = {}
ALifeCamp.Reset = Reset

Reset.ground = "blends_natural_01_64"

local function projectCrate(camp, entry)
    local object = Stock.crate(camp, entry)
    if object == nil then return nil, nil end
    local tag = World.tag(object)
    if type(tag) == "table" and tag.project ~= nil then return object, tag end
    return nil, nil
end

local function keeper(camp)
    for _, entry in ipairs(camp.storage) do
        local object = Stock.crate(camp, entry)
        local tag = object ~= nil and World.tag(object) or nil
        if object ~= nil and type(tag) == "table" and tag.project == nil then return object end
    end
    local cx, cy = Geo.center(camp)
    local fx, fy = World.freeAround(cx, cy, camp.z, 8)
    if fx ~= nil and ALifeCamp.Camp.addStorage(camp, fx, fy, camp.z) then
        local entry = camp.storage[#camp.storage]
        return Stock.crate(camp, entry)
    end
    return nil
end

function Reset.evacuate(camp)
    local doomed = {}
    for _, entry in ipairs(camp.storage) do
        local object = projectCrate(camp, entry)
        if object ~= nil then doomed[#doomed + 1] = object end
    end
    if #doomed == 0 then return 0 end
    local target = keeper(camp)
    local container
    if target ~= nil then pcall(function() container = target:getContainer() end) end
    if container == nil then return -1 end
    local moved = 0
    for _, object in ipairs(doomed) do
        pcall(function()
            local from = object:getContainer()
            local items = from:getItems()
            for i = items:size() - 1, 0, -1 do
                local item = items:get(i)
                from:Remove(item)
                container:AddItem(item)
                moved = moved + 1
            end
        end)
    end
    return moved
end

local function doneOps(project)
    local out = {}
    for _, stage in ipairs(Bp.stages(project)) do
        for _, op in ipairs(stage.ops) do
            if project.done[stage.id .. "/" .. op.slot] then out[#out + 1] = op end
        end
    end
    return out
end

local function loadedAll(project, ops)
    for _, op in ipairs(ops) do
        if World.square(op.x, op.y, op.z or 0) == nil then return false end
    end
    return true
end

Reset.margin = 2
Reset.maxZ = 2

local function inBand(px, py, x1, y1, x2, y2, band)
    return px <= x1 + band or px >= x2 - band or py <= y1 + band or py >= y2 - band
end

function Reset.purge(camp, project)
    local rect = Bp.footprint(project)
    local band = Reset.margin + 2
    local x1, y1 = rect.x1 - Reset.margin, rect.y1 - Reset.margin
    local x2, y2 = rect.x2 + Reset.margin, rect.y2 + Reset.margin
    local border = project.kind == "fence"
    local id = project.id
    local removed, unloaded = 0, false
    for z = camp.z, camp.z + Reset.maxZ do
        for px = x1, x2 do
            for py = y1, y2 do
                if not border or inBand(px, py, x1, y1, x2, y2, band) then
                    local core = px >= rect.x1 and px <= rect.x2 and py >= rect.y1 and py <= rect.y2
                    local square = World.square(px, py, z)
                    if square == nil then
                        if z == camp.z and core then unloaded = true end
                    else
                        pcall(function()
                            local objects = square:getObjects()
                            for i = objects:size() - 1, 0, -1 do
                                local object = objects:get(i)
                                local tag = World.tag(object)
                                if type(tag) == "table" and tag.project == id then
                                    World.removeHard(square, object)
                                    removed = removed + 1
                                end
                            end
                        end)
                        if z == camp.z then
                            local hasFloor = true
                            pcall(function() hasFloor = square:getFloor() ~= nil end)
                            if not hasFloor then pcall(function() square:addFloor(Reset.ground) end) end
                        end
                    end
                end
            end
        end
    end
    return removed, unloaded
end

Reset.wipeMargin = 6
Reset.zeroMargin = 24
Reset.wipeMaxZ = 4

Reset.zeroFollowups = 6
Reset.zeroEvery = 4 / 60

local function isFloorObject(object, square)
    local yes = false
    pcall(function() if object == square:getFloor() then yes = true end end)
    if yes then return true end
    pcall(function()
        local sprite = object:getSprite()
        local name = sprite:getName() or ""
        if string.find(name, "rug", 1, true) ~= nil then return end
        if sprite:getProperties():has(IsoFlagType.solidfloor) then yes = true end
    end)
    return yes
end

local function wipeKeep(object, square, keepFloor, plan)
    if keepFloor and isFloorObject(object, square) then return true end
    local tag = World.tag(object)
    if type(tag) == "table" then
        if tag.kind == "storage" or tag.kind == "flag" then return true end
        if plan ~= nil and tag.project ~= nil and plan[tostring(tag.project)] ~= nil then return true end
    end
    return false
end

local function stillThere(square, object)
    local found = false
    pcall(function()
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            if objs:get(i) == object then found = true break end
        end
    end)
    return found
end

local function spriteName(object)
    local name = "?"
    pcall(function() name = object:getSprite():getName() or "?" end)
    return name
end

local function skipSquare(camp, px, py, keepAdopted)
    if not keepAdopted then return false end
    local adopt = ALifeCamp.Adopt
    if adopt == nil or type(adopt.covered) ~= "function" then return false end
    local covered = false
    pcall(function() covered = adopt.covered(camp, px, py) ~= nil end)
    return covered
end

function Reset.wipeArea(camp, deep, margin, force, plan)
    margin = margin or Reset.wipeMargin
    local x1, y1 = camp.x1 - margin, camp.y1 - margin
    local x2, y2 = camp.x2 + margin, camp.y2 + margin
    local keepAdopted = (not force) and camp.options ~= nil and camp.options.adopt == true
    local removed, unloaded, stuck = 0, false, 0
    local stuckNames = {}
    for z = camp.z, camp.z + Reset.wipeMaxZ do
        local keepFloor = z == camp.z
        for px = x1, x2 do
            for py = y1, y2 do
                local square = World.square(px, py, z)
                if square == nil then
                    if z == camp.z then unloaded = true end
                elseif not World.isWaterSquare(square) and not skipSquare(camp, px, py, keepAdopted) then
                    local doomed = {}
                    pcall(function()
                        local objects = square:getObjects()
                        for i = objects:size() - 1, 0, -1 do
                            local object = objects:get(i)
                            if object ~= nil and not wipeKeep(object, square, keepFloor, plan) then
                                doomed[#doomed + 1] = object
                            end
                        end
                    end)
                    for _, object in ipairs(doomed) do
                        World.removeHard(square, object)
                        if stillThere(square, object) then
                            stuck = stuck + 1
                            if #stuckNames < 12 then stuckNames[#stuckNames + 1] = spriteName(object) .. "@" .. px .. "," .. py .. "," .. z end
                        else
                            removed = removed + 1
                        end
                    end
                    if deep then
                        pcall(function()
                            local list = square:getWorldObjects()
                            if list ~= nil then
                                for i = list:size() - 1, 0, -1 do
                                    local w = list:get(i)
                                    if w ~= nil then
                                        pcall(function() square:transmitRemoveItemFromSquare(w) end)
                                        pcall(function() w:removeFromWorld() end)
                                        pcall(function() w:removeFromSquare() end)
                                        removed = removed + 1
                                    end
                                end
                            end
                        end)
                        pcall(function()
                            local bodies = square:getDeadBodys()
                            if bodies ~= nil then
                                local snapshot = {}
                                for i = 0, bodies:size() - 1 do snapshot[#snapshot + 1] = bodies:get(i) end
                                for _, body in ipairs(snapshot) do
                                    pcall(function() square:removeCorpse(body, false) end)
                                    removed = removed + 1
                                end
                            end
                        end)
                        pcall(function() square:removeBlood(true, true) end)
                    end
                    if z == camp.z then
                        local hasFloor = true
                        pcall(function() hasFloor = square:getFloor() ~= nil end)
                        if not hasFloor then pcall(function() square:addFloor(Reset.ground) end) end
                        pcall(function() square:RecalcProperties() end)
                        pcall(function() square:RecalcAllWithNeighbours(true) end)
                    end
                end
            end
        end
    end
    print("[ALifeCamp:Reset] wipeArea removed=" .. removed .. " stuck=" .. stuck .. " unloaded=" .. tostring(unloaded)
        .. " deep=" .. tostring(deep == true) .. " rect=" .. x1 .. "," .. y1 .. ".." .. x2 .. "," .. y2)
    if #stuckNames > 0 then print("[ALifeCamp:Reset] stuck sample: " .. table.concat(stuckNames, " | ")) end
    return removed, unloaded, stuck
end

function Reset.stopAdopt(camp)
    if type(camp.options) == "table" then camp.options.adopt = false end
    camp.adopt = { items = {}, skipped = {} }
    camp.adoptActive = {}
end

function Reset.zeroClean(camp)
    local result = { removed = 0, far = false }
    if camp == nil then return result end
    pcall(Reset.evacuate, camp)
    Reset.stopAdopt(camp)
    local items = Build.plan(camp).items
    for key, project in pairs(items) do
        pcall(function() if ALifeCamp.Site ~= nil then ALifeCamp.Site.clear(camp, project) end end)
        items[key] = nil
    end
    local ok, removed, unloaded = pcall(Reset.wipeArea, camp, true, Reset.zeroMargin, true, nil)
    if ok then
        result.removed = tonumber(removed) or 0
        result.far = unloaded == true
    end
    camp.zeroSweeps = Reset.zeroFollowups
    camp.zeroNext = Store.hours() + Reset.zeroEvery
    camp.phase = "plan"
    camp.active = {}
    camp.planIdle = nil
    camp.planClock = nil
    camp.allBuiltNoted = nil
    camp.retiredFence = nil
    pcall(function() Stock.refresh(camp) end)
    pcall(function() Store.log(camp, "zeroclean", result.removed) end)
    return result
end

function Reset.run(camp)
    local result = { projects = 0, removed = 0, far = 0, moved = 0 }
    if camp == nil then return result end
    local moved = Reset.evacuate(camp)
    if moved < 0 then
        result.blocked = true
        return result
    end
    result.moved = moved
    local list = {}
    for _, project in pairs(Build.plan(camp).items) do list[#list + 1] = project end
    table.sort(list, function(a, b) return (tonumber(a.id) or 0) > (tonumber(b.id) or 0) end)
    for _, project in ipairs(list) do
        local ok, removed, unloaded = pcall(Reset.purge, camp, project)
        if ok and unloaded then
            result.far = result.far + 1
        elseif ok then
            result.projects = result.projects + 1
            local gone = tonumber(removed) or 0
            result.removed = result.removed + gone
            if gone > 0 then pcall(Stock.deposit, camp, "Base.Plank", math.floor(gone / 2)) end
            pcall(Build.remove, camp, project.id)
        end
    end
    for i = #camp.storage, 1, -1 do
        local entry = camp.storage[i]
        if World.square(entry.x, entry.y, entry.z or camp.z) ~= nil and Stock.crate(camp, entry) == nil then
            table.remove(camp.storage, i)
        end
    end
    local okw, wiped = pcall(Reset.wipeArea, camp)
    if okw then result.wiped = tonumber(wiped) or 0 end
    camp.phase = "plan"
    camp.active = {}
    camp.planIdle = nil
    camp.planClock = nil
    camp.allBuiltNoted = nil
    camp.retiredFence = nil
    Stock.refresh(camp)
    Store.log(camp, "reset", result.projects)
    return result
end

function Reset.followup(camp)
    if camp == nil or (tonumber(camp.zeroSweeps) or 0) <= 0 then return end
    local now = Store.hours()
    if camp.zeroNext ~= nil and now < camp.zeroNext then return end
    camp.zeroNext = now + Reset.zeroEvery
    camp.zeroSweeps = camp.zeroSweeps - 1
    if type(camp.options) == "table" and camp.options.adopt == true then Reset.stopAdopt(camp) end
    local ok, removed, unloaded = pcall(Reset.wipeArea, camp, false, Reset.zeroMargin, true, Build.plan(camp).items)
    if ok and (tonumber(removed) or 0) == 0 and unloaded ~= true then camp.zeroSweeps = 0 end
end

if ALifeCamp.Hooks ~= nil then
    ALifeCamp.Hooks.add("minute", function(camp) pcall(Reset.followup, camp) end, 3)
end

return Reset
