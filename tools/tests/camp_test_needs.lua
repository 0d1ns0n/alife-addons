dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Settlers, Work, Needs, Options, Hooks, Stock, World = A.Store, A.Camp, A.Build, A.Settlers, A.Work, A.Needs, A.Options, A.Hooks, A.Stock, A.World
local reg, orders = MOCKALIFE()

for x = 20, 145 do for y = 20, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
PLAYER.x, PLAYER.y = 80, 75
HOURS = 600

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Needs")
camp.options.recruit = false
camp.options.autoPlan = false
camp.phase = "build"

check("needs module loaded", Needs ~= nil)
check("one storage crate at founding", #camp.storage == 1, #camp.storage)

for i, uid in ipairs({ "a1", "a2", "a3", "a4" }) do
    ADDACTOR(reg, uid, "friendly", 70 + i, 74, World.square(70 + i, 74, 0))
    Settlers.settle(camp, uid, uid)
    camp.settlers[uid].role = "worker"
end

local crate = Stock.crate(camp, camp.storage[1])
local box = crate:getContainer()
for _ = 1, 4 do box:AddItem("Base.Plank") end
Stock.refresh(camp)

local big = Build.add(camp, "house_l", 64, 64, {})
big.prepared = true

local list = Needs.compute(camp)
local byId = {}
for _, need in ipairs(list) do byId[need.id] = need end
check("food missing", byId.food ~= nil and byId.food.short > 0, byId.food and byId.food.short)
check("water missing and urgent", byId.water ~= nil and byId.water.urgent == true)
check("medicine missing", byId.medicine ~= nil and byId.medicine.short >= 2)
check("planks missing", byId.planks ~= nil and byId.planks.short >= 40, byId.planks and byId.planks.short)
check("urgent first", list[1].urgent == true)

local lines = Needs.lines(camp)
check("lines show where to bring", lines[1].text:find(tostring(camp.storage[1].x), 1, true) ~= nil, lines[1].text)
check("lines list every need", #lines >= #list + 2)

local overview = Hooks.overview(camp)
check("overview mentions needs", #overview >= 1)

local tabFound
for _, tab in ipairs(Hooks.tabs) do if tab.id == "needs" then tabFound = tab end end
check("needs tab registered early", tabFound ~= nil and tabFound.priority < 20)

PLAYER.notes = {}
camp.needs = nil
for _ = 1, 6 do Needs.step(camp, 1) end
check("alert sent to the player", #PLAYER.notes == 1, #PLAYER.notes)
check("alert names the shortages", PLAYER.notes[1] ~= nil and PLAYER.notes[1]:find("Needs", 1, true) ~= nil, PLAYER.notes[1])

for _ = 1, 20 do Needs.step(camp, 1) end
check("no repeat alert for the same needs", #PLAYER.notes == 1, #PLAYER.notes)

for _ = 1, 12 do box:AddItem("Base.Nails") end
HOURS = HOURS + 0.2
Stock.refresh(camp)
camp.needs.sig = "stale"
for _ = 1, 6 do Needs.step(camp, 1) end
check("throttled within the alert window", #PLAYER.notes == 1, #PLAYER.notes)

HOURS = HOURS + 3
camp.needs.sig = "stale"
for _ = 1, 6 do Needs.step(camp, 1) end
check("alerts again after the pause when needs changed", #PLAYER.notes == 2, #PLAYER.notes)

PLAYER.x, PLAYER.y = 900, 900
HOURS = HOURS + 3
camp.needs.sig = "stale"
for _ = 1, 6 do Needs.step(camp, 1) end
check("no alert when the player is far away", #PLAYER.notes == 2, #PLAYER.notes)
PLAYER.x, PLAYER.y = 80, 75

Options.set(camp, "needsAlert", false)
HOURS = HOURS + 3
camp.needs.sig = "stale"
for _ = 1, 6 do Needs.step(camp, 1) end
check("alerts can be switched off", #PLAYER.notes == 2, #PLAYER.notes)
Options.set(camp, "needsAlert", true)

for _ = 1, 400 do box:AddItem("Base.Plank") end
for _ = 1, 100 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
local clear = Needs.compute(camp)
local ids = {}
for _, need in ipairs(clear) do ids[need.id] = true end
check("materials satisfied", not ids.planks and not ids.nails)

camp.phase = "clear"
local clearing = Needs.compute(camp)
local materialNeed = false
for _, need in ipairs(clearing) do
    if need.id == "planks" or need.id == "nails" then materialNeed = true end
end
check("no material needs while clearing", not materialNeed)

local warehouseTag = { kind = "storage", camp = camp.id, project = 5, slot = "x" }
local wx, wy = 70, 82
local object = World.putCrate(wx, wy, 0, warehouseTag, "carpentry_01_19")
check("warehouse crate placed", object ~= nil)
if object ~= nil then
    camp.storage[#camp.storage + 1] = { x = wx, y = wy, z = 0, warehouse = true }
    local first = camp.storage[1]
    local before = #crate:getContainer().items
    local moved = Stock.consolidate(camp)
    check("items moved into the warehouse", moved == before and #object:getContainer().items >= before, moved)
    check("initial crate removed from the camp list", #camp.storage == 1 and camp.storage[1].warehouse == true, #camp.storage)
    check("initial crate removed from the world", Stock.crate(camp, first) == nil)
    check("consolidation is idempotent", Stock.consolidate(camp) == 0)
end

local old = Camp.create({ x1 = 110, y1 = 60, x2 = 125, y2 = 75, z = 0 }, "Old")
World.putCrate(112, 62, 0, { kind = "storage", camp = old.id }, "carpentry_01_19")
old.storage[#old.storage + 1] = { x = 112, y = 62, z = 0 }
check("camp without a warehouse is left alone", Stock.consolidate(old) == 0 and #old.storage == 2)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
