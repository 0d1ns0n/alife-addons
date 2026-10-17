require "ALifeCamp/CampConfig"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampGates"

ALifeCamp = ALifeCamp or {}

local Entities = ALifeCamp.Entities
local Place = ALifeCamp.Place
local Gates = ALifeCamp.Gates

local Bp = {}
ALifeCamp.Blueprints = Bp

Bp.sprites = {
    roof = "roofs_02_22",
    campfire = "camping_01_4",
    tent = { "camping_01_2", "camping_01_3" },
    dirt = { "blends_natural_01_69", "blends_natural_01_70", "blends_natural_01_71" },
    crops = { "vegetation_farm_01_32", "vegetation_farm_01_33", "vegetation_farm_01_34", "vegetation_farm_01_35", "vegetation_farm_01_36", "vegetation_farm_01_38" },
    glassW = "fixtures_windows_01_0",
    glassN = "fixtures_windows_01_1",
    lamp = "carpentry_02_61",
    bench = { "furniture_seating_outdoor_01_0", "furniture_seating_outdoor_01_1" },
}

Bp.stockKinds = {
    ["Base.Plank"] = "planks", ["Base.Nails"] = "nails", ["Base.Log"] = "logs",
    ["Base.ScrapMetal"] = "metal", ["Base.SmallSheetMetal"] = "metal", ["Base.SheetMetal"] = "metal",
    ["Base.MetalPipe"] = "metal", ["Base.Rope"] = "rope", ["Base.Twine"] = "rope",
    ["Base.RippedSheets"] = "rope", ["Base.SheetRope"] = "rope",
}

Bp.flat = {
    roof = { planks = 1, nails = 2 },
    prop = { planks = 2, nails = 2 },
    dirt = {},
    crop = {},
}

function Bp.key(north, x, y, z, tag)
    return (tag or "") .. (north and "N:" or "W:") .. x .. ":" .. y .. ":" .. (z or 0)
end

Bp.costOverride = {
    StoneWall = { planks = 3, nails = 4 },
    MetalWallLvl2 = { planks = 2, nails = 6, metal = 1 },
    MetalDoorLvl2 = { planks = 4, nails = 8, metal = 2 },
}

function Bp.entityCost(entityId)
    local out = {}
    local entity = Entities[entityId]
    if entity == nil then return out end
    local override = Bp.costOverride[entityId]
    if override ~= nil then
        for kind, amount in pairs(override) do out[kind] = amount end
        return out
    end
    for _, input in ipairs(entity.inputs or {}) do
        local kind = Bp.stockKinds[input.t[1]]
        if kind ~= nil then out[kind] = (out[kind] or 0) + input.n end
    end
    return out
end

function Bp.opCost(op)
    if op.t == "piece" or op.t == "door" then return Bp.entityCost(op.e) end
    if op.t == "floor" then return op.cost or Bp.entityCost(op.e or "WoodFloorLvl1") end
    if op.t == "roof" then return Bp.flat.roof end
    if op.t == "prop" then
        if op.cost ~= nil then return op.cost end
        if op.e ~= nil then
            local cost = Bp.entityCost(op.e)
            local divisor = op.parts or 1
            local out = {}
            for kind, amount in pairs(cost) do out[kind] = math.ceil(amount / divisor) end
            return out
        end
        return Bp.flat.prop
    end
    if op.t == "window" then return Bp.entityCost("WoodenWindowFrameLvl1") end
    return {}
end

function Bp.opWork(op)
    local entity = op.e and Entities[op.e] or nil
    local ticks = entity and entity.time or nil
    if op.t == "roof" then return 1.2 end
    if op.t == "dirt" or op.t == "crop" then return 0.6 end
    if ticks ~= nil then return math.max(0.4, ticks / 100) end
    return 0.8
end

function Bp.cost(ops)
    local total = {}
    for _, op in ipairs(ops) do
        for kind, amount in pairs(Bp.opCost(op)) do total[kind] = (total[kind] or 0) + amount end
    end
    return total
end

function Bp.work(ops)
    local minutes = 0
    for _, op in ipairs(ops) do minutes = minutes + Bp.opWork(op) end
    return minutes
end

function Bp.sides(x, y, w, h)
    local slots = {}
    for i = 0, w - 1 do slots[#slots + 1] = { x = x + i, y = y, north = true, side = "N", index = i } end
    for i = 0, w - 1 do slots[#slots + 1] = { x = x + i, y = y + h, north = true, side = "S", index = i } end
    for j = 0, h - 1 do slots[#slots + 1] = { x = x, y = y + j, north = false, side = "W", index = j } end
    for j = 0, h - 1 do slots[#slots + 1] = { x = x + w, y = y + j, north = false, side = "E", index = j } end
    return slots
end

local function doorIndex(side, w, h)
    if side == "N" or side == "S" then return math.floor(w / 2) end
    return math.floor(h / 2)
end

function Bp.houseSlots(project)
    local w, h = project.w, project.h
    local door = project.door or "S"
    local doorAt = doorIndex(door, w, h)
    local windows = {}
    local function addWindow(side, index)
        windows[side .. index] = true
    end
    if w >= 5 or h >= 5 then
        if door ~= "N" then
            addWindow("N", 1)
            if w >= 6 then addWindow("N", w - 2) end
            if w >= 8 then addWindow("N", math.floor(w / 2)) end
        else
            addWindow("S", 1)
            if w >= 6 then addWindow("S", w - 2) end
        end
        if door ~= "E" then addWindow("E", math.floor(h / 2)) end
        if door ~= "W" then addWindow("W", math.floor(h / 2)) end
    elseif door ~= "N" then
        addWindow("N", 1)
    else
        addWindow("S", 1)
    end
    local out = {}
    for _, slot in ipairs(Bp.sides(project.x, project.y, w, h)) do
        slot.key = Bp.key(slot.north, slot.x, slot.y, 0, "S")
        slot.door = slot.side == door and slot.index == doorAt
        slot.window = (not slot.door) and windows[slot.side .. slot.index] == true
        out[#out + 1] = slot
    end
    return out
end

local function floorOps(project, z, sprite, tagKey, entity)
    local ops = {}
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            ops[#ops + 1] = { t = z == 0 and "floor" or "roof", e = entity, x = project.x + dx, y = project.y + dy, z = z,
                sprite = sprite, slot = tagKey .. ":" .. dx .. ":" .. dy }
        end
    end
    return ops
end

local furniturePlan = {
    house_s = {
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 0, dy = 0, parts = 2 },
        { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 3, dy = 0 },
        { e = "Wood_TableLvl1", sprites = { "carpentry_01_24", "carpentry_01_25" }, dx = 2, dy = 1, parts = 2 },
        { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 1, dy = 1 },
    },
    house_m = {
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 0, dy = 0, parts = 2 },
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 2, dy = 0, parts = 2 },
        { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 5, dy = 0 },
        { e = "Wood_TableLvl1", sprites = { "carpentry_01_24", "carpentry_01_25" }, dx = 3, dy = 2, parts = 2 },
        { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 2, dy = 2 },
        { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 5, dy = 2 },
        { e = "Wood_Crate_Lvl1", sprites = { "carpentry_01_19" }, dx = 0, dy = 3, container = "crate" },
    },
    house_l = {
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 0, dy = 0, parts = 2 },
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 2, dy = 0, parts = 2 },
        { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 4, dy = 0, parts = 2 },
        { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 7, dy = 0 },
        { e = "Wood_TableLvl1", sprites = { "carpentry_01_24", "carpentry_01_25" }, dx = 4, dy = 3, parts = 2 },
        { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 3, dy = 3 },
        { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 6, dy = 3 },
        { e = "Wood_Crate_Lvl1", sprites = { "carpentry_01_19" }, dx = 0, dy = 4, container = "crate" },
        { e = "Wood_Crate_Lvl1", sprites = { "carpentry_01_19" }, dx = 1, dy = 4, container = "crate" },
    },
    shed = {
        { e = "Wood_Crate_Lvl2", sprites = { "carpentry_01_16" }, dx = 1, dy = 0, container = "crate", storage = true },
        { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 0, dy = 2 },
        { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 3, dy = 2 },
    },
}

local function furnitureOps(project, kind)
    local ops = {}
    local plan = furniturePlan[kind] or {}
    for index, piece in ipairs(plan) do
        local fits = piece.dx + #piece.sprites <= project.w and piece.dy < project.h
        if fits then
            for part, sprite in ipairs(piece.sprites) do
                ops[#ops + 1] = { t = "prop", e = piece.e, parts = #piece.sprites, sprite = sprite, container = piece.container,
                    storage = piece.storage, x = project.x + piece.dx + part - 1, y = project.y + piece.dy, z = 0,
                    slot = "P" .. index .. ":" .. part }
            end
        end
    end
    return ops
end

local function buildingStages(project, kind)
    if (kind == "house_s" or kind == "house_m" or kind == "house_l") and ALifeCamp.Houses ~= nil then
        local designed = ALifeCamp.Houses.houseStages(project, kind)
        if designed ~= nil then return designed end
    end
    local slots = Bp.houseSlots(project)
    local wallEntity = project.level and project.level >= 2 and "WoodenWallLvl2" or "WoodenWallLvl1"
    local doorEntity, windowEntity = "WoodDoorFrameLvl1", "WoodenWindowFrameLvl1"
    if project.palette ~= nil and ALifeCamp.Houses ~= nil then
        local wall, door, window = ALifeCamp.Houses.entities(project)
        if wall ~= nil then wallEntity, doorEntity, windowEntity = wall, door, window end
    end
    local foundation = floorOps(project, 0, Place.sprite("WoodFloorLvl1", "W"), "F", "WoodFloorLvl1")
    local frame, walls, finish = {}, {}, {}
    for _, slot in ipairs(slots) do
        frame[#frame + 1] = { t = "piece", e = "WoodenWallFrame", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = slot.key, corner = true }
        local wallOp = { t = "piece", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = slot.key, replace = true, corner = true }
        if slot.door then
            wallOp.e = doorEntity
            wallOp.extra = { isDoorFrame = true }
        elseif slot.window then
            wallOp.e = windowEntity
        else
            wallOp.e = wallEntity
        end
        walls[#walls + 1] = wallOp
        if slot.door then
            finish[#finish + 1] = { t = "door", e = "HouseDoorInterior", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = "D" .. slot.key }
        elseif slot.window then
            finish[#finish + 1] = { t = "window", e = "WoodenWindowFrameLvl1", sprite = slot.north and Bp.sprites.glassN or Bp.sprites.glassW,
                x = slot.x, y = slot.y, z = 0, north = slot.north, slot = "G" .. slot.key }
        end
    end
    for _, op in ipairs(furnitureOps(project, kind)) do finish[#finish + 1] = op end
    local roof = floorOps(project, 1, Bp.sprites.roof, "R")
    if project.palette ~= nil and ALifeCamp.Houses ~= nil then roof = ALifeCamp.Houses.roofOps(project) or roof end
    return {
        { id = "foundation", ops = foundation },
        { id = "frame", ops = frame },
        { id = "walls", ops = walls },
        { id = "roof", ops = roof },
        { id = "finish", ops = finish },
    }
end

local function fenceSlots(project)
    local slots = {}
    local x1, y1, x2, y2 = project.x, project.y, project.x + project.w - 1, project.y + project.h - 1
    for x = x1, x2 do
        slots[#slots + 1] = { x = x, y = y1, north = true, side = "N", index = x - x1 }
        slots[#slots + 1] = { x = x, y = y2 + 1, north = true, side = "S", index = x - x1 }
    end
    for y = y1, y2 do
        slots[#slots + 1] = { x = x1, y = y, north = false, side = "W", index = y - y1 }
        slots[#slots + 1] = { x = x2 + 1, y = y, north = false, side = "E", index = y - y1 }
    end
    local marks = {}
    for _, gate in ipairs(Gates.of(project)) do
        local half = math.floor((gate.span or Gates.span) / 2)
        for k = -half, half do
            marks[gate.side .. (gate.index + k)] = { id = gate.id, center = k == 0, edge = (k == -half or k == half), main = gate.main == true }
        end
    end
    for _, slot in ipairs(slots) do
        slot.key = Bp.key(slot.north, slot.x, slot.y, 0, "X")
        local mark = marks[slot.side .. slot.index]
        slot.gate = mark ~= nil
        slot.gateId = mark ~= nil and mark.id or nil
        slot.gateCenter = mark ~= nil and mark.center or false
        slot.gateEdge = mark ~= nil and mark.edge or false
        slot.gateMain = mark ~= nil and mark.main or false
    end
    return slots
end

function Bp.fenceSlots(project)
    return fenceSlots(project)
end

Bp.building = buildingStages
Bp.furniture = furniturePlan
Bp.buildingKinds = { house_s = true, house_m = true, house_l = true, shed = true }

Bp.wallTiers = {
    { wall = "WoodenWallLvl2", gate = "WoodenDoorLvl1" },
    { wall = "MetalWallLvl2", gate = "MetalDoorLvl2" },
    { wall = "StoneWall", gate = "MetalDoorLvl2" },
}

local function heavyFenceStages(project, slots)
    local tier = Bp.wallTiers[math.max(1, math.min(3, math.floor(project.wall)))]
    local posts, gates = {}, {}
    for _, slot in ipairs(slots) do
        if not slot.gate then
            posts[#posts + 1] = { t = "piece", e = tier.wall, x = slot.x, y = slot.y, z = 0, north = slot.north, slot = slot.key, corner = true }
        end
    end
    return { { id = "fence", ops = posts }, { id = "gate", ops = gates } }
end

local function fenceStages(project)
    local slots = fenceSlots(project)
    if tonumber(project.wall) ~= nil and project.wall >= 1 then return heavyFenceStages(project, slots) end
    local level = project.level or 1
    local entity = level >= 3 and "WoodFenceLvl3" or (level == 2 and "WoodFenceLvl2" or "WoodFenceLvl1")
    local posts, gates, extra = {}, {}, {}
    for _, slot in ipairs(slots) do
        if slot.gate then
            if slot.gateEdge and not slot.gateMain then
                gates[#gates + 1] = { t = "door", e = "WoodFenceGate", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = slot.key }
            end
        else
            posts[#posts + 1] = { t = "piece", e = entity, x = slot.x, y = slot.y, z = 0, north = slot.north, slot = slot.key, corner = true }
        end
    end
    local stages = { { id = "fence", ops = posts }, { id = "gate", ops = gates } }
    if level >= 2 then
        for _, slot in ipairs(slots) do
            if not slot.gate then
                extra[#extra + 1] = { t = "piece", e = "BarbedWireFence", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = "B" .. slot.key }
            end
        end
        stages[#stages + 1] = { id = "wire", ops = extra }
    end
    return stages
end

local function campfireStages(project)
    local ops = {
        { t = "prop", sprite = Bp.sprites.campfire, x = project.x + 1, y = project.y + 1, z = 0, slot = "C", e = "Campfire" },
        { t = "prop", sprite = Bp.sprites.bench[1], x = project.x, y = project.y + 2, z = 0, slot = "B1" },
        { t = "prop", sprite = Bp.sprites.bench[2], x = project.x + 1, y = project.y + 2, z = 0, slot = "B2" },
        { t = "prop", sprite = Bp.sprites.tent[1], x = project.x, y = project.y, z = 0, slot = "T1" },
        { t = "prop", sprite = Bp.sprites.tent[2], x = project.x + 1, y = project.y, z = 0, slot = "T2" },
    }
    return { { id = "camp", ops = ops } }
end

local function farmStages(project)
    local beds, crops = {}, {}
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local pick = (dx * 7 + dy * 3) % #Bp.sprites.dirt + 1
            beds[#beds + 1] = { t = "dirt", sprite = Bp.sprites.dirt[pick], x = project.x + dx, y = project.y + dy, z = 0, slot = "D" .. dx .. ":" .. dy }
            if dy % 2 == 1 or project.h <= 2 then
                local crop = (dx * 5 + dy) % #Bp.sprites.crops + 1
                crops[#crops + 1] = { t = "crop", sprite = Bp.sprites.crops[crop], x = project.x + dx, y = project.y + dy, z = 0, slot = "K" .. dx .. ":" .. dy }
            end
        end
    end
    return { { id = "beds", ops = beds }, { id = "crops", ops = crops } }
end

local function towerStages(project)
    local base = floorOps(project, 0, Place.sprite("WoodFloorLvl1", "W"), "F", "WoodFloorLvl1")
    local posts = {}
    for _, slot in ipairs(Bp.sides(project.x, project.y, project.w, project.h)) do
        posts[#posts + 1] = { t = "piece", e = "WoodFenceLvl2", x = slot.x, y = slot.y, z = 0, north = slot.north, slot = Bp.key(slot.north, slot.x, slot.y, 0, "T"), corner = true }
    end
    posts[#posts + 1] = { t = "prop", e = "WoodLampPillar", sprite = Bp.sprites.lamp, x = project.x, y = project.y, z = 0, slot = "L" }
    return { { id = "base", ops = base }, { id = "posts", ops = posts } }
end

Bp.kinds = {
    house_s = { w = 4, h = 4, priority = 4, build = function(project) return buildingStages(project, "house_s") end },
    house_m = { w = 6, h = 5, priority = 4, build = function(project) return buildingStages(project, "house_m") end },
    house_l = { w = 8, h = 6, priority = 4, build = function(project) return buildingStages(project, "house_l") end },
    shed = { w = 4, h = 3, priority = 2, build = function(project) return buildingStages(project, "shed") end },
    campfire = { w = 3, h = 3, priority = 1, build = campfireStages },
    farm = { w = 5, h = 4, priority = 5, build = farmStages },
    tower = { w = 2, h = 2, priority = 6, build = towerStages },
    fence = { w = 0, h = 0, priority = 3, build = fenceStages, free = true },
}

Bp.order = { "campfire", "shed", "fence", "house_s", "house_m", "house_l", "farm", "tower" }

function Bp.stages(project)
    local kind = Bp.kinds[project.kind]
    if kind == nil then return {} end
    return kind.build(project)
end

function Bp.footprint(project)
    if project.kind == "fence" then
        return { x1 = project.x, y1 = project.y, x2 = project.x + project.w, y2 = project.y + project.h }
    end
    if Bp.buildingKinds[project.kind] then
        return { x1 = project.x, y1 = project.y, x2 = project.x + project.w, y2 = project.y + project.h }
    end
    return { x1 = project.x, y1 = project.y, x2 = project.x + project.w - 1, y2 = project.y + project.h - 1 }
end

function Bp.stageInfo(project)
    local stages = Bp.stages(project)
    local out = {}
    for index, stage in ipairs(stages) do
        out[index] = { id = stage.id, cost = Bp.cost(stage.ops), work = Bp.work(stage.ops), count = #stage.ops }
    end
    return out
end

return Bp
