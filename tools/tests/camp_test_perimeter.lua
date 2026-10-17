dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Bp, Gates, Perimeter = A.Blueprints, A.Gates, A.Perimeter

check("module loaded", Perimeter ~= nil)
check("wrap installed", Perimeter ~= nil and Perimeter.wrapped == true)
check("fence kind present", Bp.kinds.fence ~= nil and Bp.kinds.fence.perimeterBuild ~= nil)

local known, knownCount = {}, 0
local catalog = io.open("G:/SteamLibrary/steamapps/common/ProjectZomboid/media/newtiledefinitions.tiles.txt", "r")
if catalog ~= nil then
    for line in catalog:lines() do
        local name = line:match("^%s*//%s*(%S+_%d+)%s*$")
        if name ~= nil then known[name] = true knownCount = knownCount + 1 end
    end
    catalog:close()
end
check("tile catalog read", knownCount > 1000, knownCount)

local plain = { kind = "fence", x = 0, y = 0, w = 10, h = 8, gate = "S" }
local plainStages = Bp.stages(plain)
local hasApron = false
for _, stage in ipairs(plainStages) do
    if stage.id == "apron" or stage.id == "bulwark" then hasApron = true end
end
check("plain fence has no apron", not hasApron)

local heavy = { kind = "fence", x = 0, y = 0, w = 14, h = 10, wall = 3 }
heavy.gates = { { id = "g1", side = "S", index = 7, main = true, span = 3 } }
local stages = Bp.stages(heavy)
local function stage(id)
    for _, s in ipairs(stages) do if s.id == id then return s end end
    return nil
end
check("heavy fence keeps base stages", stage("fence") ~= nil and stage("gate") ~= nil)
local apron, bulwark = stage("apron"), stage("bulwark")
check("apron stage present", apron ~= nil and #apron.ops > 0, apron and #apron.ops)
check("bulwark stage present", bulwark ~= nil and #bulwark.ops > 0, bulwark and #bulwark.ops)
check("apron after base", stages[#stages].id == "bulwark" and stages[#stages - 1].id == "apron")

local wallCells = {}
for _, slot in ipairs(Bp.fenceSlots(heavy)) do wallCells[slot.x .. ":" .. slot.y] = true end

local function allApron()
    local out = {}
    for _, op in ipairs(apron.ops) do out[#out + 1] = op end
    for _, op in ipairs(bulwark.ops) do out[#out + 1] = op end
    return out
end

local offWall, offSprite, offType, offZ = true, nil, true, true
local seen, dup = {}, false
for _, op in ipairs(allApron()) do
    if wallCells[op.x .. ":" .. op.y] then offWall = false end
    if op.sprite == nil or known[op.sprite] ~= true then offSprite = op.sprite or "nil" end
    if op.t ~= "prop" then offType = false end
    if (op.z or 0) ~= 0 then offZ = false end
    if seen[op.slot] then dup = true end
    seen[op.slot] = true
end
check("apron off the wall line", offWall)
check("apron sprites in catalog", offSprite == nil, offSprite)
check("apron ops are props", offType)
check("apron ops ground level", offZ)
check("apron unique slots", not dup)

local outward = { S = { 0, 1 }, N = { 0, -1 }, W = { -1, 0 }, E = { 1, 0 } }
local blocked = {}
for _, slot in ipairs(Bp.fenceSlots(heavy)) do
    if slot.gate then
        local d = outward[slot.side]
        blocked[(slot.x + d[1]) .. ":" .. (slot.y + d[2])] = true
        blocked[slot.x .. ":" .. slot.y] = true
    end
end
local clearGate = true
for _, op in ipairs(allApron()) do
    if blocked[op.x .. ":" .. op.y] then clearGate = false end
end
check("gate passage clear", clearGate)

local hasWire, hasHesco = false, false
for _, op in ipairs(apron.ops) do
    if op.sprite == "fencing_01_108" or op.sprite == "fencing_01_109" then hasWire = true end
end
for _, op in ipairs(bulwark.ops) do
    if string.sub(op.sprite, 1, 11) == "fencing_01_" and op.sprite ~= "fencing_01_19" then hasHesco = true end
end
check("apron has razor wire", hasWire)
check("bulwark has blocks", hasHesco)

local function goodCost(c)
    local ok = true
    for kind, amount in pairs(c) do
        if (kind ~= "planks" and kind ~= "nails" and kind ~= "metal" and kind ~= "rope" and kind ~= "logs") or amount <= 0 then ok = false end
    end
    return ok
end
local total = {}
for _, op in ipairs(allApron()) do
    for k, v in pairs(Bp.opCost(op)) do total[k] = (total[k] or 0) + v end
end
check("apron cost stock kinds", goodCost(total) and (total.metal or 0) > 0)

local layout = { kind = "fence", x = 100, y = 100, w = 40, h = 40, wall = 2 }
layout.gates = Gates.layout(layout.w, layout.h, "S")
local ok = pcall(function() return Bp.stages(layout) end)
check("multi-gate layout builds", ok and #layout.gates >= 2, #layout.gates)

local visited = {}
local function pure(value)
    local kind = type(value)
    if kind == "function" or kind == "userdata" then return false end
    if kind ~= "table" then return true end
    if visited[value] then return false end
    visited[value] = true
    for _, item in pairs(value) do if not pure(item) then return false end end
    visited[value] = nil
    return true
end
check("stages serializable", pure(stages))

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
