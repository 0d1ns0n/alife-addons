dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Settlers, Work, Duty, Options, Hooks = A.Store, A.Camp, A.Build, A.Settlers, A.Work, A.Duty, A.Options, A.Hooks
local reg, orders = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 500

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Duty")
camp.options.recruit = false
camp.options.autoPlan = false
camp.phase = "build"

check("duty module loaded", Duty ~= nil and Options.byKey.stations ~= nil)
check("stations default on", Options.on(camp, "stations") == true)

local function project(kind, x, y, done)
    local p = Build.add(camp, kind, x, y, {})
    if p ~= nil and done then p.status = "done" p.stage = 99 end
    return p
end

local houseA = project("house_m", 62, 70, true)
local houseB = project("house_s", 72, 70, true)
local farm = project("farm", 80, 62, true)
local fire = project("campfire", 76, 76, true)
local building = project("house_l", 64, 80, false)
check("projects made", houseA ~= nil and houseB ~= nil and farm ~= nil and fire ~= nil and building ~= nil)
building.prepared = true
camp.active = { building.id }

local roster = {
    { "b1", "builder" }, { "b2", "builder" }, { "w1", "worker" }, { "f1", "farmer" }, { "g1", "guard" }, { "g2", "guard" },
    { "g3", "guard" }, { "s1", "scavenger" }, { "m1", "medic" }, { "x1", "sanitary" },
}
for i, row in ipairs(roster) do
    local x, y = 70 + i, 74
    ADDACTOR(reg, row[1], "friendly", x, y, A.World.square(x, y, 0))
    Settlers.settle(camp, row[1], row[1])
    camp.settlers[row[1]].role = row[2]
end

local sent = 0
local originalSet = ProjectALife.DecisionLoop.setOrder
ProjectALife.DecisionLoop.setOrder = function(uid, generation, order)
    sent = sent + 1
    return originalSet(uid, generation, order)
end

camp.orderClock = 100
Work.orders(camp, 1)
local seen, dup = {}, false
local allHold = true
for _, row in ipairs(roster) do
    local order = orders[row[1]]
    if order == nil or order.kind ~= "hold" or order.source ~= "leader" then allHold = false end
    if order ~= nil then
        local key = order.anchor.x .. "," .. order.anchor.y
        if seen[key] then dup = true end
        seen[key] = true
    end
end
check("everyone holds a station", allHold)
check("stations are distinct tiles", not dup)
check("sent one order each", sent == #roster, sent)

local function anchorOf(uid) return orders[uid].anchor end
local function near(a, rect, gap)
    return a.x >= rect.x1 - gap and a.x <= rect.x2 + gap and a.y >= rect.y1 - gap and a.y <= rect.y2 + gap
end
local frect = Duty.rectOf(farm)
check("farmer stands in the farm", anchorOf("f1").x >= frect.x1 and anchorOf("f1").x <= frect.x2 and anchorOf("f1").y >= frect.y1 and anchorOf("f1").y <= frect.y2)
local brect = Duty.rectOf(building)
check("builders stand around the site, outside walls", near(anchorOf("b1"), brect, 1) and not near(anchorOf("b1"), brect, 0), anchorOf("b1").x .. "," .. anchorOf("b1").y)
check("worker joins the site", near(anchorOf("w1"), brect, 1))
check("guards on posts, not on the site", not near(anchorOf("g1"), brect, 1))
check("scavenger by the depot", math.abs(anchorOf("s1").x - camp.storage[1].x) <= 3 and math.abs(anchorOf("s1").y - camp.storage[1].y) <= 3)
check("station kinds recorded", camp.settlers.f1.station ~= nil and camp.settlers.f1.station.kind == "farm" and camp.settlers.b1.station.kind == "site")

local before = {}
for _, row in ipairs(roster) do before[row[1]] = anchorOf(row[1]).x .. "," .. anchorOf(row[1]).y end
sent = 0
camp.orderClock = 100
Work.orders(camp, 1)
local stable = true
for _, row in ipairs(roster) do
    if anchorOf(row[1]).x .. "," .. anchorOf(row[1]).y ~= before[row[1]] then stable = false end
end
check("stations stable between passes", stable)
check("no resend while waiting", sent == 0, sent)

local farCount = 0
for _, row in ipairs(roster) do
    local shell = Settlers.shell(row[1])
    local a = anchorOf(row[1])
    if math.abs(shell.px - a.x) > Duty.arriveRange or math.abs(shell.py - a.y) > Duty.arriveRange then farCount = farCount + 1 end
end
HOURS = HOURS + 0.3
camp.orderClock = 100
Work.orders(camp, 1)
check("resend after timeout only for far settlers", sent == farCount and farCount >= 5, tostring(sent) .. "/" .. tostring(farCount))

for _, row in ipairs(roster) do
    local shell = Settlers.shell(row[1])
    shell.px, shell.py = anchorOf(row[1]).x, anchorOf(row[1]).y
end
sent = 0
HOURS = HOURS + 0.3
camp.orderClock = 100
Work.orders(camp, 1)
check("no resend when arrived", sent == 0, sent)

camp.loot = { x = 50, y = 70, z = 0, at = HOURS }
camp.orderClock = 100
Work.orders(camp, 1)
check("scavenger heads to the fresh loot site", math.abs(anchorOf("s1").x - 50) <= 1 and math.abs(anchorOf("s1").y - 70) <= 1 and camp.settlers.s1.station.kind == "loot", anchorOf("s1").x .. "," .. anchorOf("s1").y)
HOURS = HOURS + 0.5
camp.orderClock = 100
Work.orders(camp, 1)
check("scavenger returns to the depot when the site is stale", camp.settlers.s1.station.kind == "depot")
camp.loot = nil

camp.active = {}
camp.phase = "plan"
camp.orderClock = 100
Work.orders(camp, 1)
check("builders move to the depot when idle", camp.settlers.b1.station.kind == "depot")

camp.raid = { at = HOURS, people = 10, site = { x = 80, y = 60, z = 0 } }
camp.orderClock = 100
Work.orders(camp, 1)
check("guards go to the raid site", math.abs(anchorOf("g1").x - 80) <= 2 and math.abs(anchorOf("g1").y - 60) <= 2, anchorOf("g1").x .. "," .. anchorOf("g1").y)
check("others shelter near the center", math.abs(anchorOf("f1").x - 79) <= 8 and math.abs(anchorOf("f1").y - 74) <= 8)
camp.raid = nil

Options.set(camp, "stations", false)
camp.orderClock = 100
Work.orders(camp, 1)
check("patrol when stations are off", orders.f1.kind == "patrol")
check("station cleared when off", camp.settlers.f1.station == nil)
Options.set(camp, "stations", true)
camp.orderClock = 100
Work.orders(camp, 1)

local homes = {}
local got = 0
for _, row in ipairs(roster) do
    Duty.begin(camp)
    local spot = Duty.home(camp, row[1])
    if spot ~= nil then
        got = got + 1
        homes[#homes + 1] = spot
    end
end
check("home capacity 6 beds for 10 people", got == 6, got)
local again = Duty.home(camp, roster[1][1])
check("home is stable", again ~= nil and camp.settlers.b1.home ~= nil)
local inside = true
for _, spot in ipairs(homes) do
    local hit = false
    for _, p in ipairs({ houseA, houseB }) do
        local r = Duty.rectOf(p)
        if spot.x >= r.x1 and spot.x <= r.x2 and spot.y >= r.y1 and spot.y <= r.y2 then hit = true end
    end
    if not hit then inside = false end
end
check("homes inside the houses", inside)

local mess = Duty.mess(camp)
check("mess falls back to the campfire", mess.kind == "campfire" and mess.x == fire.x + 1 and mess.y == fire.y + 1)
local items = Build.plan(camp).items
items["77"] = { id = 77, kind = "canteen", status = "done", x = 84, y = 70, w = 6, h = 4, stage = 9, done = {} }
mess = Duty.mess(camp)
check("mess uses the canteen", mess.kind == "canteen" and mess.rect ~= nil and mess.indoor == true)
Duty.begin(camp)
local seat = Duty.ring(camp, mess, "b1", 0, 2, true)
check("seat inside the canteen", seat.x >= 84 and seat.x <= 89 and seat.y >= 70 and seat.y <= 73, seat.x .. "," .. seat.y)

Duty.begin(camp)
local ids, collide = {}, false
for i = 1, 24 do
    local spot = Duty.ring(camp, { x = 90, y = 80, z = 0 }, "u" .. i, 1, 3)
    local key = spot.x .. "," .. spot.y
    if ids[key] then collide = true end
    ids[key] = true
end
check("ring gives distinct tiles", not collide)

check("unloaded square counts as free", Duty.free(5000, 5000, 0, false) == true)
local info = Hooks.collect("settlerInfo", camp, "f1", camp.settlers.f1)
check("settler info shows the place", #info >= 1)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
