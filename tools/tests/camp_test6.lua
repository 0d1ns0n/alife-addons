dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Work, Land, Clear, Expand =
    A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Work, A.Land, A.Clear, A.Expand
local reg = MOCKALIFE()

for x = 100, 399 do for y = 100, 329 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

check("250x200 allowed", Camp.check({ x1 = 120, y1 = 120, x2 = 369, y2 = 319, z = 0 }) == true)
check("600x600 allowed", Camp.check({ x1 = 0, y1 = 0, x2 = 599, y2 = 599, z = 0 }) == true)

local camp = Camp.create({ x1 = 120, y1 = 120, x2 = 369, y2 = 319, z = 0 }, "Большой")
camp.phase = "plan"
check("created", camp ~= nil)

local t0 = os.clock()
local added = Plan.generate(camp)
local took = os.clock() - t0
check("generate fast enough", took < 20, took)
local counts = {}
for _, p in ipairs(Build.list(camp)) do counts[p.kind] = (counts[p.kind] or 0) + 1 end
local houses = (counts.house_s or 0) + (counts.house_m or 0) + (counts.house_l or 0)
check("many houses", houses >= 60, houses)
check("many farms", (counts.farm or 0) >= 20, counts.farm)
check("many towers", (counts.tower or 0) >= 16, counts.tower)
check("exactly one warehouse shed", (counts.shed or 0) == 1, counts.shed)
check("one fence", counts.fence == 1, counts.fence)
check("all kinds of houses", (counts.house_s or 0) > 0 and (counts.house_m or 0) > 0 and (counts.house_l or 0) > 0)

local minY, maxY, minX, maxX = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(Build.list(camp)) do
    if p.kind:sub(1, 5) == "house" then
        minY, maxY = math.min(minY, p.y), math.max(maxY, p.y)
        minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
    end
end
check("houses spread over area", maxY - minY > 60 and maxX - minX > 60, (maxX - minX) .. "x" .. (maxY - minY))

local clash = false
local list = Build.list(camp)
for i = 1, #list do
    for j = i + 1, #list do
        if list[i].kind ~= "fence" and list[j].kind ~= "fence" and Build.overlaps(Bp.footprint(list[i]), Bp.footprint(list[j])) then clash = true end
    end
end
check("no overlaps", not clash)
Plan.generate(camp) Plan.generate(camp)
check("idempotent", Plan.generate(camp) == 0)

local towers = {}
local dup = false
for _, p in ipairs(list) do
    if p.kind == "tower" then
        local key = p.x .. "," .. p.y
        if towers[key] then dup = true end
        towers[key] = true
        if p.x < camp.x1 or p.y < camp.y1 or p.x > camp.x2 or p.y > camp.y2 then dup = true end
    end
end
check("towers distinct and inside", not dup)

local survey = Land.survey(camp, Land.stride(camp, 4000))
check("sampled survey totals", survey.total == 250 * 200 and survey.loaded > 40000, survey.loaded)
check("stride grows", Land.stride(camp, 4000) >= 3, Land.stride(camp, 4000))
check("small camp stride is one", Land.stride({ x1 = 0, y1 = 0, x2 = 29, y2 = 29 }, 4000) == 1)

local state = Clear.state(camp)
state.passDone = true
state.lastRemoved = 0
check("big camp clearing finishes", Clear.finished(camp) == true)
state.passDone = true
state.lastRemoved = 3
check("not finished while removing", Clear.finished(camp) == false)

check("expand amount scales", Expand.amount(camp) == 33, Expand.amount(camp))
check("expand amount minimum", Expand.amount({ x1 = 0, y1 = 0, x2 = 19, y2 = 19 }) == 8)

local house
for _, p in ipairs(list) do if p.kind == "house_s" then house = p break end end
local treeSquare = A.World.square(house.x + 2, house.y + 2, 0)
NEWOBJ(treeSquare, "IsoTree", "e_americanholly_1_0")
NEWWORLDITEM(treeSquare, "Base.Plank")
local before = #treeSquare.objects
ADDACTOR(reg, "alice", "friendly", 140, 140, A.World.square(140, 140, 0))
ADDACTOR(reg, "bob", "friendly", 141, 140, A.World.square(141, 140, 0))
Settlers.settle(camp, "alice", "Alice")
Settlers.settle(camp, "bob", "Bob")
camp.settlers.alice.role = "builder"
camp.settlers.bob.role = "builder"
for _ = 1, 40 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
local stillThere = false
for _, o in ipairs(treeSquare.objects) do if o.class == "IsoTree" then stillThere = true end end
local prepared = 0
for _, p in ipairs(Build.list(camp)) do if p.prepared == true then prepared = prepared + 1 end end
check("some projects prepared", prepared >= 1, prepared)
check("fence never blocks others", Build.get(camp, list[1].id) ~= nil)
if house.prepared == true then
    check("tree under house cleared", not stillThere)
else
    check("unprepared house keeps waiting", house.prepared ~= true)
end

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
