dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampPerimeter.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Camp, Build, Plan, Bp, Gates, Posts, Entities, Options = A.Camp, A.Build, A.Plan, A.Blueprints, A.Gates, A.Posts, A.Entities, A.Options
local reg = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

local function fenceProject(wall, level)
    local project = { kind = "fence", x = 60, y = 60, w = 20, h = 12, gate = "S", level = level, wall = wall }
    project.gates = Gates.layout(project.w, project.h, "S")
    return project
end

local expect = {
    { wall = 1, piece = "WoodenWallLvl2", gate = "WoodenDoorLvl1" },
    { wall = 2, piece = "MetalWallLvl2", gate = "MetalDoorLvl2" },
    { wall = 3, piece = "StoneWall", gate = "MetalDoorLvl2" },
}
for _, row in ipairs(expect) do
    local stages = Bp.kinds.fence.build(fenceProject(row.wall, 3))
    check("wall " .. row.wall .. " has two stages", #stages == 2 and stages[1].id == "fence" and stages[2].id == "gate", #stages)
    local pieces, corners, others = 0, 0, 0
    for _, op in ipairs(stages[1].ops) do
        if op.t == "piece" and op.e == row.piece then pieces = pieces + 1 else others = others + 1 end
        if op.corner then corners = corners + 1 end
    end
    check("wall " .. row.wall .. " pieces", pieces > 40 and others == 0, pieces .. "/" .. others)
    check("wall " .. row.wall .. " corners", corners == pieces, corners)
    check("wall " .. row.wall .. " gate is an open drivable lane", #stages[2].ops == 0, #stages[2].ops)
    local gateSlots = 0
    for _, slot in ipairs(ALifeCamp.Blueprints.fenceSlots(fenceProject(row.wall, 3))) do
        if slot.gate then gateSlots = gateSlots + 1 end
    end
    check("wall " .. row.wall .. " gate opening is three tiles", gateSlots >= 3, gateSlots)
    check("wall " .. row.wall .. " wall entity exists", Entities[row.piece] ~= nil)
    local info = Bp.stageInfo(fenceProject(row.wall, 3))
    check("wall " .. row.wall .. " stage costs", info[1].cost.planks ~= nil and info[1].cost.planks > 0 and info[1].cost.nails > 0, info[1].cost.planks)
end

local stone = Bp.entityCost("StoneWall")
check("stone cost override", stone.planks == 3 and stone.nails == 4 and stone.metal == nil)
local metalWall = Bp.entityCost("MetalWallLvl2")
check("metal wall cost override", metalWall.planks == 2 and metalWall.nails == 6 and metalWall.metal == 1)
local metalDoor = Bp.entityCost("MetalDoorLvl2")
check("metal door cost override", metalDoor.planks == 4 and metalDoor.nails == 8 and metalDoor.metal == 2)
local wood = Bp.entityCost("WoodenWallLvl2")
check("wooden wall cost unchanged", wood.planks == 2 and wood.nails == 4)
local copy = Bp.entityCost("StoneWall")
copy.planks = 99
check("override not aliased", Bp.entityCost("StoneWall").planks == 3)

for level = 1, 3 do
    local stages = Bp.kinds.fence.build(fenceProject(nil, level))
    local wire = false
    for _, stage in ipairs(stages) do if stage.id == "wire" then wire = true end end
    local entity = level >= 3 and "WoodFenceLvl3" or (level == 2 and "WoodFenceLvl2" or "WoodFenceLvl1")
    check("legacy fence level " .. level, stages[1].ops[1].e == entity and stages[2].ops[1].e == "WoodFenceGate" and wire == (level >= 2), entity)
end

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 91, y2 = 85, z = 0 }, "Fort")
for level, tier in pairs({ [1] = 1, [2] = 2, [3] = 3, [4] = 3, [7] = 3 }) do
    camp.level = level
    check("auto tier level " .. level, Plan.fenceTier(camp) == tier, Plan.fenceTier(camp))
end
camp.level = 1
for chosen = 1, 3 do
    Options.set(camp, "wallTier", chosen)
    check("forced tier " .. chosen, Plan.fenceTier(camp) == chosen, Plan.fenceTier(camp))
end
camp.level = 3
Options.set(camp, "wallTier", 1)
check("forced tier beats level", Plan.fenceTier(camp) == 1)
Options.set(camp, "wallTier", 0)
check("zero is auto", Plan.fenceTier(camp) == 3)
local spec = Options.byKey.wallTier
check("option defined", spec ~= nil and spec.kind == "cycle" and spec.default == 0 and spec.group == "camp" and spec.priority == 20 and #spec.values == 4)

camp.level = 2
camp.options.recruit = false
camp.phase = "plan"
Plan.generate(camp)
local fence
for _, project in ipairs(Build.list(camp)) do if project.kind == "fence" then fence = project end end
check("generated fence carries tier", fence ~= nil and fence.wall == 2, fence and fence.wall)
local added = Build.add(camp, "campfire", 70, 70, {})
check("project without wall option has no wall", added == nil or added.wall == nil)

local names = {}
local function note(name)
    if name ~= nil then names[name] = true end
end

local hesco = { fencing_01_96 = true, fencing_01_97 = true, fencing_01_100 = true, fencing_01_101 = true, fencing_01_102 = true, fencing_01_103 = true }
local boomBase = { N = 64, S = 64, E = 56, W = 56 }
local jersey = { N = "street_decoration_01_29", S = "street_decoration_01_29", E = "street_decoration_01_28", W = "street_decoration_01_28" }
local gx, gy = 80, 80
for _, side in ipairs({ "N", "S", "E", "W" }) do
    local frame = Posts.outFrame(side, gx, gy)
    local x, y, w, h = Gates.rect(frame, Posts.apronLeft, 0, Posts.apronRight, Posts.apronDepth)
    local project = { kind = "post", x = x, y = y, w = w, h = h, gside = side, gx = gx, gy = gy }
    check(side .. " apron size", w * h == 54 and #Posts.apronRows == 6 and #Posts.apronRows[1] == 9, w .. "x" .. h)
    local stages = Bp.kinds.post.build(project)
    local furnish
    for _, stage in ipairs(stages) do if stage.id == "furnish" then furnish = stage end end
    check(side .. " has furnish stage", furnish ~= nil)
    local at = {}
    for _, op in ipairs(furnish.ops) do
        local u, v = Gates.toLocal(frame, op.x, op.y)
        at[(u + 0) .. ":" .. (v + 0)] = op.sprite
        note(op.sprite)
    end
    local blocked = 0
    for u = -1, 1 do
        for v = 0, 5 do
            local sprite = at[u .. ":" .. v]
            if sprite ~= nil and (hesco[sprite] or sprite == jersey[side]) then blocked = blocked + 1 end
        end
    end
    check(side .. " lane free of hesco and jersey", blocked == 0, blocked)
    local base = boomBase[side]
    check(side .. " boom post", at["-2:1"] == "street_decoration_01_" .. base, at["-2:1"])
    check(side .. " boom arm 1", at["-1:1"] == "street_decoration_01_" .. (base + 1), at["-1:1"])
    check(side .. " boom arm 2", at["0:1"] == "street_decoration_01_" .. (base + 2), at["0:1"])
    check(side .. " boom arm 3", at["1:1"] == "street_decoration_01_" .. (base + 3), at["1:1"])
    local jerseyOk = true
    for v = 0, 4 do
        if v ~= 1 and at["-2:" .. v] ~= jersey[side] then jerseyOk = false end
        if at["2:" .. v] ~= jersey[side] then jerseyOk = false end
    end
    check(side .. " jersey barriers on both lane edges", jerseyOk, tostring(at["-2:0"]) .. "/" .. tostring(at["2:2"]))
    local heavyOk = true
    for _, key in ipairs({ "-4:0", "-3:0", "-4:1", "-3:1", "3:0", "4:0", "3:1", "4:1", "3:3" }) do
        if not hesco[at[key] or ""] then heavyOk = false end
    end
    check(side .. " hesco blocks at corners", heavyOk)
    check(side .. " other tokens kept", at["-4:2"] ~= nil and at["-3:2"] ~= nil and at["-3:3"] ~= nil and at["-4:4"] ~= nil and at["-3:5"] ~= nil)
end

local variety = {}
for xs = 100, 130 do
    local frame = Posts.outFrame("S", xs, 90)
    local x, y, w, h = Gates.rect(frame, Posts.apronLeft, 0, Posts.apronRight, Posts.apronDepth)
    local stages = Bp.kinds.post.build({ kind = "post", x = x, y = y, w = w, h = h, gside = "S", gx = xs, gy = 90 })
    for _, op in ipairs(stages[#stages].ops) do if hesco[op.sprite] then variety[op.sprite] = true end end
end
local kinds = 0
for _ in pairs(variety) do kinds = kinds + 1 end
check("hesco picks vary across posts", kinds >= 4, kinds)

check("other schemes untouched", Posts.bayRows[1] == "c...Z" and Posts.rangeRows[1] == "SSSSSSSSSS" and Posts.poolRows[1] == "L..........L")

local hescoSet = { fencing_01_96 = true, fencing_01_97 = true, fencing_01_100 = true, fencing_01_101 = true, fencing_01_102 = true, fencing_01_103 = true }
local jerseySet = { street_decoration_01_28 = true, street_decoration_01_29 = true }
local wireSet = { fencing_01_20 = true, fencing_01_21 = true }
local function houseRects(c)
    local rects = {}
    for _, project in pairs(Build.plan(c).items) do
        if project.kind ~= "fence" and not Posts.isPostKind(project.kind) and not project.retired then
            rects[#rects + 1] = Bp.footprint(project)
        end
    end
    return rects
end
local postProject
for _, project in ipairs(Posts.projects(camp, "post")) do postProject = project end
check("checkpoint: a gate post project exists", postProject ~= nil and postProject.gside ~= nil)
if postProject ~= nil then
    local out = Posts.outFrame(postProject.gside, postProject.gx, postProject.gy)
    local wallKey = postProject.gside
    local inside, laneBlocked, nad, wire, wing, apronCells = 0, 0, 0, 0, 0, 0
    local outwardOk = true
    for _, stage in ipairs(Bp.kinds.post.build(postProject)) do
        for _, op in ipairs(stage.ops) do
            local u, v = Gates.toLocal(out, op.x, op.y)
            if A.Geo.contains(camp, op.x, op.y) then inside = inside + 1 end
            if wallKey == "S" and op.y <= camp.y2 then outwardOk = false end
            if wallKey == "N" and op.y >= camp.y1 then outwardOk = false end
            if wallKey == "E" and op.x <= camp.x2 then outwardOk = false end
            if wallKey == "W" and op.x >= camp.x1 then outwardOk = false end
            if op.t == "dirt" and math.abs(u) <= 1 then apronCells = apronCells + 1 end
            if op.t == "prop" and math.abs(u) <= 1 and (hescoSet[op.sprite] or jerseySet[op.sprite] or wireSet[op.sprite]) then laneBlocked = laneBlocked + 1 end
            if v == Posts.apronDepth + 1 and jerseySet[op.sprite] then nad = nad + 1 end
            if v == Posts.apronDepth + 1 and wireSet[op.sprite] then wire = wire + 1 end
            if math.abs(u) > Posts.apronRight and hescoSet[op.sprite] then wing = wing + 1 end
        end
    end
    check("checkpoint: nothing is built inside the camp", inside == 0, inside)
    check("checkpoint: whole apron sits beyond the wall, outward", outwardOk)
    check("checkpoint: 3-wide drive-through stays open", laneBlocked == 0 and apronCells > 0, laneBlocked .. "/" .. apronCells)
    check("checkpoint: anti-tank nadoby face the street", nad >= 2, nad)
    check("checkpoint: barbed wire mesh on the street side", wire >= 1, wire)
    check("checkpoint: hesco wings flare outward (funnel)", wing >= 4, wing)
    local overlap = false
    local fp = Bp.footprint(postProject)
    for _, rect in ipairs(houseRects(camp)) do
        if A.Geo.overlaps(fp, rect) then overlap = true end
    end
    check("checkpoint: no overlap with houses or districts", not overlap)
end

for _, row in ipairs(expect) do
    for _, id in ipairs({ row.piece, row.gate }) do
        local entity = Entities[id]
        for _, rows in pairs(entity.faces) do
            for _, list in ipairs(rows) do for _, name in ipairs(list) do note(name) end end
        end
        note(entity.corner)
    end
end

local out = io.open("fortress_sprites.txt", "w")
local list = {}
for name in pairs(names) do list[#list + 1] = name end
table.sort(list)
out:write(table.concat(list, "\n"))
out:close()
check("sprite list written", #list >= 20, #list)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
