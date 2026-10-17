dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Bp, Towers = A.Blueprints, A.Towers

check("module loaded", Towers ~= nil)
check("wrap installed", Towers ~= nil and Towers.wrapped == true)
check("tower kind present", Bp.kinds.tower ~= nil and Bp.kinds.tower.towerBuild ~= nil)

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

local project = { kind = "tower", x = 10, y = 10, w = 2, h = 2, id = 7 }
local stages = Bp.stages(project)
local ids = { "legs", "deck", "guard", "roof", "stair" }
local okIds = #stages == 5
for i, id in ipairs(ids) do if stages[i] == nil or stages[i].id ~= id then okIds = false end end
check("five tower stages", okIds, #stages)

local counts = {}
for _, stage in ipairs(stages) do counts[stage.id] = #stage.ops end
check("legs count 8", counts.legs == 8, counts.legs)
check("deck count 4", counts.deck == 4, counts.deck)
check("guard count 13", counts.guard == 13, counts.guard)
check("roof count 16", counts.roof == 16, counts.roof)
check("stair count 1", counts.stair == 1, counts.stair)

local zexpect = { legs = 0, deck = 1, guard = 1, roof = 2, stair = 0 }
local zok = true
for _, stage in ipairs(stages) do
    for _, op in ipairs(stage.ops) do
        if (op.z or 0) ~= zexpect[stage.id] then zok = false end
    end
end
check("stage z levels", zok)

local seen, dup, badSprite, validTypes = {}, false, nil, true
for _, stage in ipairs(stages) do
    for _, op in ipairs(stage.ops) do
        if op.t ~= "prop" and op.t ~= "roof" then validTypes = false end
        if op.sprite == nil or known[op.sprite] ~= true then badSprite = op.sprite or "nil" end
        if seen[op.slot] then dup = true end
        seen[op.slot] = true
    end
end
check("op types placeable", validTypes)
check("all sprites in catalog", badSprite == nil, badSprite)
check("unique slots", not dup)

local deckCell, lightCell = false, false
for _, op in ipairs(stages[2].ops) do
    if op.x >= 10 and op.x <= 11 and op.y >= 10 and op.y <= 11 then deckCell = true end
end
for _, op in ipairs(stages[3].ops) do
    if op.sprite == "lighting_outdoor_01_48" and op.x == 11 and op.y == 11 then lightCell = true end
end
check("deck over footprint", deckCell)
check("searchlight on platform", lightCell)

local overhang = false
for _, op in ipairs(stages[4].ops) do
    if op.x == 9 or op.y == 9 or op.x == 12 or op.y == 12 then overhang = true end
end
check("roof overhangs footprint", overhang)

local function goodCost(c)
    local ok, any = true, false
    for kind, amount in pairs(c) do
        any = true
        if (kind ~= "planks" and kind ~= "nails" and kind ~= "metal" and kind ~= "rope" and kind ~= "logs") or amount <= 0 then ok = false end
    end
    return ok and any
end
local totalCost = {}
for _, stage in ipairs(stages) do
    for k, v in pairs(Bp.cost(stage.ops)) do totalCost[k] = (totalCost[k] or 0) + v end
end
check("tower cost stock kinds", goodCost(totalCost) and (totalCost.metal or 0) > 0 and (totalCost.nails or 0) > 0)

local info = Bp.stageInfo(project)
check("stage info five", #info == 5 and info[1].count == 8)

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

local stable = Bp.stages(project)
check("stages stable rebuild", #stable == 5 and #stable[4].ops == 16)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
