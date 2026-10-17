dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Bp, Houses = A.Blueprints, A.Houses

local function roofStage(project)
    for _, stage in ipairs(Bp.stages(project)) do
        if stage.id == "roof" then return stage end
    end
end

local function count(ops, t)
    local n = 0
    for _, op in ipairs(ops) do if op.t == t then n = n + 1 end end
    return n
end

local function noFunctions(t, depth)
    if depth > 6 then return false end
    for _, v in pairs(t) do
        if type(v) == "function" or type(v) == "userdata" then return false end
        if type(v) == "table" and not noFunctions(v, depth + 1) then return false end
    end
    return true
end

local sprites = {}
local function collect(ops) for _, op in ipairs(ops) do sprites[op.sprite] = true end end

local cases = {
    { kind = "house_s", w = 4, h = 4, tiles = 16, gables = 8 },
    { kind = "house_m", w = 6, h = 5, tiles = 30, gables = 10, roofZ = 2 },
    { kind = "house_l", w = 8, h = 6, tiles = 40, gables = 16 },
    { kind = "shed", w = 4, h = 3, tiles = 12, gables = 8 },
}
for _, c in ipairs(cases) do
    for palette = 1, 6 do
        local project = { kind = c.kind, x = 100, y = 200, w = c.w, h = c.h, door = "S", level = 1, palette = palette }
        local stage = roofStage(project)
        local ops = stage.ops
        collect(ops)
        check(c.kind .. " p" .. palette .. " tiles", count(ops, "roof") == c.tiles, count(ops, "roof"))
        check(c.kind .. " p" .. palette .. " gables+accents", count(ops, "prop") == c.gables * 2, count(ops, "prop"))
        local slots, inside, positions = {}, true, true
        for _, op in ipairs(ops) do
            if slots[op.slot] then positions = false end
            slots[op.slot] = true
            if op.z ~= (c.roofZ or 1) or op.sprite == nil or op.x < 100 or op.y < 200 or op.x > 100 + c.w or op.y > 200 + c.h then inside = false end
            if op.t == "roof" and (op.x >= 100 + c.w or op.y >= 200 + c.h) then inside = false end
        end
        check(c.kind .. " p" .. palette .. " unique slots and bounds", positions and inside)
    end
end

local project = { kind = "house_m", x = 100, y = 200, w = 6, h = 5, door = "S", level = 1, palette = 1 }
local ops = roofStage(project).ops
local rows = {}
for _, op in ipairs(ops) do
    if op.t == "roof" and op.x == 100 then rows[op.y - 200] = op.sprite end
end
check("6x5 ridge along x section", rows[0] == "roofs_30_02_29" and rows[2] == "roofs_30_02_98" and rows[4] == "roofs_30_02_0")
local gable = {}
for _, op in ipairs(ops) do
    if op.t == "prop" and op.slot == "G1:6:2" then gable = op end
end
check("6x5 gable at far end", gable.sprite == "walls_exterior_roofs_30_03_34" and gable.x == 106 and gable.y == 202 and gable.z == 2)

local shed = roofStage({ kind = "shed", x = 100, y = 200, w = 4, h = 3, door = "S", palette = 2 }).ops
local cols = {}
for _, op in ipairs(shed) do
    if op.t == "roof" and op.y == 200 then cols[op.x - 100] = op.sprite end
end
check("shed ridge along y section", cols[0] == "roofs_30_01_16" and cols[3] == "roofs_30_01_13")
local south
for _, op in ipairs(shed) do if op.slot == "G:2:3" then south = op end end
check("shed gable on south edge", south ~= nil and south.sprite == "walls_exterior_roofs_30_06_28" and south.y == 203)

local cost = Bp.cost(ops)
check("prop cost override", Bp.opCost({ t = "prop", cost = { nails = 1 } }).nails == 1 and Bp.opCost({ t = "prop", cost = {} }).nails == nil)
check("roof cost counts gables", cost.planks == 30 and cost.nails == 60 + 10, tostring(cost.planks) .. "/" .. tostring(cost.nails))
check("work counted", Bp.work(ops) > 0)

local plain = { kind = "house_m", x = 100, y = 200, w = 6, h = 5, door = "S", level = 1 }
local function designedRoof(opsList)
    for _, op in ipairs(opsList) do
        if op.t == "roof" and string.sub(op.sprite, 1, 9) == "roofs_30_" then return true end
    end
    return false
end
local flat = roofStage(plain).ops
local flatOk = #flat == 30
for _, op in ipairs(flat) do
    if op.t ~= "roof" or op.sprite ~= "roofs_02_22" then flatOk = false end
end
check("no palette keeps flat roof", flatOk)
local badPalette = roofStage({ kind = "house_m", x = 100, y = 200, w = 6, h = 5, door = "S", palette = 99 }).ops
check("bad palette defaults to design", designedRoof(badPalette))
local odd = roofStage({ kind = "house_m", x = 100, y = 200, w = 3, h = 3, door = "S", palette = 1 }).ops
check("uncovered size keeps flat roof", #odd == 9 and odd[1].sprite == "roofs_02_22")
check("roofOps nil without palette", Houses.roofOps(plain) == nil and Houses.roofOps(nil) == nil)

check("roof ops serializable", noFunctions(ops, 0))
local p = A.Store ~= nil and { stages = Bp.stages(project) } or nil
check("stages serializable", p ~= nil and noFunctions(p, 0))

local function designRoof(kind, id)
    local def = Bp.kinds[kind]
    local project = { kind = kind, x = 300, y = 300, w = def.w, h = def.h, door = "S", level = 1, id = id, palette = Houses.pick({ id = id }) }
    return roofStage(project)
end

local lroof = designRoof("house_l", 0)
local lt, lg = 0, 0
for _, op in ipairs(lroof.ops) do
    if op.t == "roof" then lt = lt + 1 elseif string.sub(op.slot, 1, 1) == "G" then lg = lg + 1 end
end
check("lshape two-block roof tiles", lt == 40, lt)
check("lshape valley gables", lg == 16, lg)

local bun = designRoof("house_l", 1)
local bt = 0
for _, op in ipairs(bun.ops) do if op.t == "roof" then bt = bt + 1 end end
check("bungalow two-block tiles", bt == 40, bt)

local cot = designRoof("house_m", 0)
local hal = designRoof("house_m", 1)
local cotRidgeX, halRidgeY = false, false
local cotPal = Houses.palettes[Houses.pick({ id = 0 })]
local halPal = Houses.palettes[Houses.pick({ id = 1 })]
for _, op in ipairs(cot.ops) do if op.t == "roof" and op.sprite == "roofs_30_" .. cotPal.roof .. "_29" then cotRidgeX = true end end
for _, op in ipairs(hal.ops) do if op.t == "roof" and op.sprite == "roofs_30_" .. halPal.roof .. "_16" then halRidgeY = true end end
check("cottage ridge along x", cotRidgeX)
check("hall ridge along y", halRidgeY)
check("design roofs serializable", noFunctions({ lroof, bun, cot, hal }, 0))

local list = {}
for sprite in pairs(sprites) do list[#list + 1] = sprite end
table.sort(list)
local file = io.open("roofs_sprites.txt", "w")
file:write(table.concat(list, "\n"))
file:close()

RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = {} }
