dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local fortifyFile = loadfile(ROOT .. "/shared/ALifeCamp/CampFortify.lua")
check("module file loads", fortifyFile ~= nil)
fortifyFile()
local F = A.Fortify
local Camp, Stock, World = A.Camp, A.Stock, A.World

check("api present", type(F.analyze) == "function" and type(F.step) == "function" and type(F.summary) == "function")

local keys = 0
for k in pairs(UIJSON) do
    if k:find("^UI_ALC_Fortify") then keys = keys + 1 end
end
check("text keys present", keys >= 4, keys)

PLANKS_ADDED, REAL_ITEMS, TRANSMITS, TOUCH, GLASS_CLEANED = 0, 0, 0, {}, 0

local function newBarricade(owner, slot)
    local b = { planks = 0, metal = false, bars = false, owner = owner, slot = slot }
    function b:addPlank(chr, item)
        if self.metal or self.bars or self.planks >= 4 then return end
        self.planks = self.planks + 1
        PLANKS_ADDED = PLANKS_ADDED + 1
        if item ~= nil then REAL_ITEMS = REAL_ITEMS + 1 end
    end
    function b:getNumPlanks() return self.planks end
    function b:canAddPlank() return not self.metal and not self.bars and self.planks < 4 end
    function b:isMetal() return self.metal end
    function b:isMetalBar() return self.bars end
    function b:addMetal() if self.planks == 0 and not self.metal and not self.bars then self.metal = true end end
    function b:addMetalBar() if self.planks == 0 and not self.metal and not self.bars then self.bars = true end end
    function b:removePlank()
        if self.planks <= 0 then return nil end
        self.planks = self.planks - 1
        if self.planks == 0 and not self.metal and not self.bars then self.owner.bars[self.slot] = nil end
        return NEWITEM("Base.Plank")
    end
    function b:removeMetal()
        if not self.metal then return nil end
        self.metal = false
        self.owner.bars[self.slot] = nil
        return NEWITEM("Base.SheetMetal")
    end
    function b:removeMetalBar()
        if not self.bars then return nil end
        self.bars = false
        self.owner.bars[self.slot] = nil
        return NEWITEM("Base.MetalBar")
    end
    function b:transmitCompleteItemToClients() TRANSMITS = TRANSMITS + 1 end
    function b:getSquare() return self.owner.square end
    return b
end

IsoBarricade = {}
function IsoBarricade.AddBarricadeToObject(obj, opposite)
    if type(opposite) ~= "boolean" or obj.refuse then return nil end
    TOUCH[obj] = (TOUCH[obj] or 0) + 1
    local slot = opposite and "opp" or "same"
    local b = obj.bars[slot]
    if b == nil then
        b = newBarricade(obj, slot)
        obj.bars[slot] = b
    end
    return b
end
function instanceItem(fullType) return NEWITEM(fullType) end

local function mkSquare(x, y, z, room, building)
    local s = NEWSQUARE(x, y, z)
    s.room = room
    s.building = building
    s.outside = room == nil
    function s:getRoom() return self.room end
    function s:isInARoom() return self.room ~= nil end
    function s:removeGlassAttachments() GLASS_CLEANED = GLASS_CLEANED + 1 end
    return s
end

local function newObject(square, class, north, spec)
    local o = { class = class, north = north, mod = {}, props = spec.props or {}, noBarricade = spec.noBarricade, refuse = spec.refuse, bars = {} }
    function o:getNorth() return self.north end
    function o:getSquare() return self.square end
    function o:getModData() return self.mod end
    function o:getObjectIndex() return 0 end
    function o:getProperties()
        local p = self.props
        return { has = function(_, name) return p[name] == true end }
    end
    function o:getBarricadeOnSameSquare() return self.bars.same end
    function o:getBarricadeOnOppositeSquare() return self.bars.opp end
    function o:isBarricaded() return self.bars.same ~= nil or self.bars.opp ~= nil end
    function o:isBarricadeAllowed() return self.noBarricade ~= true end
    square:AddSpecialObject(o)
    if spec.same then o.bars.same = newBarricade(o, "same") o.bars.same.planks = spec.same end
    if spec.opp then o.bars.opp = newBarricade(o, "opp") o.bars.opp.planks = spec.opp end
    return o
end

local function addWindow(square, north, spec)
    spec = spec or {}
    local o = newObject(square, "IsoWindow", north, spec)
    o.smashed = spec.smashed == true
    function o:isSmashed() return self.smashed end
    function o:setSmashed(v) self.smashed = v end
    function o:isGlassRemoved() return false end
    function o:setGlassRemoved() end
    return o
end

local function addFrame(square, north, spec)
    local o = newObject(square, "IsoWindowFrame", north, spec or {})
    function o:hasWindow() return false end
    return o
end

local function addDoor(square, north, spec, class)
    spec = spec or {}
    local o = newObject(square, class or "IsoDoor", north, spec)
    o.locked = spec.locked == true
    o.keyLocked = spec.locked == true
    o.open = spec.open == true
    o.health = spec.health or 500
    o.maxHealth = 500
    function o:isDoor() return true end
    function o:isLocked() return self.locked end
    function o:isLockedByKey() return self.keyLocked end
    function o:setIsLocked(v) self.locked = v end
    function o:setLockedByKey(v) self.keyLocked = v self.locked = v end
    function o:IsOpen() return self.open end
    function o:ToggleDoorSilent()
        if self:isBarricaded() then return end
        self.open = not self.open
    end
    function o:getHealth() return self.health end
    function o:getMaxHealth() return self.maxHealth end
    function o:setHealth(v) self.health = v end
    return o
end

local function holder(x, y, z)
    return World.square(x, y, z) or mkSquare(x, y, z, nil, nil)
end

local function mkShell(name, ox, oy, w, h, floors)
    local shell = { name = name, ox = ox, oy = oy, w = w, h = h, floors = floors, building = { name = name }, objects = {} }
    for z = 0, floors - 1 do
        local west, east = { name = name .. "w" .. z }, { name = name .. "e" .. z }
        for x = ox, ox + w - 1 do
            for y = oy, oy + h - 1 do
                mkSquare(x, y, z, x < ox + math.floor(w / 2) and west or east, shell.building)
            end
        end
    end
    return shell
end

local function place(shell, side, offset, z)
    if side == "N" then return holder(shell.ox + offset, shell.oy, z), true end
    if side == "S" then return holder(shell.ox + offset, shell.oy + shell.h, z), true end
    if side == "W" then return holder(shell.ox, shell.oy + offset, z), false end
    return holder(shell.ox + shell.w, shell.oy + offset, z), false
end

for x = 80, 170 do
    for y = 80, 170 do mkSquare(x, y, 0, nil, nil) end
end
PLAYER = NEWPLAYER(0)
HOURS = 300

local camp = Camp.create({ x1 = 80, y1 = 80, x2 = 170, y2 = 170, z = 0 }, "Fortify")
local box = Stock.crate(camp, camp.storage[1]):getContainer()
local function addItems(fullType, n) for _ = 1, n do box:AddItem(fullType) end end
local function drain(fullType)
    for i = #box.items, 1, -1 do
        if box.items[i].full == fullType then table.remove(box.items, i) end
    end
end
local function count(fullType)
    local n = 0
    for _, it in ipairs(box.items) do
        if it.full == fullType then n = n + 1 end
    end
    return n
end

local shellA = mkShell("A", 100, 100, 10, 8, 2)
local O = {}
O.N1 = addWindow(place(shellA, "N", 2, 0), true, { smashed = true })
O.N2 = addWindow(place(shellA, "N", 7, 0), true)
O.D2 = addDoor(place(shellA, "N", 8, 0), true, { open = true })
O.D1 = addDoor(place(shellA, "S", 3, 0), true, { locked = true, opp = 2, health = 300 })
O.S1 = addWindow(place(shellA, "S", 1, 0), true)
O.S2 = addWindow(place(shellA, "S", 5, 0), true)
O.S3 = addWindow(place(shellA, "S", 8, 0), true, { opp = 1 })
O.F1 = addFrame(place(shellA, "W", 3, 0), false)
O.DD = addDoor(place(shellA, "W", 5, 0), false, { noBarricade = true, props = { DoubleDoor = true, DoubleDoor1 = true } })
O.DD2 = addDoor(place(shellA, "W", 6, 0), false, { noBarricade = true, props = { DoubleDoor = true, DoubleDoor2 = true } })
O.E1 = addWindow(place(shellA, "E", 2, 0), false)
O.UN1 = addWindow(place(shellA, "N", 1, 1), true)
O.UN2 = addWindow(place(shellA, "N", 6, 1), true)
O.US1 = addWindow(place(shellA, "S", 2, 1), true)
O.UE1 = addWindow(place(shellA, "E", 2, 1), false)
O.UW1 = addWindow(place(shellA, "W", 5, 1), false)
O.UD1 = addDoor(place(shellA, "S", 6, 1), true, {}, "IsoThumpable")
local interior = {
    ID1 = addDoor(holder(105, 103, 0), false, {}),
    IW = addWindow(holder(105, 105, 0), false),
    UID = addDoor(holder(105, 103, 1), false, {}),
}

local function newRec(shell, hint, extra)
    local rec = {
        id = 1, key = shell.ox .. "," .. shell.oy .. ",0", status = "fortify", floors = shell.floors, rooms = {},
        rect = { x1 = shell.ox, y1 = shell.oy, x2 = shell.ox + shell.w - 1, y2 = shell.oy + shell.h - 1, z = 0 },
        entrance = hint, keep = {},
    }
    for k, v in pairs(extra or {}) do rec[k] = v end
    return rec
end

local recA = newRec(shellA, { x = 103, y = 116 })
addItems("Base.Plank", 10)
addItems("Base.Nails", 30)
Stock.refresh(camp)

local cost, minutes = F.analyze(camp, recA)
local fort = recA.fortify
check("scan finished in one call", fort.scan.done == true and fort.partial == false and fort.lastScan <= 400, fort.lastScan)
check("only exterior openings listed", #fort.list == 17, #fort.list)
local listed = {}
for _, e in ipairs(fort.list) do listed[e.x .. "," .. e.y .. "," .. e.z .. (e.n and "N" or "W")] = e end
local function entryOf(o)
    local sq = o:getSquare()
    return listed[sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. (o:getNorth() and "N" or "W")]
end
check("interior door not listed", entryOf(interior.ID1) == nil and entryOf(interior.UID) == nil)
check("interior window not listed", entryOf(interior.IW) == nil)
check("every exterior opening listed", entryOf(O.N1) and entryOf(O.D1) and entryOf(O.F1) and entryOf(O.UD1) and entryOf(O.US1) and entryOf(O.DD))
check("entrance is the hinted door", fort.entrance ~= nil and fort.entrance.x == 103 and fort.entrance.y == 108 and fort.entrance.z == 0 and fort.entrance.iy == 107 and fort.entrance.oy == 108,
    fort.entrance and (fort.entrance.x .. "," .. fort.entrance.y))
check("entrance entry role", entryOf(O.D1).r == "e" and entryOf(O.D2).r == "s" and entryOf(O.DD).r == "l")
check("ground windows far from entrance get 4", entryOf(O.N1).t == 4 and entryOf(O.N2).t == 4 and entryOf(O.E1).t == 4 and entryOf(O.F1).t == 4 and entryOf(O.S3).t == 4)
check("windows next to entrance keep 2", entryOf(O.S1).t == 2 and entryOf(O.S2).t == 2)
check("upper windows get light barricade", entryOf(O.UN1).t == 1 and entryOf(O.US1).t == 1 and entryOf(O.UW1).t == 1)
check("upper door sealed fully", entryOf(O.UD1).r == "s" and entryOf(O.UD1).t == 4)
check("cost planks and nails", cost.planks == 36 and cost.nails == 72 and cost.metal == nil, (cost.planks or 0) .. "/" .. (cost.nails or 0))
check("work minutes", minutes == 178, minutes)
check("posts produced", #fort.posts == 6, #fort.posts)
local postsOk = true
for _, p in ipairs(fort.posts) do
    local sq = World.square(p.x, p.y, p.z)
    if sq == nil or sq:getRoom() == nil or p.x < 100 or p.x > 109 or p.y < 100 or p.y > 107 then postsOk = false end
end
check("posts stand inside the house", postsOk)
check("first post watches the entrance from ground", fort.posts[1].z == 0 and fort.posts[1].x == 101 and fort.posts[1].y == 107 and fort.posts[1].d == "S")
local upperPosts = 0
for _, p in ipairs(fort.posts) do if p.z == 1 then upperPosts = upperPosts + 1 end end
check("posts on upper floor", upperPosts == 5, upperPosts)
check("weak counts only unsealable openings", fort.weak == 1, fort.weak)
local s0 = F.summary(recA)
check("summary shape", s0.openings == 17 and s0.done == 0 and s0.weak == 1 and s0.posts == 6 and s0.entrance == true and s0.planks == 3,
    s0.openings .. "/" .. s0.done .. "/" .. s0.planks)

local cost2, minutes2 = F.analyze(camp, recA)
check("analyze is idempotent", cost2.planks == cost.planks and cost2.nails == cost.nails and minutes2 == minutes and #recA.fortify.list == 17)
check("analyze touches nothing", ALifeCamp.isEmpty(TOUCH) and PLANKS_ADDED == 0)

local totalSpent, calls, stalled = 0, 0, nil
repeat
    HOURS = HOURS + 5 / 60
    local done, progress, spent, waiting = F.step(camp, recA, 2, 5)
    totalSpent = totalSpent + spent
    calls = calls + 1
    check("stock never negative", (camp.stock.planks or 0) >= 0 and (camp.stock.nails or 0) >= 0 and count("Base.Plank") >= 0 and count("Base.Nails") >= 0)
    if waiting ~= nil then stalled = { done = done, progress = progress, waiting = waiting } end
until stalled ~= nil or calls > 60
check("stage waits for stock", stalled ~= nil and stalled.done == false and recA.fortify.waiting ~= nil and stalled.waiting == recA.fortify.waiting, calls)
Stock.refresh(camp)
check("all stock used while waiting", count("Base.Plank") == 0 and camp.stock.planks == 0 and count("Base.Nails") == 10, count("Base.Plank") .. "/" .. count("Base.Nails"))
check("exact consumption before stall", recA.fortify.paid.planks == 10 and recA.fortify.paid.nails == 20 and PLANKS_ADDED == 10, recA.fortify.paid.planks .. "/" .. PLANKS_ADDED)
local rest = recA.fortify.waiting
check("waiting reports what is missing", rest.planks == 26 and rest.nails == 42, (rest.planks or 0) .. "/" .. (rest.nails or 0))
check("waiting reflected in describe", string.find(F.describe(recA), "26", 1, true) ~= nil and string.find(F.describe(recA), "42", 1, true) ~= nil, F.describe(recA))
check("partial progress is below one", stalled.progress > 0.1 and stalled.progress < 1, stalled.progress)
check("priority order: side door first", O.D2.bars.same ~= nil and O.D2.bars.same.planks == 4 and O.D2.open == false)
check("priority order: ground windows next", O.F1.bars.same.planks == 4 and O.S1.bars.opp.planks == 2)
check("stalled opening repaired but not barricaded", O.N1.smashed == false and O.N1.bars.same == nil and O.UN1.bars.same == nil and O.UN1.smashed == false)
check("entrance untouched while waiting", O.D1.bars.opp.planks == 2 and O.D1.locked == true)

local before = recA.fortify.paid.planks
local more = F.step(camp, recA, 2, 5)
check("still waiting without restock", more == false and recA.fortify.paid.planks == before and recA.fortify.waiting ~= nil)

addItems("Base.Plank", 50)
addItems("Base.Nails", 100)
Stock.refresh(camp)
local finished, guard = false, 0
repeat
    HOURS = HOURS + 5 / 60
    finished = F.step(camp, recA, 2, 5)
    guard = guard + 1
until finished or guard > 80
check("completes after restock", finished == true, guard)
check("waiting cleared on completion", recA.fortify.waiting == nil and recA.fortify.done == true)
Stock.refresh(camp)
check("materials consumed exactly", count("Base.Plank") == 26 and count("Base.Nails") == 58 and recA.fortify.paid.planks == 36 and recA.fortify.paid.nails == 72,
    count("Base.Plank") .. "/" .. count("Base.Nails"))
check("planks come from real items", REAL_ITEMS == 36 and PLANKS_ADDED == 36, REAL_ITEMS .. "/" .. PLANKS_ADDED)
check("barricade changes transmitted", TRANSMITS >= 36, TRANSMITS)

local function planks(o, side) return o.bars[side] and o.bars[side].planks or 0 end
check("smashed window repaired and sealed", O.N1.smashed == false and planks(O.N1, "same") == 4)
check("broken glass cleaned once", GLASS_CLEANED == 1, GLASS_CLEANED)
check("north windows inside-barricaded", planks(O.N2, "same") == 4 and planks(O.D2, "same") == 4)
check("south wall barricades land on inside square", planks(O.S1, "opp") == 2 and planks(O.S2, "opp") == 2 and planks(O.S3, "opp") == 4 and planks(O.S1, "same") == 0)
check("frame and east window sealed", planks(O.F1, "same") == 4 and planks(O.E1, "opp") == 4)
check("upper windows light", planks(O.UN1, "same") == 1 and planks(O.UN2, "same") == 1 and planks(O.US1, "opp") == 1 and planks(O.UE1, "opp") == 1 and planks(O.UW1, "same") == 1)
check("upper door sealed", planks(O.UD1, "opp") == 4)
check("other exterior door fully barricaded and closed", planks(O.D2, "same") == 4 and O.D2.open == false)
check("main entrance cleared and usable", O.D1.bars.opp == nil and O.D1.bars.same == nil and O.D1.locked == false and O.D1.keyLocked == false and O.D1.open == false and O.D1.health == 500)
check("planks refunded from entrance", count("Base.Plank") == 26)
check("unsealable doors locked", O.DD.keyLocked == true and O.DD2.keyLocked == true and O.DD.bars.same == nil and O.DD.bars.opp == nil)
local untouched = true
for _, o in pairs(interior) do
    if TOUCH[o] ~= nil or o.bars.same ~= nil or o.bars.opp ~= nil or o.keyLocked == true then untouched = false end
end
check("interior openings untouched", untouched)
local sA = F.summary(recA)
check("summary after run", sA.done == 17 and sA.openings == 17 and sA.entrance == true and sA.posts == 6 and sA.planks == 37 and sA.weak == 1,
    sA.done .. "/" .. sA.planks)
check("describe done", string.find(F.describe(recA), "17", 1, true) ~= nil, F.describe(recA))

local d, p, spent = F.step(camp, recA, 5, 10)
Stock.refresh(camp)
check("step after finish is idempotent", d == true and p == 1 and spent == 0 and count("Base.Plank") == 26)

local forced = F.analyze(camp, recA, true)
check("forced rescan rebuilds the same state", recA.fortify.done == true and #recA.fortify.list == 17 and ALifeCamp.isEmpty(forced) and recA.fortify.paid == nil)
local recA2 = newRec(shellA, { x = 103, y = 116 })
local reCost, reMinutes = F.analyze(camp, recA2)
check("reload: nothing left to pay", ALifeCamp.isEmpty(reCost) and reMinutes == 0, reMinutes)
check("reload: same plan", #recA2.fortify.list == 17 and recA2.fortify.done == true and #recA2.fortify.posts == 6 and recA2.fortify.entrance.x == 103)
local sameSummary = true
local sa, sb = F.summary(recA), F.summary(recA2)
for k, v in pairs(sa) do if sb[k] ~= v then sameSummary = false end end
check("reload: same summary", sameSummary)
local samePosts = true
for i, pp in ipairs(recA.fortify.posts) do
    local q = recA2.fortify.posts[i]
    if q == nil or q.x ~= pp.x or q.y ~= pp.y or q.z ~= pp.z then samePosts = false end
end
check("reload: same posts", samePosts)
local pd, pp2, ps = F.step(camp, recA2, 3, 10)
Stock.refresh(camp)
check("reload: step completes with no spending", pd == true and ps == 0 and count("Base.Plank") == 26 and count("Base.Nails") == 58)

fortifyFile()
local F2 = A.Fortify
local recA3 = newRec(shellA, { x = 103, y = 116 })
recA3.fortify = { stale = true }
F2.analyze(camp, recA3)
check("module reload with stale rec table", recA3.fortify.done == true and recA3.fortify.stale == nil and F2.summary(recA3).done == 17)
F = F2

local shellC = mkShell("C", 120, 100, 8, 6, 1)
local C = {}
C.N1 = addWindow(place(shellC, "N", 2, 0), true)
C.N2 = addWindow(place(shellC, "N", 6, 0), true)
C.S1 = addWindow(place(shellC, "S", 2, 0), true)
C.S2 = addWindow(place(shellC, "S", 6, 0), true)
C.Front = addDoor(place(shellC, "S", 4, 0), true, {})
C.Back = addDoor(place(shellC, "W", 2, 0), false, {})
addItems("Base.ScrapMetal", 40)
Stock.refresh(camp)
local recC = newRec(shellC, { x = 124, y = 115 }, { keep = { ["122,100,0"] = true } })
local costC = F.analyze(camp, recC)
local fc = recC.fortify
check("keep squares skipped", #fc.list == 5 and not (function() for _, e in ipairs(fc.list) do if e.x == 122 and e.y == 100 then return true end end end)(), #fc.list)
check("single storey posts at entrance loopholes", #fc.posts == 2 and fc.posts[1].z == 0 and fc.posts[2].z == 0, #fc.posts)
check("metal upgrade planned", costC.metal == 8 and costC.planks == 4 and costC.nails == 8, (costC.metal or 0) .. "/" .. (costC.planks or 0))
local doneC, guardC = false, 0
repeat
    HOURS = HOURS + 5 / 60
    doneC = F.step(camp, recC, 3, 5)
    guardC = guardC + 1
until doneC or guardC > 60
Stock.refresh(camp)
check("metal house completes", doneC == true, guardC)
check("far window got a metal sheet", C.N2.bars.same ~= nil and C.N2.bars.same.metal == true and C.N2.bars.same.planks == 0)
check("entrance windows got metal bars", C.S1.bars.opp.bars == true and C.S2.bars.opp.bars == true)
check("metal consumed exactly", count("Base.ScrapMetal") == 32, count("Base.ScrapMetal"))
check("back door still planked", planks(C.Back, "same") == 4 and C.Front.bars.same == nil and C.Front.bars.opp == nil)

local shellE = mkShell("E", 140, 100, 8, 6, 1)
local E = {}
E.N1 = addWindow(place(shellE, "N", 2, 0), true)
E.S1 = addWindow(place(shellE, "S", 2, 0), true)
E.Front = addDoor(place(shellE, "S", 4, 0), true, {})
local recE = newRec(shellE, { x = 144, y = 115 })
local costE = F.analyze(camp, recE)
check("metal planned for second house", (costE.metal or 0) > 0, costE.metal)
drain("Base.ScrapMetal")
Stock.refresh(camp)
local doneE, guardE = false, 0
repeat
    HOURS = HOURS + 5 / 60
    doneE = F.step(camp, recE, 3, 5)
    guardE = guardE + 1
until doneE or guardE > 60
Stock.refresh(camp)
check("metal shortage falls back to planks", doneE == true and planks(E.N1, "same") == 4 and E.N1.bars.same.metal == false and planks(E.S1, "opp") == 2, guardE)

local shellF = mkShell("F", 150, 100, 8, 6, 1)
local FW = addWindow(place(shellF, "N", 3, 0), true, { refuse = true })
local FD = addDoor(place(shellF, "S", 4, 0), true, {})
local recF = newRec(shellF, { x = 154, y = 115 })
local planksBefore = count("Base.Plank")
F.analyze(camp, recF)
local doneF, guardF = false, 0
repeat
    HOURS = HOURS + 5 / 60
    doneF = F.step(camp, recF, 3, 5)
    guardF = guardF + 1
until doneF or guardF > 80
Stock.refresh(camp)
check("engine refusal gives up without losing materials", doneF == true and count("Base.Plank") == planksBefore and FW.bars.same == nil, guardF)
check("refused opening reported as weak", F.summary(recF).weak == 1, F.summary(recF).weak)

local shellG = mkShell("G", 100, 150, 8, 6, 1)
local G = {}
G.N = addDoor(place(shellG, "N", 2, 0), true, {})
G.S = addDoor(place(shellG, "S", 5, 0), true, {})
G.W1 = addWindow(place(shellG, "W", 3, 0), false)
local recG = newRec(shellG, nil)
F.analyze(camp, recG)
check("no hint: nearest door to camp centre is the entrance", recG.fortify.entrance ~= nil and recG.fortify.entrance.y == 150 and recG.fortify.entrance.oy == 149 and recG.fortify.list[#recG.fortify.list].r == "e")
G.S:getSquare():transmitRemoveItemFromSquare(G.S)
local doneG, guardG = false, 0
repeat
    HOURS = HOURS + 5 / 60
    doneG = F.step(camp, recG, 3, 5)
    guardG = guardG + 1
until doneG or guardG > 60
local sG = F.summary(recG)
check("destroyed door is skipped and reported weak", doneG == true and sG.weak == 1 and sG.done == sG.openings and planks(G.W1, "same") == 2, guardG)

local shellH = mkShell("H", 100, 130, 8, 6, 1)
local squaresMissing = true
local HW = addWindow(place(shellH, "N", 3, 0), true)
local HD = addDoor(place(shellH, "S", 4, 0), true, {})
local recH = newRec(shellH, { x = 104, y = 145 })
local realGet = getCell
getCell = function()
    return { getGridSquare = function(_, x, y, z)
        if x == 107 and y == 135 and z == 0 and squaresMissing then return nil end
        return realGet():getGridSquare(x, y, z)
    end }
end
F.analyze(camp, recH)
check("unloaded squares mark partial", recH.fortify.partial == true and #recH.fortify.list == 2 and recH.fortify.scan.unloaded == 1, recH.fortify.scan.unloaded)
local stepDone = F.step(camp, recH, 3, 5)
check("partial scan does not finish the stage", stepDone == false and recH.fortify.done ~= true)
squaresMissing = false
HOURS = HOURS + 0.3
F.analyze(camp, recH)
check("loaded squares clear partial after rescan", recH.fortify.partial == false and #recH.fortify.list == 2, tostring(recH.fortify.partial))
getCell = realGet

local bx, by = 200, 200
local bw, bh, bf = 62, 52, 3
local bigBuilding = { name = "big" }
local bigRoom = { name = "big" }
for x = bx - 2, bx + bw + 2 do
    for y = by - 2, by + bh + 2 do mkSquare(x, y, 0, nil, nil) end
end
for z = 0, bf - 1 do
    for x = bx, bx + bw - 1 do
        for y = by, by + bh - 1 do mkSquare(x, y, z, bigRoom, bigBuilding) end
    end
end
local shellD = { ox = bx, oy = by, w = bw, h = bh, floors = bf, building = bigBuilding }
addWindow(place(shellD, "N", 10, 0), true)
addDoor(place(shellD, "S", 30, 0), true, {})
addWindow(place(shellD, "E", 20, 2), false)
local recD = newRec(shellD, { x = 230, y = 280 })
local scanCalls, maxScan, firstStep = 0, 0, nil
repeat
    scanCalls = scanCalls + 1
    if scanCalls == 1 then firstStep = { F.step(camp, recD, 2, 5) } else F.analyze(camp, recD) end
    maxScan = math.max(maxScan, recD.fortify.lastScan or 0)
until recD.fortify.scan.done or scanCalls > 100
check("big scan is bounded per call", maxScan <= 400 and maxScan > 0, maxScan)
check("big scan takes several calls", scanCalls >= 25 and scanCalls <= 30, scanCalls)
check("step during scan only scans", firstStep[1] == false and firstStep[2] < 0.1 and firstStep[3] == 0)
check("big scan finds all openings", #recD.fortify.list == 3, #recD.fortify.list)
check("big building has entrance and upper loophole", recD.fortify.entrance ~= nil and #recD.fortify.posts >= 1)

local recX = { id = 9, key = "1,1,0", status = "fortify" }
local xc, xm = F.analyze(camp, recX)
check("record without rect is harmless", ALifeCamp.isEmpty(xc) and xm == 0)
local xd, xp, xs = F.step(camp, recX, 1, 1)
check("step without rect finishes", xd == true and xp == 1 and xs == 0)
local empty = F.summary({})
check("summary of empty rec", empty.openings == 0 and empty.entrance == false and empty.posts == 0)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
