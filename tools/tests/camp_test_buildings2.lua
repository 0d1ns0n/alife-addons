dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Plan, Settlers, Duty, Hooks, Buildings, Buildings2, Districts = A.Store, A.Camp, A.Build, A.Blueprints, A.Plan, A.Settlers, A.Duty, A.Hooks, A.Buildings, A.Buildings2, A.Districts
local reg = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 500
local CLOCK = 12
local realGameTime = getGameTime
getGameTime = function()
    local base = realGameTime()
    return setmetatable({ getHour = function() return CLOCK end }, { __index = base })
end

local kinds = { "barracks", "powerhouse" }
local sizes = { barracks = { 9, 6 }, powerhouse = { 6, 4 } }
check("module loaded", Buildings2 ~= nil and Duty ~= nil and Buildings ~= nil)

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

local ids = { "foundation", "frame", "walls", "roof", "finish" }
for _, kind in ipairs(kinds) do
    local w, h = sizes[kind][1], sizes[kind][2]
    local def = Bp.kinds[kind]
    check(kind .. " registered", def ~= nil and def.w == w and def.h == h and Bp.buildingKinds[kind] == true)
    check(kind .. " has text", A.T("Kind_" .. kind) ~= nil)
    check(kind .. " planner color", type(Districts.colors[kind]) == "table" and Districts.colors[kind].r ~= nil)
    local project = { kind = kind, x = 70, y = 70, w = w, h = h, door = "S", level = 1, palette = 2, id = 1 }
    local stages = Bp.stages(project)
    local same = #stages == 5
    for index, id in ipairs(ids) do if stages[index] == nil or stages[index].id ~= id then same = false end end
    check(kind .. " five stages", same)
    check(kind .. " foundation and roof", #stages[1].ops == w * h and #stages[4].ops >= w * h, #stages[1].ops .. "/" .. #stages[4].ops)
    check(kind .. " frame and walls", #stages[2].ops == 2 * (w + h) and #stages[3].ops == 2 * (w + h))
    local furniture, storage, doors, windows = 0, 0, 0, 0
    local seen, dup = {}, false
    for _, op in ipairs(stages[5].ops) do
        if op.t == "prop" then
            furniture = furniture + 1
            if op.storage then storage = storage + 1 end
            check(kind .. " sprite in catalog " .. op.sprite, known[op.sprite] == true)
            check(kind .. " prop inside " .. op.slot, op.x >= 70 and op.x <= 70 + w - 1 and op.y >= 70 and op.y <= 70 + h - 1)
        elseif op.t == "door" then doors = doors + 1
        elseif op.t == "window" then windows = windows + 1 end
        if seen[op.slot] then dup = true end
        seen[op.slot] = true
    end
    check(kind .. " furniture count " .. furniture, furniture == #Buildings2.definitions[kind].furniture and furniture >= 15)
    check(kind .. " one door and windows", doors == 1 and windows >= 3)
    check(kind .. " unique slots", not dup)
    check(kind .. " storage none", storage == 0)
    local cost = Bp.cost(stages[5].ops)
    local good = true
    for key, amount in pairs(cost) do
        if (key ~= "planks" and key ~= "nails" and key ~= "metal") or amount <= 0 then good = false end
    end
    check(kind .. " finish cost stock kinds", good and (cost.planks or 0) > 0 and (cost.metal or 0) > 0)
    local info = Bp.stageInfo(project)
    check(kind .. " stage info", #info == 5 and info[5].count == #stages[5].ops)
end

for _, kind in ipairs(kinds) do
    local w, h = sizes[kind][1], sizes[kind][2]
    local cell = false
    for _, piece in ipairs(Buildings2.definitions[kind].furniture) do
        if piece.dx == math.floor(w / 2) and piece.dy == h - 1 then cell = true end
    end
    check(kind .. " door cell clear", not cell)
end

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
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind ~= "fence" then list[#list + 1] = Bp.footprint(project) end
    end
    for i = 1, #list do
        for j = i + 1, #list do
            if Build.overlaps(list[i], list[j]) then return false end
        end
    end
    return true
end

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 104, y2 = 94, z = 0 }, "Buildings2")
camp.options.recruit = false
camp.phase = "plan"
settle(camp, 6)
Plan.generate(camp)
check("six people: nothing", count(camp, "barracks") == 0 and count(camp, "powerhouse") == 0)
settle(camp, 7)
Plan.generate(camp)
check("seven people: barracks only", count(camp, "barracks") == 1 and count(camp, "powerhouse") == 0)
settle(camp, 8)
Plan.generate(camp)
check("eight people: still no powerhouse", count(camp, "powerhouse") == 0)
settle(camp, 9)
Plan.generate(camp)
Plan.generate(camp)
check("nine people: powerhouse, one each", count(camp, "barracks") == 1 and count(camp, "powerhouse") == 1)
check("older buildings still planned", count(camp, "canteen") == 1 and count(camp, "infirmary") == 1 and count(camp, "forge") == 1, count(camp, "canteen") .. count(camp, "infirmary") .. count(camp, "forge"))
check("plan has no overlaps", disjoint(camp))
local cx, cy = A.Geo.center(camp)
for _, kind in ipairs(kinds) do
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind then
            check(kind .. " inside interior", project.x > camp.x1 and project.y > camp.y1 and project.x + project.w - 1 < camp.x2 and project.y + project.h - 1 < camp.y2, project.x .. "," .. project.y .. " c " .. cx .. "," .. cy)
            check(kind .. " has palette and door", project.palette ~= nil and project.door == "S")
            check(kind .. " inside camp", project.x >= camp.x1 and project.y >= camp.y1 and project.x + project.w <= camp.x2 and project.y + project.h <= camp.y2)
        end
    end
end

local small = Camp.create({ x1 = 110, y1 = 60, x2 = 130, y2 = 100, z = 0 }, "Small")
small.options.recruit = false
small.phase = "plan"
settle(small, 10)
Plan.generate(small)
check("small plot: no new buildings", count(small, "barracks") == 0 and count(small, "powerhouse") == 0)

local tight = Camp.create({ x1 = 60, y1 = 100, x2 = 85, y2 = 130, z = 0 }, "Tight")
tight.options.recruit = false
tight.phase = "plan"
settle(tight, 9)
for i = 1, 6 do Build.add(tight, "house_s", 61 + ((i - 1) % 3) * 8, 102 + math.floor((i - 1) / 3) * 8, { door = "S" }) end
local result = Buildings2.displace(tight, "barracks", 72, 115)
check("displace gives barracks or nothing", result == nil or result.kind == "barracks")

local barracks, powerhouse
for _, project in pairs(Build.plan(camp).items) do
    if project.kind == "barracks" then barracks = project elseif project.kind == "powerhouse" then powerhouse = project end
end

local function ready(project)
    project.status = "done"
    project.stage = 99
end

local baseMorale, baseDefense = Hooks.sum("morale", camp), Hooks.sum("defense", camp)
check("no bonus before building", Buildings2.built(camp, "barracks") == nil and Buildings2.built(camp, "powerhouse") == nil)
ready(barracks)
check("barracks morale +4", Hooks.sum("morale", camp) - baseMorale == 4 and Hooks.sum("defense", camp) == baseDefense)
ready(powerhouse)
check("powerhouse morale +2 and defense +3", Hooks.sum("morale", camp) - baseMorale == 6 and Hooks.sum("defense", camp) - baseDefense == 3)
local stats = A.Stats.compute(camp)
check("stats compute works", type(stats) == "table")

A.Stock.kinds[#A.Stock.kinds + 1] = "fuel"
camp.stock = camp.stock or {}
camp.stock.fuel = 0
check("no fuel: powerhouse gives nothing", Hooks.sum("morale", camp) - baseMorale == 4 and Hooks.sum("defense", camp) == baseDefense)
camp.stock.fuel = 5
check("fuel: powerhouse works", Hooks.sum("morale", camp) - baseMorale == 6 and Hooks.sum("defense", camp) - baseDefense == 3)
A.Stock.kinds[#A.Stock.kinds] = nil

powerhouse.retired = true
check("retired powerhouse gives nothing", Hooks.sum("morale", camp) - baseMorale == 4 and Hooks.sum("defense", camp) == baseDefense)
powerhouse.retired = nil
barracks.status = "planned"
check("unbuilt barracks gives nothing", Hooks.sum("morale", camp) - baseMorale == 2)
ready(barracks)

local function inside(spot, project)
    return spot ~= nil and spot.x >= project.x and spot.x <= project.x + project.w - 1 and spot.y >= project.y and spot.y <= project.y + project.h - 1
end

local settler = camp.settlers["p1"]
settler.role = "worker"
CLOCK = 12
check("day: no barracks spot", Duty.barracks(camp, "p1") == nil)
CLOCK = 23
local spot = Duty.barracks(camp, "p1")
check("night 23: barracks spot inside", inside(spot, barracks) and spot.kind == "home", spot and (spot.x .. "," .. spot.y))
check("night: home is barracks", inside(Duty.home(camp, "p1"), barracks))
check("night: station in barracks", inside(Duty.station(camp, "p1", settler, Duty.context(camp)), barracks))
CLOCK = 3
check("night 3: barracks spot", inside(Duty.barracks(camp, "p1"), barracks))
CLOCK = 6
check("morning 6: free again", Duty.barracks(camp, "p1") == nil)
CLOCK = 22
check("22 counts as night", Duty.barracks(camp, "p1") ~= nil)
camp.raid = { id = 1 }
check("raid: no barracks", Duty.barracks(camp, "p1") == nil)
camp.raid = nil
barracks.retired = true
check("retired barracks ignored", Duty.barracks(camp, "p1") == nil)
barracks.retired = nil
CLOCK = 12

check("anchor hooks run without error", pcall(function() return Hooks.first("anchor", camp, "p1", settler, { x = cx, y = cy, z = 0 }) end))

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

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
