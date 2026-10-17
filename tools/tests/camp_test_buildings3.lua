dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Plan, Settlers, Hooks, B3, Districts, Stats = A.Store, A.Camp, A.Build, A.Blueprints, A.Plan, A.Settlers, A.Hooks, A.Buildings3, A.Districts, A.Stats
local reg = MOCKALIFE()

for x = 30, 175 do for y = 30, 175 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 500

local kinds = { "greenhouse", "tents" }
check("module loaded", B3 ~= nil and A.Buildings ~= nil)

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

local function validCost(cost)
    for key, amount in pairs(cost) do
        if (key ~= "planks" and key ~= "nails" and key ~= "metal" and key ~= "logs" and key ~= "rope") or amount <= 0 then return false end
    end
    return true
end

for _, kind in ipairs(kinds) do
    local def = Bp.kinds[kind]
    check(kind .. " registered", def ~= nil)
    check(kind .. " has text", A.T("Kind_" .. kind) ~= nil)
    check(kind .. " planner color", type(Districts.colors[kind]) == "table" and Districts.colors[kind].r ~= nil)
    for _, piece in ipairs(B3.definitions[kind].furniture) do
        check(kind .. " sprite in catalog " .. piece.sprite, known[piece.sprite] == true)
    end
end
check("greenhouse size and class", Bp.kinds.greenhouse.w == 6 and Bp.kinds.greenhouse.h == 5 and Bp.buildingKinds.greenhouse == true)
check("tents size and class", Bp.kinds.tents.w == 14 and Bp.kinds.tents.h == 9 and not Bp.buildingKinds.tents)

local project = { kind = "greenhouse", x = 70, y = 70, w = 6, h = 5, door = "S", level = 1, palette = 1, id = 1 }
local stages = Bp.stages(project)
local ids = { "foundation", "frame", "walls", "roof", "finish" }
local same = #stages == 5
for index, id in ipairs(ids) do if stages[index] == nil or stages[index].id ~= id then same = false end end
check("greenhouse five stages", same)
check("greenhouse foundation 30", #stages[1].ops == 30)
check("greenhouse frame and walls 22", #stages[2].ops == 22 and #stages[3].ops == 22, #stages[2].ops)
check("greenhouse green walls despite palette", string.sub(stages[3].ops[1].e, 1, 10) == "HouseGreen")
local glass, gables, accents = 0, 0, 0
local rseen, rdup = {}, false
for _, op in ipairs(stages[4].ops) do
    if op.t == "roof" then
        glass = glass + 1
        check("glass roof sprite " .. op.sprite, string.sub(op.sprite, 1, 12) == "roofs_30_04_" and known[op.sprite] == true and op.z == 1)
    elseif string.sub(op.sprite, 1, 24) == "walls_exterior_roofs_30_" then
        gables = gables + 1
        check("gable sprite " .. op.sprite, string.sub(op.sprite, 1, 27) == "walls_exterior_roofs_30_08_" and known[op.sprite] == true)
    else
        accents = accents + 1
        check("accent sprite " .. op.sprite, known[op.sprite] == true)
    end
    if rseen[op.slot] then rdup = true end
    rseen[op.slot] = true
end
check("glass roof 30 cells, 10 gables, 10 accents", glass == 30 and gables == 10 and accents == 10, glass .. "/" .. gables .. "/" .. accents)
check("roof slots unique", not rdup)
local beds, plants, barrels, crates, doors, windows = 0, 0, 0, 0, 0, 0
local seen, dup = {}, false
for _, op in ipairs(stages[5].ops) do
    if op.t == "dirt" then beds = beds + 1
    elseif op.t == "crop" then plants = plants + 1; check("plant sprite " .. op.sprite, known[op.sprite] == true)
    elseif op.t == "prop" then
        if op.container == "crate" then crates = crates + 1 else barrels = barrels + 1 end
        check("greenhouse prop inside " .. op.slot, op.x >= 70 and op.x <= 75 and op.y >= 70 and op.y <= 74)
        check("greenhouse prop off door cell " .. op.slot, not (op.x == 73 and op.y == 74))
    elseif op.t == "door" then doors = doors + 1
    elseif op.t == "window" then windows = windows + 1 end
    if seen[op.slot] then dup = true end
    seen[op.slot] = true
end
check("greenhouse beds, plants, barrels", beds == 12 and plants == 12 and barrels == 4 and crates == 2, beds .. "/" .. plants .. "/" .. barrels .. "/" .. crates)
check("greenhouse one door and windows", doors == 1 and windows >= 3)
check("greenhouse unique finish slots", not dup)
check("greenhouse costs in stock kinds", validCost(Bp.cost(stages[4].ops)) and validCost(Bp.cost(stages[5].ops)))
check("greenhouse stage info", #Bp.stageInfo(project) == 5)

local tent = { kind = "tents", x = 80, y = 80, w = 14, h = 9, level = 1, id = 2 }
local tstages = Bp.stages(tent)
check("tents two stages", #tstages == 2 and tstages[1].id == "ground" and tstages[2].id == "camp")
check("tents ground covers footprint", #tstages[1].ops == 126)
local cells, dupCell, tseen, tdup = {}, false, {}, false
local counts = { tent = 0, fire = 0, rack = 0, pile = 0, smoke = 0 }
for _, op in ipairs(tstages[2].ops) do
    check("tent prop in catalog " .. op.sprite, known[op.sprite] == true)
    check("tent prop inside " .. op.slot, op.x >= 80 and op.x <= 93 and op.y >= 80 and op.y <= 88)
    local cell = op.x .. ":" .. op.y
    if cells[cell] then dupCell = true end
    cells[cell] = true
    if tseen[op.slot] then tdup = true end
    tseen[op.slot] = true
    if string.sub(op.sprite, 1, 10) == "camping_04" then counts.tent = counts.tent + 1 end
    if op.sprite == "camping_01_4" then counts.fire = counts.fire + 1 end
    if string.sub(op.sprite, 1, 19) == "vegetation_drying_0" then counts.rack = counts.rack + 1 end
    if string.sub(op.sprite, 1, 12) == "camping_01_2" or string.sub(op.sprite, 1, 12) == "camping_01_3" then counts.pile = counts.pile + 1 end
    if op.sprite == "crafted_05_56" then counts.smoke = counts.smoke + 1 end
end
check("tents: no two props on one cell", not dupCell)
check("tents: unique slots", not tdup)
check("tents: 24 canvas tiles, fire, racks, woodpile, smokehouse", counts.tent == 24 and counts.fire == 1 and counts.rack == 8 and counts.pile >= 8 and counts.smoke == 1, counts.tent .. "/" .. counts.fire .. "/" .. counts.rack .. "/" .. counts.pile .. "/" .. counts.smoke)
check("tents costs in stock kinds", validCost(Bp.cost(tstages[2].ops)) and (Bp.cost(tstages[2].ops).rope or 0) > 0)
check("tents stage info", #Bp.stageInfo(tent) == 2)

local function settle(camp, count)
    local have = Store.settlerCount(camp)
    for i = have + 1, count do
        local uid = "p" .. i
        ADDACTOR(reg, uid, "friendly", 70 + i, 74, A.World.square(70 + i, 74, 0))
        Settlers.settle(camp, uid, uid)
    end
end

local function count(camp, kind) return Plan.countKind(camp, kind) end
local function disjoint(camp)
    local list = {}
    for _, p in pairs(Build.plan(camp).items) do
        if p.kind ~= "fence" then list[#list + 1] = Bp.footprint(p) end
    end
    for i = 1, #list do
        for j = i + 1, #list do
            if Build.overlaps(list[i], list[j]) then return false end
        end
    end
    return true
end

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 109, y2 = 99, z = 0 }, "Buildings3")
camp.options.recruit = false
camp.phase = "plan"
settle(camp, 5)
B3.generate(camp)
check("five people: nothing", count(camp, "greenhouse") == 0 and count(camp, "tents") == 0)
settle(camp, 6)
B3.generate(camp)
check("six people: greenhouse only", count(camp, "greenhouse") == 1 and count(camp, "tents") == 0)
settle(camp, 9)
B3.generate(camp)
check("nine people: still no tents", count(camp, "tents") == 0)
settle(camp, 10)
check("ten people: generate adds the tents", B3.generate(camp) == 1)
B3.generate(camp)
check("ten people: one each", count(camp, "greenhouse") == 1 and count(camp, "tents") == 1)
check("plan has no overlaps", disjoint(camp))
for _, kind in ipairs(kinds) do
    for _, p in pairs(Build.plan(camp).items) do
        if p.kind == kind then
            local def = Bp.kinds[kind]
            check(kind .. " inside camp", p.x >= camp.x1 and p.y >= camp.y1 and p.x + def.w <= camp.x2 + 1 and p.y + def.h <= camp.y2 + 1)
            check(kind .. " planned size", p.w == def.w and p.h == def.h)
        end
    end
end
Plan.generate(camp)
check("plan generate keeps one each", count(camp, "greenhouse") == 1 and count(camp, "tents") == 1 and disjoint(camp))

local whole = Camp.create({ x1 = 120, y1 = 60, x2 = 189, y2 = 109, z = 0 }, "Whole")
whole.options.recruit = false
whole.phase = "plan"
settle(whole, 10)
Plan.generate(whole)
check("plan generate with ten people places both", count(whole, "greenhouse") == 1 and count(whole, "tents") == 1 and disjoint(whole))

local narrow = Camp.create({ x1 = 60, y1 = 110, x2 = 82, y2 = 160, z = 0 }, "Narrow")
narrow.options.recruit = false
narrow.phase = "plan"
settle(narrow, 12)
Plan.generate(narrow)
check("side 23: no new buildings", count(narrow, "greenhouse") == 0 and count(narrow, "tents") == 0)

local medium = Camp.create({ x1 = 90, y1 = 110, x2 = 115, y2 = 150, z = 0 }, "Medium")
medium.options.recruit = false
medium.phase = "plan"
settle(medium, 12)
Plan.generate(medium)
check("side 26: greenhouse yes, tents no", count(medium, "greenhouse") == 1 and count(medium, "tents") == 0)

local greenhouse, tents
for _, p in pairs(Build.plan(camp).items) do
    if p.kind == "greenhouse" then greenhouse = p elseif p.kind == "tents" then tents = p end
end

local baseFarm = Hooks.product("farm", camp)
check("farm multiplier unchanged before the greenhouse is built", baseFarm > 0, baseFarm)
greenhouse.status = "done"
greenhouse.stage = 99
check("farm multiplier 1.15 with greenhouse", math.abs(Hooks.product("farm", camp) / baseFarm - 1.15) < 0.0001, Hooks.product("farm", camp))
greenhouse.retired = true
check("retired greenhouse gives nothing", math.abs(Hooks.product("farm", camp) - baseFarm) < 0.0001)
greenhouse.retired = nil

local baseMorale = Hooks.sum("morale", camp)
tents.status = "done"
tents.stage = 99
check("morale plus 2 with tents", Hooks.sum("morale", camp) - baseMorale == 2, Hooks.sum("morale", camp))
tents.retired = true
check("retired tents give nothing", Hooks.sum("morale", camp) == baseMorale)
tents.retired = nil
check("stats compute with both", Stats.compute(camp) ~= nil)

local visited = {}
local function pure(value)
    local kind = type(value)
    if kind == "function" or kind == "userdata" then return false end
    if kind ~= "table" then return true end
    if visited[value] then return false end
    visited[value] = true
    for _, item in pairs(value) do
        if not pure(item) then return false end
    end
    visited[value] = nil
    return true
end
check("camp stays serializable", pure(camp.plan) and pure(camp.settlers))

local before = #Build.list(camp)
Plan.generate(camp)
check("generate is stable", #Build.list(camp) == before)

local crowded = Camp.create({ x1 = 60, y1 = 165, x2 = 100, y2 = 169, z = 0 }, "Crowded")
check("generate on thin camp adds nothing", B3.generate(crowded) == 0)
check("generate nil camp", B3.generate(nil) == 0)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
