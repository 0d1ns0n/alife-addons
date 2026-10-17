require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampDistricts"
require "ALifeCamp/CampBuildings"
require "ALifeCamp/CampBuildings2"
require "ALifeCamp/CampBuildings3"
require "ALifeCamp/CampPosts"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Entities = ALifeCamp.Entities
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local T = ALifeCamp.T

local Scenery = {}
ALifeCamp.Scenery = Scenery

Scenery.kinds = { "market", "plaza", "well", "garden", "memorial" }
Scenery.moraleCap = 3
Scenery.farmFactor = 1.05
Scenery.prefix = "SC"

Entities.CampDecoFree = { id = "CampDecoFree", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 30, inputs = {} }
Entities.CampDecoNail = { id = "CampDecoNail", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 40,
    inputs = { { n = 1, t = { "Base.Nails" } } } }
Entities.CampDecoCloth = { id = "CampDecoCloth", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 50,
    inputs = { { n = 2, t = { "Base.Nails" } } } }
Entities.CampDecoLight = { id = "CampDecoLight", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 50,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 1, t = { "Base.Nails" } } } }

local FREE, NAIL, CLOTH, LIGHT = "CampDecoFree", "CampDecoNail", "CampDecoCloth", "CampDecoLight"

local Art = {
    awning = { "walls_decoration_01_100", "walls_decoration_01_84" },
    counter = "carpentry_02_21",
    drum = "crafted_01_24",
    rainBarrel = "carpentry_02_120",
    barrelWater = "carpentry_02_53",
    carton = "furniture_storage_02_24",
    crate = "carpentry_01_16",
    sign = "constructedobjects_signs_01_11",
    well = "camping_01_16",
    pole = "street_decoration_01_24",
    flag = "street_decoration_01_16",
    boardS = "location_business_office_generic_01_7",
    boardE = "location_business_office_generic_01_15",
    roses = "vegetation_gardening_01_4",
    poppies = "vegetation_gardening_01_12",
    lavender = "vegetation_gardening_01_20",
    lamp = "carpentry_02_61",
    hedge = "vegetation_ornamental_01_4",
    scarecrow = "location_farm_accesories_01_36",
    compost = { "carpentry_02_116", "carpentry_02_117" },
    hay = { "vegetation_farm_01_10", "vegetation_farm_01_8" },
    candle = { "constructedobjects_01_0", "constructedobjects_01_1" },
    skullStag = "constructedobjects_signs_01_52",
    skullCowW = "constructedobjects_signs_01_62",
    skullDoeE = "constructedobjects_signs_01_79",
    skullPig = "constructedobjects_signs_01_84",
    sandbagRow = "carpentry_02_13",
    gabion = { "fencing_01_96", "fencing_01_102", "fencing_01_103" },
    ammoCrate = { "location_military_generic_01_0", "location_military_generic_01_2", "location_military_generic_01_4", "location_military_generic_01_8" },
    milBarrel = { "location_military_generic_01_6", "location_military_generic_01_14" },
    cone = "street_decoration_01_26",
    barrelRust = "carpentry_02_52",
    drumYellow = "industry_01_22",
    anvil = "crafted_01_18", chopBlock = "crafted_02_85", stump = "crafted_02_86",
    tires = { "location_business_machinery_01_50", "location_business_machinery_01_51", "location_business_machinery_01_52" },
    toolCab = "location_business_machinery_01_32",
    birdbath = "vegetation_ornamental_01_50", bush = "vegetation_ornamental_01_9",
    conifer = "vegetation_ornamental_01_8", hedgeCol = "vegetation_ornamental_01_5",
    pot = { "vegetation_ornamental_01_16", "vegetation_ornamental_01_17", "vegetation_ornamental_01_19", "vegetation_ornamental_01_20" },
    cropRow = { "vegetation_farm_01_32", "vegetation_farm_01_33", "vegetation_farm_01_34", "vegetation_farm_01_35" },
    brazier = "crafted_02_42",
}

local DEFAULT_STYLE = { edge = { Art.roses, Art.poppies, Art.lavender }, accent = Art.hedge, corner = Art.lamp, cost = FREE, mod = 7, fill = 4 }
local frontageStyles = {
    house_s    = { edge = { Art.roses, Art.poppies, Art.lavender, Art.pot[1] }, accent = Art.hedge,    corner = Art.lamp, flank = Art.bush,    cost = FREE, mod = 7, fill = 4 },
    house_m    = { edge = { Art.roses, Art.lavender, Art.pot[2], Art.pot[3] },  accent = Art.hedge,    corner = Art.lamp, flank = Art.conifer, cost = FREE, mod = 7, fill = 4 },
    house_l    = { edge = { Art.poppies, Art.pot[1], Art.pot[4], Art.hedge },   accent = Art.hedgeCol, corner = Art.lamp, flank = Art.conifer, cost = FREE, mod = 7, fill = 4 },
    shed       = { edge = { Art.crate, Art.carton, Art.barrelRust, Art.compost[1], Art.hay[1] }, accent = Art.crate, corner = Art.lamp, cost = NAIL, mod = 6, fill = 4 },
    greenhouse = { edge = { Art.cropRow[1], Art.cropRow[2], Art.hay[1], Art.compost[1], Art.pot[1] }, accent = Art.rainBarrel, corner = Art.scarecrow, cost = FREE, mod = 6, fill = 5 },
    canteen    = { edge = { Art.pot[1], Art.pot[2], Art.barrelWater, Art.crate }, accent = Art.hedge, corner = Art.lamp, cost = FREE, mod = 7, fill = 4 },
    infirmary  = { edge = { Art.hedge, Art.hedgeCol, Art.roses, Art.lavender, Art.pot[3] }, accent = Art.birdbath, corner = Art.lamp, cost = FREE, mod = 6, fill = 5, tidy = true },
    forge      = { edge = { Art.barrelRust, Art.drumYellow, Art.anvil, Art.chopBlock, Art.crate, Art.compost[2] }, accent = Art.stump, corner = Art.brazier, cost = NAIL, mod = 6, fill = 5 },
    powerhouse = { edge = { Art.milBarrel[1], Art.drumYellow, Art.toolCab, Art.tires[1], Art.crate }, accent = Art.cone, corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    barracks   = { edge = { Art.ammoCrate[1], Art.ammoCrate[2], Art.milBarrel[1], Art.sandbagRow, Art.gabion[1] }, accent = Art.gabion[2], corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    guardhouse = { edge = { Art.sandbagRow, Art.ammoCrate[1], Art.milBarrel[1], Art.cone }, accent = Art.gabion[1], corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    vault      = { edge = { Art.crate, Art.carton, Art.ammoCrate[3], Art.milBarrel[2], Art.barrelRust }, accent = Art.sandbagRow, corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    garage     = { edge = { Art.tires[1], Art.tires[2], Art.toolCab, Art.barrelRust, Art.crate }, accent = Art.cone, corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    farm       = { fence = "WoodFenceLvl1", gap = true, edge = { Art.hay[1], Art.hay[2], Art.compost[1] }, accent = Art.scarecrow, corner = Art.hay[1], cost = FREE, mod = 6, fill = 5 },
    garden     = { edge = { Art.roses, Art.poppies, Art.lavender, Art.cropRow[3], Art.pot[2], Art.hedge }, accent = Art.birdbath, corner = Art.hedgeCol, flank = Art.bush, cost = FREE, mod = 6, fill = 5 },
    tents      = { edge = { Art.crate, Art.carton, Art.hay[1], Art.milBarrel[1], Art.sandbagRow }, accent = Art.gabion[1], corner = Art.lamp, cost = NAIL, mod = 6, fill = 4 },
    motorpool  = { edge = { Art.tires[1], Art.tires[2], Art.barrelRust, Art.drumYellow, Art.cone }, accent = Art.toolCab, corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    bay        = { edge = { Art.tires[1], Art.milBarrel[1], Art.sandbagRow, Art.crate, Art.cone }, accent = Art.gabion[1], corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    range      = { edge = { Art.sandbagRow, Art.ammoCrate[1], Art.milBarrel[1], Art.gabion[1], Art.cone }, accent = Art.gabion[2], corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
    post       = { edge = { Art.sandbagRow, Art.gabion[1], Art.cone, Art.milBarrel[1] }, accent = Art.ammoCrate[1], corner = Art.lamp, cost = NAIL, mod = 6, fill = 4 },
    workyard   = { edge = { Art.crate, Art.carton, Art.barrelRust, Art.compost[2], Art.stump }, accent = Art.chopBlock, corner = Art.lamp, cost = NAIL, mod = 6, fill = 5 },
}

local knownSprites = {}

local function known(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function key(x, y)
    return x * 65536 + y
end

local function claimedCells(stages)
    local set = {}
    for _, stage in ipairs(stages) do
        for _, op in ipairs(stage.ops) do
            if op.t ~= "dirt" and op.t ~= "floor" and op.t ~= "roof" and (op.z or 0) == 0 then
                set[key(op.x, op.y)] = true
            end
        end
    end
    return set
end

local function scene(project, taken, zone)
    local self = { ops = {}, n = 0, used = {}, covered = {}, raised = {} }
    local function inside(x, y)
        return x >= project.x and x < project.x + project.w and y >= project.y and y < project.y + project.h
    end
    zone = zone or inside
    local function emit(x, y, z, sprite, cost)
        self.n = self.n + 1
        if inside(x, y) and known(sprite) then
            self.ops[#self.ops + 1] = { t = "prop", e = cost, sprite = sprite, x = x, y = y, z = z, slot = Scenery.prefix .. self.n }
        end
    end
    function self.free(x, y)
        local cell = key(x, y)
        return zone(x, y) and not taken[cell] and not self.used[cell]
    end
    function self.put(x, y, sprite, cost)
        if not self.free(x, y) then return false end
        self.used[key(x, y)] = true
        emit(x, y, 0, sprite, cost)
        return true
    end
    function self.cover(x, y, sprite, cost)
        local cell = key(x, y)
        if not zone(x, y) or self.covered[cell] then return false end
        self.covered[cell] = true
        emit(x, y, 0, sprite, cost)
        return true
    end
    function self.raise(x, y, sprite, cost)
        local cell = key(x, y)
        if not zone(x, y) or self.raised[cell] then return false end
        self.raised[cell] = true
        emit(x, y, 1, sprite, cost)
        return true
    end
    function self.first(cells, fn)
        for _, cell in ipairs(cells) do
            if self.free(cell[1], cell[2]) then
                fn(cell[1], cell[2])
                return true
            end
        end
        return false
    end
    return self
end

local function plazaRects(project)
    local fx, fy, radius = project.fx, project.fy, project.radius
    return {
        { fx - radius, fy - radius, 2 * radius + 1, radius - 1 },
        { fx - radius, fy + 2, 2 * radius + 1, radius - 1 },
        { fx - radius, fy - 1, radius - 1, 3 },
        { fx + 2, fy - 1, radius - 1, 3 },
    }
end

local function plazaGround(project, original)
    local rects = plazaRects(project)
    local taken = {}
    for index, rect in ipairs(rects) do
        local part = { kind = "plaza", x = rect[1], y = rect[2], w = rect[3], h = rect[4], fx = project.fx, fy = project.fy,
            radius = project.radius, gate = project.gate, part = index }
        for cell in pairs(claimedCells(original(part))) do taken[cell] = true end
    end
    local function zone(x, y)
        for _, rect in ipairs(rects) do
            if x >= rect[1] and x < rect[1] + rect[3] and y >= rect[2] and y < rect[2] + rect[4] then return true end
        end
        return false
    end
    return taken, zone
end

local function rotate(side, x, y)
    if side == "N" then return -x, -y end
    if side == "E" then return y, -x end
    if side == "W" then return -y, x end
    return x, y
end

local function plazaScene(project, s)
    local radius = project.radius or 0
    if radius < 3 or project.fx == nil then return end
    local side = project.gate or "S"
    local back = radius - 1
    local function at(x, y)
        local rx, ry = rotate(side, x, y)
        return project.fx + rx, project.fy + ry
    end
    local function cells(list)
        local out = {}
        for _, pair in ipairs(list) do
            local x, y = at(pair[1], pair[2])
            out[#out + 1] = { x, y }
        end
        return out
    end
    local wx, wy = at(0, -back)
    s.put(wx, wy, Art.well, LIGHT)
    s.first(cells({ { 2, -back }, { -2, -back }, { 3, -back + 1 } }), function(x, y)
        if known(Art.pole) and known(Art.flag) then
            s.put(x, y, Art.pole, NAIL)
            s.raise(x, y, Art.flag, NAIL)
        end
    end)
    local board = (side == "N" or side == "S") and Art.boardS or Art.boardE
    s.first(cells({ { -2, -back }, { -3, -back + 1 }, { -1, -back } }), function(x, y)
        s.put(x, y, board, NAIL)
    end)
    local bx, by = at(-1, -back)
    s.put(bx, by, Art.roses, FREE)
    local lx, ly = at(1, -back)
    s.put(lx, ly, Art.lavender, FREE)
    local flowers = { Art.poppies, Art.roses, Art.lavender, Art.poppies }
    local index = 0
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            index = index + 1
            local px, py = at(sx * back, sy * back)
            s.put(px, py, flowers[index], FREE)
        end
    end
end

local stallEnds = { Art.drum, Art.barrelWater, Art.carton, Art.crate }

local function marketScene(project, s)
    local count = math.floor((project.w + 1) / 4)
    local shift = (math.abs(project.x) + math.abs(project.y)) % 2
    for index = 0, count - 1 do
        local x0, y0 = project.x + index * 4, project.y
        local awning = Art.awning[(index + shift) % 2 + 1]
        s.cover(x0 + 1, y0, awning, CLOTH)
        s.cover(x0 + 2, y0, awning, CLOTH)
        s.put(x0 + 1, y0 + 2, Art.counter, LIGHT)
        s.put(x0 + 2, y0 + 2, Art.counter, LIGHT)
        s.put(x0 + 3, y0 + 2, stallEnds[(index + shift) % #stallEnds + 1], LIGHT)
        s.put(x0 + 2, y0 + 3, Art.sign, NAIL)
    end
end

local function wellScene(project, s)
    local x, y = project.x, project.y
    s.put(x, y + 1, Art.crate, LIGHT)
    s.put(x + 4, y + 1, Art.rainBarrel, LIGHT)
    s.put(x, y + 3, Art.roses, FREE)
    s.put(x + 3, y + 4, Art.lavender, FREE)
    s.put(x + 2, y + 3, Art.sign, NAIL)
    s.put(x + 4, y + 2, Art.poppies, FREE)
end

local function gardenScene(project, s)
    local x, y = project.x, project.y
    s.put(x + 3, y + 3, Art.scarecrow, NAIL)
    s.put(x, y + 1, Art.rainBarrel, LIGHT)
    s.put(x, y + 2, Art.barrelWater, LIGHT)
    s.put(x + 6, y + 1, Art.compost[1], LIGHT)
    s.put(x + 6, y + 2, Art.compost[2], LIGHT)
    s.put(x, y + 4, Art.hay[1], NAIL)
    s.put(x, y + 5, Art.hay[2], NAIL)
    s.put(x + 6, y + 4, Art.roses, FREE)
    s.put(x + 4, y + 5, Art.poppies, FREE)
end

local function memorialScene(project, s)
    local x, y = project.x, project.y
    s.put(x, y + 1, Art.skullCowW, NAIL)
    s.put(x + 5, y + 1, Art.skullDoeE, NAIL)
    s.put(x, y + 4, Art.skullStag, NAIL)
    s.put(x + 5, y + 4, Art.skullPig, NAIL)
    s.put(x + 3, y, Art.sign, NAIL)
    s.put(x + 2, y + 2, Art.candle[1], FREE)
    s.put(x + 3, y + 3, Art.candle[2], FREE)
    s.put(x + 1, y + 1, Art.poppies, FREE)
    s.put(x + 4, y + 1, Art.lavender, FREE)
    s.put(x + 1, y + 4, Art.roses, FREE)
    s.put(x + 4, y + 4, Art.poppies, FREE)
end

local scenes = {
    market = marketScene,
    plaza = plazaScene,
    well = wellScene,
    garden = gardenScene,
    memorial = memorialScene,
}

local cache = {}
local cacheSize = 0

local function signature(kind, project)
    return kind .. ":" .. project.x .. ":" .. project.y .. ":" .. project.w .. ":" .. project.h .. ":"
        .. tostring(project.fx) .. ":" .. tostring(project.fy) .. ":" .. tostring(project.radius) .. ":" .. tostring(project.gate)
end

function Scenery.ops(kind, project, stages, original)
    local id = signature(kind, project)
    local found = cache[id]
    if found ~= nil then return found end
    local taken, zone
    if kind == "plaza" and project.fx ~= nil and project.radius ~= nil then
        taken, zone = plazaGround(project, original)
    else
        taken = claimedCells(stages)
    end
    local s = scene(project, taken, zone)
    scenes[kind](project, s)
    if cacheSize >= 400 then
        cache = {}
        cacheSize = 0
    end
    cache[id] = s.ops
    cacheSize = cacheSize + 1
    return s.ops
end

local function attach(stages, ops)
    if #ops == 0 then return stages end
    local last = stages[#stages]
    if last ~= nil and last.id == "furnish" then
        for _, op in ipairs(ops) do last.ops[#last.ops + 1] = op end
    else
        local copy = {}
        for index, op in ipairs(ops) do copy[index] = op end
        stages[#stages + 1] = { id = "furnish", ops = copy }
    end
    return stages
end

local function wrap(kind)
    local def = Bp.kinds[kind]
    if def == nil or def.build == nil or def.sceneryBuild ~= nil then return end
    local original = def.build
    def.sceneryBuild = original
    def.build = function(project)
        local stages = original(project)
        local ok, ops = pcall(Scenery.ops, kind, project, stages, original)
        if not ok or type(ops) ~= "table" then return stages end
        return attach(stages, ops)
    end
end

for _, kind in ipairs(Scenery.kinds) do wrap(kind) end

local function frontageUsable(x, y, z)
    local W, P = ALifeCamp.World, ALifeCamp.Place
    local sq = W and W.square and W.square(x, y, z) or nil
    if sq == nil then return true end
    if W.isWaterSquare and W.isWaterSquare(sq) then return false end
    if P and P.blocked and P.blocked(x, y, z) then return false end
    local clear = true
    pcall(function()
        local floor = sq.getFloor and sq:getFloor() or nil
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            local tag = W.tag(o)
            if type(tag) == "table" and (tag.kind == "built" or tag.kind == "crop" or tag.kind == "storage") and o ~= floor then
                clear = false
                return
            end
        end
    end)
    return clear
end

local function frontageOps(project)
    local ops = {}
    local x1, y1 = project.x, project.y
    local x2, y2 = project.x + project.w, project.y + project.h
    local z = project.z or 0
    local door = project.door or "S"
    local style = frontageStyles[project.kind] or DEFAULT_STYLE
    local foot = {}
    for x = x1, x2 do for y = y1, y2 do foot[key(x, y)] = true end end
    local rx1, ry1, rx2, ry2 = x1 - 1, y1 - 1, x2 + 1, y2 + 1
    local ring = {}
    for x = rx1, rx2 do ring[#ring + 1] = { x, ry1, "N" } ring[#ring + 1] = { x, ry2, "S" } end
    for y = y1, y2 do ring[#ring + 1] = { rx1, y, "W" } ring[#ring + 1] = { rx2, y, "E" } end
    local function allowed(x, y, side)
        if foot[key(x, y)] then return false end
        if side == door then return false end
        return frontageUsable(x, y, z)
    end
    local n, lamps = 0, 0
    if style.fence ~= nil then
        for _, c in ipairs(ring) do
            local cx, cy, side = c[1], c[2], c[3]
            local corner = (cx == rx1 or cx == rx2) and (cy == ry1 or cy == ry2)
            local along = (side == "N" or side == "S") and (cx - rx1) or (cy - ry1)
            local span = (side == "N" or side == "S") and (rx2 - rx1) or (ry2 - ry1)
            local gap = style.gap and side == door and along == math.floor(span / 2)
            if not foot[key(cx, cy)] and not gap and frontageUsable(cx, cy, z) then
                n = n + 1
                ops[#ops + 1] = { t = "piece", e = style.fence, x = cx, y = cy, z = 0,
                    north = (side == "N" or side == "S"), corner = true, slot = Scenery.prefix .. "FN" .. n }
            end
        end
        if known(style.accent) then
            ops[#ops + 1] = { t = "prop", e = FREE, sprite = style.accent, x = x1, y = y1, z = 0, slot = Scenery.prefix .. "FA" }
        end
        return ops
    end
    for i, c in ipairs(ring) do
        local cx, cy, side = c[1], c[2], c[3]
        if allowed(cx, cy, side) then
            local along = (side == "N" or side == "S") and (cx - rx1) or (cy - ry1)
            local corner = (cx == rx1 or cx == rx2) and (cy == ry1 or cy == ry2)
            local roll = (math.abs(cx * 374761 + cy * 668265)) % style.mod
            local sprite, cost = nil, style.cost
            if corner and lamps < 2 and known(style.corner) then
                sprite, cost, lamps = style.corner, LIGHT, lamps + 1
            elseif corner and style.flank ~= nil then
                sprite = style.flank
            elseif not style.tidy and along % 4 == 2 then
                sprite = nil
            elseif roll < style.fill then
                sprite = style.edge[(i % #style.edge) + 1]
            elseif roll == style.fill then
                sprite = style.accent
            end
            if sprite ~= nil and known(sprite) then
                n = n + 1
                ops[#ops + 1] = { t = "prop", e = cost, sprite = sprite, x = cx, y = cy, z = 0, slot = Scenery.prefix .. "F" .. n }
            end
        end
    end
    return ops
end

Scenery.frontageKinds = {}

local function wrapFrontage(kind)
    local def = Bp.kinds[kind]
    if def == nil or def.build == nil or def.frontageBuild ~= nil then return end
    def.frontageBuild = def.build
    local original = def.build
    def.build = function(project)
        local stages = original(project)
        local ok, ops = pcall(frontageOps, project)
        if ok and type(ops) == "table" then return attach(stages, ops) end
        return stages
    end
end

local EXTRA_FRONTAGE = {
    "canteen", "infirmary", "forge", "powerhouse", "barracks", "guardhouse", "vault", "garage",
    "greenhouse", "farm", "garden", "tents", "motorpool", "bay", "range", "post", "workyard",
}
local frontageSeen = {}
for kind in pairs(Bp.buildingKinds) do
    if not frontageSeen[kind] then frontageSeen[kind] = true Scenery.frontageKinds[#Scenery.frontageKinds + 1] = kind end
end
for _, kind in ipairs(EXTRA_FRONTAGE) do
    if not frontageSeen[kind] then frontageSeen[kind] = true Scenery.frontageKinds[#Scenery.frontageKinds + 1] = kind end
end
table.sort(Scenery.frontageKinds)
for _, kind in ipairs(Scenery.frontageKinds) do wrapFrontage(kind) end

function Scenery.decorated(project)
    if project.status ~= "done" then return false end
    if project.scenic ~= nil then return project.scenic end
    local found = false
    for slot in pairs(project.done or {}) do
        if string.find(slot, "/" .. Scenery.prefix, 1, true) ~= nil then
            found = true
            break
        end
    end
    project.scenic = found
    return found
end

function Scenery.counts(camp)
    local markets, memorials, gardens = 0, 0, 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status == "done" and not project.retired then
            if project.kind == "market" then
                markets = markets + 1
            elseif project.kind == "memorial" and Scenery.decorated(project) then
                memorials = memorials + 1
            elseif project.kind == "garden" and Scenery.decorated(project) then
                gardens = gardens + 1
            end
        end
    end
    return markets, memorials, gardens
end

function Scenery.morale(camp)
    local markets, memorials = Scenery.counts(camp)
    return math.min(Scenery.moraleCap, markets + memorials)
end

function Scenery.farm(camp)
    local _, _, gardens = Scenery.counts(camp)
    if gardens > 0 then return Scenery.farmFactor end
    return 1
end

Hooks.add("morale", function(camp) return Scenery.morale(camp) end)
Hooks.add("farm", function(camp) return Scenery.farm(camp) end)

Hooks.add("overview", function(camp)
    local mood = Scenery.morale(camp)
    local farm = Scenery.farm(camp)
    if mood <= 0 and farm <= 1 then return {} end
    local percent = math.floor((farm - 1) * 100 + 0.5)
    return { Hooks.line(T("Scenery_Overview", tostring(mood), tostring(percent)), 0.85, 0.8, 0.95) }
end)

local lastHour = {}

Hooks.add("minute", function(camp)
    local hour = math.floor(Store.hours())
    if lastHour[camp.id] == hour then return end
    lastHour[camp.id] = hour
    local markets, memorials, gardens = Scenery.counts(camp)
    print("[ALifeCamp:Scenery] markets=" .. markets .. " memorials=" .. memorials .. " gardens=" .. gardens
        .. " morale=" .. Scenery.morale(camp) .. " farm=" .. Scenery.farm(camp))
end)

return Scenery
