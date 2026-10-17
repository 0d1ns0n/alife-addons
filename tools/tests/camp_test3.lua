dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Work = A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Work
local reg, orders = MOCKALIFE()

for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 0) end end
for x = 30, 145 do for y = 30, 145 do NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 91, y2 = 85, z = 0 }, "Строй")
camp.options.recruit = false
camp.phase = "plan"
local crate = Stock.crate(camp, camp.storage[1])
local box = crate:getContainer()
for _ = 1, 400 do box:AddItem("Base.Plank") end
for _ = 1, 700 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
check("stock planks", camp.stock.planks == 400, camp.stock.planks)

local info = Bp.stageInfo({ kind = "house_s", x = 70, y = 70, w = 4, h = 4, door = "S" })
check("house has 5 stages", #info == 5, #info)
check("foundation count", info[1].count == 16, info[1].count)
check("frame count", info[2].count == 16, info[2].count)
check("foundation cost", info[1].cost.planks == 16 and info[1].cost.nails == 16, tostring(info[1].cost.planks))
check("walls cost", info[3].cost.planks ~= nil and info[3].cost.planks > 20, tostring(info[3].cost.planks))
check("roof count", info[4].count == 16, info[4].count)
check("finish has door and furniture", info[5].count >= 6, info[5].count)

local generated = Plan.generate(camp)
check("generated projects", generated >= 4, generated)
local list = Build.list(camp)
local kinds = {}
for _, p in ipairs(list) do kinds[p.kind] = (kinds[p.kind] or 0) + 1 end
check("has fence", kinds.fence == 1)
check("has campfire", kinds.campfire == 1)
check("has shed", (kinds.shed or 0) >= 1)
check("has houses", (kinds.house_s or 0) + (kinds.house_m or 0) + (kinds.house_l or 0) >= 1)
check("has farm", (kinds.farm or 0) >= 1, kinds.farm)
local clash = false
for i = 1, #list do
    for j = i + 1, #list do
        if list[i].kind ~= "fence" and list[j].kind ~= "fence" and Build.overlaps(Bp.footprint(list[i]), Bp.footprint(list[j])) then clash = true end
    end
    if list[i].kind ~= "fence" then
        local r = Bp.footprint(list[i])
        if r.x1 < camp.x1 or r.y1 < camp.y1 or r.x2 > camp.x2 or r.y2 > camp.y2 then clash = true end
    end
end
check("projects do not overlap and stay inside", not clash)
Plan.generate(camp)
check("generate is idempotent", Plan.generate(camp) == 0)

check("outside refused", select(2, Build.add(camp, "house_s", 200, 200, {})) == "outside")
local campfireProject
for _, p in ipairs(list) do if p.kind == "campfire" then campfireProject = p end end
check("overlap refused", select(2, Build.add(camp, "house_s", campfireProject.x, campfireProject.y, {})) == "overlap")

ADDACTOR(reg, "alice", "friendly", 75, 75, A.World.square(75, 75, 0))
ADDACTOR(reg, "bob", "friendly", 76, 75, A.World.square(76, 75, 0))
ADDACTOR(reg, "cara", "friendly", 77, 75, A.World.square(77, 75, 0))
Settlers.settle(camp, "alice", "Alice")
Settlers.settle(camp, "bob", "Bob")
Settlers.settle(camp, "cara", "Cara")
camp.settlers.alice.role = "builder"
camp.settlers.bob.role = "builder"
camp.settlers.cara.role = "guard"

for i = 1, 240 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("phase build or plan", camp.phase == "build" or camp.phase == "plan", camp.phase)
local done = 0
for _, p in ipairs(Build.list(camp)) do if p.status == "done" then done = done + 1 end end
check("some projects done", done >= 1, done)
check("built stat", camp.stats.built == done, camp.stats.built .. "/" .. done)
Stock.refresh(camp)
check("materials consumed", camp.stock.planks < 400 and camp.stock.nails < 700, camp.stock.planks .. "/" .. camp.stock.nails)

local campfire
for _, p in ipairs(Build.list(camp)) do if p.kind == "campfire" then campfire = p end end
check("campfire done", campfire ~= nil and campfire.status == "done", campfire and campfire.status)
local fx = A.World.square(campfire.x + 1, campfire.y + 1, 0)
local found = false
for i = 0, fx:getObjects():size() - 1 do
    local o = fx:getObjects():get(i)
    local tag = A.World.tag(o)
    if tag and tag.project == campfire.id then found = true end
end
check("campfire object tagged", found)

local shed
for _, p in ipairs(Build.list(camp)) do if p.kind == "shed" then shed = p end end
check("shed progressed", shed ~= nil and (shed.status == "done" or shed.stage > 1), shed and (shed.status .. "/" .. shed.stage))
for i = 1, 900 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("shed done", shed.status == "done", shed.status .. "/" .. shed.stage)
local floors, walls, windows, roofs, crates = 0, 0, 0, 0, 0
for x = shed.x, shed.x + shed.w do
    for y = shed.y, shed.y + shed.h do
        for z = 0, 1 do
            local sq = A.World.square(x, y, z)
            for i = 0, sq:getObjects():size() - 1 do
                local o = sq:getObjects():get(i)
                local tag = A.World.tag(o)
                if tag and tag.project == shed.id then
                    if rawget(o, "isFloor") and z == 0 then floors = floors + 1 end
                    if rawget(o, "isFloor") and z == 1 then roofs = roofs + 1 end
                    if o.class == "IsoThumpable" and tag.slot and tag.slot:sub(1, 1) == "S" then walls = walls + 1 end
                    if o.class == "IsoWindow" then windows = windows + 1 end
                    if rawget(o, "container") then crates = crates + 1 end
                end
            end
        end
    end
end
check("shed floors", floors == 12, floors)
check("shed roof", roofs == 12, roofs)
check("shed walls", walls >= 12, walls)
check("shed crates", crates == 1, crates)
check("shed crate is the warehouse, the initial crate moved in", #camp.storage >= 1 and camp.storage[#camp.storage].warehouse == true, #camp.storage)

local noStock = Camp.create({ x1 = 100, y1 = 60, x2 = 125, y2 = 80, z = 0 }, "Пустой")
noStock.phase = "plan"
noStock.kitGiven = true
noStock.options.recruit = false
reg.records.dave = { uid = "dave", revision = 1, generation = 1, lifecycle = "active", profileId = "p", factionId = "f", worldPosition = { x = 105, y = 65, z = 0 }, memory = {} }
Settlers.settle(noStock, "dave", "Dave")
local pp = Build.add(noStock, "house_s", 105, 65, { door = "S" })
check("project added", pp ~= nil)
for i = 1, 30 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("waits for materials", pp.waiting == true and pp.stage == 1, tostring(pp.waiting) .. "/" .. pp.stage)
local missing = Build.needs(noStock, pp)
check("missing list", missing.planks ~= nil and missing.nails ~= nil)

Stock.give(noStock, "Base.Log", 6)
Stock.refresh(noStock)
check("logs stocked", noStock.stock.logs == 6, noStock.stock.logs)
for i = 1, 30 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
Stock.refresh(noStock)
check("sawmill made planks", noStock.stock.planks > 0 and noStock.stock.logs < 6, noStock.stock.planks .. "/" .. noStock.stock.logs)

local fenceP
for _, p in ipairs(Build.list(camp)) do if p.kind == "fence" then fenceP = p end end
check("fence project", fenceP ~= nil)
local slots = Bp.fenceSlots(fenceP)
local gates = 0
for _, s in ipairs(slots) do if s.gate then gates = gates + 1 end end
check("gates are three slots wide", gates == 3 * #A.Gates.of(fenceP), gates)
check("fence slots count", #slots == 2 * (Geo.width(camp) + Geo.height(camp)), #slots)

check("planner class", ALifeCamp.Planner ~= nil)
check("window class", ALifeCamp.Window ~= nil)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
