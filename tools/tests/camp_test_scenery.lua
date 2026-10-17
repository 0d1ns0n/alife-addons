dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings3", "Houses" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Hooks, Scenery, Entities = A.Store, A.Camp, A.Build, A.Blueprints, A.Hooks, A.Scenery, A.Entities
local reg = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
for x = 60, 100 do for y = 60, 100 do NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 500

check("module loaded", Scenery ~= nil and Scenery.kinds ~= nil)

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

local stockOnly = { planks = true, nails = true }
for _, id in ipairs({ "CampDecoFree", "CampDecoNail", "CampDecoCloth", "CampDecoLight" }) do
    local cost = Bp.entityCost(id)
    local good = Entities[id] ~= nil
    for kind, amount in pairs(cost) do
        if not stockOnly[kind] or amount > 2 then good = false end
    end
    check("entity " .. id .. " cheap boards and nails", good)
end
local freeCount = 0
for _ in pairs(Bp.entityCost("CampDecoFree")) do freeCount = freeCount + 1 end
check("free entity costs nothing", freeCount == 0)
check("light entity costs plank and nail", Bp.entityCost("CampDecoLight").planks == 1 and Bp.entityCost("CampDecoLight").nails == 1)

local function wrapped(kind)
    return Bp.kinds[kind].sceneryBuild
end

for _, kind in ipairs({ "market", "plaza", "well", "garden", "memorial" }) do
    check(kind .. " wrapped", type(wrapped(kind)) == "function")
end
check("workyard untouched", Bp.kinds.workyard.sceneryBuild == nil)
check("checkpoint untouched", Bp.kinds.checkpoint.sceneryBuild == nil)

local function decorOf(stages)
    local out = {}
    for _, stage in ipairs(stages) do
        for _, op in ipairs(stage.ops) do
            if string.sub(op.slot, 1, 2) == "SC" then out[#out + 1] = op end
        end
    end
    return out
end

local function key(x, y) return x * 65536 + y end

local function verify(label, project, minCount)
    local original = wrapped(project.kind)(project)
    local stages = Bp.stages(project)
    check(label .. " stage ids kept", #stages == #original or (#stages == #original + 1 and stages[#stages].id == "furnish"))
    for index, stage in ipairs(original) do
        check(label .. " stage " .. stage.id .. " keeps original ops", stages[index].id == stage.id and #stages[index].ops >= #stage.ops)
        for i, op in ipairs(stage.ops) do
            if stages[index].ops[i] ~= nil and stages[index].ops[i].slot ~= op.slot then
                check(label .. " original op order", false, stage.id .. "/" .. i)
            end
        end
    end
    local extra = decorOf(stages)
    check(label .. " decor count " .. #extra, #extra >= minCount, #extra)
    local seen, dup, claimed, outside, badSprite, priced = {}, false, {}, false, nil, true
    for _, stage in ipairs(original) do
        for _, op in ipairs(stage.ops) do
            if op.t ~= "dirt" and (op.z or 0) == 0 then claimed[key(op.x, op.y)] = true end
        end
    end
    for _, op in ipairs(stages[#stages].ops) do
        if seen[op.slot] then dup = true end
        seen[op.slot] = true
    end
    local overlap, raised, covers = 0, 0, 0
    local solidCells = {}
    for _, op in ipairs(extra) do
        if op.x < project.x or op.x >= project.x + project.w or op.y < project.y or op.y >= project.y + project.h then outside = true end
        if not known[op.sprite] then badSprite = op.sprite end
        if op.t ~= "prop" or Entities[op.e] == nil then priced = false end
        if (op.z or 0) == 1 then raised = raised + 1
        elseif string.find(op.sprite, "walls_decoration", 1, true) then covers = covers + 1
        else
            if claimed[key(op.x, op.y)] then overlap = overlap + 1 end
            if solidCells[key(op.x, op.y)] then overlap = overlap + 1 end
            solidCells[key(op.x, op.y)] = true
        end
    end
    check(label .. " unique slots", not dup)
    check(label .. " decor inside project", not outside)
    check(label .. " sprites exist in catalog", badSprite == nil, badSprite)
    check(label .. " decor never on project objects", overlap == 0, overlap)
    check(label .. " decor ops priced by entities", priced)
    local total = Bp.cost(extra)
    local good = true
    for k in pairs(total) do
        if not stockOnly[k] then good = false end
    end
    check(label .. " decor cost boards and nails only", good and (total.planks or 0) <= 12 and (total.nails or 0) <= 40, (total.planks or 0) .. "/" .. (total.nails or 0))
    return extra, raised, covers
end

local market, _, covers = verify("market", { kind = "market", x = 70, y = 70, w = 11, h = 4, id = 1 }, 14)
check("market awnings on every stall", covers == 6, covers)
local red, blue = 0, 0
for _, op in ipairs(market) do
    if op.sprite == "walls_decoration_01_100" then red = red + 1 end
    if op.sprite == "walls_decoration_01_84" then blue = blue + 1 end
end
check("market awnings alternate colors", red > 0 and blue > 0, red .. "/" .. blue)
local other = decorOf(Bp.stages({ kind = "market", x = 71, y = 70, w = 11, h = 4, id = 2 }))
local firstA, firstB
for _, op in ipairs(market) do if string.find(op.sprite, "walls_decoration", 1, true) then firstA = op.sprite break end end
for _, op in ipairs(other) do if string.find(op.sprite, "walls_decoration", 1, true) then firstB = op.sprite break end end
check("market start color varies by project", firstA ~= firstB, tostring(firstA) .. "/" .. tostring(firstB))
verify("market narrow", { kind = "market", x = 70, y = 70, w = 7, h = 4, id = 3 }, 6)

verify("well", { kind = "well", x = 70, y = 80, w = 5, h = 5, id = 4 }, 5)
verify("garden", { kind = "garden", x = 70, y = 90, w = 7, h = 6, id = 5 }, 8)
local memorial = verify("memorial", { kind = "memorial", x = 80, y = 90, w = 6, h = 5, id = 6 }, 10)
local skulls = 0
for _, op in ipairs(memorial) do
    if string.find(op.sprite, "constructedobjects_signs_01_", 1, true) and op.sprite ~= "constructedobjects_signs_01_11" then skulls = skulls + 1 end
end
check("memorial skull posts around", skulls == 4, skulls)

local garden = decorOf(Bp.stages({ kind = "garden", x = 70, y = 90, w = 7, h = 6, id = 5 }))
local gardenSprites = {}
for _, op in ipairs(garden) do gardenSprites[op.sprite] = true end
check("garden scarecrow compost hay barrels roses", gardenSprites["location_farm_accesories_01_36"] and gardenSprites["carpentry_02_116"]
    and gardenSprites["vegetation_farm_01_10"] and gardenSprites["carpentry_02_120"] and gardenSprites["vegetation_gardening_01_4"])

local function plazaParts(side, radius)
    local fx, fy = 80, 80
    local rects = {
        { fx - radius, fy - radius, 2 * radius + 1, radius - 1 }, { fx - radius, fy + 2, 2 * radius + 1, radius - 1 },
        { fx - radius, fy - 1, radius - 1, 3 }, { fx + 2, fy - 1, radius - 1, 3 },
    }
    local list = {}
    for index, r in ipairs(rects) do
        list[index] = { kind = "plaza", x = r[1], y = r[2], w = r[3], h = r[4], fx = fx, fy = fy, radius = radius, gate = side, id = 10 + index }
    end
    return list
end

for _, side in ipairs({ "S", "N", "E", "W" }) do
    for radius = 3, 6 do
        local label = "plaza " .. side .. radius
        local wells, poles, flags, boards, total, dupCells = 0, 0, 0, 0, 0, false
        local cells = {}
        for _, part in ipairs(plazaParts(side, radius)) do
            local extra = verify(label .. " part", part, 0)
            for _, op in ipairs(extra) do
                total = total + 1
                if op.sprite == "camping_01_16" then wells = wells + 1 end
                if op.sprite == "street_decoration_01_24" then poles = poles + 1 end
                if op.sprite == "street_decoration_01_16" then flags = flags + 1 end
                if string.find(op.sprite, "office_generic_01", 1, true) then boards = boards + 1 end
                local id = op.x .. ":" .. op.y .. ":" .. (op.z or 0)
                if cells[id] then dupCells = true end
                cells[id] = true
            end
        end
        check(label .. " one well pole flag board", wells == 1 and poles == 1 and flags == 1 and boards == 1, wells .. poles .. flags .. boards)
        check(label .. " no duplicate cells across parts", not dupCells)
        check(label .. " decor present", total >= 6, total)
    end
end

local function wellOf(side)
    local found = {}
    for _, part in ipairs(plazaParts(side, 5)) do
        for _, op in ipairs(decorOf(Bp.stages(part))) do
            if op.sprite == "camping_01_16" then found = op end
        end
    end
    return found
end
local w = wellOf("S")
check("plaza well opposite to gate S", w.x == 80 and w.y == 76, tostring(w.x) .. "," .. tostring(w.y))
w = wellOf("N")
check("plaza well opposite to gate N", w.x == 80 and w.y == 84, tostring(w.x) .. "," .. tostring(w.y))
w = wellOf("E")
check("plaza well opposite to gate E", w.x == 76 and w.y == 80, tostring(w.x) .. "," .. tostring(w.y))
w = wellOf("W")
check("plaza well opposite to gate W", w.x == 84 and w.y == 80, tostring(w.x) .. "," .. tostring(w.y))

local tiny = plazaParts("S", 2)[1]
local okTiny, stagesTiny = pcall(Bp.stages, tiny)
check("plaza radius two skipped", okTiny and #decorOf(stagesTiny) == 0)

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 99, z = 0 }, "Scenery")
camp.options.recruit = false
camp.phase = "plan"
camp.stock = { planks = 500, nails = 500, logs = 50, metal = 50, rope = 50 }

local function run(project)
    local guard = 0
    while project.status ~= "done" and guard < 12 do
        guard = guard + 1
        Build.work(camp, project, 50, 30)
    end
end

local function objectsAt(x, y, z)
    local square = A.World.square(x, y, z or 0)
    local n = 0
    if square ~= nil then n = square:getObjects():size() end
    return n
end

local baseMorale = Hooks.sum("morale", camp)
local baseFarm = Hooks.product("farm", camp)

local market1 = Build.add(camp, "market", 62, 62)
check("market added", market1 ~= nil)
local garden1 = Build.add(camp, "garden", 62, 70)
local memorial1 = Build.add(camp, "memorial", 72, 70)
local well1 = Build.add(camp, "well", 82, 70)
check("projects added", garden1 ~= nil and memorial1 ~= nil and well1 ~= nil)

check("nothing built: no bonus", Hooks.sum("morale", camp) == baseMorale and Hooks.product("farm", camp) == baseFarm)

for _, project in ipairs({ market1, garden1, memorial1, well1 }) do run(project) end
check("market built", market1.status == "done", market1.status .. " stage " .. market1.stage)
check("garden built", garden1.status == "done")
check("memorial built", memorial1.status == "done")
check("well built", well1.status == "done")
local decorKeys = 0
for slot in pairs(market1.done) do if string.find(slot, "/SC", 1, true) then decorKeys = decorKeys + 1 end end
check("market decor applied", decorKeys >= 14, decorKeys)
check("decor placed in world", objectsAt(63, 64) >= 1 and objectsAt(64, 64) >= 1)
check("market decorated flag", Scenery.decorated(market1) == true and market1.scenic == true)
check("garden decorated flag", Scenery.decorated(garden1) == true)
check("memorial decorated flag", Scenery.decorated(memorial1) == true)

check("morale +2 for market and memorial", Hooks.sum("morale", camp) - baseMorale == 2, Hooks.sum("morale", camp) - baseMorale)
check("farm factor 1.05 for garden", math.abs(Hooks.product("farm", camp) / baseFarm - 1.05) < 0.0001, Hooks.product("farm", camp))
check("overview line", #Hooks.collect("overview", camp) >= 1)

local function fake(kind, id, scenic, status)
    local project = { id = id, camp = camp.id, kind = kind, x = 10, y = 10, w = 1, h = 1, stage = 3, status = status or "done", work = 0, paid = false, done = {} }
    if scenic then project.done["furnish/SC1"] = true end
    Build.plan(camp).items[tostring(id)] = project
    return project
end
fake("market", 801, false)
fake("market", 802, false)
fake("market", 803, false)
check("morale capped at three", Hooks.sum("morale", camp) - baseMorale == 3, Hooks.sum("morale", camp) - baseMorale)
local plain = fake("memorial", 804, false)
check("memorial without decor gives nothing", Scenery.decorated(plain) == false)
local unfinished = fake("garden", 805, true, "active")
check("unfinished decorated garden not counted", Scenery.decorated(unfinished) == false)
fake("garden", 806, true)
check("farm bonus not stacking", math.abs(Hooks.product("farm", camp) / baseFarm - 1.05) < 0.0001)
market1.retired = true
check("retired market not counted", (Scenery.counts(camp)) == 3)
market1.retired = nil

local fresh = Camp.create({ x1 = 60, y1 = 20, x2 = 99, y2 = 29, z = 0 }, "Fresh")
check("fresh camp neutral", Scenery.morale(fresh) == 0 and Scenery.farm(fresh) == 1)

for index = #PRINTS, 1, -1 do PRINTS[index] = nil end
Hooks.each("minute", camp, 1)
Hooks.each("minute", camp, 1)
local function diagLines()
    local lines = 0
    for _, line in ipairs(PRINTS) do
        if string.find(line, "[ALifeCamp:Scenery]", 1, true) then lines = lines + 1 end
    end
    return lines
end
check("diagnostic line once per hour", diagLines() == 1, diagLines())
HOURS = HOURS + 1
Hooks.each("minute", camp, 1)
check("diagnostic line next hour", diagLines() == 2, diagLines())

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
check("camp stays serializable", pure(camp.plan))

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
