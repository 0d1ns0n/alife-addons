SKIPMOD = {
    ["shared/ALifeCamp/CampSalvage.lua"] = true, ["shared/ALifeCamp/CampFortify.lua"] = true,
    ["shared/ALifeCamp/CampFitout.lua"] = true, ["shared/ALifeCamp/CampDistricts.lua"] = true,
}
dofile(MOCK)
do
    local baseDerive = ISPanel.derive
    ISPanel.derive = function(self, name)
        local cls = baseDerive(self, name)
        for _, m in ipairs({ "initialise", "instantiate", "setStencilRect", "clearStencilRect", "drawRect", "drawRectBorder", "setX", "setY", "setWidth", "setHeight" }) do
            cls[m] = function() end
        end
        return cls
    end
    ISPanel.prerender = function() end
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Work, Land, Clear, Stats, Adopt, Flags =
    A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Work, A.Land, A.Clear, A.Stats, A.Adopt, A.Flags
local reg, orders = MOCKALIFE()

IsoFlagType = { solidfloor = "solidfloor" }
for x = 30, 200 do for y = 30, 200 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

local function LIST(t)
    return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

local function ROOMDEF(spec)
    local r = { name = spec[1], x = spec[2], y = spec[3], w = spec[4], h = spec[5], z = spec[6] or 0 }
    function r:getName() return self.name end
    function r:getX() return self.x end
    function r:getY() return self.y end
    function r:getW() return self.w end
    function r:getH() return self.h end
    function r:getZ() return self.z end
    function r:getArea() return self.w * self.h end
    return r
end

local function squareAt(x, y, z)
    local sq = A.World.square(x, y, z)
    if sq == nil then
        sq = NEWSQUARE(x, y, z)
        function sq:hasFloor() return self.floorObj ~= nil end
    end
    return sq
end

local function solidFloor(obj)
    local name = obj.sprite.name
    obj.getSprite = function() return { getName = function() return name end, getProperties = function() return { has = function() return true end } end } end
end

local function NEWHOUSE(spec)
    local rooms = {}
    for _, r in ipairs(spec.rooms) do rooms[#rooms + 1] = ROOMDEF(r) end
    local def = { x = spec.x, y = spec.y, w = spec.w, h = spec.h }
    function def:getX() return self.x end
    function def:getY() return self.y end
    function def:getW() return self.w end
    function def:getH() return self.h end
    function def:getRooms() return LIST(rooms) end
    local b = { def = def, spec = spec }
    function b:getDef() return def end
    function b:isResidential() return spec.residential ~= false end
    local levels = spec.levels or 1
    for z = 0, levels - 1 do
        for x = spec.x, spec.x + spec.w - 1 do
            for y = spec.y, spec.y + spec.h - 1 do
                local sq = squareAt(x, y, z)
                sq.building = b
                sq.outside = false
                local floor = sq:addFloor("floors_interior_tilesandwood_01_41")
                solidFloor(floor)
                if z == 0 and x == spec.x and y == spec.y then
                    local wall = NEWOBJ(sq, "IsoObject", "walls_interior_house_01_1")
                    wall.getSprite = function() return { getName = function() return "walls_interior_house_01_1" end, getProperties = function() return { has = function(_, f) return f == "WallN" end } end } end
                end
                if z == 0 and x == spec.x + 1 and y == spec.y + 1 then
                    local chair = NEWOBJ(sq, "IsoThumpable", "carpentry_02_40")
                    chair.isDoor = function() return false end
                    chair.isWindowN = function() return false end
                    chair.isWindowW = function() return false end
                end
            end
        end
    end
    if spec.roof ~= false then
        for x = spec.x, spec.x + spec.w - 1 do
            for y = spec.y, spec.y + spec.h - 1 do
                local sq = squareAt(x, y, levels)
                sq:addFloor("roofs_02_22")
            end
        end
    end
    return b
end

local function OPENING(x, y, class, north)
    local sq = A.World.square(x, y, 0)
    local o = NEWOBJ(sq, class, "x")
    function o:getNorth() return north end
    return o
end

local houseA = { x = 104, y = 104, w = 8, h = 6, levels = 2, rooms = {
    { "bedroom", 104, 104, 4, 3, 0 }, { "kitchen", 108, 104, 4, 3, 0 }, { "livingroom", 104, 107, 4, 3, 0 },
    { "bathroom", 108, 107, 4, 3, 0 }, { "bedroom", 104, 104, 4, 3, 1 }, { "bedroom", 108, 104, 4, 3, 1 } } }
local houseB = { x = 120, y = 104, w = 3, h = 3, rooms = { { "shed", 120, 104, 3, 3, 0 } } }
local houseC = { x = 120, y = 112, w = 6, h = 4, rooms = { { "restaurantdining", 120, 112, 3, 4, 0 }, { "restaurantkitchen", 123, 112, 3, 4, 0 } } }
local houseD = { x = 94, y = 118, w = 8, h = 5, rooms = { { "bedroom", 94, 118, 3, 5, 0 }, { "livingroom", 97, 118, 3, 5, 0 }, { "kitchen", 100, 118, 2, 5, 0 } } }
local houseE = { x = 104, y = 115, w = 8, h = 6, roof = false, rooms = { { "bedroom", 104, 115, 4, 6, 0 }, { "livingroom", 108, 115, 4, 3, 0 }, { "kitchen", 108, 118, 4, 3, 0 } } }
local houseF = { x = 124, y = 120, w = 7, h = 6, rooms = { { "bedroom", 124, 120, 3, 6, 0 }, { "livingroom", 127, 120, 4, 3, 0 }, { "kitchen", 127, 123, 4, 3, 0 } } }

local bA = NEWHOUSE(houseA)
NEWHOUSE(houseB)
NEWHOUSE(houseC)
NEWHOUSE(houseD)
NEWHOUSE(houseE)
NEWHOUSE(houseF)
OPENING(105, 107, "IsoDoor", true)
OPENING(104, 104, "IsoWindow", true)
OPENING(106, 104, "IsoWindow", true)

local rect = { x1 = 100, y1 = 100, x2 = 139, y2 = 129, z = 0 }
local pre = Adopt.preview(rect, 0)
check("preview counts buildings", pre.buildings == 6, pre.buildings)
check("preview counts eligible", pre.eligible == 2, pre.eligible)
check("preview estimates beds", pre.beds > 0, pre.beds)

local function nameBox(text) return { internal = "OK", parent = { entry = { getText = function() return text end } } } end

local popBase = #UIPOP
Flags.draft = { rect = rect, survey = { buildings = 6 }, player = PLAYER }
Flags.onNameAnswer(nil, nameBox("Adopt"))
check("adopt dialog asked", #UIPOP == popBase + 1 and UIPOP[#UIPOP].yesno == true, UIPOP[#UIPOP] and UIPOP[#UIPOP].text)
check("adopt dialog handler", UIPOP[#UIPOP].onclick == Flags.onAdoptAnswer)
check("adopt dialog numbers", UIPOP[#UIPOP].text:find("6") ~= nil and UIPOP[#UIPOP].text:find("2") ~= nil, UIPOP[#UIPOP].text)
UIPOP[#UIPOP].onclick(nil, { internal = "NO" })
check("no keeps nothing: camp demolish all", Store.count() == 1 and Store.list()[1].options.demolish == true and Store.list()[1].options.adopt == false)
check("no creates no adoption state", Store.list()[1].adopt == nil)
Camp.abandon(Store.list()[1])

Flags.draft = { rect = rect, survey = { buildings = 6 }, player = PLAYER }
Flags.onNameAnswer(nil, nameBox("Adopt"))
UIPOP[#UIPOP].onclick(nil, { internal = "YES" })
check("yes creates camp", Store.count() == 1)
local camp = Store.list()[1]
camp.options.autoPlan = false
check("yes sets adopt and demolish", camp.options.adopt == true and camp.options.demolish == true)
check("camp phase clear", camp.phase == "clear")

local wasteRect = { x1 = 150, y1 = 150, x2 = 170, y2 = 170, z = 0 }
NEWHOUSE({ x = 155, y = 155, w = 3, h = 3, rooms = { { "shed", 155, 155, 3, 3, 0 } } })
local preWaste = Adopt.preview(wasteRect, 0)
check("preview shed only", preWaste.buildings == 1 and preWaste.eligible == 0, preWaste.buildings .. "/" .. preWaste.eligible)
Flags.draft = { rect = wasteRect, survey = { buildings = 1 }, player = PLAYER }
Flags.onNameAnswer(nil, nameBox("Waste"))
check("old demolish dialog without eligible", UIPOP[#UIPOP].onclick == Flags.onDemolishAnswer, UIPOP[#UIPOP].text)
UIPOP[#UIPOP].onclick(nil, { internal = "YES" })
local wasteCamp = Store.campAt(160, 160, 0)
check("old flow demolish only", wasteCamp ~= nil and wasteCamp.options.demolish == true and wasteCamp.options.adopt == false)
Camp.abandon(wasteCamp)

local st = camp.adopt
check("adopt state exists", st ~= nil and st.size == 2, st and st.size)
local recA, recF = st.items["104,104,0"], st.items["124,120,0"]
check("rec keys", recA ~= nil and recF ~= nil)
check("rec status queued", recA.status == "queued" and recF.status == "queued")
check("rec ids distinct", recA.id ~= recF.id and recA.id >= 1)
check("rec rect", recA.rect.x1 == 104 and recA.rect.y1 == 104 and recA.rect.x2 == 111 and recA.rect.y2 == 109 and recA.rect.z == 0)
check("rec floors", recA.floors == 2 and recF.floors == 1, recA.floors .. "/" .. recF.floors)
check("rec rooms", #recA.rooms == 6 and #recF.rooms == 3, #recA.rooms)
local bed = recA.rooms[1]
check("room fields", bed.name == "bedroom" and bed.x1 == 104 and bed.x2 == 107 and bed.y2 == 106 and bed.z == 0 and bed.area == 12)
check("room windows counted", bed.windows == 2, bed.windows)
check("room doors counted on shared wall", bed.doors == 1 and recA.rooms[3].doors == 1, bed.doors .. "/" .. recA.rooms[3].doors)
check("rec score ordering", recA.score > recF.score, recA.score .. "/" .. recF.score)
check("rec capacity zero before work", recA.capacity == 0)
check("rec estimate positive", recA.estimate >= 6 and recF.estimate >= 1, recA.estimate)
check("skipped reasons", st.skipped["120,104,0"] == "tiny" and st.skipped["120,112,0"] == "shop" and st.skipped["94,118,0"] == "border" and st.skipped["104,115,0"] == "ruin")
check("covered inside rect", Adopt.covered(camp, 108, 106) == recA and Adopt.covered(camp, 103, 103) == recA)
check("not covered outside", Adopt.covered(camp, 100, 100) == nil and Adopt.covered(camp, 121, 105) == nil)
check("overlaps helper", Adopt.overlaps(camp, { x1 = 112, y1 = 104, x2 = 114, y2 = 106 }) == recA and Adopt.overlaps(camp, { x1 = 113, y1 = 104, x2 = 114, y2 = 106 }) == nil)

local bad = Build.fits(camp, "house_s", 108, 108, 4, 4, nil, "S")
check("build refuses adopted spot", bad == false and select(2, Build.fits(camp, "house_s", 108, 108, 4, 4, nil, "S")) == "adopted")
check("plan cell adopted", Plan.cellState(camp, 106, 106) == Plan.ADOPTED and Plan.cellState(camp, 101, 101) ~= Plan.ADOPTED)
check("add refused on adopted", select(2, Build.add(camp, "house_s", 107, 105, {})) == "adopted")

local wallSquare = A.World.square(104, 104, 0)
local wallObject
for _, o in ipairs(wallSquare.objects) do if o.sprite.name == "walls_interior_house_01_1" then wallObject = o end end
check("clear apply refuses adopted structure", Clear.apply(camp, { kind = "structure", object = wallObject, square = wallSquare }) == false and #wallSquare.objects == 3)
check("clear scan sees only haulables in adopted house", #Clear.scanSquare(camp, wallSquare, true) == 0)
local before = Land.dirty(camp, 1)
check("land dirty skips adopted when camp given", Land.dirty(camp, 1, camp) < before, Land.dirty(camp, 1, camp) .. "/" .. before)

local control = Camp.create({ x1 = 150, y1 = 100, x2 = 189, y2 = 129, z = 0 }, "Control", { demolish = true, adopt = false, autoPlan = false })
NEWHOUSE({ x = 154, y = 104, w = 8, h = 6, levels = 2, rooms = houseA.rooms })
control.phase = "clear"
check("control options", control.options.adopt == false and control.options.demolish == true)
check("control guards nothing", Adopt.guards(control, A.World.square(156, 106, 0)) == false and control.adopt == nil)

local function SNAP(x1, y1, x2, y2, zmax)
    local out = {}
    for z = 0, zmax do
        for x = x1, x2 do
            for y = y1, y2 do
                local sq = A.World.square(x, y, z)
                if sq ~= nil then
                    local names = {}
                    for _, o in ipairs(sq.objects) do names[#names + 1] = tostring(o.sprite and o.sprite.name) .. ":" .. tostring(o.class) end
                    out[x .. "," .. y .. "," .. z] = table.concat(names, "|") .. "#" .. tostring(sq.floorName)
                end
            end
        end
    end
    return out
end
local function SAME(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then return false, key end
    end
    for key in pairs(b) do
        if a[key] == nil then return false, key end
    end
    return true
end

local calls = { analyze = {}, step = {} }
local function count(list, text)
    local n = 0
    for _, v in ipairs(list) do if v == text then n = n + 1 end end
    return n
end

local function STUB(name, key, total)
    local m = { hold = false, total = total, fail = false, need = nil }
    function m.analyze(c, rec)
        calls.analyze[#calls.analyze + 1] = name .. ":" .. rec.id
        rec[key] = rec[key] or { got = 0 }
        return { planks = 2, nails = 2 }, m.total
    end
    function m.step(c, rec, labor, minutes)
        calls.step[#calls.step + 1] = name .. ":" .. rec.id
        if m.fail then error("boom") end
        local d = rec[key]
        if m.hold then return false, 0.3, 0 end
        if m.need ~= nil and (c.stock.planks or 0) < m.need then
            d.waiting = { planks = m.need - (c.stock.planks or 0) }
            return false, d.got / m.total, 0
        end
        d.waiting = nil
        d.got = d.got + labor * minutes
        if key == "fortify" then
            d.posts = { { x = rec.rect.x1 + 2, y = rec.rect.y1 + 1, z = 1 } }
            d.sealed = 6
        end
        return d.got >= m.total, math.min(1, d.got / m.total), labor * minutes
    end
    function m.summary(rec)
        local d = rec[key] or {}
        if key == "fitout" then return { beds = 6 } end
        if key == "fortify" then return { sealed = d.sealed or 0, posts = d.posts } end
        return { got = d.got }
    end
    return m
end

local salvage, fortify, fitout = STUB("Salvage", "salvage", 30), STUB("Fortify", "fortify", 40), STUB("Fitout", "fitout", 50)
salvage.hold = true
A.Salvage, A.Fortify, A.Fitout = salvage, fortify, fitout

ADDACTOR(reg, "alice", "friendly", 112, 125, A.World.square(112, 125, 0))
ADDACTOR(reg, "bob", "friendly", 113, 125, A.World.square(113, 125, 0))
ADDACTOR(reg, "carl", "friendly", 160, 125, A.World.square(160, 125, 0))
Settlers.settle(camp, "alice", "Alice")
Settlers.settle(camp, "bob", "Bob")
Settlers.settle(control, "carl", "Carl")
camp.settlers.alice.role = "builder"
camp.settlers.bob.role = "builder"
control.settlers.carl.role = "builder"

local lateSquares = {}
local snapA = SNAP(102, 102, 113, 111, 3)
local snapF = SNAP(122, 118, 132, 128, 3)
local snapBuilt = SNAP(154, 104, 161, 109, 3)
local snapB = SNAP(120, 104, 122, 106, 2)

local function tick(n)
    for _ = 1, n do
        HOURS = HOURS + 1 / 60
        fire("EveryOneMinute")
    end
end

tick(90)
check("camp finished clearing despite kept houses", camp.phase == "plan", camp.phase)
local same, key = SAME(snapA, SNAP(102, 102, 113, 111, 3))
check("adopted house A untouched (all floors)", same, key)
same, key = SAME(snapF, SNAP(122, 118, 132, 128, 3))
check("adopted house F untouched", same, key)
check("house A still has wall and chair and floors", #A.World.square(104, 104, 0).objects >= 3 and A.World.square(106, 106, 1).floorObj ~= nil and A.World.square(106, 106, 2).floorObj ~= nil)
local shedSq = A.World.square(121, 105, 0)
check("tiny shed wiped to ground", #shedSq.objects == 1 and shedSq.floorName == "blends_natural_01_64", #shedSq.objects .. "/" .. tostring(shedSq.floorName))
check("shed wall removed", #A.World.square(120, 104, 0).objects == 1)
check("shop wiped", #A.World.square(121, 113, 0).objects == 1 and A.World.square(121, 113, 0).floorName == "blends_natural_01_64")
check("ruin wiped", #A.World.square(105, 116, 0).objects == 1 and A.World.square(105, 116, 0).floorName == "blends_natural_01_64")
check("border building wiped inside camp", A.World.square(100, 119, 0).floorName == "blends_natural_01_64")
check("border building outside camp kept", A.World.square(95, 119, 0).floorName == "floors_interior_tilesandwood_01_41")
check("control demolished good house", A.World.square(156, 106, 0).floorName == "blends_natural_01_64" and #A.World.square(156, 106, 1).objects == 0)
check("control wall removed", #A.World.square(154, 104, 0).objects == 1)
check("control keeps no adoption state", control.adopt == nil)
check("hold keeps salvage status", recA.status == "salvage" and recF.status == "queued", recA.status .. "/" .. recF.status)
check("salvage analyzed once before steps", count(calls.analyze, "Salvage:" .. recA.id) == 1, count(calls.analyze, "Salvage:" .. recA.id))
check("queued rec not analyzed", count(calls.analyze, "Salvage:" .. recF.id) == 0)
check("labor limit gives single active rec", #camp.adoptActive == 1 and camp.adoptActive[1] == recA.id, #camp.adoptActive)
check("start logged", (function() for _, e in ipairs(camp.log) do if e.k == "adopt_start" and e.a == recA.id then return true end end return false end)())
check("found logged", (function() for _, e in ipairs(camp.log) do if e.k == "adopt_found" and e.a == 2 then return true end end return false end)())

local lateHouse = NEWHOUSE({ x = 130, y = 104, w = 7, h = 6, rooms = { { "bedroom", 130, 104, 3, 6, 0 }, { "livingroom", 133, 104, 4, 3, 0 }, { "kitchen", 133, 107, 4, 3, 0 } } })
local snapLate = SNAP(128, 102, 138, 111, 2)
camp.phase = "clear"
camp.clear = nil
tick(30)
check("late building adopted lazily by clearing guard", st.items["130,104,0"] ~= nil and st.items["130,104,0"].status ~= nil)
same, key = SAME(snapLate, SNAP(128, 102, 138, 111, 2))
check("late building untouched", same, key)
check("late building queued behind", st.items["130,104,0"] ~= nil and st.items["130,104,0"].status == "queued")
check("clear phase over again", camp.phase == "plan", camp.phase)

local box = Stock.crate(camp, camp.storage[1]):getContainer()
for _ = 1, 40 do box:AddItem("Base.Plank") end
for _ = 1, 40 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
fitout.need = 9999
salvage.hold = false
local seen = {}
local maxActive = 0
local guardLoop = 0
repeat
    tick(1)
    guardLoop = guardLoop + 1
    local active = 0
    for _, rec in ipairs(Adopt.list(camp)) do
        if rec.status == "salvage" or rec.status == "fortify" or rec.status == "fitout" then active = active + 1 end
        seen[rec.id .. ":" .. rec.status] = true
    end
    maxActive = math.max(maxActive, active)
until recA.status == "fitout" or guardLoop > 400
check("rec A reached fitout", recA.status == "fitout", recA.status)
check("only one rec active at a time with low labor", maxActive == 1, maxActive)
check("status sequence seen", seen[recA.id .. ":salvage"] and seen[recA.id .. ":fortify"] and seen[recA.id .. ":fitout"] and not seen[recA.id .. ":done"])
check("fortify posts stored", type(recA.fortify.posts) == "table" and #recA.fortify.posts == 1)
check("stage log entries", (function()
    local starts, stages = 0, 0
    for _, e in ipairs(camp.log) do
        if e.k == "adopt_stage" and e.a == recA.id then stages = stages + 1 end
        if e.k == "adopt_start" then starts = starts + 1 end
    end
    return stages == 2 and starts >= 1
end)())
tick(3)
check("stage analyze once each", count(calls.analyze, "Salvage:" .. recA.id) == 1 and count(calls.analyze, "Fortify:" .. recA.id) == 1 and count(calls.analyze, "Fitout:" .. recA.id) == 1)
check("waiting recorded", recA.waiting ~= nil and recA.waiting.planks ~= nil and recA.waiting.planks > 0, recA.waiting and recA.waiting.planks)
local summary = Adopt.summary(camp, recA)
check("summary waiting", summary.waiting ~= nil and summary.waiting.planks > 0 and summary.stage == "fitout")
check("summary progress between", summary.progress > 0.5 and summary.progress < 1, summary.progress)
local win = setmetatable({ survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 } }, A.Window)
local lines = win:adoptLines(camp)
local hasWait, hasRow = false, false
for _, l in ipairs(lines) do
    if l.text:find("материалов") then hasWait = true end
    if l.text:find("№" .. recA.id) then hasRow = true end
end
check("window adopt tab shows house and waiting", hasWait and hasRow and #lines >= 4, #lines)

local before = count(calls.analyze, "Fitout:" .. recA.id)
Adopt.ready = {}
Adopt.index = {}
tick(2)
check("analyze again after reload", count(calls.analyze, "Fitout:" .. recA.id) == before + 1, count(calls.analyze, "Fitout:" .. recA.id))
check("covered after index rebuild", Adopt.covered(camp, 106, 106) == recA)
check("still fitout and waiting", recA.status == "fitout" and recA.waiting ~= nil)

fitout.need = nil
local finished = 0
guardLoop = 0
repeat
    tick(1)
    guardLoop = guardLoop + 1
until (recA.status == "done" and recF.status == "done") or guardLoop > 600
check("both houses done", recA.status == "done" and recF.status == "done", recA.status .. "/" .. recF.status)
check("capacity from fitout summary", recA.capacity == 6 and recF.capacity == 6, recA.capacity .. "/" .. recF.capacity)
check("done logged with capacity", (function() for _, e in ipairs(camp.log) do if e.k == "adopt_done" and e.a == recA.id and e.b == 6 then return true end end return false end)())
check("notifications sent", #PLAYER.notes >= 4, #PLAYER.notes)
check("camp adopted stat", (camp.stats.adopted or 0) >= 2, camp.stats.adopted)
check("waiting cleared when done", recA.waiting == nil)
check("progress full", Adopt.overall(recA) == 1 and Adopt.summary(camp, recA).progress == 1)

local function stepsOf(rec)
    return count(calls.step, "Salvage:" .. rec.id) + count(calls.step, "Fortify:" .. rec.id) + count(calls.step, "Fitout:" .. rec.id)
end
local stepsA, stepsF, serial = stepsOf(recA), stepsOf(recF), st.serial
tick(30)
check("done recs not stepped again", stepsOf(recA) == stepsA and stepsOf(recF) == stepsF, stepsOf(recA) .. "/" .. stepsA)
local lateRec = st.items["130,104,0"]
check("late rec processed too", lateRec.status == "done" or lateRec.status == "fitout" or lateRec.status == "fortify" or lateRec.status == "salvage", lateRec.status)
Adopt.discover(camp)
check("rediscovery adds nothing", st.serial == serial and st.size == 3, st.serial .. "/" .. st.size)
local analyzeAfter = #calls.analyze
tick(1)
check("no new analyze for done", #calls.analyze == analyzeAfter)

guardLoop = 0
repeat
    tick(2)
    guardLoop = guardLoop + 1
until lateRec.status == "done" or guardLoop > 300
check("all three houses done", lateRec.status == "done")

local counts = Stats.counts(camp)
check("counts include adopted houses", counts.adopted == 3 and counts.houses == 3 and counts.adoptBeds == 18, counts.adopted .. "/" .. counts.houses .. "/" .. counts.adoptBeds)
check("projects include adopted", counts.projects >= 3 and counts.done >= 3)
check("capacity includes adopted beds", Stats.capacity(counts) == 18, Stats.capacity(counts))
local with = Stats.compute(camp)
check("defense counts fortify", counts.adoptDefense > 0, counts.adoptDefense)
local saved = counts.adoptDefense
for _, rec in ipairs(Adopt.list(camp)) do rec.sealed, rec.stands = 0, 0 end
local without = Stats.compute(camp)
check("defense lower without fortify", with.defense > without.defense and with.defense - without.defense == saved, with.defense .. "/" .. without.defense .. "/" .. saved)
for _, rec in ipairs(Adopt.list(camp)) do Adopt.refresh(rec) end
check("stats level counts adopted houses", with.counts.houses >= 2)

local plain = Plan.targets(control)
local adoptedTargets = Plan.targets(camp)
check("targets reduce houses", adoptedTargets.houses < plain.houses, adoptedTargets.houses .. "/" .. plain.houses)
check("towers unaffected", adoptedTargets.towers == plain.towers and adoptedTargets.farms == plain.farms)

local dcalls = 0
A.Districts = { generate = function(c) dcalls = dcalls + 1 return 3 end, colors = { plaza = { 0.2, 0.4, 0.6 } } }
local added = Plan.generate(camp)
check("districts called once", dcalls == 1)
check("generate counts districts", added >= 3, added)
local houses = 0
local clash = false
for _, p in ipairs(Build.list(camp)) do
    if p.kind:sub(1, 5) == "house" then houses = houses + 1 end
    if p.kind ~= "fence" then
        local r = Bp.footprint(p)
        if Adopt.overlaps(camp, r) ~= nil then clash = true end
    end
end
check("new houses fewer than plain", houses == adoptedTargets.houses, houses .. "/" .. adoptedTargets.houses)
check("no project on adopted houses", not clash)
A.Districts = { generate = function() error("broken") end }
check("broken districts do not break generate", pcall(Plan.generate, camp) == true)
A.Districts = nil
check("generate works without districts", Plan.generate(camp) == 0)

local controlAdded = Plan.generate(control)
check("control generate unaffected", controlAdded >= 4)

local guards = { "g1", "g2", "g3", "g4", "g5", "g6", "g7", "g8" }
for i, uid in ipairs(guards) do
    ADDACTOR(reg, uid, "friendly", 110 + i, 126, A.World.square(110 + i, 126, 0))
    Settlers.settle(camp, uid, uid)
    camp.settlers[uid].role = "guard"
end
local posts = Work.posts(camp)
local hasUpper, gateLast = false, false
for _, p in ipairs(posts) do if p.z == 1 then hasUpper = true end end
local gate = Work.gate(camp)
gateLast = posts[#posts].x == gate.x and posts[#posts].y == gate.y
check("posts include fortify post upstairs", hasUpper, #posts)
check("gate stays last", gateLast)
tick(4)
local anchoredUp = 0
for _, uid in ipairs(guards) do
    local order = orders[uid]
    if order ~= nil and order.anchor ~= nil and order.anchor.z == 1 then anchoredUp = anchoredUp + 1 end
end
check("some guards anchored to house posts", anchoredUp >= 1, anchoredUp)
local exactList = {}
for _, p in ipairs(posts) do if p.exact then exactList[#exactList + 1] = p end end
local exactHits = 0
for _, uid in ipairs(guards) do
    local order = orders[uid]
    if order ~= nil and order.anchor ~= nil and order.anchor.z == 1 then
        for _, p in ipairs(exactList) do
            if p.z == order.anchor.z and math.abs(p.x - order.anchor.x) <= 1 and math.abs(p.y - order.anchor.y) <= 1 then
                exactHits = exactHits + 1
                break
            end
        end
    end
end
check("house posts used without jitter", exactHits == anchoredUp and exactHits >= 1, exactHits)

fortify.fail = true
local thirdCamp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Third", { demolish = false, adopt = true })
NEWHOUSE({ x = 64, y = 64, w = 7, h = 6, rooms = { { "bedroom", 64, 64, 3, 6, 0 }, { "livingroom", 67, 64, 4, 3, 0 }, { "kitchen", 67, 67, 4, 3, 0 } } })
thirdCamp.phase = "plan"
Adopt.discover(thirdCamp)
check("third camp discovered", thirdCamp.adopt.size == 1)
ADDACTOR(reg, "dan", "friendly", 80, 80, A.World.square(80, 80, 0))
ADDACTOR(reg, "eve", "friendly", 81, 80, A.World.square(81, 80, 0))
Settlers.settle(thirdCamp, "dan", "Dan")
Settlers.settle(thirdCamp, "eve", "Eve")
thirdCamp.settlers.dan.role = "builder"
thirdCamp.settlers.eve.role = "builder"
local recT = thirdCamp.adopt.items["64,64,0"]
guardLoop = 0
repeat
    tick(1)
    guardLoop = guardLoop + 1
until recT.status == "done" or guardLoop > 400
check("failing stage is skipped after errors", recT.status == "done" and recT.skip ~= nil and recT.skip.fortify == true, recT.status)
check("errors printed", #PRINTS > 0)
fortify.fail = false

local enabledOff = Camp.create({ x1 = 40, y1 = 140, x2 = 59, y2 = 159, z = 0 }, "Off", { adopt = false })
NEWHOUSE({ x = 44, y = 144, w = 7, h = 6, rooms = { { "bedroom", 44, 144, 3, 6, 0 }, { "livingroom", 47, 144, 4, 3, 0 }, { "kitchen", 47, 147, 4, 3, 0 } } })
check("disabled camp finds nothing", Adopt.step(enabledOff, 5, 1) == 0 and enabledOff.adopt == nil)

local info = A.Planner.infoLines({ selectedAdopt = recA.id }, camp)
check("planner info for adopted house", #info >= 1 and info[1]:find("№" .. recA.id) ~= nil, info[1])
local logs = win:logLines(camp)
local adoptLogs = 0
for _, l in ipairs(logs) do if l.text:find("Дом №") or l.text:find("обживание") then adoptLogs = adoptLogs + 1 end end
check("log lines render adopt entries", adoptLogs >= 5, adoptLogs)
A.Districts = { describe = function() return { { key = "plaza", name_key = "Room_other", count = 3, done = 1 } } end }
A.Window.districtCache.id = nil
local overview = win:lines(camp)
A.Districts = nil
local overviewAdopt, overviewDistricts = false, false
for _, l in ipairs(overview) do
    if l.text:find("Обжитые дома") then overviewAdopt = true end
    if l.text:find("Районы лагеря") and l.text:find("готово 1 из 3") then overviewDistricts = true end
end
check("overview shows adopted houses", overviewAdopt)
check("overview shows districts", overviewDistricts)
check("totals", Adopt.totals(camp).done == 3 and Adopt.totals(camp).items == 3 and Adopt.totals(camp).skipped >= 4)
local list = Adopt.summaries(camp)
check("summaries complete", #list == 3 and list[1].names[1] ~= nil and list[1].rooms >= 3)
check("room labels", Adopt.roomLabel("bedroom") ~= nil and Adopt.roomLabel("zzz") ~= "UI_ALC_Room_other")

local plannerWin = A.Planner.open(camp)
A.Planner.createChildren(plannerWin)
local canvas = plannerWin.canvas
canvas.width, canvas.height = 600, 400
local owner = { grid = Plan.newGrid(camp), tool = "fence", selectedAdopt = recA.id }
function owner:camp() return camp end
canvas.owner = owner
local drawn = {}
canvas.drawRect = function(_, x, y, w, h, a, r, g, b) drawn[#drawn + 1] = { x = x, y = y, w = w, h = h, a = a, r = r, g = g, b = b } end
canvas:prerender()
local adoptedDrawn = 0
for _, d in ipairs(drawn) do
    if math.abs(d.r - 0.25) < 0.001 and math.abs(d.g - 0.75) < 0.001 and math.abs(d.b - 0.85) < 0.001 then adoptedDrawn = adoptedDrawn + 1 end
end
check("planner canvas draws done adopted houses", adoptedDrawn == 3, adoptedDrawn)
local hit = canvas:adoptAt(106, 106)
check("canvas adoptAt", hit ~= nil and hit.id == recA.id and canvas:adoptAt(101, 101) == nil)
local plain = setmetatable({ campId = camp.id, door = "S", canvas = canvas }, { __index = function(_, k) return rawget(A.Planner, k) end })
canvas.owner = plain
plain:onCell(106, 106)
check("planner selects adopted house", plain.selectedAdopt == recA.id and plain.selected == nil)
plain:onCell(101, 101)
check("planner deselects on empty cell", plain.selectedAdopt == nil)
plain.tool = "house_s"
plain:onCell(107, 105)
check("planner refuses building on adopted house", plain.message ~= nil and plain.message:find("обжитый") ~= nil, plain.message)
local colorFn = canvas.districtColor
A.Districts = { colors = { plaza = { 0.2, 0.4, 0.6 }, lamp = { r = 0.9, g = 0.8, b = 0.7 } } }
local c1, c2, c3 = colorFn("plaza"), colorFn("lamp"), colorFn("unknown")
check("district colors both formats", c1[1] == 0.2 and c1[3] == 0.6 and c2[1] == 0.9 and c2[3] == 0.7 and c3[1] == 1)
A.Districts = nil

local windowObj = A.Window.open(camp)
A.Window.createChildren(windowObj)
windowObj.survey = win.survey
for _, tab in ipairs(A.Window.tabIds) do
    windowObj:selectTab(tab)
    windowObj:prerender()
end
check("window has adopt tab", A.Window.tabIds[2] == "adopt" and windowObj.tabButtons.adopt ~= nil)

camp.options.expand = false
local rectSnapshot = Geo.copy(camp)
camp.x2 = camp.x2 + 8
Adopt.state(camp)
check("rect change resets skipped", ALifeCamp.isEmpty(camp.adopt.skipped))
camp.x2 = rectSnapshot.x2

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
