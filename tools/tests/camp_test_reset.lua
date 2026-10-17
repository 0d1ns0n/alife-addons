dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Stock, World, Reset = A.Store, A.Camp, A.Build, A.Stock, A.World, A.Reset

check("reset module loaded", Reset ~= nil)
for x = 40, 130 do for y = 40, 130 do NEWSQUARE(x, y, 0) NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 700

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Reset")
camp.options.recruit = false
camp.options.autoPlan = false
camp.phase = "build"

local function tagged(projectId)
    local n = 0
    for x = 55, 105 do
        for y = 55, 95 do
            for z = 0, 1 do
                local sq = World.square(x, y, z)
                for _, o in ipairs(sq.objects) do
                    local tag = o.mod and o.mod.ALC
                    if type(tag) == "table" and tag.project ~= nil and (projectId == nil or tag.project == projectId) then n = n + 1 end
                end
            end
        end
    end
    return n
end

local house = Build.add(camp, "house_s", 64, 64, {})
local shed = Build.add(camp, "shed", 76, 64, {})
local fence = Build.add(camp, "fence", camp.x1, camp.y1, { w = 40, h = 30 })
local built = 0
for _, project in ipairs({ house, shed }) do
    if project ~= nil and A.Cheats ~= nil and A.Cheats.complete(camp, project) then built = built + 1 end
end
check("two projects built for the test", built == 2, built)
check("objects exist", tagged() > 20, tagged())

local initial = Stock.crate(camp, camp.storage[1])
for _ = 1, 5 do initial:getContainer():AddItem("Base.Nails") end
local shedCrate
for _, entry in ipairs(camp.storage) do
    local object = Stock.crate(camp, entry)
    local tag = object ~= nil and World.tag(object) or nil
    if tag ~= nil and tag.project == shed.id then shedCrate = object end
end
check("shed crate registered", shedCrate ~= nil)
if shedCrate ~= nil then
    for _ = 1, 7 do shedCrate:getContainer():AddItem("Base.Plank") end
end
Stock.refresh(camp)
local plankBefore = camp.stock.planks

local result = Reset.run(camp)
check("projects demolished", result.projects == 3 and result.far == 0, result.projects .. "/" .. result.far)
check("no project objects remain", tagged() == 0, tagged())
check("plan emptied of the demolished projects", Build.get(camp, house.id) == nil and Build.get(camp, shed.id) == nil)
check("phase back to plan", camp.phase == "plan")
Stock.refresh(camp)
check("shed crate items moved to the initial crate", camp.stock.planks >= plankBefore, camp.stock.planks .. "/" .. plankBefore)
check("storage list has no dead crates", #camp.storage == 1 and Stock.crate(camp, camp.storage[1]) ~= nil, #camp.storage)
local hasFloor = true
for x = 64, 67 do
    for y = 64, 67 do
        if World.square(x, y, 0):getFloor() == nil then hasFloor = false end
    end
end
check("ground restored where floors were", hasFloor)

local second = Reset.run(camp)
check("second reset is harmless", second.projects <= 1 and not second.blocked)

local far = Build.add(camp, "house_s", 64, 70, {})
A.Cheats.complete(camp, far)
NEWSQUARE = NEWSQUARE
local sq = World.square(65, 71, 0)
local keep = sq
local cell = getCell()
local original = cell.getGridSquare
getCell = function() return { getGridSquare = function(_, x, y, z) if x == 65 and y == 71 and z == 0 then return nil end return original(cell, x, y, z) end } end
local partial = Reset.run(camp)
check("unloaded squares keep the project", partial.far >= 1 and Build.get(camp, far.id) ~= nil, partial.far)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
