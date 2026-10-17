require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local World = ALifeCamp.World
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan

local Districts = {}
ALifeCamp.Districts = Districts

local function sprite(prefix, index)
    return prefix .. "_" .. index
end

local function sprites(prefix, indices)
    local out = {}
    for _, index in ipairs(indices) do out[#out + 1] = sprite(prefix, index) end
    return out
end

local TS = "floors_exterior_tilesandstone_01"
local ORN = "vegetation_ornamental_01"
local CEM = "location_community_cemetary_01"
local SEAT = "furniture_seating_outdoor_01"

local STREET = "floors_exterior_street_01"
local Ground = {
    street = sprites(STREET, { 16, 17 }),
    verge = sprites(STREET, { 0 }),
    lane = sprites(STREET, { 16 }),
    apron = sprites(STREET, { 16 }),
    yard = { "blends_natural_01_64", "blends_natural_01_69", "blends_natural_01_70", "blends_natural_01_96", "blends_natural_01_71" },
    sand = sprites("blends_natural_01", { 0, 5 }),
    pale = sprites(TS, { 3, 4 }),
    brick = sprite(TS, 2),
    brickAlt = sprite(TS, 6),
    paver = sprite(TS, 55),
    rosette = sprite(TS, 9),
    flag = sprite(TS, 5),
}

local Prop = {
    lamp = "carpentry_02_61",
    brazier = "crafted_02_42",
    signN = "constructedobjects_signs_01_11",
    signW = "constructedobjects_signs_01_27",
    flowers = sprites(ORN, { 16, 17, 18, 19, 20, 21, 22, 23 }),
    hedgeRow = sprite(ORN, 4),
    hedgeColumn = sprite(ORN, 5),
    birdbath = sprite(ORN, 50),
    gnome = sprite(ORN, 48),
    flamingo = sprite(ORN, 24),
    crate = "carpentry_01_19",
    crateAlt = "carpentry_01_16",
    barrel = "carpentry_02_52",
    barrelWater = "carpentry_02_53",
    crateWater = "carpentry_02_54",
    drum = "crafted_01_24",
    barrelOrange = "industry_01_22",
    hay = "vegetation_farm_01_8",
    hayDouble = "vegetation_farm_01_10",
    table = "carpentry_02_5",
    stool = "crafted_02_94",
    anvil = "crafted_01_18",
    forge = "crafted_01_61",
    chopBlock = "crafted_02_85",
    stump = "crafted_02_86",
    well = "camping_01_16",
    pump = "camping_01_64",
    sandbagColumn = "carpentry_02_12",
    sandbagRow = "carpentry_02_13",
    gabion = sprites("fencing_01", { 96, 102, 103, 96 }),
    cone = "street_decoration_01_26",
    stopSign = "street_decoration_01_0",
    mound = sprites(CEM, { 24, 25, 26, 27, 40, 41, 42, 43 }),
    cross = sprites(CEM, { 22, 23, 36, 37, 38, 39 }),
    headstone = sprites(CEM, { 0, 2, 4, 8 }),
    angel = sprite(CEM, 11),
}

local Group = {
    benchS = { { sprite(SEAT, 0), 0, 0 }, { sprite(SEAT, 1), 1, 0 } },
    benchN = { { sprite(SEAT, 4), 0, 0 }, { sprite(SEAT, 5), 1, 0 } },
    benchE = { { sprite(SEAT, 3), 0, 0 }, { sprite(SEAT, 2), 0, 1 } },
    benchW = { { sprite(SEAT, 7), 0, 0 }, { sprite(SEAT, 6), 0, 1 } },
    logBenchRow = { { "crafted_02_58", 0, 0 }, { "crafted_02_59", 1, 0 } },
    logBenchColumn = { { "crafted_02_57", 0, 0 }, { "crafted_02_56", 0, 1 } },
    workbench = { { "crafted_04_96", 0, 0 }, { "crafted_04_97", 1, 0 } },
    logPileA = { { "camping_01_30", 0, 0 }, { "camping_01_31", 1, 0 } },
    logPileB = { { "camping_01_40", 0, 0 }, { "camping_01_41", 1, 0 } },
    tent = { { "camping_03_25", 0, 0 }, { "camping_03_24", 0, 1 } },
    bigTable = { { "crafted_02_90", 0, 0 }, { "crafted_02_91", 1, 0 } },
}

local Cost = {
    free = { e = "DirtFloor" },
    bench = { e = "Wood_Chair_Lvl1", parts = 2 },
    table = { e = "Wood_TableLvl1", parts = 4 },
    crate = { e = "Wood_Crate_Lvl1", parts = 4 },
    lamp = { e = "Wood_Shelves_Lvl1" },
    sign = { e = "WoodSign", parts = 2 },
    well = { e = "Well" },
    fire = { e = "Campfire" },
    sandbag = { e = "SandbagWall" },
    logs = { e = "Chopping_Block" },
}

Districts.sprites = { ground = Ground, props = Prop, groups = Group }
Districts.costs = Cost

Districts.kinds = { "plaza", "path", "lamp", "market", "workyard", "well", "garden", "checkpoint", "memorial" }

Districts.colors = {
    plaza = { r = 0.86, g = 0.42, b = 0.34 },
    path = { r = 0.82, g = 0.74, b = 0.52 },
    lamp = { r = 1.0, g = 0.95, b = 0.45 },
    market = { r = 0.92, g = 0.36, b = 0.64 },
    workyard = { r = 0.62, g = 0.46, b = 0.3 },
    well = { r = 0.3, g = 0.66, b = 0.96 },
    garden = { r = 0.3, g = 0.86, b = 0.72 },
    checkpoint = { r = 0.62, g = 0.68, b = 0.8 },
    memorial = { r = 0.82, g = 0.82, b = 0.96 },
}

for _, color in pairs(Districts.colors) do
    color[1], color[2], color[3] = color.r, color.g, color.b
end

local districtOf = {
    plaza = "plaza", path = "streets", lamp = "lights", market = "market", workyard = "workyard",
    well = "well", garden = "garden", checkpoint = "checkpoint", memorial = "memorial",
}

Districts.districtOf = districtOf
Districts.order = { "plaza", "streets", "lights", "checkpoint", "market", "workyard", "well", "garden", "memorial" }

local kindSet = {}
for _, kind in ipairs(Districts.kinds) do kindSet[kind] = true end

local networkKinds = { path = true, plaza = true, market = true, workyard = true, well = true }
local buildingKinds = {
    house_s = true, house_m = true, house_l = true, shed = true,
    barracks = true, tents = true, canteen = true, infirmary = true, forge = true,
    greenhouse = true, powerhouse = true, guardhouse = true, garage = true, vault = true,
    motorpool = true, bay = true, post = true, range = true,
    farm = true, garden = true, workyard = true, campfire = true,
}

local function hash(x, y, salt)
    return (math.abs(x) * 73856093 + math.abs(y) * 19349663 + (salt or 0) * 83492791) % 2147483647
end

local function pick(list, x, y, salt)
    return list[hash(x, y, salt) % #list + 1]
end

local knownSprites = {}

local function known(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function sink()
    local self = { ops = {}, count = 0 }
    function self.ground(x, y, name)
        self.count = self.count + 1
        if known(name) then
            self.ops[#self.ops + 1] = { t = "dirt", sprite = name, x = x, y = y, z = 0, slot = "G" .. self.count }
        end
    end
    function self.prop(x, y, name, cost)
        self.count = self.count + 1
        if known(name) then
            self.ops[#self.ops + 1] = { t = "prop", e = cost.e, parts = cost.parts, sprite = name, x = x, y = y, z = 0, slot = "P" .. self.count }
        end
    end
    function self.group(x, y, cells, cost)
        for _, cell in ipairs(cells) do self.prop(x + cell[2], y + cell[3], cell[1], cost) end
    end
    return self
end

local function stages(pave, furnish)
    local out = { { id = "pave", ops = pave.ops } }
    if furnish ~= nil and #furnish.ops > 0 then out[2] = { id = "furnish", ops = furnish.ops } end
    return out
end

local function pavePlain(project, list, salt)
    local out = sink()
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            out.ground(x, y, pick(list, x, y, salt))
        end
    end
    return out
end

local function pathStages(project)
    local pave = sink()
    local width = math.min(project.w, project.h)
    local length = math.max(project.w, project.h)
    local alongX = project.w >= project.h
    local main = project.style == "street" and Ground.street or Ground.lane
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local across = alongX and dy or dx
            local edge = width >= 3 and (across == 0 or across == width - 1)
            pave.ground(x, y, pick(edge and Ground.verge or main, x, y, 1))
        end
    end
    local furnish = sink()
    if width >= 3 and length >= 6 then
        local function at(along, across)
            if alongX then return project.x + along, project.y + across end
            return project.x + across, project.y + along
        end
        local ordinal = 0
        for along = 2, length - 1, 6 do
            local lampSide = ordinal % 2 == 0 and 0 or width - 1
            local lx, ly = at(along, lampSide)
            furnish.prop(lx, ly, Prop.lamp, Cost.lamp)
            if along + 3 <= length - 1 then
                local fx, fy = at(along + 3, width - 1 - lampSide)
                furnish.prop(fx, fy, pick(Prop.flowers, fx, fy, 2), Cost.free)
            end
            ordinal = ordinal + 1
        end
    end
    return stages(pave, furnish)
end

local function lampStages(project)
    local furnish = sink()
    furnish.prop(project.x, project.y, Prop.lamp, Cost.lamp)
    return { { id = "furnish", ops = furnish.ops } }
end

local function inRect(project, x, y)
    return x >= project.x and x < project.x + project.w and y >= project.y and y < project.y + project.h
end

local function plazaStages(project)
    local fx, fy, radius = project.fx, project.fy, project.radius
    local pave = sink()
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local ox, oy = x - fx, y - fy
            local ring = math.max(math.abs(ox), math.abs(oy))
            local name
            if ring == radius then
                name = Ground.paver
            elseif ring == 2 then
                name = Ground.flag
            elseif ox == 0 or oy == 0 then
                name = Ground.rosette
            else
                name = (x + y) % 2 == 0 and Ground.brick or Ground.brickAlt
            end
            pave.ground(x, y, name)
        end
    end
    local furnish = sink()
    local function put(x, y, name, cost)
        if inRect(project, x, y) then furnish.prop(x, y, name, cost) end
    end
    local function putGroup(x, y, cells, cost)
        for _, cell in ipairs(cells) do put(x + cell[2], y + cell[3], cell[1], cost) end
    end
    if radius >= 4 then
        putGroup(fx - 3, fy - 3, Group.benchS, Cost.bench)
        putGroup(fx + 3, fy - 3, Group.benchW, Cost.bench)
        putGroup(fx + 2, fy + 3, Group.benchN, Cost.bench)
        putGroup(fx - 3, fy + 2, Group.benchE, Cost.bench)
        for _, sx in ipairs({ -2, 2 }) do
            for _, sy in ipairs({ -2, 2 }) do put(fx + sx, fy + sy, Prop.brazier, Cost.fire) end
        end
    end
    for _, sx in ipairs({ -radius, radius }) do
        for _, sy in ipairs({ -radius, radius }) do
            put(fx + sx, fy + sy, Prop.lamp, Cost.lamp)
            local nx = sx > 0 and -1 or 1
            local ny = sy > 0 and -1 or 1
            put(fx + sx + nx, fy + sy, pick(Prop.flowers, fx + sx, fy + sy, 3), Cost.free)
            put(fx + sx, fy + sy + ny, pick(Prop.flowers, fx + sy, fy + sx, 4), Cost.free)
        end
    end
    local side = project.gate or "S"
    if radius >= 3 then
        if side == "S" then put(fx - 2, fy + radius, Prop.signN, Cost.sign)
        elseif side == "N" then put(fx - 2, fy - radius, Prop.signN, Cost.sign)
        elseif side == "E" then put(fx + radius, fy - 2, Prop.signW, Cost.sign)
        else put(fx - radius, fy - 2, Prop.signW, Cost.sign) end
    end
    return stages(pave, furnish)
end

local stallStyles = {
    { a = Prop.crate, costA = Cost.crate, b = Prop.barrel, costB = Cost.crate },
    { a = Prop.hayDouble, costA = Cost.free, b = Prop.crateAlt, costB = Cost.crate },
    { a = Prop.anvil, costA = Cost.free, b = Prop.drum, costB = Cost.free },
}

local function marketStages(project)
    local pave = pavePlain(project, Ground.verge, 5)
    local furnish = sink()
    local count = math.floor((project.w + 1) / 4)
    for index = 0, count - 1 do
        local x0, y0 = project.x + index * 4, project.y
        local style = stallStyles[index % #stallStyles + 1]
        furnish.group(x0, y0, Group.tent, Cost.crate)
        furnish.prop(x0 + 1, y0, style.a, style.costA)
        furnish.prop(x0 + 2, y0, style.b, style.costB)
        furnish.prop(x0 + 1, y0 + 1, Prop.table, Cost.table)
        furnish.prop(x0 + 2, y0 + 1, Prop.table, Cost.table)
        furnish.prop(x0, y0 + 2, Prop.stool, Cost.crate)
        if index < count - 1 then furnish.prop(x0 + 3, y0, Prop.lamp, Cost.lamp) end
    end
    return stages(pave, furnish)
end

local function workyardStages(project)
    local pave = pavePlain(project, Ground.yard, 6)
    local furnish = sink()
    local x, y = project.x, project.y
    furnish.group(x + 1, y, Group.workbench, Cost.table)
    furnish.prop(x + 4, y, Prop.anvil, Cost.free)
    furnish.prop(x + 5, y, Prop.forge, Cost.fire)
    furnish.prop(x + 6, y, Prop.barrelOrange, Cost.crate)
    furnish.prop(x + 7, y, Prop.crateAlt, Cost.crate)
    furnish.prop(x + 7, y + 1, Prop.crate, Cost.crate)
    furnish.group(x, y + 2, Group.logPileA, Cost.logs)
    furnish.group(x, y + 3, Group.logPileB, Cost.logs)
    furnish.prop(x + 3, y + 2, Prop.chopBlock, Cost.logs)
    furnish.prop(x + 4, y + 3, Prop.stump, Cost.free)
    furnish.group(x + 5, y + 3, Group.bigTable, Cost.table)
    furnish.prop(x + 7, y + 4, Prop.lamp, Cost.lamp)
    return stages(pave, furnish)
end

local function wellStages(project)
    local pave = sink()
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            pave.ground(x, y, (x + y) % 2 == 0 and Ground.flag or Ground.brickAlt)
        end
    end
    local furnish = sink()
    local x, y = project.x, project.y
    furnish.prop(x + 2, y + 2, Prop.well, Cost.well)
    furnish.prop(x + 3, y + 2, Prop.pump, Cost.free)
    furnish.prop(x, y, Prop.barrel, Cost.crate)
    furnish.prop(x + 1, y, Prop.barrelWater, Cost.crate)
    furnish.prop(x + 4, y, Prop.crateWater, Cost.crate)
    furnish.group(x, y + 4, Group.logBenchRow, Cost.bench)
    furnish.prop(x + 4, y + 4, Prop.lamp, Cost.lamp)
    furnish.prop(x + 4, y + 3, pick(Prop.flowers, x, y, 5), Cost.free)
    return stages(pave, furnish)
end

local function gardenStages(project)
    local pave = sink()
    local x, y = project.x, project.y
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            if dx == 3 or dy == 3 then pave.ground(x + dx, y + dy, pick(Ground.sand, x + dx, y + dy, 7)) end
        end
    end
    local furnish = sink()
    for _, dx in ipairs({ 0, 1, 2, 4, 5, 6 }) do furnish.prop(x + dx, y, Prop.hedgeRow, Cost.free) end
    furnish.prop(x + 3, y + 1, Prop.birdbath, Cost.free)
    for _, dx in ipairs({ 1, 2, 4, 5 }) do
        for _, dy in ipairs({ 1, 2 }) do furnish.prop(x + dx, y + dy, pick(Prop.flowers, x + dx, y + dy, 8), Cost.free) end
    end
    for _, dx in ipairs({ 1, 2 }) do
        for _, dy in ipairs({ 4, 5 }) do furnish.prop(x + dx, y + dy, pick(Prop.flowers, x + dx, y + dy, 9), Cost.free) end
    end
    furnish.group(x + 4, y + 4, Group.benchN, Cost.bench)
    furnish.prop(x + 6, y + 5, Prop.gnome, Cost.free)
    furnish.prop(x + 5, y + 5, Prop.flamingo, Cost.free)
    return stages(pave, furnish)
end

local function memorialStages(project)
    local pave = sink()
    local x, y = project.x, project.y
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            if dx == 2 or dx == 3 then pave.ground(x + dx, y + dy, pick(Ground.pale, x + dx, y + dy, 10)) end
        end
    end
    local furnish = sink()
    for _, dx in ipairs({ 0, 1, 4, 5 }) do furnish.prop(x + dx, y, Prop.hedgeRow, Cost.free) end
    furnish.prop(x + 2, y, Prop.angel, Cost.free)
    furnish.prop(x + 3, y + 1, pick(Prop.flowers, x, y, 11), Cost.free)
    furnish.prop(x + 2, y + 1, pick(Prop.flowers, y, x, 12), Cost.free)
    for _, dx in ipairs({ 0, 1, 4, 5 }) do
        for _, dy in ipairs({ 2, 3 }) do
            local gx, gy = x + dx, y + dy
            furnish.prop(gx, gy, pick(Prop.mound, gx, gy, 13), Cost.free)
            if (dx + dy) % 2 == 0 then
                furnish.prop(gx, gy, pick(Prop.cross, gx, gy, 14), Cost.crate)
            else
                furnish.prop(gx, gy, pick(Prop.headstone, gx, gy, 15), Cost.free)
            end
        end
    end
    furnish.group(x + 2, y + 4, Group.benchN, Cost.bench)
    return stages(pave, furnish)
end

local function toCanonical(side, ox, oy, x, y)
    if side == "S" then return x - ox, oy - y end
    if side == "N" then return x - ox, y - oy end
    if side == "E" then return y - oy, ox - x end
    return y - oy, x - ox
end

local wingCells = {
    [0] = { [0] = "lamp", [1] = "cone", [2] = "cone" },
    [1] = { [0] = "gabion", [1] = "sandbag", [2] = "bench" },
    [2] = { [0] = "gabion", [1] = "sandbag", [2] = "bench" },
    [3] = { [0] = "gabion", [1] = "sandbag", [2] = "brazier" },
}

local function checkpointStages(project)
    local pave = pavePlain(project, Ground.apron, 16)
    local furnish = sink()
    local side = project.gate or "S"
    local horizontal = side == "N" or side == "S"
    local benchTiles = {}
    local reach = (project.reach or 1) + 1
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local u, v = toCanonical(side, project.ox, project.oy, x, y)
            local a = math.abs(u) - reach
            local token = wingCells[a] ~= nil and wingCells[a][v] or nil
            if token == "lamp" then
                furnish.prop(x, y, Prop.lamp, Cost.lamp)
            elseif token == "cone" then
                if v == 1 and u < 0 then
                    furnish.prop(x, y, Prop.stopSign, Cost.free)
                else
                    furnish.prop(x, y, Prop.cone, Cost.free)
                end
            elseif token == "gabion" then
                furnish.prop(x, y, pick(Prop.gabion, x, y, 17), Cost.sandbag)
            elseif token == "sandbag" then
                furnish.prop(x, y, horizontal and Prop.sandbagRow or Prop.sandbagColumn, Cost.sandbag)
            elseif token == "brazier" then
                furnish.prop(x, y, Prop.brazier, Cost.fire)
            elseif token == "bench" then
                benchTiles[#benchTiles + 1] = { x, y }
            end
        end
    end
    if #benchTiles == 2 then
        table.sort(benchTiles, function(p, q)
            if p[1] ~= q[1] then return p[1] < q[1] end
            return p[2] < q[2]
        end)
        local cells = horizontal and Group.logBenchRow or Group.logBenchColumn
        for index, tile in ipairs(benchTiles) do furnish.prop(tile[1], tile[2], cells[index][1], Cost.bench) end
    end
    return stages(pave, furnish)
end

Bp.kinds.plaza = { w = 7, h = 3, priority = 7, build = plazaStages }
Bp.kinds.path = { w = 1, h = 1, priority = 7, build = pathStages }
Bp.kinds.lamp = { w = 1, h = 1, priority = 8, build = lampStages }
Bp.kinds.checkpoint = { w = 4, h = 3, priority = 8, build = checkpointStages }
Bp.kinds.market = { w = 11, h = 4, priority = 9, build = marketStages }
Bp.kinds.workyard = { w = 8, h = 5, priority = 9, build = workyardStages }
Bp.kinds.well = { w = 5, h = 5, priority = 9, build = wellStages }
Bp.kinds.garden = { w = 7, h = 6, priority = 9, build = gardenStages }
Bp.kinds.memorial = { w = 6, h = 5, priority = 10, build = memorialStages }

local function key(x, y)
    return x * 65536 + y
end

local function shape(camp)
    local w, h = Geo.width(camp), Geo.height(camp)
    return w * h, math.min(w, h)
end

function Districts.quotas(camp)
    local area, minDim = shape(camp)
    local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
    local radius = 0
    if minDim >= 80 then radius = 6
    elseif minDim >= 40 then radius = 5
    elseif minDim >= 24 then radius = 4
    elseif minDim >= 16 then radius = 3 end
    return {
        radius = radius,
        streetHalf = minDim >= 24 and 1 or 0,
        checkpoint = minDim >= 16,
        market = minDim >= 22 and clamp(math.floor(area / 4000) + 1, 1, 4) or 0,
        workyard = minDim >= 20 and clamp(math.floor(area / 5000) + 1, 1, 3) or 0,
        well = minDim >= 18 and clamp(math.floor(area / 2500) + 1, 1, 6) or 0,
        garden = minDim >= 24 and clamp(math.floor(area / 3500) + 1, 1, 5) or 0,
        memorial = minDim >= 28 and (area >= 25000 and 2 or 1) or 0,
        lamps = clamp(math.floor(area / 150), 4, 90),
        cap = math.min(math.floor(Build.maxProjects * 0.6), 48 + math.floor(area / 30)),
    }
end

local function countProjects(camp)
    local total, decor = 0, 0
    for _, project in pairs(Build.plan(camp).items) do
        total = total + 1
        if kindSet[project.kind] then decor = decor + 1 end
    end
    return total, decor
end

local function growBox(ctx, x, y)
    local box = ctx.box
    if box == nil then
        ctx.box = { x1 = x, y1 = y, x2 = x, y2 = y }
        return
    end
    if x < box.x1 then box.x1 = x end
    if x > box.x2 then box.x2 = x end
    if y < box.y1 then box.y1 = y end
    if y > box.y2 then box.y2 = y end
end

local function markProject(ctx, project)
    local rect = Bp.footprint(project)
    local network = networkKinds[project.kind] == true
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            local cell = key(x, y)
            ctx.occ[cell] = true
            if network then
                ctx.network[cell] = true
                growBox(ctx, x, y)
            else
                ctx.solid[cell] = true
            end
        end
    end
end

local function markRect(ctx, rect)
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            local cell = key(x, y)
            ctx.occ[cell] = true
            ctx.solid[cell] = true
        end
    end
end

local function onlyBuilt(square)
    local clean = true
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local tag = World.tag(objects:get(i))
            if type(tag) == "table" and tag.kind ~= "built" and tag.kind ~= "site" then clean = false end
        end
    end)
    return clean
end

local function cellUsable(ctx, x, y)
    local cell = key(x, y)
    local cached = ctx.cells[cell]
    if cached ~= nil then return cached end
    local ok = true
    local square = World.square(x, y, ctx.camp.z)
    if square ~= nil then
        local state = Plan.cellState(ctx.camp, x, y)
        if state == Plan.WATER or state == Plan.BUILDING or state == Plan.BLOCKED then
            ok = false
        elseif state == Plan.BUILT then
            ok = onlyBuilt(square)
        end
    end
    ctx.cells[cell] = ok
    return ok
end

local function cellFree(ctx, x, y)
    if not Geo.contains(ctx.camp, x, y) then return false end
    if ctx.occ[key(x, y)] then return false end
    return cellUsable(ctx, x, y)
end

local function rectFree(ctx, x, y, w, h, margin)
    for cx = x, x + w - 1 do
        for cy = y, y + h - 1 do
            if ctx.reserved[key(cx, cy)] or not cellFree(ctx, cx, cy) then return false end
        end
    end
    if (margin or 0) > 0 then
        for cx = x - margin, x + w - 1 + margin do
            for cy = y - margin, y + h - 1 + margin do
                local outside = cx < x or cx >= x + w or cy < y or cy >= y + h
                if outside and ctx.solid[key(cx, cy)] then return false end
            end
        end
    end
    return true
end

local function fitNear(ctx, cx, cy, w, h, radius, margin)
    local ax, ay = cx - math.floor(w / 2), cy - math.floor(h / 2)
    for r = 0, radius do
        for dx = -r, r do
            for dy = -r, r do
                if r == 0 or math.abs(dx) == r or math.abs(dy) == r then
                    if rectFree(ctx, ax + dx, ay + dy, w, h, margin) then return ax + dx, ay + dy end
                end
            end
        end
    end
    return nil
end

local function canAdd(ctx, count, forLamps)
    local limit = ctx.allowed - (forLamps and 0 or ctx.lampReserve)
    return ctx.used + count <= limit
end

local function addProject(ctx, kind, x, y, options, fields)
    if not canAdd(ctx, 1, kind == "lamp") then return nil end
    local project = Build.add(ctx.camp, kind, x, y, options)
    if project == nil then return nil end
    if fields ~= nil then
        for name, value in pairs(fields) do project[name] = value end
    end
    markProject(ctx, project)
    ctx.used = ctx.used + 1
    ctx.added = ctx.added + 1
    return project
end

local function discard(ctx, projects)
    for _, project in ipairs(projects) do
        Build.plan(ctx.camp).items[tostring(project.id)] = nil
    end
end

local function heapPush(heap, cost, value)
    local n = #heap + 1
    heap[n] = { cost, value }
    while n > 1 do
        local parent = math.floor(n / 2)
        if heap[parent][1] <= heap[n][1] then break end
        heap[parent], heap[n] = heap[n], heap[parent]
        n = parent
    end
end

local function heapPop(heap)
    local top = heap[1]
    local last = heap[#heap]
    heap[#heap] = nil
    local n = #heap
    if n > 0 then
        heap[1] = last
        local i = 1
        while true do
            local left, right = i * 2, i * 2 + 1
            local smallest = i
            if left <= n and heap[left][1] < heap[smallest][1] then smallest = left end
            if right <= n and heap[right][1] < heap[smallest][1] then smallest = right end
            if smallest == i then break end
            heap[smallest], heap[i] = heap[i], heap[smallest]
            i = smallest
        end
    end
    return top[1], top[2]
end

local steps = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function touchesNetwork(ctx, x, y)
    for _, step in ipairs(steps) do
        if ctx.network[key(x + step[1], y + step[2])] then return true end
    end
    return false
end

local function boxDistance(ctx, x, y)
    local box = ctx.box
    if box == nil then return 0 end
    return math.max(box.x1 - x, 0, x - box.x2) + math.max(box.y1 - y, 0, y - box.y2)
end

local function route(ctx, sx, sy)
    if not cellFree(ctx, sx, sy) then return nil end
    local best, previous, heap = {}, {}, {}
    local startState = key(sx, sy) * 5
    best[startState] = 0
    previous[startState] = false
    heapPush(heap, boxDistance(ctx, sx, sy), { sx, sy, 0, startState, 0 })
    local expanded = 0
    while #heap > 0 and expanded < ctx.routeNodes do
        local _, node = heapPop(heap)
        local x, y, heading, state, cost = node[1], node[2], node[3], node[4], node[5]
        if best[state] == cost then
            expanded = expanded + 1
            if touchesNetwork(ctx, x, y) then
                local cells = {}
                local cursor = state
                while cursor do
                    local cell = math.floor(cursor / 5)
                    cells[#cells + 1] = { math.floor(cell / 65536), cell % 65536 }
                    cursor = previous[cursor]
                end
                local ordered = {}
                for i = #cells, 1, -1 do ordered[#ordered + 1] = cells[i] end
                return ordered
            end
            for index, step in ipairs(steps) do
                local nx, ny = x + step[1], y + step[2]
                if cellFree(ctx, nx, ny) then
                    local nextCost = cost + 1
                    if heading ~= 0 and heading ~= index then nextCost = nextCost + 3 end
                    if ctx.reserved[key(nx, ny)] then nextCost = nextCost + 3 end
                    local nextState = key(nx, ny) * 5 + index
                    if best[nextState] == nil or nextCost < best[nextState] then
                        best[nextState] = nextCost
                        previous[nextState] = state
                        heapPush(heap, nextCost + boxDistance(ctx, nx, ny), { nx, ny, index, nextState, nextCost })
                    end
                end
            end
        end
    end
    return nil
end

local function runsOf(cells)
    local runs = {}
    local i = 1
    while i <= #cells do
        local j = i
        if i < #cells then
            local dx, dy = cells[i + 1][1] - cells[i][1], cells[i + 1][2] - cells[i][2]
            while j < #cells and cells[j + 1][1] - cells[j][1] == dx and cells[j + 1][2] - cells[j][2] == dy do j = j + 1 end
        end
        local x1, y1 = math.min(cells[i][1], cells[j][1]), math.min(cells[i][2], cells[j][2])
        local x2, y2 = math.max(cells[i][1], cells[j][1]), math.max(cells[i][2], cells[j][2])
        runs[#runs + 1] = { x = x1, y = y1, w = x2 - x1 + 1, h = y2 - y1 + 1 }
        i = j + 1
    end
    return runs
end

local function connect(ctx, serves, sx, sy, style)
    if ctx.served[serves] then return false end
    local cells = route(ctx, sx, sy)
    if cells == nil then return false end
    local runs = runsOf(cells)
    if #runs > 8 or not canAdd(ctx, #runs, false) then return false end
    local made = {}
    for _, run in ipairs(runs) do
        local project = Build.add(ctx.camp, "path", run.x, run.y, { w = run.w, h = run.h })
        if project == nil then
            discard(ctx, made)
            return false
        end
        project.style = style or "lane"
        project.serves = serves
        made[#made + 1] = project
    end
    for _, project in ipairs(made) do
        markProject(ctx, project)
        ctx.used = ctx.used + 1
        ctx.added = ctx.added + 1
    end
    ctx.served[serves] = true
    return true
end

local function findFence(camp)
    for _, project in ipairs(Build.list(camp)) do
        if project.kind == "fence" and not project.retired then return project end
    end
    return nil
end

function Districts.gate(camp)
    local main = ALifeCamp.Gates.list(camp)[1]
    if main ~= nil then
        local out = { side = main.side, x = main.x, y = main.y, dx = main.dx, dy = main.dy }
        local posts = ALifeCamp.Posts
        if posts ~= nil then
            local inner = posts.innerEnd(camp, main)
            if inner ~= nil then out.x, out.y = inner.x, inner.y end
        end
        return out
    end
    local x1, y1, x2, y2 = camp.x1, camp.y1, camp.x2, camp.y2
    local w, h = x2 - x1 + 1, y2 - y1 + 1
    return { side = "S", x = x1 + math.floor(w / 2), y = y2, dx = 0, dy = -1 }
end

function Districts.doorEntry(project)
    local side = project.door or "S"
    local i, j = math.floor(project.w / 2), math.floor(project.h / 2)
    if side == "N" then return { x = project.x + i, y = project.y - 1, porchX = project.x + i, porchY = project.y - 1 } end
    if side == "W" then return { x = project.x - 1, y = project.y + j, porchX = project.x - 1, porchY = project.y + j } end
    if side == "E" then return { x = project.x + project.w + 1, y = project.y + j, porchX = project.x + project.w, porchY = project.y + j } end
    return { x = project.x + i, y = project.y + project.h + 1, porchX = project.x + i, porchY = project.y + project.h }
end

local function insideRect(rect, x, y)
    return x >= rect.x1 and x <= rect.x2 and y >= rect.y1 and y <= rect.y2
end

function Districts.adoptedDoors(camp, rect)
    local found = {}
    local function scan(x, y)
        local square = World.square(x, y, camp.z)
        if square == nil then return end
        pcall(function()
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local object = objects:get(i)
                if instanceof(object, "IsoDoor") then
                    local ox, oy = x, y
                    if object:getNorth() then oy = y - 1 else ox = x - 1 end
                    local here, there = insideRect(rect, x, y), insideRect(rect, ox, oy)
                    if here and not there then
                        found[#found + 1] = { x = ox, y = oy, beyondX = ox + (ox - x), beyondY = oy + (oy - y) }
                    end
                    if there and not here then
                        found[#found + 1] = { x = x, y = y, beyondX = x + (x - ox), beyondY = y + (y - oy) }
                    end
                end
            end
        end)
    end
    for x = rect.x1 - 1, rect.x2 + 1 do
        scan(x, rect.y1 - 1)
        scan(x, rect.y1)
        scan(x, rect.y2)
        scan(x, rect.y2 + 1)
    end
    for y = rect.y1, rect.y2 do
        scan(rect.x1 - 1, y)
        scan(rect.x1, y)
        scan(rect.x2, y)
        scan(rect.x2 + 1, y)
    end
    return found
end

local function adoptedRecords(camp)
    local out = {}
    if type(camp.adopt) ~= "table" or type(camp.adopt.items) ~= "table" then return out end
    local names = {}
    for name in pairs(camp.adopt.items) do names[#names + 1] = tostring(name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local rec = camp.adopt.items[name]
        if rec == nil then rec = camp.adopt.items[tonumber(name)] end
        if type(rec) == "table" and type(rec.rect) == "table" and rec.status ~= "rejected"
                and (rec.rect.z == nil or rec.rect.z == camp.z) then
            out[#out + 1] = { name = name, rec = rec }
        end
    end
    return out
end

local function newContext(camp)
    local area, minDim = shape(camp)
    local ctx = {
        camp = camp, area = area, minDim = minDim, quotas = Districts.quotas(camp),
        occ = {}, solid = {}, network = {}, reserved = {}, cells = {}, served = {},
        used = 0, added = 0, routeNodes = 6000,
    }
    ctx.cx, ctx.cy = Geo.center(camp)
    local total, decor = countProjects(camp)
    local room = Build.maxProjects - total - math.max(20, math.floor(Build.maxProjects * 0.1))
    ctx.allowed = math.max(0, math.min(ctx.quotas.cap - decor, room))
    ctx.lampReserve = math.min(ctx.quotas.lamps, math.floor(ctx.allowed * 0.2))
    for _, project in ipairs(Build.list(camp)) do
        if project.kind ~= "fence" and not project.retired then
            markProject(ctx, project)
            if project.serves ~= nil then ctx.served[project.serves] = true end
        end
    end
    ctx.records = adoptedRecords(camp)
    for _, entry in ipairs(ctx.records) do
        local rect = entry.rec.rect
        markRect(ctx, { x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2 })
    end
    return ctx
end

local function reserve(ctx, x, y)
    ctx.reserved[key(x, y)] = true
end

local function firstOf(camp, kind)
    for _, project in ipairs(Build.list(camp)) do
        if project.kind == kind and not project.retired then return project end
    end
    return nil
end

local function plazaCenter(ctx)
    local fire = firstOf(ctx.camp, "campfire")
    if fire == nil then return nil end
    return fire.x + 1, fire.y + 1
end

local function focus(ctx)
    local fx, fy = plazaCenter(ctx)
    if fx == nil then return ctx.cx, ctx.cy end
    return fx, fy
end

local function placePlaza(ctx)
    if firstOf(ctx.camp, "plaza") ~= nil then return end
    local fx, fy = plazaCenter(ctx)
    if fx == nil or ctx.quotas.radius < 3 then return end
    local gate = Districts.gate(ctx.camp)
    local parts = { "N", "S", "W", "E" }
    local function rectOf(part, radius)
        if part == "N" then return fx - radius, fy - radius, 2 * radius + 1, radius - 1 end
        if part == "S" then return fx - radius, fy + 2, 2 * radius + 1, radius - 1 end
        if part == "W" then return fx - radius, fy - 1, radius - 1, 3 end
        return fx + 2, fy - 1, radius - 1, 3
    end
    for radius = ctx.quotas.radius, 3, -1 do
        local fits = {}
        for _, part in ipairs(parts) do
            local x, y, w, h = rectOf(part, radius)
            if rectFree(ctx, x, y, w, h, 0) then fits[#fits + 1] = part end
        end
        if #fits == 4 or (radius == 3 and #fits >= 2) then
            if not canAdd(ctx, #fits, false) then return end
            for _, part in ipairs(fits) do
                local x, y, w, h = rectOf(part, radius)
                addProject(ctx, "plaza", x, y, { w = w, h = h },
                    { part = part, fx = fx, fy = fy, radius = radius, gate = gate.side })
            end
            return
        end
    end
end

local function plazaBounds(ctx)
    local x1, y1, x2, y2
    for _, project in ipairs(Build.list(ctx.camp)) do
        if project.kind == "plaza" and not project.retired then
            x1 = x1 == nil and project.x or math.min(x1, project.x)
            y1 = y1 == nil and project.y or math.min(y1, project.y)
            x2 = x2 == nil and project.x + project.w - 1 or math.max(x2, project.x + project.w - 1)
            y2 = y2 == nil and project.y + project.h - 1 or math.max(y2, project.y + project.h - 1)
        end
    end
    if x1 ~= nil then return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 } end
    local fire = firstOf(ctx.camp, "campfire")
    if fire ~= nil then return { x1 = fire.x, y1 = fire.y, x2 = fire.x + 2, y2 = fire.y + 2 } end
    return nil
end

local function reserveGateCorridor(ctx, gate)
    for step = 0, 14 do
        for lateral = -1, 1 do
            if gate.dx == 0 then
                reserve(ctx, gate.x + lateral, gate.y + gate.dy * step)
            else
                reserve(ctx, gate.x + gate.dx * step, gate.y + lateral)
            end
        end
    end
end

local function streetRect(gate, bounds, half)
    if gate.side == "S" then
        local top = bounds.y2 + 1
        if top > gate.y then return nil end
        return gate.x - half, top, 2 * half + 1, gate.y - top + 1
    end
    if gate.side == "N" then
        local bottom = bounds.y1 - 1
        if bottom < gate.y then return nil end
        return gate.x - half, gate.y, 2 * half + 1, bottom - gate.y + 1
    end
    if gate.side == "E" then
        local left = bounds.x2 + 1
        if left > gate.x then return nil end
        return left, gate.y - half, gate.x - left + 1, 2 * half + 1
    end
    local right = bounds.x1 - 1
    if right < gate.x then return nil end
    return gate.x, gate.y - half, right - gate.x + 1, 2 * half + 1
end

local function lateralWithin(gate, bounds, half)
    if gate.dx == 0 then return gate.x - half >= bounds.x1 and gate.x + half <= bounds.x2 end
    return gate.y - half >= bounds.y1 and gate.y + half <= bounds.y2
end

local function existingStreet(ctx)
    for _, project in ipairs(Build.list(ctx.camp)) do
        if project.kind == "path" and project.style == "street" and project.serves == "gate" and not project.retired then
            return project
        end
    end
    return nil
end

local function placeStreet(ctx)
    local gate = Districts.gate(ctx.camp)
    local street = existingStreet(ctx)
    if street ~= nil then
        ctx.gateHalf = math.floor((math.min(street.w, street.h) - 1) / 2)
        return
    end
    local bounds = plazaBounds(ctx)
    if bounds == nil then return end
    local half = ctx.quotas.streetHalf
    while half >= 0 do
        if lateralWithin(gate, bounds, half) then
            local x, y, w, h = streetRect(gate, bounds, half)
            if x == nil then return end
            if rectFree(ctx, x, y, w, h, 0) then
                if addProject(ctx, "path", x, y, { w = w, h = h }, { style = "street", serves = "gate" }) ~= nil then
                    ctx.served.gate = true
                    ctx.gateHalf = half
                end
                return
            end
        end
        half = half - 1
    end
    if connect(ctx, "gate", gate.x, gate.y, "street") then
        ctx.gateHalf = 0
    else
        reserveGateCorridor(ctx, gate)
    end
end

local function placeCheckpoint(ctx)
    if not ctx.quotas.checkpoint or firstOf(ctx.camp, "checkpoint") ~= nil or firstOf(ctx.camp, "post") ~= nil then return end
    local gate = Districts.gate(ctx.camp)
    local half = ctx.gateHalf or 0
    local reach = half + 1
    local function world(u, v)
        if gate.side == "S" then return gate.x + u, gate.y - v end
        if gate.side == "N" then return gate.x + u, gate.y + v end
        if gate.side == "E" then return gate.x - v, gate.y + u end
        return gate.x + v, gate.y + u
    end
    local specs = {}
    for _, sign in ipairs({ 1, -1 }) do
        local u1, u2 = sign * reach, sign * (reach + 3)
        local ax, ay = world(math.min(u1, u2), 0)
        local bx, by = world(math.max(u1, u2), 2)
        local x, y = math.min(ax, bx), math.min(ay, by)
        local w, h = math.abs(ax - bx) + 1, math.abs(ay - by) + 1
        if rectFree(ctx, x, y, w, h, 0) then specs[#specs + 1] = { x, y, w, h } end
    end
    for _, spec in ipairs(specs) do
        addProject(ctx, "checkpoint", spec[1], spec[2], { w = spec[3], h = spec[4] },
            { gate = gate.side, ox = gate.x, oy = gate.y, reach = half })
    end
end

local function buildingEntries(ctx)
    local list = {}
    for _, project in ipairs(Build.list(ctx.camp)) do
        if buildingKinds[project.kind] and not project.retired then
            local entry = Districts.doorEntry(project)
            list[#list + 1] = { serves = project.kind .. ":" .. project.id, x = entry.x, y = entry.y, porchX = entry.porchX, porchY = entry.porchY }
        end
    end
    for _, item in ipairs(ctx.records) do
        local rect = item.rec.rect
        local doors = type(item.rec.entrances) == "table" and item.rec.entrances or Districts.adoptedDoors(ctx.camp, rect)
        local fx, fy = focus(ctx)
        local best, bestDistance
        for _, door in ipairs(doors) do
            local distance = (door.x - fx) * (door.x - fx) + (door.y - fy) * (door.y - fy)
            if bestDistance == nil or distance < bestDistance then best, bestDistance = door, distance end
        end
        if best == nil then
            local mx, my = math.floor((rect.x1 + rect.x2) / 2), math.floor((rect.y1 + rect.y2) / 2)
            local dx, dy = fx - mx, fy - my
            if math.abs(dx) > math.abs(dy) then
                best = { x = dx > 0 and rect.x2 + 1 or rect.x1 - 1, y = my }
            else
                best = { x = mx, y = dy > 0 and rect.y2 + 1 or rect.y1 - 1 }
            end
        end
        local entryX, entryY = best.x, best.y
        if best.beyondX ~= nil and not cellFree(ctx, entryX, entryY) then entryX, entryY = best.beyondX, best.beyondY end
        list[#list + 1] = { serves = "adopt:" .. item.name, x = entryX, y = entryY, porchX = best.x, porchY = best.y }
    end
    return list
end

local function reserveEntries(ctx)
    ctx.entries = buildingEntries(ctx)
    for _, entry in ipairs(ctx.entries) do
        reserve(ctx, entry.x, entry.y)
        reserve(ctx, entry.porchX, entry.porchY)
    end
end

local function connectBuildings(ctx)
    local fx, fy = focus(ctx)
    local entries = ctx.entries
    table.sort(entries, function(a, b)
        local da = (a.x - fx) * (a.x - fx) + (a.y - fy) * (a.y - fy)
        local db = (b.x - fx) * (b.x - fx) + (b.y - fy) * (b.y - fy)
        if da ~= db then return da < db end
        return a.serves < b.serves
    end)
    for _, entry in ipairs(entries) do
        if not ctx.served[entry.serves] then connect(ctx, entry.serves, entry.x, entry.y) end
    end
end

local function entryFor(ctx, project)
    local fx, fy = focus(ctx)
    local mx, my = project.x + math.floor(project.w / 2), project.y + math.floor(project.h / 2)
    local options = {
        { x = mx, y = project.y - 1, score = my - fy },
        { x = mx, y = project.y + project.h, score = fy - my },
        { x = project.x - 1, y = my, score = mx - fx },
        { x = project.x + project.w, y = my, score = fx - mx },
    }
    table.sort(options, function(a, b) return a.score > b.score end)
    for _, option in ipairs(options) do
        if cellFree(ctx, option.x, option.y) then return option end
    end
    return nil
end

local function connectDistrict(ctx, project)
    local entry = entryFor(ctx, project)
    if entry == nil then return false end
    return connect(ctx, project.kind .. ":" .. project.id, entry.x, entry.y)
end

local function countKind(camp, kind)
    local n = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and not project.retired then n = n + 1 end
    end
    return n
end

local function placeDistrict(ctx, kind, anchors, radius, margin)
    local def = Bp.kinds[kind]
    for _, anchor in ipairs(anchors) do
        local x, y = fitNear(ctx, anchor[1], anchor[2], def.w, def.h, radius, margin)
        if x ~= nil then
            local project = addProject(ctx, kind, x, y, nil, nil)
            if project ~= nil then return project end
        end
    end
    return nil
end

local function buildingCenters(ctx, kinds)
    local out = {}
    for _, project in ipairs(Build.list(ctx.camp)) do
        if kinds[project.kind] and not project.retired then out[#out + 1] = project end
    end
    return out
end

local function placeMarkets(ctx)
    local need = ctx.quotas.market - countKind(ctx.camp, "market")
    local fx, fy = focus(ctx)
    local radius = math.max(ctx.quotas.radius, 3)
    for index = 1, need do
        local anchors = {
            { fx, fy - radius - 4 },
            { fx - radius - 8, fy - 2 },
            { fx + radius + 8, fy - 2 },
            { fx, fy + radius + 5 },
        }
        if index > 1 then
            anchors = {}
            local houses = buildingCenters(ctx, buildingKinds)
            local base = houses[(index * 3) % math.max(1, #houses) + 1]
            if base ~= nil then anchors[1] = { base.x + base.w + 6, base.y } end
            anchors[#anchors + 1] = { fx + (index - 1) * 12 - 12, fy - radius - 8 - (index - 1) * 3 }
        end
        local project = placeDistrict(ctx, "market", anchors, 8 + index * 3, 1)
        if project ~= nil then connectDistrict(ctx, project) end
    end
end

local function placeWorkyards(ctx)
    local need = ctx.quotas.workyard - countKind(ctx.camp, "workyard")
    local sheds = buildingCenters(ctx, { shed = true })
    local fx, fy = focus(ctx)
    for index = 1, need do
        local anchors = {}
        local shed = sheds[index]
        if shed ~= nil then
            anchors[#anchors + 1] = { shed.x + shed.w + 6, shed.y + 2 }
            anchors[#anchors + 1] = { shed.x - 5, shed.y + 2 }
            anchors[#anchors + 1] = { shed.x + 2, shed.y + shed.h + 5 }
            anchors[#anchors + 1] = { shed.x + 2, shed.y - 5 }
        end
        anchors[#anchors + 1] = { fx - ctx.quotas.radius - 9, fy + 4 + (index - 1) * 8 }
        anchors[#anchors + 1] = { fx + ctx.quotas.radius + 9, fy + 4 + (index - 1) * 8 }
        local project = placeDistrict(ctx, "workyard", anchors, 12, 1)
        if project ~= nil then connectDistrict(ctx, project) end
    end
end

local function placeWells(ctx)
    local need = ctx.quotas.well - countKind(ctx.camp, "well")
    local fx, fy = focus(ctx)
    local houses = buildingCenters(ctx, buildingKinds)
    for index = 1, need do
        local anchors = {}
        if index == 1 then
            anchors[1] = { fx - ctx.quotas.radius - 5, fy + ctx.quotas.radius }
            anchors[2] = { fx + ctx.quotas.radius + 5, fy + ctx.quotas.radius }
        end
        local base = houses[(index * 5) % math.max(1, #houses) + 1]
        if base ~= nil then
            anchors[#anchors + 1] = { base.x + base.w + 4, base.y + base.h + 2 }
            anchors[#anchors + 1] = { base.x - 3, base.y + base.h + 2 }
        end
        local project = placeDistrict(ctx, "well", anchors, 10, 1)
        if project ~= nil then connectDistrict(ctx, project) end
    end
end

local function placeGardens(ctx)
    local need = ctx.quotas.garden - countKind(ctx.camp, "garden")
    local fx, fy = focus(ctx)
    local houses = buildingCenters(ctx, buildingKinds)
    for index = 1, need do
        local anchors = {}
        if index == 1 then
            anchors[1] = { fx + ctx.quotas.radius + 7, fy - 3 }
            anchors[2] = { fx - ctx.quotas.radius - 7, fy - 3 }
        end
        local base = houses[(index * 7) % math.max(1, #houses) + 1]
        if base ~= nil then anchors[#anchors + 1] = { base.x + base.w + 6, base.y + 1 } end
        local project = placeDistrict(ctx, "garden", anchors, 12, 1)
        if project ~= nil then connectDistrict(ctx, project) end
    end
end

local function placeMemorials(ctx)
    local need = ctx.quotas.memorial - countKind(ctx.camp, "memorial")
    if need <= 0 then return end
    local gate = Districts.gate(ctx.camp)
    local camp = ctx.camp
    local corners = {
        { camp.x1 + 5, camp.y1 + 5 }, { camp.x2 - 5, camp.y1 + 5 },
        { camp.x1 + 5, camp.y2 - 5 }, { camp.x2 - 5, camp.y2 - 5 },
    }
    local gx, gy = gate.x, gate.y
    table.sort(corners, function(a, b)
        local da = (a[1] - gx) * (a[1] - gx) + (a[2] - gy) * (a[2] - gy)
        local db = (b[1] - gx) * (b[1] - gx) + (b[2] - gy) * (b[2] - gy)
        if da ~= db then return da > db end
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a[2] < b[2]
    end)
    for index = 1, need do
        local anchors = {}
        for offset = 0, 3 do
            local corner = corners[(offset + index - 1) % 4 + 1]
            anchors[#anchors + 1] = corner
        end
        placeDistrict(ctx, "memorial", anchors, 8, 1)
    end
end

local function collectLamps(ctx)
    ctx.lampGrid = {}
    local function register(x, y)
        local bucket = key(math.floor(x / 5), math.floor(y / 5))
        local list = ctx.lampGrid[bucket]
        if list == nil then
            list = {}
            ctx.lampGrid[bucket] = list
        end
        list[#list + 1] = { x, y }
        ctx.lampCount = (ctx.lampCount or 0) + 1
    end
    ctx.registerLamp = register
    for _, project in pairs(Build.plan(ctx.camp).items) do
        if kindSet[project.kind] then
            for _, stage in ipairs(Bp.stages(project)) do
                for _, op in ipairs(stage.ops) do
                    if op.sprite == Prop.lamp then register(op.x, op.y) end
                end
            end
        end
    end
end

local function lampSpaced(ctx, x, y)
    local bx, by = math.floor(x / 5), math.floor(y / 5)
    for gx = bx - 1, bx + 1 do
        for gy = by - 1, by + 1 do
            local list = ctx.lampGrid[key(gx, gy)]
            if list ~= nil then
                for _, lamp in ipairs(list) do
                    if math.max(math.abs(lamp[1] - x), math.abs(lamp[2] - y)) < 5 then return false end
                end
            end
        end
    end
    return true
end

local function placeLamps(ctx)
    collectLamps(ctx)
    local fx, fy = focus(ctx)
    local paths = {}
    for _, project in ipairs(Build.list(ctx.camp)) do
        if project.kind == "path" and not project.retired and math.min(project.w, project.h) < 3 and math.max(project.w, project.h) >= 6 then
            paths[#paths + 1] = project
        end
    end
    table.sort(paths, function(a, b)
        local da = (a.x - fx) * (a.x - fx) + (a.y - fy) * (a.y - fy)
        local db = (b.x - fx) * (b.x - fx) + (b.y - fy) * (b.y - fy)
        if da ~= db then return da < db end
        return a.id < b.id
    end)
    for _, project in ipairs(paths) do
        if (ctx.lampCount or 0) >= ctx.quotas.lamps then return end
        local alongX = project.w >= project.h
        local length = math.max(project.w, project.h)
        for along = 2, length - 1, 6 do
            for _, side in ipairs({ -1, 1 }) do
                local lx = alongX and project.x + along or project.x + side
                local ly = alongX and project.y + side or project.y + along
                if rectFree(ctx, lx, ly, 1, 1, 0) and lampSpaced(ctx, lx, ly) and canAdd(ctx, 1, true)
                        and (ctx.lampCount or 0) < ctx.quotas.lamps then
                    if addProject(ctx, "lamp", lx, ly, nil, { along = project.id }) ~= nil then
                        ctx.registerLamp(lx, ly)
                    end
                    break
                end
            end
        end
    end
end

local function ensureCampfire(ctx)
    if Plan.hasKind(ctx.camp, "campfire") or not canAdd(ctx, 1, false) then return end
    local project = Plan.place(ctx.camp, "campfire", ctx.cx - 1, ctx.cy - 1, 8)
    if project ~= nil then
        markProject(ctx, project)
        ctx.used = ctx.used + 1
        ctx.added = ctx.added + 1
    end
end

local function placeGateRoads(ctx)
    local posts = ALifeCamp.Posts
    if posts == nil then return end
    for index, geo in ipairs(ALifeCamp.Gates.list(ctx.camp)) do
        if index > 1 then
            local inner = posts.innerEnd(ctx.camp, geo)
            if inner ~= nil then connect(ctx, "gate:" .. geo.key, inner.x, inner.y, "street") end
        end
    end
end

local function skeleton(ctx)
    ensureCampfire(ctx)
    placePlaza(ctx)
    placeStreet(ctx)
    placeGateRoads(ctx)
    placeCheckpoint(ctx)
    reserveEntries(ctx)
end

function Districts.reserve(camp)
    if camp == nil then return 0 end
    local ctx = newContext(camp)
    if ctx.allowed <= 0 then return 0 end
    skeleton(ctx)
    return ctx.added
end

function Districts.generate(camp)
    if camp == nil then return 0 end
    local ctx = newContext(camp)
    if ctx.allowed <= 0 then return 0 end
    skeleton(ctx)
    connectBuildings(ctx)
    placeMarkets(ctx)
    placeWorkyards(ctx)
    placeWells(ctx)
    placeGardens(ctx)
    placeMemorials(ctx)
    connectBuildings(ctx)
    placeLamps(ctx)
    return ctx.added
end

function Districts.describe(camp)
    local boxes = {}
    for _, project in pairs(Build.plan(camp).items) do
        local district = districtOf[project.kind]
        if district ~= nil and not project.retired then
            local rect = Bp.footprint(project)
            local box = boxes[district]
            if box == nil then
                box = { x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2, count = 0, done = 0 }
                boxes[district] = box
            end
            box.x1, box.y1 = math.min(box.x1, rect.x1), math.min(box.y1, rect.y1)
            box.x2, box.y2 = math.max(box.x2, rect.x2), math.max(box.y2, rect.y2)
            box.count = box.count + 1
            if project.status == "done" then box.done = box.done + 1 end
        end
    end
    local out = {}
    for _, district in ipairs(Districts.order) do
        local box = boxes[district]
        if box ~= nil then
            out[#out + 1] = {
                key = district, name_key = "District_" .. district,
                x = box.x1, y = box.y1, w = box.x2 - box.x1 + 1, h = box.y2 - box.y1 + 1,
                count = box.count, done = box.done,
            }
        end
    end
    return out
end

function Districts.clearPlanned(camp)
    local removed = 0
    local items = Build.plan(camp).items
    for name, project in pairs(items) do
        if kindSet[project.kind] and project.status == "planned" and project.stage == 1 and not project.paid then
            items[name] = nil
            removed = removed + 1
        end
    end
    return removed
end

function Districts.isDecor(kind)
    return kindSet[kind] == true
end

return Districts
