dofile(MOCK)
LOADMOD(ROOT)
local A = ALifeCamp
local Camp, Settlers, Stock, World = A.Camp, A.Settlers, A.Stock, A.World
local reg = MOCKALIFE()
for x = 100, 140 do for y = 100, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300
local camp = Camp.create({ x1 = 100, y1 = 100, x2 = 399, y2 = 399, z = 0 }, "Wide")
check("no crate at far center", #camp.storage == 0, #camp.storage)
ADDACTOR(reg, "alice", "friendly", 120, 120, World.square(120, 120, 0))
Settlers.settle(camp, "alice", "Alice")
camp.settlers.alice.role = "builder"
for _ = 1, 5 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("crates placed by settlers", #camp.storage >= 1, #camp.storage)
check("crate resolvable", camp.storage[1] ~= nil and Stock.crate(camp, camp.storage[1]) ~= nil)
check("crate near settler", camp.storage[1] ~= nil and math.abs(camp.storage[1].x - 120) <= 9)
Stock.deposit(camp, "Base.Plank", 3)
local sq = World.square(camp.storage[1].x, camp.storage[1].y, 0)
for i = sq:getObjects():size() - 1, 0, -1 do
    local o = sq:getObjects():get(i)
    if World.tag(o) ~= nil then sq:transmitRemoveItemFromSquare(o) end
end
for _ = 1, 5 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("lost crate replaced", #camp.storage >= 1 and Stock.crate(camp, camp.storage[1]) ~= nil, #camp.storage)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = {} }
