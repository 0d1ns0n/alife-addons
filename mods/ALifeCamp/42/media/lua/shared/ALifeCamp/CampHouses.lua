require "ALifeCamp/CampEntities"

ALifeCamp = ALifeCamp or {}

local Entities = ALifeCamp.Entities

local Houses = {}
ALifeCamp.Houses = Houses

local knownSprites = {}
local function known(name)
    if name == nil then return false end
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end
Houses.known = known

Houses.palettes = {
    { name = "White", sheet = "walls_exterior_house_01", base = 32, window = 40, door = 42, roof = "02", gable = "03" },
    { name = "Blue", sheet = "walls_exterior_house_02", base = 20, window = 28, door = 30, roof = "01", gable = "06" },
    { name = "Beige", sheet = "walls_exterior_house_02", base = 32, window = 40, door = 42, roof = "10", gable = "12" },
    { name = "Rose", sheet = "walls_exterior_house_02", base = 68, window = 76, door = 78, roof = "09", gable = "09" },
    { name = "Green", sheet = "walls_exterior_house_02", base = 80, window = 88, door = 90, roof = "08", gable = "08" },
    { name = "Brown", sheet = "walls_exterior_house_01", base = 48, window = 56, door = 58, roof = "05", gable = "10" },
    { name = "BrickOrange", sheet = "walls_exterior_house_01", base = 16, window = 24, door = 26, roof = "01", gable = "04", brick = true },
    { name = "BrickRed", sheet = "walls_exterior_house_01", base = 4, window = 12, door = 14, roof = "02", gable = "04", brick = true },
    { name = "BrickWorn", sheet = "walls_exterior_house_01", base = 20, window = 28, door = 30, roof = "10", gable = "04", brick = true },
    { name = "BrickDark", sheet = "walls_exterior_house_01", base = 52, window = 60, door = 62, roof = "01", gable = "04", brick = true },
    { name = "BrickGrey", sheet = "walls_exterior_house_02", base = 0, window = 8, door = 10, roof = "01", gable = "04", brick = true },
    { name = "BrickTan", sheet = "walls_exterior_house_02", base = 4, window = 12, door = 14, roof = "02", gable = "04", brick = true },
    { name = "BrickMauve", sheet = "walls_exterior_house_02", base = 16, window = 24, door = 26, roof = "10", gable = "04", brick = true },
}

local function tile(palette, number)
    return palette.sheet .. "_" .. number
end

local function register(palette)
    local wall = "House" .. palette.name .. "Wall"
    local door = "House" .. palette.name .. "Door"
    local window = "House" .. palette.name .. "Window"
    local corner = tile(palette, palette.base + 3)
    Entities[wall] = { id = wall, category = "walls", faces = { W = { { tile(palette, palette.base) } }, N = { { tile(palette, palette.base + 1) } } },
        health = 450, skill = 20, corner = corner, breakSound = "ZombieThumpWoodCollapse", time = 200,
        inputs = { { n = 2, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } } } }
    Entities[door] = { id = door, category = "walls", faces = { W = { { tile(palette, palette.door) } }, N = { { tile(palette, palette.door + 1) } } },
        skill = 300, corner = corner, thumpable = false, time = 200,
        inputs = { { n = 4, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } } } }
    Entities[window] = { id = window, category = "walls", faces = { W = { { tile(palette, palette.window) } }, N = { { tile(palette, palette.window + 1) } } },
        health = 450, skill = 20, corner = corner, time = 200,
        inputs = { { n = 2, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } } } }
    palette.wallId, palette.doorId, palette.windowId = wall, door, window
end

for _, palette in ipairs(Houses.palettes) do register(palette) end

Houses.interiors = {
    { name = "IntA", sheet = "walls_interior_house_01" },
    { name = "IntB", sheet = "walls_interior_house_02" },
    { name = "IntC", sheet = "walls_interior_house_04" },
}

local function registerInterior(it)
    local wall = "House" .. it.name .. "Wall"
    local door = "House" .. it.name .. "Door"
    Entities[wall] = { id = wall, category = "walls", faces = { W = { { it.sheet .. "_0" } }, N = { { it.sheet .. "_1" } } },
        health = 300, skill = 20, corner = it.sheet .. "_3", breakSound = "ZombieThumpWoodCollapse", time = 150,
        inputs = { { n = 2, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } } } }
    Entities[door] = { id = door, category = "walls", faces = { W = { { it.sheet .. "_10" } }, N = { { it.sheet .. "_11" } } },
        skill = 300, thumpable = false, time = 150,
        inputs = { { n = 4, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } } } }
    it.wallId, it.doorId = wall, door
end

for _, it in ipairs(Houses.interiors) do registerInterior(it) end

Entities.HouseBathWall = { id = "HouseBathWall", category = "walls", faces = { W = { { "walls_interior_bathroom_01_0" } }, N = { { "walls_interior_bathroom_01_1" } } },
    health = 300, skill = 20, corner = "walls_interior_bathroom_01_3", breakSound = "ZombieThumpWoodCollapse", time = 150,
    inputs = { { n = 2, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } } } }
Entities.HouseBathDoor = { id = "HouseBathDoor", category = "walls", faces = { W = { { "walls_interior_bathroom_01_10" } }, N = { { "walls_interior_bathroom_01_11" } } },
    skill = 300, thumpable = false, time = 150,
    inputs = { { n = 4, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } } } }
Entities.HouseGarageDoor = { id = "HouseGarageDoor", category = "walls", faces = { W = { { "walls_garage_01_0" } }, N = { { "walls_garage_01_3" } } },
    health = 500, skill = 20, breakSound = "ZombieThumpMetal", time = 200,
    inputs = { { n = 4, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } }, { n = 1, t = { "Base.SheetMetal" } } } }

function Houses.count()
    return #Houses.palettes
end

function Houses.pick(project)
    local id = tonumber(project and project.id) or 0
    return (id % #Houses.palettes) + 1
end

function Houses.pickInterior(project)
    local id = tonumber(project and project.id) or 0
    return (id % #Houses.interiors) + 1
end

function Houses.entities(project)
    local index = tonumber(project and project.palette)
    if index == nil or Houses.palettes[index] == nil then return nil end
    local palette = Houses.palettes[index]
    return palette.wallId, palette.doorId, palette.windowId
end

Houses.roofAlong = {
    RY = { [4] = { 29, 28, 1, 0 }, [5] = { 29, 28, 98, 1, 0 }, [6] = { 29, 28, 27, 2, 1, 0 }, [7] = { 29, 28, 27, 99, 2, 1, 0 }, [8] = { 29, 28, 27, 26, 3, 2, 1, 0 } },
    GY = { [4] = { 13, 12, 1, 0 }, [5] = { 13, 12, 34, 1, 0 }, [6] = { 13, 12, 11, 2, 1, 0 }, [7] = { 13, 12, 11, 35, 2, 1, 0 }, [8] = { 13, 12, 11, 10, 3, 2, 1, 0 } },
    RX = { [4] = { 16, 17, 12, 13 }, [5] = { 16, 17, 107, 12, 13 }, [6] = { 16, 17, 18, 11, 12, 13 }, [7] = { 16, 17, 18, 106, 11, 12, 13 }, [8] = { 16, 17, 18, 19, 10, 11, 12, 13 } },
    GX = { [4] = { 16, 17, 28, 29 }, [5] = { 16, 17, 42, 28, 29 }, [6] = { 16, 17, 18, 27, 28, 29 }, [7] = { 16, 17, 18, 43, 27, 28, 29 }, [8] = { 16, 17, 18, 19, 26, 27, 28, 29 } },
}

local gableCost = { nails = 1 }
local noCost = {}

local function ridgeAxis(w, h)
    local R = Houses.roofAlong
    local alongX, alongY = R.RY[h] ~= nil, R.RX[w] ~= nil
    if w >= h and alongX then return "X" end
    if h > w and alongY then return "Y" end
    if alongX then return "X" end
    if alongY then return "Y" end
    return nil
end

function Houses.roofOps(project)
    local index = tonumber(project and project.palette)
    local palette = index ~= nil and Houses.palettes[index] or nil
    local w, h = tonumber(project and project.w), tonumber(project and project.h)
    if palette == nil or w == nil or h == nil then return nil end
    local axis = ridgeAxis(w, h)
    if axis == nil then return nil end
    local R = Houses.roofAlong
    local ops = {}
    local function put(sprite, dx, dy, tag, cost)
        local op = { t = tag == "R" and "roof" or "prop", sprite = sprite, x = project.x + dx, y = project.y + dy, z = 1, slot = tag .. ":" .. dx .. ":" .. dy }
        if tag ~= "R" then op.cost = cost end
        ops[#ops + 1] = op
    end
    local roofSheet = "roofs_30_" .. palette.roof .. "_"
    local gableSheet = "walls_exterior_roofs_30_" .. palette.gable .. "_"
    local accentSheet = "roofs_accents_30_01_"
    for dx = 0, w - 1 do
        for dy = 0, h - 1 do
            put(roofSheet .. (axis == "X" and R.RY[h][dy + 1] or R.RX[w][dx + 1]), dx, dy, "R")
        end
    end
    if axis == "X" then
        for _, dx in ipairs({ 0, w }) do
            for dy = 0, h - 1 do
                put(gableSheet .. R.GY[h][dy + 1], dx, dy, "G", gableCost)
                put(accentSheet .. R.GY[h][dy + 1], dx, dy, "A", noCost)
            end
        end
    else
        for _, dy in ipairs({ 0, h }) do
            for dx = 0, w - 1 do
                put(gableSheet .. R.GX[w][dx + 1], dx, dy, "G", gableCost)
                put(accentSheet .. R.GX[w][dx + 1], dx, dy, "A", noCost)
            end
        end
    end
    return ops
end

local function blockRoofOps(ops, palette, blocks, px, py, rz)
    local R = Houses.roofAlong
    rz = rz or 1
    local owner = {}
    local axes = {}
    for bi, b in ipairs(blocks) do
        local axis = b.axis or ridgeAxis(b.w, b.h)
        if axis == "X" and R.RY[b.h] == nil then axis = nil end
        if axis == "Y" and R.RX[b.w] == nil then axis = nil end
        axes[bi] = axis
        if axis ~= nil then
            local roofSheet = "roofs_30_" .. palette.roof .. "_"
            for dx = 0, b.w - 1 do
                for dy = 0, b.h - 1 do
                    local idx = axis == "X" and R.RY[b.h][dy + 1] or R.RX[b.w][dx + 1]
                    local gx, gy = px + b.x + dx, py + b.y + dy
                    owner[gx .. ":" .. gy] = bi
                    local sprite = roofSheet .. idx
                    if known(sprite) then
                        ops[#ops + 1] = { t = "roof", sprite = sprite, x = gx, y = gy, z = rz, slot = "R" .. bi .. ":" .. dx .. ":" .. dy }
                    end
                end
            end
        end
    end
    for bi, b in ipairs(blocks) do
        local axis = axes[bi]
        if axis ~= nil then
            local gableSheet = "walls_exterior_roofs_30_" .. palette.gable .. "_"
            local accentSheet = "roofs_accents_30_01_"
            local placed = {}
            local function gab(dx, dy, idx)
                local gx, gy = px + b.x + dx, py + b.y + dy
                local ck = gx .. ":" .. gy
                if placed[ck] then return end
                placed[ck] = true
                if owner[ck] ~= nil and owner[ck] ~= bi then return end
                local gs, ac = gableSheet .. idx, accentSheet .. idx
                if known(gs) then ops[#ops + 1] = { t = "prop", sprite = gs, x = gx, y = gy, z = rz, slot = "G" .. bi .. ":" .. dx .. ":" .. dy, cost = gableCost } end
                if known(ac) then ops[#ops + 1] = { t = "prop", sprite = ac, x = gx, y = gy, z = rz, slot = "A" .. bi .. ":" .. dx .. ":" .. dy, cost = noCost } end
            end
            if axis == "X" then
                for _, dx in ipairs({ 0, b.w }) do
                    for dy = 0, b.h - 1 do gab(dx, dy, R.GY[b.h][dy + 1]) end
                end
            else
                for _, dy in ipairs({ 0, b.h }) do
                    for dx = 0, b.w - 1 do gab(dx, dy, R.GX[b.w][dx + 1]) end
                end
            end
        end
    end
end

local F_LIGHT = { planks = 1, nails = 1 }
local F_HEAVY = { planks = 2, nails = 2 }
local F_BED = { planks = 2, nails = 1 }
local F_APPL = { planks = 1, nails = 2, metal = 1 }
local F_DECO = { nails = 2 }
local F_PAVE = { planks = 1, nails = 1 }

local WINDOW_GLASS = { N = "fixtures_windows_01_11", W = "fixtures_windows_01_10" }
local WINDOW_FALLBACK = { N = "fixtures_windows_01_1", W = "fixtures_windows_01_0" }
local SHUTTER_SHEET = "fixtures_windows_detailing_01_"
local SHUTTER_SIDE = { N = { 18, 19 }, W = { 16, 17 } }
local SHUTTER_COST = { nails = 1 }
local UPPER_FLOOR = "floors_interior_tilesandwood_01_40"

local function newBuilder()
    local D = { blocks = {}, rooms = {}, yard = {}, openType = {}, parts = {}, props = {}, skylights = {}, defaultFloor = "carpentry_02_58", stories = 1 }
    local function okey(x, y, side)
        if side == "N" then return "N:" .. x .. ":" .. y end
        if side == "S" then return "N:" .. x .. ":" .. (y + 1) end
        if side == "W" then return "W:" .. x .. ":" .. y end
        return "W:" .. (x + 1) .. ":" .. y
    end
    local function epos(x, y, side)
        if side == "N" then return x, y, true end
        if side == "S" then return x, y + 1, true end
        if side == "W" then return x, y, false end
        return x + 1, y, false
    end
    function D.block(x, y, w, h, axis) D.blocks[#D.blocks + 1] = { x = x, y = y, w = w, h = h, axis = axis } end
    function D.floors(n) D.stories = n end
    function D.floor(f) D.defaultFloor = f end
    function D.room(x, y, w, h, f) D.rooms[#D.rooms + 1] = { x = x, y = y, w = w, h = h, floor = f } end
    function D.pave(x, y, s) D.yard[#D.yard + 1] = { x = x, y = y, sprite = s } end
    function D.open(x, y, side, typ) D.openType[okey(x, y, side)] = typ end
    function D.part(x, y, side, door, bath)
        local ex, ey, north = epos(x, y, side)
        D.parts[#D.parts + 1] = { key = (north and "N:" or "W:") .. ex .. ":" .. ey, x = ex, y = ey, north = north, door = door, bath = bath }
    end
    function D.prop(x, y, sprite, cost, z) D.props[#D.props + 1] = { x = x, y = y, sprite = sprite, cost = cost, z = z } end
    function D.cont(x, y, sprite, cost, container) D.props[#D.props + 1] = { x = x, y = y, sprite = sprite, cost = cost, container = container } end
    function D.skylight(x, y) D.skylights[#D.skylights + 1] = { x = x, y = y } end
    return D
end

local function vindex(project, n)
    local id = tonumber(project and project.id) or 0
    return (id % n) + 1
end

local function vpick(project, n, salt)
    local id = (tonumber(project and project.id) or 0) + (tonumber(project and project.palette) or 0) + (salt or 0)
    if id < 0 then id = -id end
    return (id % n) + 1
end

local DT = {
    canopy = { S = "walls_decoration_01_116", N = "walls_decoration_01_117", E = "walls_decoration_01_116", W = "walls_decoration_01_117" },
    wallLamp = { S = "lighting_outdoor_01_25", N = "lighting_outdoor_01_24", E = "lighting_outdoor_01_24", W = "lighting_outdoor_01_25" },
    mailbox = "street_decoration_01_19",
    streetLamp = "lighting_outdoor_01_0",
    porchColumn = "fixtures_railings_01_79",
    porchRail = "fixtures_railings_01_65",
    bush = "vegetation_ornamental_01_9",
    conifer = "vegetation_ornamental_01_8",
    flower = { "vegetation_ornamental_01_16", "vegetation_ornamental_01_17", "vegetation_ornamental_01_19" },
    path = "floors_exterior_tilesandstone_01_0",
    apron = "floors_exterior_street_01_1",
}

local Y_PAVE = { planks = 1, nails = 1 }
local Y_DECO = { nails = 2 }

local FLOWER_SETS = {
    { "vegetation_ornamental_01_16", "vegetation_ornamental_01_17" },
    { "vegetation_ornamental_01_17", "vegetation_ornamental_01_19" },
    { "vegetation_ornamental_01_19", "vegetation_ornamental_01_16" },
    { "vegetation_ornamental_01_9", "vegetation_ornamental_01_16" },
}

local function addDetails(project, palette, D, occ, hull, foundation, finish)
    local px, py = project.x, project.y
    local yardSet, usedProp = {}, {}
    for _, yt in ipairs(D.yard) do yardSet[yt.x .. ":" .. yt.y] = true end
    local function freeFloor(x, y) return not occ[x .. ":" .. y] and not yardSet[x .. ":" .. y] end
    local function pave(x, y, sprite)
        if not freeFloor(x, y) or not known(sprite) then return end
        yardSet[x .. ":" .. y] = true
        foundation[#foundation + 1] = { t = "floor", e = "WoodFloorLvl1", sprite = sprite, x = px + x, y = py + y, z = 0, slot = "YD:" .. x .. ":" .. y }
    end
    local function plantProp(x, y, sprite, cost, z)
        if occ[x .. ":" .. y] or usedProp[x .. ":" .. y .. ":" .. (z or 0)] then return end
        if not known(sprite) then return end
        usedProp[x .. ":" .. y .. ":" .. (z or 0)] = true
        finish[#finish + 1] = { t = "prop", sprite = sprite, x = px + x, y = py + y, z = z or 0, slot = "YP:" .. x .. ":" .. y .. ":" .. (z or 0), cost = cost or Y_DECO }
    end
    local function overlay(x, y, sprite, cost)
        if not known(sprite) then return end
        finish[#finish + 1] = { t = "prop", sprite = sprite, x = px + x, y = py + y, z = 0, slot = "YO:" .. x .. ":" .. y .. ":" .. (#finish + 1), cost = cost or Y_DECO }
    end
    local doors = {}
    for _, e in ipairs(hull) do
        local key = (e.north and "N:" or "W:") .. e.x .. ":" .. e.y
        if D.openType[key] == "door" then
            local ix, iy, ox, oy, side
            if e.north then
                if occ[e.x .. ":" .. (e.y - 1)] then ix, iy, ox, oy, side = e.x, e.y - 1, e.x, e.y, "S"
                else ix, iy, ox, oy, side = e.x, e.y, e.x, e.y - 1, "N" end
            else
                if occ[(e.x - 1) .. ":" .. e.y] then ix, iy, ox, oy, side = e.x - 1, e.y, e.x, e.y, "E"
                else ix, iy, ox, oy, side = e.x, e.y, e.x - 1, e.y, "W" end
            end
            doors[#doors + 1] = { ix = ix, iy = iy, ox = ox, oy = oy, side = side, e = e }
        end
    end
    local fset = FLOWER_SETS[vpick(project, #FLOWER_SETS, 0)]
    local wantMailbox = vpick(project, 2, 1) == 1
    local wantStreetLamp = vpick(project, 3, 2) ~= 1
    local wantRails = vpick(project, 4, 3) ~= 1
    for di, d in ipairs(doors) do
        local dxp, dyp = d.ox - d.ix, d.oy - d.iy
        local perpx, perpy = dyp, dxp
        overlay(d.ox, d.oy, DT.canopy[d.side], Y_DECO)
        if di == 1 then
            for k = 1, 3 do pave(d.ix + dxp * k, d.iy + dyp * k, DT.path) end
            pave(d.ix + dxp + perpx, d.iy + dyp + perpy, DT.path)
            local wx, wy = d.ox + perpx, d.oy + perpy
            overlay(wx, wy, DT.wallLamp[d.side], Y_DECO)
            plantProp(d.ox - perpx, d.oy - perpy, DT.porchColumn, Y_DECO)
            if wantRails then
                plantProp(d.ox - perpx + dxp, d.oy - perpy + dyp, DT.porchRail, Y_DECO)
                plantProp(d.ox + perpx + dxp, d.oy + perpy + dyp, DT.porchRail, Y_DECO)
            end
            if wantMailbox then
                plantProp(d.ix + dxp * 3 + perpx * 2, d.iy + dyp * 3 + perpy * 2, DT.mailbox, Y_DECO)
            end
            if wantStreetLamp then
                plantProp(d.ix + dxp * 3 - perpx * 2, d.iy + dyp * 3 - perpy * 2, DT.streetLamp, Y_DECO)
            end
            plantProp(d.ix + dxp + perpx * 2, d.iy + dyp + perpy * 2, fset[1], Y_DECO)
            plantProp(d.ix + dxp - perpx * 2, d.iy + dyp - perpy * 2, fset[2], Y_DECO)
        else
            local wx, wy = d.ox + (d.oy - d.iy), d.oy + (d.ox - d.ix)
            overlay(wx, wy, DT.wallLamp[d.side], Y_DECO)
        end
    end
    local minx, maxx, miny, maxy = 1e9, -1e9, 1e9, -1e9
    for _, b in ipairs(D.blocks) do
        if b.x < minx then minx = b.x end
        if b.x + b.w - 1 > maxx then maxx = b.x + b.w - 1 end
        if b.y < miny then miny = b.y end
        if b.y + b.h - 1 > maxy then maxy = b.y + b.h - 1 end
    end
    for x = minx, maxx do
        if occ[x .. ":" .. maxy] then pave(x, maxy + 1, DT.apron) end
    end
    local shrubs = vpick(project, 3, 4)
    if shrubs ~= 1 then plantProp(minx - 1, maxy + 1, DT.bush, Y_DECO) end
    if shrubs ~= 2 then plantProp(maxx + 1, maxy + 1, DT.conifer, Y_DECO) end
    if shrubs ~= 3 then plantProp(minx - 1, maxy, DT.bush, Y_DECO) end
    plantProp(maxx + 1, maxy, DT.conifer, Y_DECO)
end

local GLASS_SKY = { nails = 2 }

local function addSkylights(project, D, finish, rz)
    local R = Houses.roofAlong
    rz = rz or 1
    local px, py = project.x, project.y
    for _, c in ipairs(D.skylights) do
        for _, b in ipairs(D.blocks) do
            if c.x >= b.x and c.x < b.x + b.w and c.y >= b.y and c.y < b.y + b.h then
                local axis = b.axis or ridgeAxis(b.w, b.h)
                if axis == "X" and R.RY[b.h] == nil then axis = nil end
                if axis == "Y" and R.RX[b.w] == nil then axis = nil end
                if axis ~= nil then
                    local dx, dy = c.x - b.x, c.y - b.y
                    local idx = axis == "X" and R.RY[b.h][dy + 1] or R.RX[b.w][dx + 1]
                    if idx ~= nil then
                        local sprite = "roofs_30_04_" .. idx
                        if known(sprite) then
                            finish[#finish + 1] = { t = "prop", sprite = sprite, x = px + c.x, y = py + c.y, z = rz, slot = "SK:" .. c.x .. ":" .. c.y, cost = GLASS_SKY }
                        end
                    end
                end
                break
            end
        end
    end
end

local function assemble(project, palette, interior, D)
    local px, py = project.x, project.y
    local occ, cells = {}, {}
    for _, b in ipairs(D.blocks) do
        for dx = 0, b.w - 1 do
            for dy = 0, b.h - 1 do
                local k = (b.x + dx) .. ":" .. (b.y + dy)
                if not occ[k] then occ[k] = true cells[#cells + 1] = { x = b.x + dx, y = b.y + dy } end
            end
        end
    end
    local floorAt = {}
    for _, r in ipairs(D.rooms) do
        for dx = 0, r.w - 1 do
            for dy = 0, r.h - 1 do floorAt[(r.x + dx) .. ":" .. (r.y + dy)] = r.floor end
        end
    end
    local foundation = {}
    for _, c in ipairs(cells) do
        local f = floorAt[c.x .. ":" .. c.y] or D.defaultFloor
        if not known(f) then f = "carpentry_02_58" end
        foundation[#foundation + 1] = { t = "floor", e = "WoodFloorLvl1", sprite = f, x = px + c.x, y = py + c.y, z = 0, slot = "F:" .. c.x .. ":" .. c.y }
    end
    for _, yt in ipairs(D.yard) do
        local f = known(yt.sprite) and yt.sprite or "floors_exterior_street_01_0"
        foundation[#foundation + 1] = { t = "floor", e = "WoodFloorLvl1", sprite = f, x = px + yt.x, y = py + yt.y, z = 0, slot = "Y:" .. yt.x .. ":" .. yt.y }
    end
    local hull = {}
    for _, c in ipairs(cells) do
        if not occ[c.x .. ":" .. (c.y - 1)] then hull[#hull + 1] = { x = c.x, y = c.y, north = true } end
        if not occ[c.x .. ":" .. (c.y + 1)] then hull[#hull + 1] = { x = c.x, y = c.y + 1, north = true } end
        if not occ[(c.x - 1) .. ":" .. c.y] then hull[#hull + 1] = { x = c.x, y = c.y, north = false } end
        if not occ[(c.x + 1) .. ":" .. c.y] then hull[#hull + 1] = { x = c.x + 1, y = c.y, north = false } end
    end
    local frame, walls, finish = {}, {}, {}
    local function edgeKey(e) return (e.north and "N:" or "W:") .. e.x .. ":" .. e.y end
    local hullKeys = {}
    for _, e in ipairs(hull) do hullKeys[edgeKey(e)] = true end
    for _, e in ipairs(hull) do
        local key = edgeKey(e)
        local slot = "S" .. key
        frame[#frame + 1] = { t = "piece", e = "WoodenWallFrame", x = px + e.x, y = py + e.y, z = 0, north = e.north, slot = slot, corner = true }
        local typ = D.openType[key] or "wall"
        local wop = { t = "piece", x = px + e.x, y = py + e.y, z = 0, north = e.north, slot = slot, replace = true, corner = true }
        if typ == "door" then
            wop.e = palette.doorId
            wop.extra = { isDoorFrame = true }
        elseif typ == "window" then
            wop.e = palette.windowId
        elseif typ == "garage" then
            wop.e = "HouseGarageDoor"
            wop.corner = false
        else
            wop.e = palette.wallId
        end
        walls[#walls + 1] = wop
        if typ == "door" then
            finish[#finish + 1] = { t = "door", e = "HouseDoorExterior", x = px + e.x, y = py + e.y, z = 0, north = e.north, slot = "DR" .. key }
        elseif typ == "window" then
            local face = e.north and "N" or "W"
            local glass = WINDOW_GLASS[face]
            if not known(glass) then glass = WINDOW_FALLBACK[face] end
            finish[#finish + 1] = { t = "window", e = "WoodenWindowFrameLvl1", sprite = glass, x = px + e.x, y = py + e.y, z = 0, north = e.north, slot = "GL" .. key }
            local shut = SHUTTER_SIDE[face]
            for si = 1, 2 do
                local sp = SHUTTER_SHEET .. shut[si]
                if known(sp) then
                    finish[#finish + 1] = { t = "prop", sprite = sp, x = px + e.x, y = py + e.y, z = 0, north = e.north, slot = "SH" .. si .. ":" .. key, cost = SHUTTER_COST }
                end
            end
        end
    end
    for _, p in ipairs(D.parts) do
        if not hullKeys[p.key] then
        local slot = "P" .. p.key
        frame[#frame + 1] = { t = "piece", e = "WoodenWallFrame", x = px + p.x, y = py + p.y, z = 0, north = p.north, slot = slot }
        local wop = { t = "piece", x = px + p.x, y = py + p.y, z = 0, north = p.north, slot = slot, replace = true }
        if p.door then
            wop.e = p.bath and "HouseBathDoor" or interior.doorId
        elseif p.bath then
            wop.e = "HouseBathWall"
        else
            wop.e = interior.wallId
        end
        walls[#walls + 1] = wop
        if p.door then
            finish[#finish + 1] = { t = "door", e = "HouseDoorInterior", x = px + p.x, y = py + p.y, z = 0, north = p.north, slot = "PD" .. p.key }
        end
        end
    end
    local storey = tonumber(D.stories) or 1
    if storey < 1 then storey = 1 end
    local upperFloor = known(UPPER_FLOOR) and UPPER_FLOOR or "carpentry_02_58"
    for uz = 1, storey - 1 do
        for _, c in ipairs(cells) do
            foundation[#foundation + 1] = { t = "floor", e = "WoodFloorLvl1", sprite = upperFloor, x = px + c.x, y = py + c.y, z = uz, slot = "UF" .. uz .. ":" .. c.x .. ":" .. c.y }
        end
        for _, e in ipairs(hull) do
            local key = edgeKey(e)
            local slot = "U" .. uz .. key
            local typ = D.openType[key] or "wall"
            frame[#frame + 1] = { t = "piece", e = "WoodenWallFrame", x = px + e.x, y = py + e.y, z = uz, north = e.north, slot = slot, corner = true }
            local wop = { t = "piece", x = px + e.x, y = py + e.y, z = uz, north = e.north, slot = slot, replace = true, corner = true }
            if typ == "window" or typ == "door" then
                wop.e = palette.windowId
                local face = e.north and "N" or "W"
                local glass = WINDOW_GLASS[face]
                if not known(glass) then glass = WINDOW_FALLBACK[face] end
                finish[#finish + 1] = { t = "window", e = "WoodenWindowFrameLvl1", sprite = glass, x = px + e.x, y = py + e.y, z = uz, north = e.north, slot = "UG" .. uz .. key }
                local shut = SHUTTER_SIDE[face]
                for si = 1, 2 do
                    local sp = SHUTTER_SHEET .. shut[si]
                    if known(sp) then
                        finish[#finish + 1] = { t = "prop", sprite = sp, x = px + e.x, y = py + e.y, z = uz, north = e.north, slot = "US" .. uz .. si .. ":" .. key, cost = SHUTTER_COST }
                    end
                end
            else
                wop.e = palette.wallId
            end
            walls[#walls + 1] = wop
        end
    end
    local roofZ = storey
    local roof = {}
    blockRoofOps(roof, palette, D.blocks, px, py, roofZ)
    local function ckey(x, y) return x .. ":" .. y end
    local solidEdge = {}
    for _, p in ipairs(D.parts) do
        if not hullKeys[p.key] and not p.door then solidEdge[p.key] = true end
    end
    local function edgeBetween(ax, ay, bx, by)
        if bx == ax and by == ay - 1 then return "N:" .. ax .. ":" .. ay end
        if bx == ax and by == ay + 1 then return "N:" .. bx .. ":" .. by end
        if by == ay and bx == ax - 1 then return "W:" .. ax .. ":" .. ay end
        if by == ay and bx == ax + 1 then return "W:" .. bx .. ":" .. by end
        return nil
    end
    local function linked(ax, ay, bx, by)
        if not occ[ckey(bx, by)] then return false end
        local ek = edgeBetween(ax, ay, bx, by)
        if ek ~= nil and solidEdge[ek] then return false end
        return true
    end
    local entX, entY
    for _, e in ipairs(hull) do
        if D.openType[edgeKey(e)] == "door" then
            if e.north then
                if occ[ckey(e.x, e.y - 1)] then entX, entY = e.x, e.y - 1 else entX, entY = e.x, e.y end
            else
                if occ[ckey(e.x - 1, e.y)] then entX, entY = e.x - 1, e.y else entX, entY = e.x, e.y end
            end
            break
        end
    end
    local keepClear = {}
    local function keep(x, y) keepClear[ckey(x, y)] = true end
    if entX ~= nil then keep(entX, entY) end
    local doorTiles = {}
    for _, p in ipairs(D.parts) do
        if p.door and not hullKeys[p.key] then
            keep(p.x, p.y)
            if p.north then keep(p.x, p.y - 1) else keep(p.x - 1, p.y) end
            doorTiles[#doorTiles + 1] = { x = p.x, y = p.y }
        end
    end
    local parent, NB = {}, { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
    if entX ~= nil then
        parent[ckey(entX, entY)] = false
        local q, head = { { entX, entY } }, 1
        while head <= #q do
            local cx2, cy2 = q[head][1], q[head][2]
            head = head + 1
            for _, d in ipairs(NB) do
                local nx, ny = cx2 + d[1], cy2 + d[2]
                local nk = ckey(nx, ny)
                if parent[nk] == nil and linked(cx2, cy2, nx, ny) then
                    parent[nk] = { cx2, cy2 }
                    q[#q + 1] = { nx, ny }
                end
            end
        end
    end
    for _, dt in ipairs(doorTiles) do
        local x, y, k = dt.x, dt.y, ckey(dt.x, dt.y)
        while parent[k] do
            keep(x, y)
            x, y = parent[k][1], parent[k][2]
            k = ckey(x, y)
        end
        keep(x, y)
    end
    local STACK_PREFIX = {
        "floors_rugs_01_", "walls_decoration_01_", "appliances_television_01_",
        "appliances_com_01_", "fixtures_fireplaces_01_", "fixtures_windows_detailing_01_",
        "roofs_", "walls_exterior_roofs_",
    }
    local STACK_EXACT = { ["lighting_indoor_02_42"] = true }
    local USE_FRONT = {
        ["appliances_refrigeration_01_8"] = true, ["appliances_cooking_01_13"] = true,
        ["fixtures_counters_01_13"] = true, ["fixtures_sinks_01_33"] = true,
        ["fixtures_sinks_01_12"] = true, ["fixtures_bathroom_01_0"] = true,
    }
    local function hasPrefix(s, p) return string.sub(s, 1, #p) == p end
    local function classify(f)
        local s = f.sprite or ""
        if (f.z or 0) > 0 or STACK_EXACT[s] then return "stack", 9 end
        for _, p in ipairs(STACK_PREFIX) do if hasPrefix(s, p) then return "stack", 9 end end
        if USE_FRONT[s] then return "use", 1 end
        if hasPrefix(s, "furniture_bedding_") then return "block", 1 end
        if hasPrefix(s, "appliances_") or hasPrefix(s, "fixtures_") then return "block", 1 end
        if hasPrefix(s, "furniture_seating_indoor_") or hasPrefix(s, "furniture_tables_") then return "block", 2 end
        if hasPrefix(s, "furniture_storage_") or hasPrefix(s, "furniture_shelving_") then return "block", 3 end
        if hasPrefix(s, "vegetation_indoor_") or s == "lighting_indoor_02_61" then return "block", 5 end
        return "block", 3
    end
    local order = {}
    for i, f in ipairs(D.props) do
        local kind, pr = classify(f)
        order[#order + 1] = { i = i, f = f, kind = kind, pr = pr }
    end
    table.sort(order, function(a, b)
        if a.pr ~= b.pr then return a.pr < b.pr end
        return a.i < b.i
    end)
    local frontClear = {}
    for _, o in ipairs(order) do
        if o.kind == "use" then
            local fk = ckey(o.f.x, o.f.y + 1)
            if occ[fk] then frontClear[fk] = true end
        end
    end
    local taken, emit = {}, {}
    for _, o in ipairs(order) do
        local f = o.f
        local z0 = (f.z or 0) == 0
        local tk = ckey(f.x, f.y)
        local keepIt = true
        if z0 and keepClear[tk] == true then
            keepIt = false
        elseif o.kind == "stack" then
            keepIt = true
        elseif taken[tk] then
            keepIt = false
        elseif frontClear[tk] and o.pr >= 3 then
            keepIt = false
        else
            taken[tk] = true
        end
        if keepIt and known(f.sprite) then emit[o.i] = true end
    end
    for i, f in ipairs(D.props) do
        if emit[i] then
            finish[#finish + 1] = { t = "prop", sprite = f.sprite, x = px + f.x, y = py + f.y, z = f.z or 0, slot = "FP" .. i, cost = f.cost or F_LIGHT, container = f.container }
        end
    end
    local oks = pcall(addSkylights, project, D, finish, roofZ)
    if not oks then print("[ALifeCamp:Houses] skylights failed") end
    local okd = pcall(addDetails, project, palette, D, occ, hull, foundation, finish)
    if not okd then print("[ALifeCamp:Houses] details failed") end
    return {
        { id = "foundation", ops = foundation },
        { id = "frame", ops = frame },
        { id = "walls", ops = walls },
        { id = "roof", ops = roof },
        { id = "finish", ops = finish },
    }
end

local WOOD_OAK = "floors_interior_tilesandwood_01_41"
local WOOD_HARD = "floors_interior_tilesandwood_01_40"
local WOOD_BIRCH = "floors_interior_tilesandwood_01_42"
local TILE_WHITE = "floors_interior_tilesandwood_01_16"
local TILE_GREY = "floors_interior_tilesandwood_01_30"
local CARPET_BROWN = "floors_interior_carpet_01_3"
local CARPET_GREEN = "floors_interior_carpet_01_5"
local CARPET_BLUE = "floors_interior_carpet_01_0"
local CONCRETE = "floors_exterior_street_01_0"

local SOFA = {
    { 0, 1, s = "furniture_seating_indoor_01_0", e = "furniture_seating_indoor_01_1" },
    { 17, 16, s = "furniture_seating_indoor_01_17", e = "furniture_seating_indoor_01_16" },
    { 48, 49, s = "furniture_seating_indoor_02_48", e = "furniture_seating_indoor_02_49" },
}
local BEDS = {
    { "furniture_bedding_01_25", "furniture_bedding_01_27", "furniture_bedding_01_24", "furniture_bedding_01_26" },
    { "furniture_bedding_01_5", "furniture_bedding_01_7", "furniture_bedding_01_4", "furniture_bedding_01_6" },
}

local function chimney(D, project, x, y)
    local palette = Houses.palettes[tonumber(project.palette) or 1]
    local faceW, faceN
    if palette and palette.brick then
        faceW, faceN = "fixtures_fireplaces_01_12", "fixtures_fireplaces_01_13"
    else
        faceW, faceN = "fixtures_fireplaces_01_16", "fixtures_fireplaces_01_17"
    end
    D.prop(x, y, faceW, F_DECO, 1)
    D.prop(x, y, faceN, F_DECO, 1)
end

local function sofaRow(D, project, x, y)
    local set = SOFA[vindex(project, #SOFA)]
    D.prop(x, y, set.s, F_HEAVY)
    D.prop(x + 1, y, set.e, F_HEAVY)
end

local function bed2(D, project, x, y)
    local b = BEDS[vindex(project, #BEDS)]
    D.prop(x, y, b[1], F_BED)
    D.prop(x + 1, y, b[2], F_BED)
    D.prop(x, y + 1, b[3], F_BED)
    D.prop(x + 1, y + 1, b[4], F_BED)
end

local function kitchen3(D, x, y)
    D.cont(x, y, "appliances_refrigeration_01_8", F_APPL)
    D.cont(x + 1, y, "fixtures_counters_01_13", F_HEAVY, "counter")
    D.cont(x + 2, y, "fixtures_sinks_01_33", F_HEAVY)
end

local function garageKit(D, project, x, y, w, h)
    local back = { "crafted_02_0", "crafted_02_1" }
    D.prop(x, y, back[1], F_HEAVY)
    D.prop(x + 1, y, back[2], F_HEAVY)
    D.cont(x + 2, y, "location_business_machinery_01_32", F_HEAVY, "toolcabinet")
    if w >= 4 then D.cont(x + 3, y, "crafted_05_41", F_LIGHT, "shelves") end
    if h >= 2 then
        D.cont(x, y + 1, "carpentry_01_19", F_HEAVY, "crate")
        D.prop(x + 1, y + 1, "crafted_01_24", F_HEAVY)
        if w >= 4 then D.prop(x + 3, y + 1, "location_business_machinery_01_44", F_HEAVY) end
    end
    if h >= 3 then
        D.cont(x, y + 2, "carpentry_01_16", F_HEAVY, "crate")
        if w >= 4 then D.prop(x + 3, y + 2, "industry_04_20", F_HEAVY) end
    end
    D.prop(x + 1, y, "appliances_com_01_80", F_APPL, 1)
end

local function bathSet(D, toiletX, toiletY, sinkX, sinkY, tubX, tubY, tubVert)
    D.prop(toiletX, toiletY, "fixtures_bathroom_01_0", F_HEAVY)
    D.cont(sinkX, sinkY, "fixtures_sinks_01_12", F_HEAVY)
    D.prop(sinkX, sinkY, "walls_decoration_01_5", F_DECO)
    if tubVert then
        D.prop(tubX, tubY, "fixtures_bathroom_01_25", F_HEAVY)
        D.prop(tubX, tubY + 1, "fixtures_bathroom_01_24", F_HEAVY)
    else
        D.prop(tubX, tubY, "fixtures_bathroom_01_52", F_HEAVY)
        D.prop(tubX + 1, tubY, "fixtures_bathroom_01_53", F_HEAVY)
    end
end

Houses.designs = {}

Houses.designs.cabin = { size = { 4, 4 }, build = function(D, project)
    D.block(0, 0, 4, 4)
    D.floor(WOOD_OAK)
    D.room(2, 0, 2, 2, TILE_WHITE)
    D.open(1, 3, "S", "door")
    D.open(1, 0, "N", "window")
    D.open(0, 1, "W", "window")
    D.open(3, 1, "E", "window")
    D.open(3, 3, "S", "window")
    D.part(2, 0, "W", false, true)
    D.part(2, 1, "W", false, true)
    D.part(2, 1, "S", true, true)
    D.part(3, 1, "S", false, true)
    D.prop(0, 0, "furniture_bedding_01_9", F_BED)
    D.prop(0, 1, "furniture_bedding_01_8", F_BED)
    D.cont(1, 0, "furniture_storage_01_48", F_LIGHT, "sidetable")
    D.prop(1, 0, "lighting_indoor_02_42", F_LIGHT)
    D.prop(1, 2, "furniture_seating_indoor_01_12", F_HEAVY)
    D.prop(0, 2, "vegetation_indoor_01_11", F_LIGHT)
    D.cont(0, 3, "furniture_storage_01_13", F_HEAVY, "dresser")
    D.cont(3, 2, "furniture_shelving_01_42", F_LIGHT, "shelves")
    D.prop(3, 0, "fixtures_bathroom_01_0", F_HEAVY)
    D.cont(2, 0, "fixtures_sinks_01_12", F_HEAVY)
    D.prop(2, 0, "walls_decoration_01_5", F_DECO)
    D.prop(2, 1, "floors_rugs_01_51", F_LIGHT)
    D.prop(1, 3, "walls_decoration_01_116", F_DECO)
    D.prop(2, 3, "lighting_indoor_02_61", F_LIGHT)
    chimney(D, project, 0, 1)
end }

Houses.designs.cottage = { size = { 6, 5 }, build = function(D, project)
    D.block(0, 0, 6, 5)
    D.floors(2)
    D.floor(CARPET_BROWN)
    D.room(0, 0, 4, 1, WOOD_OAK)
    D.room(4, 0, 2, 2, CARPET_GREEN)
    D.room(4, 2, 2, 3, TILE_WHITE)
    D.open(2, 4, "S", "door")
    D.open(1, 0, "N", "window")
    D.open(0, 2, "W", "window")
    D.open(5, 0, "N", "window")
    D.open(5, 3, "E", "window")
    D.open(0, 4, "S", "window")
    D.open(4, 4, "S", "window")
    for y = 0, 4 do
        local door = (y == 0 or y == 3)
        D.part(4, y, "W", door, y >= 2)
    end
    for x = 4, 5 do D.part(x, 2, "N", false, true) end
    kitchen3(D, 0, 0)
    D.cont(3, 0, "appliances_cooking_01_13", F_APPL)
    sofaRow(D, project, 0, 2)
    D.prop(0, 3, "furniture_tables_low_01_14", F_LIGHT)
    D.prop(1, 3, "furniture_tables_low_01_15", F_LIGHT)
    D.prop(3, 3, "furniture_seating_indoor_01_13", F_HEAVY)
    D.cont(3, 1, "furniture_storage_01_44", F_HEAVY, "crate")
    D.prop(3, 1, "appliances_television_01_2", F_APPL)
    D.cont(0, 1, "furniture_shelving_01_42", F_LIGHT, "shelves")
    D.prop(2, 3, "vegetation_indoor_01_11", F_LIGHT)
    D.prop(1, 2, "floors_rugs_01_72", F_LIGHT)
    D.prop(2, 2, "floors_rugs_01_73", F_LIGHT)
    D.prop(4, 0, "furniture_bedding_01_25", F_BED)
    D.prop(5, 0, "furniture_bedding_01_27", F_BED)
    D.prop(4, 1, "furniture_bedding_01_24", F_BED)
    D.prop(5, 1, "furniture_bedding_01_26", F_BED)
    D.prop(4, 4, "fixtures_bathroom_01_0", F_HEAVY)
    D.cont(4, 2, "fixtures_sinks_01_12", F_HEAVY)
    D.prop(4, 2, "walls_decoration_01_5", F_DECO)
    D.prop(5, 3, "fixtures_bathroom_01_25", F_HEAVY)
    D.prop(5, 4, "fixtures_bathroom_01_24", F_HEAVY)
    D.prop(5, 2, "fixtures_bathroom_01_32", F_HEAVY)
    D.prop(4, 3, "floors_rugs_01_51", F_LIGHT)
    D.prop(2, 4, "walls_decoration_01_116", F_DECO)
    D.prop(1, 4, "lighting_indoor_02_61", F_LIGHT)
    chimney(D, project, 0, 3)
    D.prop(2, 1, "appliances_com_01_20", F_APPL, 1)
    D.skylight(1, 3)
    D.skylight(4, 3)
end }

Houses.designs.hall = { size = { 6, 5 }, build = function(D, project)
    D.block(0, 0, 6, 5, "Y")
    D.floor(WOOD_HARD)
    D.room(0, 0, 3, 3, CARPET_BLUE)
    D.room(0, 3, 3, 2, TILE_GREY)
    D.open(4, 4, "S", "door")
    D.open(1, 0, "N", "window")
    D.open(0, 1, "W", "window")
    D.open(0, 3, "W", "window")
    D.open(5, 0, "N", "window")
    D.open(5, 2, "E", "window")
    D.open(2, 4, "S", "window")
    for y = 0, 4 do
        local door = (y == 1 or y == 4)
        D.part(3, y, "W", door, y >= 3)
    end
    for x = 0, 2 do D.part(x, 3, "N", false, true) end
    D.prop(0, 0, "furniture_bedding_01_5", F_BED)
    D.prop(1, 0, "furniture_bedding_01_7", F_BED)
    D.prop(0, 1, "furniture_bedding_01_4", F_BED)
    D.prop(1, 1, "furniture_bedding_01_6", F_BED)
    D.cont(2, 0, "furniture_storage_01_48", F_LIGHT, "sidetable")
    D.prop(2, 0, "lighting_indoor_02_42", F_LIGHT)
    D.cont(2, 1, "furniture_storage_01_13", F_HEAVY, "dresser")
    D.cont(2, 2, "furniture_storage_01_43", F_HEAVY, "dresser")
    D.prop(0, 4, "fixtures_bathroom_01_0", F_HEAVY)
    D.cont(0, 3, "fixtures_sinks_01_12", F_HEAVY)
    D.prop(0, 3, "walls_decoration_01_5", F_DECO)
    D.prop(2, 3, "fixtures_bathroom_01_25", F_HEAVY)
    D.prop(2, 4, "fixtures_bathroom_01_24", F_HEAVY)
    D.prop(1, 4, "floors_rugs_01_51", F_LIGHT)
    kitchen3(D, 3, 0)
    sofaRow(D, project, 3, 2)
    D.prop(5, 2, "furniture_seating_indoor_01_10", F_HEAVY)
    D.prop(3, 3, "furniture_tables_low_01_14", F_LIGHT)
    D.prop(4, 3, "furniture_tables_low_01_15", F_LIGHT)
    D.cont(3, 4, "furniture_storage_01_45", F_HEAVY, "crate")
    D.prop(3, 4, "appliances_television_01_3", F_APPL)
    D.cont(5, 1, "furniture_shelving_01_40", F_LIGHT, "shelves")
    D.prop(5, 3, "vegetation_indoor_01_6", F_LIGHT)
    D.prop(4, 4, "walls_decoration_01_124", F_DECO)
    chimney(D, project, 0, 2)
    D.prop(3, 2, "appliances_com_01_20", F_APPL, 1)
    D.skylight(1, 2)
    D.skylight(4, 2)
end }

Houses.designs.lshape = { size = { 8, 6 }, build = function(D, project)
    D.block(0, 0, 4, 6, "X")
    D.block(4, 0, 4, 4, "Y")
    D.floor(CARPET_BROWN)
    D.room(0, 0, 4, 1, WOOD_OAK)
    D.room(2, 1, 2, 2, CARPET_GREEN)
    D.room(2, 3, 2, 3, TILE_WHITE)
    D.room(4, 0, 4, 4, CONCRETE)
    for x = 4, 7 do
        for y = 4, 5 do D.pave(x, y, CONCRETE) end
    end
    D.open(1, 5, "S", "door")
    D.open(5, 3, "S", "garage")
    D.open(6, 3, "S", "garage")
    D.open(7, 3, "S", "garage")
    D.open(1, 0, "N", "window")
    D.open(0, 2, "W", "window")
    D.open(0, 4, "W", "window")
    D.open(3, 4, "E", "window")
    D.open(7, 1, "E", "window")
    D.open(5, 0, "N", "window")
    for y = 1, 5 do
        local door = (y == 1 or y == 4)
        D.part(2, y, "W", door, y >= 3)
    end
    for x = 2, 3 do D.part(x, 3, "N", false, true) end
    for y = 0, 3 do D.part(4, y, "W", y == 1, false) end
    kitchen3(D, 0, 0)
    sofaRow(D, project, 0, 2)
    D.prop(0, 3, "furniture_tables_low_01_14", F_LIGHT)
    D.prop(1, 3, "furniture_tables_low_01_15", F_LIGHT)
    D.cont(0, 4, "furniture_storage_01_46", F_HEAVY, "crate")
    D.prop(0, 4, "appliances_television_01_0", F_APPL)
    D.prop(1, 4, "furniture_seating_indoor_01_13", F_HEAVY)
    D.cont(1, 1, "furniture_shelving_01_42", F_LIGHT, "shelves")
    D.prop(0, 5, "vegetation_indoor_01_11", F_LIGHT)
    D.prop(0, 3, "floors_rugs_01_72", F_LIGHT)
    D.prop(1, 3, "floors_rugs_01_73", F_LIGHT)
    D.prop(2, 1, "furniture_bedding_01_25", F_BED)
    D.prop(3, 1, "furniture_bedding_01_27", F_BED)
    D.prop(2, 2, "furniture_bedding_01_24", F_BED)
    D.prop(3, 2, "furniture_bedding_01_26", F_BED)
    D.prop(2, 5, "fixtures_bathroom_01_0", F_HEAVY)
    D.cont(2, 3, "fixtures_sinks_01_12", F_HEAVY)
    D.prop(2, 3, "walls_decoration_01_5", F_DECO)
    D.prop(3, 4, "fixtures_bathroom_01_25", F_HEAVY)
    D.prop(3, 5, "fixtures_bathroom_01_24", F_HEAVY)
    D.prop(2, 4, "floors_rugs_01_51", F_LIGHT)
    garageKit(D, project, 4, 0, 4, 3)
    D.prop(1, 5, "walls_decoration_01_116", F_DECO)
    D.prop(0, 5, "lighting_indoor_02_61", F_LIGHT)
    chimney(D, project, 0, 1)
    D.prop(1, 1, "appliances_com_01_20", F_APPL, 1)
    D.skylight(1, 4)
    D.skylight(2, 4)
    D.skylight(6, 2)
end }

Houses.designs.bungalow = { size = { 8, 6 }, build = function(D, project)
    D.block(4, 0, 4, 6, "X")
    D.block(0, 0, 4, 4, "Y")
    D.floor(CARPET_BROWN)
    D.room(4, 0, 4, 1, WOOD_OAK)
    D.room(4, 1, 2, 2, CARPET_GREEN)
    D.room(6, 1, 2, 2, TILE_WHITE)
    D.room(0, 0, 4, 4, CONCRETE)
    for x = 0, 3 do
        for y = 4, 5 do D.pave(x, y, CONCRETE) end
    end
    D.open(6, 5, "S", "door")
    D.open(1, 3, "S", "garage")
    D.open(2, 3, "S", "garage")
    D.open(3, 3, "S", "garage")
    D.open(5, 0, "N", "window")
    D.open(7, 1, "E", "window")
    D.open(7, 4, "E", "window")
    D.open(4, 5, "S", "window")
    D.open(0, 1, "W", "window")
    D.open(0, 0, "N", "window")
    for x = 4, 7 do D.part(x, 1, "N", x == 5, false) end
    D.part(6, 1, "W", false, true)
    D.part(6, 2, "W", true, true)
    D.part(6, 3, "N", false, true)
    D.part(7, 3, "N", false, true)
    D.part(4, 3, "N", true, false)
    D.part(5, 3, "N", false, false)
    for y = 0, 3 do D.part(4, y, "W", y == 1, false) end
    kitchen3(D, 4, 0)
    D.cont(7, 0, "furniture_storage_01_13", F_HEAVY, "dresser")
    bed2(D, project, 4, 1)
    bathSet(D, 7, 1, 6, 1, 6, 2, false)
    sofaRow(D, project, 4, 3)
    D.prop(6, 3, "furniture_seating_indoor_01_10", F_HEAVY)
    D.prop(4, 4, "furniture_tables_low_01_14", F_LIGHT)
    D.prop(5, 4, "furniture_tables_low_01_15", F_LIGHT)
    D.cont(4, 5, "furniture_storage_01_45", F_HEAVY, "crate")
    D.prop(4, 5, "appliances_television_01_3", F_APPL)
    D.prop(5, 5, "furniture_seating_indoor_01_13", F_HEAVY)
    D.cont(7, 3, "furniture_shelving_01_40", F_LIGHT, "shelves")
    D.prop(7, 5, "vegetation_indoor_01_11", F_LIGHT)
    D.prop(4, 4, "floors_rugs_01_72", F_LIGHT)
    D.prop(5, 4, "floors_rugs_01_73", F_LIGHT)
    garageKit(D, project, 0, 0, 4, 3)
    D.prop(6, 5, "walls_decoration_01_116", F_DECO)
    D.prop(5, 5, "lighting_indoor_02_61", F_LIGHT)
    chimney(D, project, 7, 4)
    D.prop(5, 1, "appliances_com_01_20", F_APPL, 1)
    D.skylight(4, 4)
    D.skylight(5, 4)
    D.skylight(1, 2)
end }

Houses.designList = {
    house_s = { "cabin" },
    house_m = { "cottage", "hall" },
    house_l = { "lshape", "bungalow" },
}

function Houses.designFor(project, kind)
    local list = Houses.designList[kind]
    if list == nil then return nil end
    local id = tonumber(project and project.id) or 0
    local name = list[(id % #list) + 1]
    return Houses.designs[name], name
end

function Houses.houseStages(project, kind)
    local def = Houses.designFor(project, kind)
    if def == nil then return nil end
    if project.w ~= def.size[1] or project.h ~= def.size[2] then return nil end
    if tonumber(project.palette) == nil then return nil end
    local palette = Houses.palettes[tonumber(project.palette)] or Houses.palettes[1]
    local interior = Houses.interiors[Houses.pickInterior(project)]
    local D = newBuilder()
    local ok, err = pcall(def.build, D, project)
    if not ok then
        print("[ALifeCamp:Houses] design build failed: " .. tostring(err))
        return nil
    end
    return assemble(project, palette, interior, D)
end

return Houses
