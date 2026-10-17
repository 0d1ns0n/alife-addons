require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampDistricts"
require "ALifeCamp/CampHouses"
require "ALifeCamp/CampBuildings"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan

local Buildings3 = {}
ALifeCamp.Buildings3 = Buildings3

Buildings3.greenhouseSide = 24
Buildings3.tentsSide = 28
Buildings3.farmFactor = 1.15
Buildings3.moraleBonus = 2
Buildings3.roofFamily = "04"
Buildings3.gableFamily = "08"
Buildings3.paletteName = "Green"

local knownSprites = {}

local function known(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function layout()
    local list = {}
    local self = {}
    function self.put(dx, dy, sprite, cost, container)
        list[#list + 1] = { dx = dx, dy = dy, sprite = sprite, cost = cost, container = container }
    end
    function self.group(dx, dy, cost, cells)
        for index, cell in ipairs(cells) do
            self.put(dx + cell[2], dy + cell[3], cell[1], index == 1 and cost or {})
        end
    end
    function self.list()
        return list
    end
    return self
end

local BARREL = { planks = 2, nails = 3 }
local PLANT = {}
local FIRE = { logs = 2 }
local LOG = { logs = 1 }
local PILE = { logs = 2 }
local CANVAS = { rope = 4, planks = 2 }
local SMALL = { rope = 2, planks = 1 }
local SHELTER = { rope = 1, planks = 2 }
local RACK = { planks = 2, rope = 2 }
local IRONWORK = { planks = 1, metal = 1 }
local BRAZIER = { metal = 1, nails = 1 }
local CRATE = { planks = 2, nails = 2 }

local bedRows = {
    { 117, 125 },
    { 69, 77 },
    { 85, 101 },
}

local function greenhouseLayout()
    local l = layout()
    l.put(0, 0, "carpentry_02_52", BARREL)
    l.put(1, 0, "carpentry_02_53", BARREL)
    l.put(4, 0, "carpentry_02_54", BARREL)
    l.put(5, 0, "carpentry_02_52", BARREL)
    l.put(2, 0, "carpentry_01_19", CRATE, "crate")
    l.put(3, 0, "carpentry_01_16", CRATE, "crate")
    return l.list()
end

local function bedCells()
    local cells = {}
    for index, pair in ipairs(bedRows) do
        for _, dx in ipairs({ 0, 1 }) do cells[#cells + 1] = { dx = dx, dy = index, sprite = "vegetation_farming_01b_" .. pair[1] } end
        for _, dx in ipairs({ 4, 5 }) do cells[#cells + 1] = { dx = dx, dy = index, sprite = "vegetation_farming_01b_" .. pair[2] } end
    end
    return cells
end

local function tentsLayout()
    local l = layout()
    l.group(0, 0, CANVAS, {
        { "camping_04_16", 0, 0 }, { "camping_04_17", 1, 0 }, { "camping_04_18", 2, 0 }, { "camping_04_19", 3, 0 },
        { "camping_04_20", 0, 1 }, { "camping_04_21", 1, 1 }, { "camping_04_22", 2, 1 }, { "camping_04_23", 3, 1 },
    })
    l.group(5, 0, CANVAS, {
        { "camping_04_112", 0, 0 }, { "camping_04_113", 1, 0 }, { "camping_04_114", 2, 0 }, { "camping_04_115", 3, 0 },
        { "camping_04_116", 0, 1 }, { "camping_04_117", 1, 1 }, { "camping_04_118", 2, 1 }, { "camping_04_119", 3, 1 },
    })
    l.group(10, 0, CANVAS, {
        { "camping_04_80", 0, 0 }, { "camping_04_81", 1, 0 }, { "camping_04_82", 2, 0 }, { "camping_04_83", 3, 0 },
        { "camping_04_84", 0, 1 }, { "camping_04_85", 1, 1 }, { "camping_04_86", 2, 1 }, { "camping_04_87", 3, 1 },
    })
    l.put(4, 2, "crafted_02_42", BRAZIER)
    l.put(9, 2, "crafted_02_42", BRAZIER)
    l.put(6, 5, "camping_01_4", FIRE)
    l.group(5, 4, LOG, { { "crafted_02_58", 0, 0 }, { "crafted_02_59", 1, 0 } })
    l.group(6, 6, LOG, { { "crafted_02_58", 0, 0 }, { "crafted_02_59", 1, 0 } })
    l.put(4, 5, "crafted_02_86", LOG)
    l.put(8, 5, "crafted_02_86", LOG)
    l.group(10, 3, PILE, { { "camping_01_24", 0, 0 }, { "camping_01_25", 1, 0 } })
    l.group(12, 3, PILE, { { "camping_01_28", 0, 0 }, { "camping_01_29", 1, 0 } })
    l.group(10, 4, PILE, { { "camping_01_26", 0, 0 }, { "camping_01_27", 1, 0 } })
    l.group(12, 4, PILE, { { "camping_01_30", 0, 0 }, { "camping_01_31", 1, 0 } })
    l.group(0, 4, RACK, {
        { "vegetation_drying_01_17", 0, 0 }, { "vegetation_drying_01_19", 1, 0 },
        { "vegetation_drying_01_16", 0, 1 }, { "vegetation_drying_01_18", 1, 1 },
    })
    l.group(2, 4, RACK, {
        { "vegetation_drying_01_17", 0, 0 }, { "vegetation_drying_01_19", 1, 0 },
        { "vegetation_drying_01_16", 0, 1 }, { "vegetation_drying_01_18", 1, 1 },
    })
    l.put(10, 6, "crafted_05_56", IRONWORK)
    l.group(11, 6, RACK, {
        { "crafted_05_81", 0, 0 }, { "crafted_05_83", 1, 0 },
        { "crafted_05_80", 0, 1 }, { "crafted_05_82", 1, 1 },
    })
    l.put(13, 6, "carpentry_02_52", BARREL)
    l.put(13, 7, "carpentry_01_19", CRATE, "crate")
    l.group(0, 7, SHELTER, { { "camping_03_0", 0, 0 }, { "camping_03_1", 1, 0 } })
    l.group(3, 7, SMALL, { { "camping_01_2", 0, 0 }, { "camping_01_3", 1, 0 } })
    return l.list()
end

Buildings3.definitions = {
    greenhouse = { w = 6, h = 5, priority = 5.4, people = 6, side = Buildings3.greenhouseSide, dx = 9, dy = 4, radius = 8, furniture = greenhouseLayout(), open = false },
    tents = { w = 14, h = 9, priority = 5.8, people = 10, side = Buildings3.tentsSide, dx = -12, dy = 8, radius = 10, furniture = tentsLayout(), open = true },
}

Buildings3.kinds = { "greenhouse", "tents" }

local yard = { "blends_natural_01_64", "blends_natural_01_69", "blends_natural_01_70", "blends_natural_01_71" }

local function ops(project, kind)
    local def = Buildings3.definitions[kind]
    local out = {}
    local aisle = {}
    if not def.open then
        local dw = math.floor(project.w / 2)
        for dy = 0, project.h - 1 do aisle[dw .. ":" .. dy] = true end
    end
    for index, piece in ipairs(def.furniture) do
        if piece.dx < project.w and piece.dy < project.h and known(piece.sprite)
                and not aisle[piece.dx .. ":" .. piece.dy] then
            out[#out + 1] = { t = "prop", cost = piece.cost, sprite = piece.sprite, container = piece.container,
                x = project.x + piece.dx, y = project.y + piece.dy, z = 0, slot = "B" .. index }
        end
    end
    return out
end

local function greenPalette()
    local houses = ALifeCamp.Houses
    if houses == nil then return nil end
    for index, palette in ipairs(houses.palettes) do
        if palette.name == Buildings3.paletteName then return index end
    end
    return nil
end

function Buildings3.roofOps(project)
    local houses = ALifeCamp.Houses
    local out = {}
    if houses == nil then return out end
    local R = houses.roofAlong
    local w, h = project.w, project.h
    local alongX = R.RY[h] ~= nil and (w >= h or R.RX[w] == nil)
    local roofSheet = "roofs_30_" .. Buildings3.roofFamily .. "_"
    local gableSheet = "walls_exterior_roofs_30_" .. Buildings3.gableFamily .. "_"
    local accentSheet = "roofs_accents_30_01_"
    local function put(sprite, dx, dy, tag, cost)
        local op = { t = tag == "R" and "roof" or "prop", sprite = sprite, x = project.x + dx, y = project.y + dy, z = 1, slot = tag .. ":" .. dx .. ":" .. dy }
        if tag ~= "R" then op.cost = cost end
        out[#out + 1] = op
    end
    for dx = 0, w - 1 do
        for dy = 0, h - 1 do
            put(roofSheet .. (alongX and R.RY[h][dy + 1] or R.RX[w][dx + 1]), dx, dy, "R")
        end
    end
    if alongX then
        for _, dx in ipairs({ 0, w }) do
            for dy = 0, h - 1 do
                put(gableSheet .. R.GY[h][dy + 1], dx, dy, "G", { nails = 1 })
                put(accentSheet .. R.GY[h][dy + 1], dx, dy, "A", {})
            end
        end
    else
        for _, dy in ipairs({ 0, h }) do
            for dx = 0, w - 1 do
                put(gableSheet .. R.GX[w][dx + 1], dx, dy, "G", { nails = 1 })
                put(accentSheet .. R.GX[w][dx + 1], dx, dy, "A", {})
            end
        end
    end
    return out
end

local function greenhouseStages(project)
    local copy = {}
    for key, value in pairs(project) do copy[key] = value end
    copy.palette = greenPalette()
    local out = Bp.building(copy, "greenhouse")
    local finish
    for _, stage in ipairs(out) do
        if stage.id == "roof" and ALifeCamp.Houses ~= nil then stage.ops = Buildings3.roofOps(project) end
        if stage.id == "finish" then finish = stage end
    end
    if finish == nil then
        finish = { id = "finish", ops = {} }
        out[#out + 1] = finish
    end
    local blocked = {}
    for _, piece in ipairs(Buildings3.definitions.greenhouse.furniture) do blocked[piece.dx .. ":" .. piece.dy] = true end
    local beds, plants = {}, {}
    for index, cell in ipairs(bedCells()) do
        if not blocked[cell.dx .. ":" .. cell.dy] and cell.dx < project.w and cell.dy < project.h then
            local x, y = project.x + cell.dx, project.y + cell.dy
            beds[#beds + 1] = { t = "dirt", sprite = yard[index % #yard + 1], x = x, y = y, z = 0, slot = "D" .. cell.dx .. ":" .. cell.dy }
            if known(cell.sprite) then
                plants[#plants + 1] = { t = "crop", sprite = cell.sprite, x = x, y = y, z = 0, slot = "K" .. cell.dx .. ":" .. cell.dy }
            end
        end
    end
    local merged = {}
    for _, op in ipairs(beds) do merged[#merged + 1] = op end
    for _, op in ipairs(plants) do merged[#merged + 1] = op end
    for _, op in ipairs(ops(project, "greenhouse")) do merged[#merged + 1] = op end
    for _, op in ipairs(finish.ops) do merged[#merged + 1] = op end
    finish.ops = merged
    return out
end

local function tentsStages(project)
    local ground = {}
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local pick = (dx * 7 + dy * 13) % #yard + 1
            ground[#ground + 1] = { t = "dirt", sprite = yard[pick], x = project.x + dx, y = project.y + dy, z = 0, slot = "G" .. dx .. ":" .. dy }
        end
    end
    return { { id = "ground", ops = ground }, { id = "camp", ops = ops(project, "tents") } }
end

Bp.kinds.greenhouse = { w = 6, h = 5, priority = 5.4, build = greenhouseStages }
Bp.kinds.tents = { w = 14, h = 9, priority = 5.8, build = tentsStages }
Bp.buildingKinds.greenhouse = true
Bp.furniture.greenhouse = {}
if ALifeCamp.Site ~= nil and type(ALifeCamp.Site.buildings) == "table" then ALifeCamp.Site.buildings.greenhouse = true end

Buildings3.colors = {
    greenhouse = { 0.42, 0.86, 0.46 },
    tents = { 0.88, 0.62, 0.26 },
}

if ALifeCamp.Districts ~= nil and type(ALifeCamp.Districts.colors) == "table" then
    for kind, color in pairs(Buildings3.colors) do
        ALifeCamp.Districts.colors[kind] = { r = color[1], g = color[2], b = color[3], color[1], color[2], color[3] }
    end
end

local Buildings = ALifeCamp.Buildings
if Buildings ~= nil and type(Buildings.definitions) == "table" then
    for _, kind in ipairs(Buildings3.kinds) do
        local def = Buildings3.definitions[kind]
        if Buildings.definitions[kind] == nil then Buildings.definitions[kind] = { w = def.w, h = def.h, people = def.people, dx = def.dx, dy = def.dy, radius = def.radius, furniture = {} } end
    end
end

function Buildings3.built(camp, kind)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and project.status == "done" and not project.retired then return project end
    end
    return nil
end

function Buildings3.generate(camp)
    if camp == nil then return 0 end
    local side = math.min(Geo.width(camp), Geo.height(camp))
    local people = Store.settlerCount(camp)
    local cx, cy = Geo.center(camp)
    local added = 0
    local T = ALifeCamp.Tiers
    local function placeOne(kind, def)
        local extra = def.open and nil or { door = "S" }
        local ax, ay, radius = Plan.anchorFor(camp, kind, cx + def.dx, cy + def.dy, def.radius)
        local project = Plan.place(camp, kind, ax, ay, radius, extra)
        if project == nil and Buildings ~= nil and type(Buildings.displace) == "function" then
            project = Buildings.displace(camp, kind, ax, ay)
        end
        return project
    end
    for _, kind in ipairs(Buildings3.kinds) do
        local def = Buildings3.definitions[kind]
        local want = (T ~= nil and type(T.want) == "function") and T.want(camp, kind) or nil
        if side >= def.side then
            if want == nil then
                if people >= def.people and Plan.countKind(camp, kind) < 1 then
                    if placeOne(kind, def) ~= nil then added = added + 1 end
                end
            else
                local guard = 0
                while Plan.countKind(camp, kind) < want and guard < want + 4 do
                    guard = guard + 1
                    if placeOne(kind, def) ~= nil then added = added + 1 else break end
                end
            end
        end
    end
    return added
end

Hooks.add("farm", function(camp)
    if Buildings3.built(camp, "greenhouse") ~= nil then return Buildings3.farmFactor end
    return 1
end)

Hooks.add("morale", function(camp)
    if Buildings3.built(camp, "tents") ~= nil then return Buildings3.moraleBonus end
    return 0
end)

return Buildings3
