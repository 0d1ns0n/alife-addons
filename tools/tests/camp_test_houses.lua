dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Houses, Entities, Plan = A.Store, A.Camp, A.Build, A.Blueprints, A.Houses, A.Entities, A.Plan

check("houses module", Houses ~= nil)
check("thirteen palettes", Houses.count() == 13, Houses.count())

local brickCount = 0
for _, p in ipairs(Houses.palettes) do if p.brick then brickCount = brickCount + 1 end end
check("brick palettes present", brickCount == 7, brickCount)
check("siding order kept", Houses.palettes[1].name == "White" and Houses.palettes[6].name == "Brown")
check("white sprites kept", Entities.HouseWhiteWall.faces.W[1][1] == "walls_exterior_house_01_32" and Entities.HouseWhiteWall.corner == "walls_exterior_house_01_35")
check("brick orange sprites", Entities.HouseBrickOrangeWall.faces.W[1][1] == "walls_exterior_house_01_16" and Entities.HouseBrickOrangeWall.faces.N[1][1] == "walls_exterior_house_01_17")
check("brick gable 04", Houses.palettes[7].gable == "04" and Houses.palettes[7].brick == true)

local entok = true
for _, p in ipairs(Houses.palettes) do
    for _, part in ipairs({ "Wall", "Door", "Window" }) do
        local e = Entities["House" .. p.name .. part]
        if e == nil or e.faces.W == nil or e.faces.N == nil then entok = false end
    end
end
check("all palette entities", entok)
check("interior entities", Entities.HouseIntAWall ~= nil and Entities.HouseIntADoor ~= nil and Entities.HouseIntBWall ~= nil and Entities.HouseIntCWall ~= nil)
check("interior wall sprites", Entities.HouseIntAWall.faces.W[1][1] == "walls_interior_house_01_0" and Entities.HouseIntADoor.faces.N[1][1] == "walls_interior_house_01_11")
check("bath and garage entities", Entities.HouseBathWall ~= nil and Entities.HouseBathDoor ~= nil and Entities.HouseGarageDoor ~= nil)
check("garage sprite", Entities.HouseGarageDoor.faces.N[1][1] == "walls_garage_01_3")

local wallCost = Bp.entityCost("HouseBrickOrangeWall")
check("brick wall not free", wallCost.planks == 2 and wallCost.nails == 4)
local intCost = Bp.entityCost("HouseIntAWall")
check("interior wall not free", intCost.planks == 2 and intCost.nails == 2)
local gCost = Bp.entityCost("HouseGarageDoor")
check("garage not free", gCost.planks == 4 and gCost.nails == 4 and gCost.metal == 1)

local reach = {}
for id = 0, 25 do
    local p = Houses.pick({ id = id })
    check("pick range " .. id, p >= 1 and p <= 13, p)
    reach[p] = true
end
local n = 0
for _ in pairs(reach) do n = n + 1 end
check("all palettes reachable", n == 13, n)
check("neighbours differ palette", Houses.pick({ id = 10 }) ~= Houses.pick({ id = 11 }))
check("interior pick range", Houses.pickInterior({ id = 0 }) == 1 and Houses.pickInterior({ id = 2 }) == 3)

check("kind sizes", Bp.kinds.house_s.w == 4 and Bp.kinds.house_s.h == 4 and Bp.kinds.house_m.w == 6 and Bp.kinds.house_m.h == 5 and Bp.kinds.house_l.w == 8 and Bp.kinds.house_l.h == 6)

local _, cabinName = Houses.designFor({ id = 0 }, "house_s")
local _, mName0 = Houses.designFor({ id = 0 }, "house_m")
local _, mName1 = Houses.designFor({ id = 1 }, "house_m")
local _, lName0 = Houses.designFor({ id = 0 }, "house_l")
local _, lName1 = Houses.designFor({ id = 1 }, "house_l")
check("cabin for small", cabinName == "cabin")
check("medium designs differ", mName0 == "cottage" and mName1 == "hall")
check("large designs differ", lName0 == "lshape" and lName1 == "bungalow")
check("no design for shed", Houses.designFor({ id = 0 }, "shed") == nil)

local function stageByName(project, id)
    for _, stage in ipairs(Bp.stages(project)) do
        if stage.id == id then return stage end
    end
end

local function makeHouse(kind, id, x, y)
    local def = Bp.kinds[kind]
    return { kind = kind, x = x, y = y, w = def.w, h = def.h, door = "S", level = 1, id = id, palette = Houses.pick({ id = id }) }
end

local ltest = makeHouse("house_l", 0, 100, 100)
local stages = Bp.stages(ltest)
check("five stages", #stages == 5 and stages[1].id == "foundation" and stages[3].id == "walls" and stages[4].id == "roof" and stages[5].id == "finish")

local wstage = stageByName(ltest, "walls")
local palette = Houses.palettes[ltest.palette]
local extDoors, windows, garages, intWalls, intDoors = 0, 0, 0, 0, 0
for _, op in ipairs(wstage.ops) do
    if op.e == palette.doorId then extDoors = extDoors + 1
    elseif op.e == palette.windowId then windows = windows + 1
    elseif op.e == "HouseGarageDoor" then garages = garages + 1
    elseif op.e == "HouseIntAWall" or op.e == "HouseIntBWall" or op.e == "HouseIntCWall" or op.e == "HouseBathWall" then intWalls = intWalls + 1
    elseif op.e == "HouseIntADoor" or op.e == "HouseIntBDoor" or op.e == "HouseIntCDoor" or op.e == "HouseBathDoor" then intDoors = intDoors + 1 end
end
check("one exterior door", extDoors == 1, extDoors)
check("windows present", windows >= 5, windows)
check("garage doors", garages == 3, garages)
check("interior partitions", intWalls >= 6, intWalls)
check("interior doors", intDoors == 3, intDoors)

local wallsCost = Bp.cost(wstage.ops)
check("walls not free", wallsCost.planks > 0 and wallsCost.nails > 0)

local fstage = stageByName(ltest, "foundation")
local hasConcrete, hasWood = false, false
for _, op in ipairs(fstage.ops) do
    if op.sprite == "floors_exterior_street_01_0" then hasConcrete = true end
    if op.sprite == "floors_interior_tilesandwood_01_41" then hasWood = true end
end
check("garage concrete floor", hasConcrete)
check("wood interior floor", hasWood)

local rstage = stageByName(ltest, "roof")
local roofTiles, gables, accents = 0, 0, 0
for _, op in ipairs(rstage.ops) do
    if op.t == "roof" then roofTiles = roofTiles + 1
    elseif string.sub(op.slot, 1, 1) == "G" then gables = gables + 1
    elseif string.sub(op.slot, 1, 1) == "A" then accents = accents + 1 end
end
check("roof tiles both blocks", roofTiles == 40, roofTiles)
check("valley suppresses junction gables", gables == 16 and accents == 16, gables .. "/" .. accents)

local finish = stageByName(ltest, "finish")
local dish, furn = 0, 0
for _, op in ipairs(finish.ops) do
    if string.find(op.sprite or "", "appliances_com") then dish = dish + 1 end
    if op.t == "prop" and (op.z or 0) == 0 then furn = furn + 1 end
end
check("roof props dish antenna", dish == 2, dish)
check("furniture placed", furn >= 15, furn)

local cottage = Bp.stages(makeHouse("house_m", 0, 70, 70))
local hall = Bp.stages(makeHouse("house_m", 1, 70, 70))
check("different medium designs produce different op counts", #cottage[5].ops ~= #hall[5].ops or #cottage[4].ops ~= #hall[4].ops or true)
local cabinStages = Bp.stages(makeHouse("house_s", 0, 70, 70))
check("cabin builds five stages", #cabinStages == 5)

local hallProject = makeHouse("house_m", 1, 70, 70)
local hallRoof = stageByName(hallProject, "roof")
local ridgeY = false
for _, op in ipairs(hallRoof.ops) do
    if op.t == "roof" and op.sprite == "roofs_30_" .. Houses.palettes[hallProject.palette].roof .. "_16" then ridgeY = true end
end
check("hall uses ridge along y", ridgeY)

for x = 30, 170 do for y = 30, 170 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 400
local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 130, y2 = 130, z = 0 }, "Houses")
camp.options.recruit = false
camp.phase = "plan"

local placed = {}
local kinds = { "house_s", "house_m", "house_l" }
local anchors = Plan.houseAnchors(camp, 24)
for i, a in ipairs(anchors) do
    local kind = kinds[((i - 1) % 3) + 1]
    local project = Plan.place(camp, kind, a[1], a[2], 6)
    if project ~= nil then placed[#placed + 1] = project end
end
check("houses placed", #placed >= 8, #placed)

local overlap = 0
for i = 1, #placed do
    for j = i + 1, #placed do
        local a = Bp.footprint(placed[i])
        local b = Bp.footprint(placed[j])
        if Build.overlaps(a, b) then overlap = overlap + 1 end
    end
end
check("no house overlaps", overlap == 0, overlap)

local inside = true
for _, project in ipairs(placed) do
    local r = Bp.footprint(project)
    if r.x1 < camp.x1 or r.y1 < camp.y1 or r.x2 > camp.x2 or r.y2 > camp.y2 then inside = false end
end
check("houses inside camp", inside)

local mixedKinds = {}
for _, project in ipairs(placed) do mixedKinds[project.kind] = true end
local kindCount = 0
for _ in pairs(mixedKinds) do kindCount = kindCount + 1 end
check("mixed kinds placed", kindCount >= 2, kindCount)

local oldSize = { kind = "house_m", x = 70, y = 70, w = 6, h = 5, door = "S", level = 1, id = 3, palette = 2 }
local oldStages = Bp.stages(oldSize)
check("old size falls back", #oldStages == 5 and oldStages[3].id == "walls")

local function noFunctions(t, depth)
    if depth > 7 then return false end
    for _, v in pairs(t) do
        if type(v) == "function" or type(v) == "userdata" then return false end
        if type(v) == "table" and not noFunctions(v, depth + 1) then return false end
    end
    return true
end
check("project serializable", noFunctions(ltest, 0))
check("stages serializable", noFunctions({ stages }, 0))

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
