dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Gates, Posts, Motor, Skills, Recycle, Work =
    A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Gates, A.Posts, A.Motor, A.Skills, A.Recycle, A.Work
local reg = MOCKALIFE()

for x = 20, 330 do for y = 20, 330 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

IsoDirections = { N = "N", S = "S", E = "E", W = "W" }
local VEH = {}
local baseCell = getCell()
function getCell()
    return {
        getGridSquare = baseCell.getGridSquare,
        getVehicles = function() return { size = function() return #VEH end, get = function(_, i) return VEH[i + 1] end } end,
    }
end

local function newVehicle(id, script, x, y)
    local v = { id = id, script = script, x = x, y = y, md = {}, removed = false, rust = 0.2 }
    v.parts = {
        { id = "GasTank", cond = 80, amount = 30 },
        { id = "Engine", cond = 40, amount = 0 },
    }
    function v:getId() return self.id end
    function v:getScriptName() return self.script end
    function v:getX() return self.x end
    function v:getY() return self.y end
    function v:getDriver() return nil end
    function v:getCurrentSpeedKmHour() return 0 end
    function v:getVehicleTowing() return nil end
    function v:getVehicleTowedBy() return nil end
    function v:isRemovedFromWorld() return self.removed end
    function v:getModData() return self.md end
    function v:getSkinIndex() return 1 end
    function v:getRust() return self.rust end
    function v:setRust(value) self.rust = value end
    function v:repair() for _, p in ipairs(self.parts) do p.cond = 100 end end
    function v:permanentlyRemove()
        self.removed = true
        for i = #VEH, 1, -1 do if VEH[i] == self then table.remove(VEH, i) end end
    end
    local function wrap(p)
        return {
            getId = function() return p.id end,
            getCondition = function() return p.cond end,
            setCondition = function(_, value) p.cond = value end,
            isContainer = function() return p.id == "GasTank" end,
            getContainerContentAmount = function() return p.amount end,
            setContainerContentAmount = function(_, value) p.amount = value end,
            getItemContainer = function() return nil end,
        }
    end
    function v:getParts()
        local owner = self
        return {
            getPartCount = function() return #owner.parts end,
            getPartByIndex = function(_, i) return wrap(owner.parts[i + 1]) end,
            getPartById = function(_, id)
                for _, p in ipairs(owner.parts) do if p.id == id then return wrap(p) end end
                return nil
            end,
        }
    end
    VEH[#VEH + 1] = v
    return v
end

local nextId = 100
function addVehicleDebug(script, direction, skin, square)
    nextId = nextId + 1
    local v = newVehicle(nextId, script, square.x + 0.5, square.y + 0.5)
    v.direction = direction
    for _, p in ipairs(v.parts) do p.cond = 100 p.amount = 5 end
    square.vehicle = v
    return v
end

local layout = Gates.layout(100, 140)
check("gate count scales", #layout == 6, #layout)
check("main gate south middle", layout[1].side == "S" and layout[1].index == 50 and layout[1].main == true)
local sides = {}
local spacingOk = true
for i, gate in ipairs(layout) do
    sides[gate.side] = true
    for j = i + 1, #layout do
        if layout[j].side == gate.side and math.abs(layout[j].index - gate.index) < 17 then spacingOk = false end
    end
    local len = (gate.side == "N" or gate.side == "S") and 100 or 140
    if gate.index < 14 or gate.index > len - 15 then spacingOk = false end
end
check("gate spacing and margins", spacingOk)
check("gates reach all sides", sides.S and sides.N and sides.E and sides.W)
check("small camp single gate", #Gates.layout(10, 10) == 1)
check("medium camp two gates", #Gates.layout(30, 30) == 2, #Gates.layout(30, 30))
check("huge camp capped", #Gates.layout(600, 600) <= Gates.maxCount)

local camp = Camp.create({ x1 = 120, y1 = 120, x2 = 219, y2 = 259, z = 0 }, "Gates")
camp.phase = "plan"
camp.options.recruit = false
check("camp created", camp ~= nil)
local added = Plan.generate(camp)
check("plan generated", added > 20, added)

local fence
for _, p in ipairs(Build.list(camp)) do if p.kind == "fence" then fence = p end end
check("fence has gates", fence ~= nil and type(fence.gates) == "table" and #fence.gates == 6, fence and fence.gates and #fence.gates)
local gateSlots, stagesById = 0, {}
for _, slot in ipairs(Bp.fenceSlots(fence)) do if slot.gate then gateSlots = gateSlots + 1 end end
check("three slots per gate", gateSlots == 18, gateSlots)
for _, stage in ipairs(Bp.stages(fence)) do stagesById[stage.id] = stage end
check("gate stage is open drivable lanes", stagesById.gate ~= nil and #stagesById.gate.ops == 0, stagesById.gate and #stagesById.gate.ops)
check("fence stage keeps wall", stagesById.fence ~= nil and #stagesById.fence.ops == 2 * (100 + 140) * 1 - 18 + 0, stagesById.fence and #stagesById.fence.ops)

local counts = {}
for _, p in ipairs(Build.list(camp)) do counts[p.kind] = (counts[p.kind] or 0) + 1 end
check("post per gate", counts.post == 6, counts.post)
check("guardhouse per gate", counts.guardhouse >= 5, counts.guardhouse)
check("bay per gate", counts.bay >= 5, counts.bay)
check("towers flank gates", (counts.tower or 0) >= 12, counts.tower)
check("motor pool planned", (counts.motorpool or 0) >= 1, counts.motorpool)
check("garage planned", (counts.garage or 0) >= 1, counts.garage)
check("training range planned", (counts.range or 0) >= 1, counts.range)
check("houses still planned", ((counts.house_s or 0) + (counts.house_m or 0) + (counts.house_l or 0)) >= 20)

local list = Build.list(camp)
local clash = false
for i = 1, #list do
    for j = i + 1, #list do
        if list[i].kind ~= "fence" and list[j].kind ~= "fence" and Build.overlaps(Bp.footprint(list[i]), Bp.footprint(list[j])) then clash = true end
    end
end
check("no overlaps", not clash)

local stagesOk, opCount = true, 0
for _, p in ipairs(list) do
    local ok, stages = pcall(Bp.stages, p)
    if not ok or type(stages) ~= "table" or #stages == 0 then stagesOk = false
    else
        for _, stage in ipairs(stages) do
            local seen = {}
            for _, op in ipairs(stage.ops) do
                opCount = opCount + 1
                if type(op.x) ~= "number" or type(op.y) ~= "number" or seen[op.slot] then stagesOk = false end
                seen[op.slot] = true
                if op.e ~= nil and A.Entities[op.e] == nil then stagesOk = false end
            end
        end
    end
end
check("all stages valid", stagesOk, opCount)

local postProject
for _, p in ipairs(list) do if p.kind == "post" and p.gkey ~= nil then postProject = p break end end
local props = 0
for _, stage in ipairs(Bp.stages(postProject)) do
    if stage.id == "furnish" then props = #stage.ops end
end
check("post has defences", props >= 20, props)

local main = Gates.list(camp)[1]
local inner = Posts.innerEnd(camp, main)
check("inner end beyond apron", inner ~= nil and A.Districts.gate(camp).y == inner.y)

for _, p in ipairs(list) do p.status = "done" end
check("bays available", #Posts.bays(camp) >= 6 + 3, #Posts.bays(camp))
check("guard points", #Posts.guardPoints(camp) == 12, #Posts.guardPoints(camp))
check("gate sites", #Posts.gateSites(camp) == 6)
local summary = Posts.summary(camp)
check("summary", summary.gates == 6 and summary.posts == 6 and summary.garage == true, summary.posts)
for _ = 1, 3 do Plan.generate(camp) end
check("generation converges", Plan.generate(camp) == 0)

local cx, cy = Geo.center(camp)
Camp.addStorage(camp, math.floor(cx), math.floor(cy), 0)
Camp.addStorage(camp, math.floor(cx) + 1, math.floor(cy), 0)
Stock.refresh(camp)
for i = 1, 5 do
    ADDACTOR(reg, "u" .. i, "friendly", math.floor(cx) + i, math.floor(cy) + 3, A.World.square(math.floor(cx) + i, math.floor(cy) + 3, 0))
    Settlers.settle(camp, "u" .. i, "Man" .. i)
end
camp.settlers.u1.role = "mechanic"
camp.settlers.u2.role = "worker"
camp.settlers.u3.role = "builder"
camp.settlers.u4.role = "scavenger"
camp.settlers.u5.role = "guard"

local box = Stock.crate(camp, camp.storage[1]):getContainer()
local function junk(category, weight, flag)
    local item = { class = "InventoryItem", full = "Base.Junk" .. category, md = {} }
    function item:getFullType() return self.full end
    function item:getDisplayCategory() return category end
    function item:getActualWeight() return weight end
    function item:getModData() return self.md end
    if flag then item.md.ALCj = true end
    box:AddItem(item)
    return item
end
local nailsBefore = camp.stock.nails or 0
camp.recycleReady = true
local kept = junk("Tool", 1.2, false)
for i = 1, 10 do junk("Tool", 1.2, true) junk("Clothing", 0.5, true) junk("Furniture", 3, true) end
local protected = junk("Weapon", 2, true)
local bag = junk("Bag", 1, true)
function bag:getInventory() return { getItems = function() return { size = function() return 0 end, get = function() return nil end } end, Remove = function() end } end
Stock.refresh(camp)
local processed
for _ = 1, 6 do processed = Recycle.step(camp, 4, 1) end
Stock.refresh(camp)
local remaining = 0
for i = 0, box:getItems():size() - 1 do
    local item = box:getItems():get(i)
    if item.getDisplayCategory ~= nil and item:getDisplayCategory() ~= "" and item.full ~= nil and string.sub(item.full, 1, 9) == "Base.Junk" then remaining = remaining + 1 end
end
check("junk recycled", remaining <= 3, remaining)
check("nails produced", (camp.stock.nails or 0) > nailsBefore + 20, camp.stock.nails)
check("metal or planks produced", (camp.stock.planks or 0) > 0 and ((camp.stock.rope or 0) > 0))
check("unflagged junk kept", (function()
    for i = 0, box:getItems():size() - 1 do if box:getItems():get(i) == kept then return true end end
    return false
end)())
check("weapon protected", (function()
    for i = 0, box:getItems():size() - 1 do if box:getItems():get(i) == protected then return true end end
    return false
end)())

camp.kitGiven = nil
local before = camp.stock.nails or 0
Recycle.starterKit(camp)
Stock.refresh(camp)
check("starter kit delivers nails", (camp.stock.nails or 0) >= before + 100, camp.stock.nails)
check("kit once", Recycle.starterKit(camp) == false)

local forgeBefore = camp.stock.nails or 0
Stock.deposit(camp, "Base.ScrapMetal", 30)
Stock.refresh(camp)
camp.stock.nails = 0
Recycle.nailFloor = 10000
local forged = Recycle.forge(camp, 3, 5)
Recycle.nailFloor = 150
check("forge makes nails from metal", forged >= 60, forged)

for _ = 1, 1200 do Skills.step(camp, 1) end
local u3 = camp.settlers.u3
check("skills grow", Skills.level(u3, "build") >= 1, Skills.level(u3, "build"))
check("factor above one", Skills.factor(camp, "build") > 1.05, Skills.factor(camp, "build"))
check("side skills train", Skills.totalLevel(u3) > Skills.level(u3, "build"))
local best = Skills.best(u3)
check("best skill", best == "build", best)

local camo = newVehicle(7, "Base.PickUpTruck_Camo", 30, 30)
local civil = newVehicle(8, "Base.CarNormal", 40, 40)
check("military detection", Motor.isMilitary("Base.PickUpTruck_Camo") and Motor.isMilitary("Base.BTR80") and not Motor.isMilitary("Base.CarNormal"))
check("burnt excluded", not Motor.isMilitary("Base.ArmyTruckBurnt"))
check("candidate found", Motor.candidate(camp) == camo)
camp.motor = nil
for _ = 1, 400 do
    HOURS = HOURS + 1 / 60
    Motor.step(camp, 1)
end
local state = Motor.state(camp)
check("hauled one vehicle", state.moved == 1, state.moved)
check("old vehicle removed", camo.removed == true and civil.removed == false)
local parkedEntry
for key, entry in pairs(state.parked) do parkedEntry = entry end
check("registered at post bay", parkedEntry ~= nil and parkedEntry.military == true)
local fresh = Motor.find(parkedEntry.id)
check("fuel and condition copied", fresh ~= nil and fresh.parts[1].amount == 30 and fresh.parts[2].cond == 40 or (fresh ~= nil and fresh.parts[2].cond == 100), fresh and fresh.parts[2].cond)
check("armor counted", state.armor >= Motor.armorMilitary, state.armor)
check("no second job for civilians", ALifeCamp.isEmpty(state.jobs))

Stock.deposit(camp, "Base.ScrapMetal", 40)
Stock.refresh(camp)
for _ = 1, 60 do
    HOURS = HOURS + 1 / 60
    Motor.step(camp, 1)
end
local engine = Motor.find(parkedEntry.id)
check("garage repairs parked vehicles", engine ~= nil and engine.parts[2].cond == 100, engine and engine.parts[2].cond)


local Cheats = A.Cheats
check("cheat camp found", Cheats.camp(PLAYER) == camp)
local nailsNow = camp.stock.nails or 0
local text = Cheats.run("fillnails", PLAYER)
Stock.refresh(camp)
check("cheat nails", (camp.stock.nails or 0) >= nailsNow + 900, camp.stock.nails)
check("cheat message", type(text) == "string" and #text > 0, text)
check("cheat status", #Cheats.status(PLAYER) > 0)
Cheats.run("supplies", PLAYER)
Cheats.run("maxskills", PLAYER)
check("max skills", Skills.level(camp.settlers.u1, "mech") == Skills.maxLevel)
Cheats.toggle("godfolk", PLAYER, true)
check("toggle stored", Cheats.toggle("godfolk", PLAYER) == true and camp.options.godfolk == true)
check("default toggle", Cheats.toggle("recruit", PLAYER) == false)
check("raid toggle default", Cheats.optionOn({ options = {} }, "raids") == true)
local small = Camp.create({ x1 = 250, y1 = 120, x2 = 291, y2 = 160, z = 0 }, "Small")
small.options.recruit = false
small.phase = "plan"
Plan.generate(small)
local openBefore = 0
for _, p in ipairs(Build.list(small)) do if p.status ~= "done" then openBefore = openBefore + 1 end end
Cheats.camp = function() return small end
Cheats.run("buildnow", PLAYER)
local doneNow = 0
for _, p in ipairs(Build.list(small)) do if p.status == "done" then doneNow = doneNow + 1 end end
check("cheat builds projects", doneNow >= 1, doneNow .. "/" .. openBefore)
Cheats.toggle("freeBuild", PLAYER, true)
check("free build option", small.options.freeBuild == true)
local ph = {}
for _, p in ipairs(Build.list(small)) do if p.status ~= "done" then ph[#ph + 1] = p break end end
if ph[1] ~= nil then check("free build pays", Build.pay(small, ph[1]) == true) end
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
