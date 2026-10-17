dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Land, Clear, Settlers, Work, Director = A.Store, A.Geo, A.Camp, A.Stock, A.Land, A.Clear, A.Settlers, A.Work, A.Director
local reg, orders = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)

local camp = Camp.create({ x1 = 100, y1 = 100, x2 = 111, y2 = 111, z = 0 }, "Тест")
camp.phase = "clear"
camp.options.demolish = false
check("camp", camp ~= nil and #camp.storage == 1)

local sq = A.World.square
NEWOBJ(sq(101, 101, 0), "IsoTree", "vegetation_trees_01_1")
NEWOBJ(sq(102, 101, 0), "IsoTree", "vegetation_trees_01_2")
NEWOBJ(sq(103, 101, 0), "IsoObject", "d_trash_1_3")
NEWOBJ(sq(104, 101, 0), "IsoObject", "vegetation_foliage_01_3")
NEWOBJ(sq(105, 105, 0), "IsoThumpable", "carpentry_02_40")
NEWWORLDITEM(sq(106, 101, 0), "Base.Hammer")
NEWWORLDITEM(sq(107, 101, 0), "Base.Bandage")
local body = { class = "IsoDeadBody" }
table.insert(sq(108, 101, 0).bodies, body)
local fence = NEWOBJ(sq(120, 120, 0), "IsoThumpable", "x")

local survey = Land.survey(camp)
check("survey sees trees", survey.tree == 2, survey.tree)
check("survey sees junk", survey.junk == 1 and survey.item == 2 and survey.corpse == 1, survey.junk .. "/" .. survey.item .. "/" .. survey.corpse)
check("survey structure", survey.structure == 1, survey.structure)
check("outside camp untouched in survey", survey.structure == 1)

HOURS = 200
local alice = ADDACTOR(reg, "alice", "friendly", 125, 125, sq(125, 125, 0))
local bob = ADDACTOR(reg, "bob", "hostile", 126, 125, sq(126, 125, 0))
local carl = ADDACTOR(reg, "carl", "neutral", 127, 125, sq(127, 125, 0))
check("identity", Settlers.identity(alice) ~= nil and Settlers.identity(alice).uid == "alice")
check("not actor", Settlers.identity({ getModData = function() return {} end }) == nil)

local ok, why = Settlers.invite(PLAYER, bob, camp)
check("hostile refused", ok == false and why == "hostile", why)
ok, why = Settlers.invite(PLAYER, alice, camp)
check("friendly invited", ok == true)
check("settled at once", camp.settlers.alice ~= nil, camp.settlers.alice and camp.settlers.alice.role)
check("no pending left", camp.pending == nil or camp.pending.alice == nil)
check("patrol order to camp", orders.alice ~= nil and orders.alice.kind == "patrol")
check("persistent mark", reg.records.alice.memory.persistent == true and reg.records.alice.memory.camp == camp.id)
check("accept line", #alice.lines == 1, alice.lines[1])
ok, why = Settlers.invite(PLAYER, alice, camp)
check("double invite refused", ok == false and why == "already", why)
check("carl invited", select(1, Settlers.invite(PLAYER, carl, camp)) == true)
check("carl settled at once", camp.settlers.carl ~= nil)
check("role set", camp.settlers.alice.role ~= "worker" or camp.settlers.alice.role == "worker")

fire("EveryOneMinute")
check("memory camp", reg.records.alice.memory.camp == camp.id and reg.records.alice.memory.campInvite == nil)
check("population", Store.settlerCount(camp) == 2)

camp.pending = camp.pending or {}
camp.pending.legacy = { since = HOURS, name = "Legacy" }
ADDACTOR(reg, "legacy", "friendly", 126, 126, sq(126, 126, 0))
for i = 1, 3 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("legacy pending settles", camp.settlers.legacy ~= nil and camp.pending.legacy == nil)

check("labor", Work.labor(camp) >= 1, Work.labor(camp))
local before = Land.survey(camp)
for i = 1, 40 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
local after = Land.survey(camp)
check("trees cleared", after.tree == 0, after.tree)
check("junk cleared", after.junk == 0)
check("items hauled", after.item == 0)
check("corpse removed", after.corpse == 0)
check("structure removed", after.structure == 0, after.structure)
check("fence outside kept", #sq(120, 120, 0).objects == 1)
Stock.refresh(camp)
check("logs sawn into planks", camp.stock.logs <= 2 and camp.stock.planks >= 10, camp.stock.logs .. "/" .. camp.stock.planks)
check("planks from structure", camp.stock.planks >= 1, camp.stock.planks)
local found = false
for _, entry in ipairs(camp.storage) do
    local crate = Stock.crate(camp, entry)
    local items = crate:getContainer():getItems()
    for i = 0, items:size() - 1 do if items:get(i).full == "Base.Hammer" then found = true end end
end
check("world item stored", found)
check("clear stat", camp.stats.cleared >= 8, camp.stats.cleared)

for i = 1, 30 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("phase advanced", camp.phase == "plan" or camp.phase == "build", camp.phase)

camp.phase = "clear"
camp.options.demolish = true
local house = A.World.square(110, 110, 0)
house.building = { id = 7 }
local wallObj = NEWOBJ(house, "IsoObject", "walls_interior_house_01_1")
wallObj.getSprite = function() return { getName = function() return "walls_interior_house_01_1" end, getProperties = function() return { has = function(_, f) return f == "WallN" end } end } end
NEWOBJ(house, "IsoObject", "floors_interior_tilesandwood_01_41")
local up = NEWSQUARE(110, 110, 1)
NEWOBJ(up, "IsoObject", "floors_interior_tilesandwood_01_41")
NEWOBJ(up, "IsoObject", "roofs_02_22")
local floorObj = house.objects[2]
floorObj.getSprite = function() return { getName = function() return "floors_interior_tilesandwood_01_41" end, getProperties = function() return { has = function() return true end } end } end
IsoFlagType = { solidfloor = "solidfloor" }
for i = 1, 60 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("upper level wiped", #up.objects == 0, #up.objects)
check("house wiped to ground", #house.objects == 1 and house.floorName == "blends_natural_01_64", #house.objects)

local rich = Camp.create({ x1 = 60, y1 = 60, x2 = 71, y2 = 71, z = 0 }, "Сытый")
local crate = Stock.crate(rich, rich.storage[1])
for _ = 1, 40 do local f = NEWITEM("Base.Canned", 1000) f.container = crate:getContainer() table.insert(crate:getContainer().items, f) end
Stock.refresh(rich)
check("rich food", rich.stock.food == 40000, rich.stock.food)
rich.phase = "plan"
Settlers.settle(rich, "dave", "Dave")
reg.records.dave = { uid = "dave", revision = 1, generation = 1, lifecycle = "active", profileId = "p", factionId = "f", worldPosition = { x = 65, y = 65, z = 0 }, memory = {} }
for i = 1, 24 * 60 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
Stock.refresh(rich)
print("DEBT", rich.foodDebt, Store.settlerCount(rich), rich.stock.food)
check("food consumed over a day", rich.stock.food < 40000 and rich.stock.food >= 36000, rich.stock.food)

local poor = Camp.create({ x1 = 40, y1 = 40, x2 = 51, y2 = 51, z = 0 }, "Бедный")
poor.phase = "plan"
Settlers.settle(poor, "erin", "Erin")
reg.records.erin = { uid = "erin", revision = 1, generation = 1, lifecycle = "active", profileId = "p", factionId = "f", worldPosition = { x = 45, y = 45, z = 0 }, memory = {} }
for i = 1, 30 * 60 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("starvation leaves", Store.settlerCount(poor) == 0, Store.settlerCount(poor))

reg.records.dave.lifecycle = "dead"
fire("EveryOneMinute")
check("dead removed", rich.settlers.dave == nil)

local missing = {}
for k in pairs(MISSING) do missing[#missing + 1] = k end
table.sort(missing)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missing }
