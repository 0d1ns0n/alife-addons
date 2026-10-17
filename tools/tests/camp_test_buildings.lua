dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Plan, Settlers, Duty, Hooks, Health, Buildings, Districts = A.Store, A.Camp, A.Build, A.Blueprints, A.Plan, A.Settlers, A.Duty, A.Hooks, A.Health, A.Buildings, A.Districts
local reg = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 500

local kinds = { "canteen", "infirmary", "forge" }
check("module loaded", Buildings ~= nil and Duty ~= nil and Health ~= nil)

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
    local def = Bp.kinds[kind]
    check(kind .. " registered", def ~= nil and def.w == 9 and def.h == 6 and Bp.buildingKinds[kind] == true)
    check(kind .. " has text", A.T("Kind_" .. kind) ~= nil)
    check(kind .. " planner color", type(Districts.colors[kind]) == "table" and Districts.colors[kind].r ~= nil)
    local project = { kind = kind, x = 70, y = 70, w = 9, h = 6, door = "S", level = 1, palette = 2, id = 1 }
    local stages = Bp.stages(project)
    local same = #stages == 5
    for index, id in ipairs(ids) do if stages[index] == nil or stages[index].id ~= id then same = false end end
    check(kind .. " five stages", same)
    check(kind .. " foundation 54 and roof", #stages[1].ops == 54 and #stages[4].ops >= 54, #stages[1].ops .. "/" .. #stages[4].ops)
    check(kind .. " frame and walls 30", #stages[2].ops == 30 and #stages[3].ops == 30)
    local wall = stages[3].ops[1].e
    check(kind .. " palette walls", string.sub(wall, 1, 9) == "HouseBlue")
    local furniture, containers, storage, doors, windows = 0, 0, 0, 0, 0
    local seen, dup = {}, false
    for _, op in ipairs(stages[5].ops) do
        if op.t == "prop" then
            furniture = furniture + 1
            if op.container ~= nil then containers = containers + 1 end
            if op.storage then storage = storage + 1 end
            check(kind .. " sprite in catalog " .. op.sprite, known[op.sprite] == true)
            check(kind .. " prop inside " .. op.slot, op.x >= 70 and op.x <= 78 and op.y >= 70 and op.y <= 75)
        elseif op.t == "door" then doors = doors + 1
        elseif op.t == "window" then windows = windows + 1 end
        if seen[op.slot] then dup = true end
        seen[op.slot] = true
    end
    check(kind .. " furniture count " .. furniture, furniture == #Buildings.definitions[kind].furniture and furniture >= 20)
    check(kind .. " one door and windows", doors == 1 and windows >= 3)
    check(kind .. " unique slots", not dup)
    check(kind .. " storage none", storage == 0)
    if kind == "forge" then check("forge crates are crate containers", containers == 2)
    else check(kind .. " no containers", containers == 0) end
    local cost = Bp.cost(stages[5].ops)
    local good = true
    for key, amount in pairs(cost) do
        if (key ~= "planks" and key ~= "nails" and key ~= "metal") or amount <= 0 then good = false end
    end
    check(kind .. " finish cost stock kinds", good and (cost.planks or 0) > 0)
    local info = Bp.stageInfo(project)
    check(kind .. " stage info", #info == 5 and info[5].count == #stages[5].ops)
end

local function hasDoorCell(kind)
    for _, piece in ipairs(Buildings.definitions[kind].furniture) do
        if piece.dx == 4 and piece.dy == 5 then return true end
    end
    return false
end
check("door cell clear", not hasDoorCell("canteen") and not hasDoorCell("infirmary") and not hasDoorCell("forge"))

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

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Buildings")
camp.options.recruit = false
camp.phase = "plan"
settle(camp, 4)
Plan.generate(camp)
check("four people: nothing", count(camp, "canteen") == 0 and count(camp, "infirmary") == 0 and count(camp, "forge") == 0)
settle(camp, 5)
Plan.generate(camp)
check("five people: canteen only", count(camp, "canteen") == 1 and count(camp, "infirmary") == 0 and count(camp, "forge") == 0)
settle(camp, 6)
Plan.generate(camp)
check("six people: infirmary", count(camp, "canteen") == 1 and count(camp, "infirmary") == 1 and count(camp, "forge") == 0)
settle(camp, 8)
Plan.generate(camp)
Plan.generate(camp)
check("eight people: forge, one each", count(camp, "canteen") == 1 and count(camp, "infirmary") == 1 and count(camp, "forge") == 1)
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
settle(small, 9)
check("small camp has people", Store.settlerCount(small) >= 8, Store.settlerCount(small))
Plan.generate(small)
check("small plot: no new buildings", count(small, "canteen") == 0 and count(small, "infirmary") == 0 and count(small, "forge") == 0)

local function ready(project)
    project.status = "done"
    project.stage = 99
end
local canteen, infirmary, forge
for _, project in pairs(Build.plan(camp).items) do
    if project.kind == "canteen" then canteen = project elseif project.kind == "infirmary" then infirmary = project elseif project.kind == "forge" then forge = project end
end

check("mess without built canteen", Duty.mess(camp).kind ~= "canteen")
ready(canteen)
local mess = Duty.mess(camp)
check("mess finds built canteen", mess.kind == "canteen" and mess.indoor == true and mess.rect.x1 == canteen.x and mess.rect.x2 == canteen.x + 8 and mess.rect.y2 == canteen.y + 5)
check("mess point inside canteen", mess.x >= mess.rect.x1 and mess.x <= mess.rect.x2 and mess.y >= mess.rect.y1 and mess.y <= mess.rect.y2)

Health.wardCache = {}
check("no ward before infirmary built", Health.ward(camp, true) == nil)
ready(infirmary)
local ward = Health.ward(camp, true)
check("health finds built infirmary", ward ~= nil and ward.x1 == infirmary.x and ward.y1 == infirmary.y and ward.x2 == infirmary.x + 8 and ward.y2 == infirmary.y + 5 and ward.z == 0)
local point = Health.wardPoint(camp, "p1")
check("ward point inside", point ~= nil and point.x >= ward.x1 and point.x <= ward.x2 and point.y >= ward.y1 and point.y <= ward.y2)

local baseRecycle = Hooks.product("recycle", camp)
check("recycle multiplier unchanged before forge is built", baseRecycle > 0, baseRecycle)
ready(forge)
check("recycle multiplier 1.15 with forge", math.abs(Hooks.product("recycle", camp) / baseRecycle - 1.15) < 0.0001, Hooks.product("recycle", camp))
forge.retired = true
check("retired forge gives nothing", Hooks.product("recycle", camp) == 1)
forge.retired = nil

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
