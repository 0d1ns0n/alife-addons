dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
SKIPMOD["shared/ALifeCamp/CampSupply.lua"] = nil
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Settlers, Work, Duty, Options, Hooks, Stock, Supply = A.Store, A.Camp, A.Build, A.Settlers, A.Work, A.Duty, A.Options, A.Hooks, A.Stock, A.Supply
local reg, orders = MOCKALIFE()

check("supply module loaded", Supply ~= nil)
if Supply == nil then
    RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = {} }
    return
end

for x = 20, 145 do for y = 20, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 500

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Supply")
camp.options.recruit = false
camp.options.autoPlan = false
camp.phase = "build"

local crate = Stock.crate(camp, camp.storage[1])
local box = crate:getContainer()
for _ = 1, 12 do box:AddItem("Base.Plank") end
for _ = 1, 400 do box:AddItem("Base.Nails") end
Stock.refresh(camp)

local big = Build.add(camp, "house_l", 64, 64, {})
big.prepared = true
check("project added", big ~= nil)

local roster = { { "b1", "builder" }, { "w1", "worker" }, { "s1", "scavenger" }, { "g1", "guard" }, { "f1", "farmer" } }
for i, row in ipairs(roster) do
    local x, y = 70 + i, 74
    ADDACTOR(reg, row[1], "friendly", x, y, A.World.square(x, y, 0))
    Settlers.settle(camp, row[1], row[1])
    camp.settlers[row[1]].role = row[2]
end

local trees = {}
for i = 1, 6 do
    trees[i] = { x = 52 + i, y = 70 }
    NEWTREE(A.World.square(trees[i].x, trees[i].y, 0))
end
local function treeCount()
    local n = 0
    for _, t in ipairs(trees) do
        local sq = A.World.square(t.x, t.y, 0)
        for _, o in ipairs(sq.objects) do if o.class == "IsoTree" then n = n + 1 end end
    end
    return n
end
check("six trees standing", treeCount() == 6)

local need = Supply.demand(camp)
check("demand sees missing planks", (need.planks or 0) >= 36, need.planks)
check("logs wanted", Supply.logsWanted(camp, need) >= 12, Supply.logsWanted(camp, need))

for _ = 1, 6 do Supply.step(camp, 0.01) end
local jacks = Supply.jacks(camp)
check("lumberjacks assigned from helpers first", #jacks >= 1 and camp.settlers.w1.job == "lumber", #jacks)
check("guard never a lumberjack", camp.settlers.g1.job == nil and camp.settlers.f1.job == nil)
check("scan found trees", #camp.supply.trees >= 1, #camp.supply.trees)
check("scan keeps nearest first", camp.supply.trees[1].x == 58 and camp.supply.trees[1].y == 70, camp.supply.trees[1].x .. "," .. camp.supply.trees[1].y)

local target = Supply.target(camp)
check("target is a tree", target ~= nil and target.x <= 59)
camp.orderClock = 100
Work.orders(camp, 1)
local order = orders.w1
check("jack holds a tile beside the tree", order ~= nil and order.kind == "hold" and math.abs(order.anchor.x - target.x) <= 2 and math.abs(order.anchor.y - target.y) <= 2, order and (order.anchor.x .. "," .. order.anchor.y))
check("station is lumber", camp.settlers.w1.station ~= nil and camp.settlers.w1.station.kind == "lumber")

local before = treeCount()
for _ = 1, 40 do
    HOURS = HOURS + 1 / 60
    Supply.step(camp, 1)
end
Stock.refresh(camp)
check("trees felled while jacks wait or arrive", treeCount() < before, treeCount())
check("logs arrived in storage", (camp.stock.logs or 0) >= 2, camp.stock.logs)
check("twigs not counted as logs", (camp.stock.logs or 0) % 2 == 0)

local planksBefore = camp.stock.planks
for _ = 1, 30 do
    Work.supply(camp, 1)
    Stock.refresh(camp)
end
check("logs are sawn into planks", camp.stock.planks > planksBefore, camp.stock.planks)

local lines = Supply.lines(camp)
check("overview lines present", #lines >= 1 and lines[1].text ~= nil)
local overview = Hooks.overview(camp)
check("overview hook feeds the lines", #overview >= 1)

for _, t in ipairs(trees) do
    local sq = A.World.square(t.x, t.y, 0)
    for i = #sq.objects, 1, -1 do if sq.objects[i].class == "IsoTree" then table.remove(sq.objects, i) end end
end
camp.supply.trees = {}
camp.supply.ring = 1
camp.supply.index = 0
camp.supply.progress = 0
local far = camp.supply.far
for _ = 1, 60 do Supply.step(camp, 1) end
Stock.refresh(camp)
check("no trees nearby falls back to the far forest", camp.supply.far > far, camp.supply.far)

Options.set(camp, "lumber", false)
Supply.step(camp, 1)
check("option off releases jacks", #Supply.jacks(camp) == 0 and camp.settlers.w1.job == nil)
Options.set(camp, "lumber", true)

for _, project in pairs(Build.plan(camp).items) do project.status = "done" end
Supply.step(camp, 1)
check("no demand no jacks", #Supply.jacks(camp) == 0)
local lines2 = Supply.lines(camp)
check("ok line when nothing is missing", lines2[1] ~= nil and lines2[1].text ~= nil and #lines2 == 1)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
