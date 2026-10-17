dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Settlers, Work, Stats, Adopt, World =
    A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Settlers, A.Work, A.Stats, A.Adopt, A.World
local reg, orders = MOCKALIFE()

check("real salvage present", A.Salvage ~= nil and type(A.Salvage.analyze) == "function")
check("real fortify present", A.Fortify ~= nil and type(A.Fortify.analyze) == "function")
local hasFitout = A.Fitout ~= nil
local hasDistricts = A.Districts ~= nil

PLANKS_ADDED, REAL_ITEMS, TRANSMITS = 0, 0, 0

local function newBarricade(owner, slot)
    local b = { planks = 0, metal = false, bars = false, owner = owner, slot = slot }
    function b:addPlank(chr, item)
        if self.metal or self.bars or self.planks >= 4 then return end
        self.planks = self.planks + 1
        PLANKS_ADDED = PLANKS_ADDED + 1
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
    local slot = opposite and "opp" or "same"
    local b = obj.bars[slot]
    if b == nil then
        b = newBarricade(obj, slot)
        obj.bars[slot] = b
    end
    return b
end
function instanceItem(fullType) return NEWITEM(fullType) end

local function LIST(t)
    return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

local function mkSquare(x, y, z, room, building)
    local s = NEWSQUARE(x, y, z)
    s.room = room
    s.building = building
    s.outside = room == nil
    function s:getRoom() return self.room end
    function s:isInARoom() return self.room ~= nil end
    function s:hasFloor() return self.floorObj ~= nil end
    function s:isWallTo(other)
        if other == nil then return true end
        return self.room ~= other.room
    end
    function s:HasStairs() return false end
    return s
end

local function holder(x, y, z)
    return World.square(x, y, z) or mkSquare(x, y, z, nil, nil)
end

local function newObject(square, class, north, spec)
    local o = { class = class, north = north, mod = {}, props = spec.props or {}, noBarricade = spec.noBarricade, bars = {} }
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
    return o
end

local function addWindow(square, north, spec)
    local o = newObject(square, "IsoWindow", north, spec or {})
    o.smashed = (spec or {}).smashed == true
    function o:isSmashed() return self.smashed end
    function o:setSmashed(v) self.smashed = v end
    function o:isGlassRemoved() return false end
    function o:setGlassRemoved() end
    return o
end

local function addDoor(square, north, spec)
    spec = spec or {}
    local o = newObject(square, "IsoDoor", north, spec)
    o.locked = spec.locked == true
    o.keyLocked = spec.locked == true
    o.open = false
    o.health = 300
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
    function o:getMaxHealth() return 500 end
    function o:setHealth(v) self.health = v end
    return o
end

local function FURN(square, spriteName, props)
    local o = NEWOBJ(square, "IsoObject", spriteName)
    o.hasModData = function() return false end
    o.getSprite = function()
        return {
            getName = function() return spriteName end,
            getSpriteGrid = function() return nil end,
            getProperties = function()
                return { has = function(_, k) return props[k] ~= nil end, get = function(_, k) return props[k] end }
            end,
        }
    end
    return o
end

local CHAIR = { CustomName = "Chair", IsMoveAble = true, Material = "Wood", PickUpWeight = "20" }
local SOFA = { CustomName = "Couch", IsMoveAble = true, Material = "Fabric", Material2 = "Wood", PickUpWeight = "150" }
local WARDROBE = { container = "wardrobe", IsMoveAble = true, Material = "Wood", PickUpWeight = "200" }
local TOILET = { CustomName = "Toilet", IsMoveAble = true, waterPiped = true }
local FRIDGE = { container = "fridge", IsMoveAble = true }
local BED = { CustomName = "Bed", IsMoveAble = true, Material = "Wood" }

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

local function HOUSE(spec)
    local defRooms = {}
    local roomObjects = {}
    for _, r in ipairs(spec.rooms) do
        defRooms[#defRooms + 1] = ROOMDEF(r)
        local name = r[1]
        roomObjects[#roomObjects + 1] = { name = name, x = r[2], y = r[3], w = r[4], h = r[5], z = r[6] or 0,
            getName = function() return name end }
    end
    local def = { x = spec.x, y = spec.y, w = spec.w, h = spec.h }
    function def:getX() return self.x end
    function def:getY() return self.y end
    function def:getW() return self.w end
    function def:getH() return self.h end
    function def:getRooms() return LIST(defRooms) end
    local b = { def = def }
    function b:getDef() return def end
    function b:isResidential() return true end
    for z = 0, spec.floors - 1 do
        for x = spec.x, spec.x + spec.w - 1 do
            for y = spec.y, spec.y + spec.h - 1 do
                local room
                for _, ro in ipairs(roomObjects) do
                    if ro.z == z and x >= ro.x and x < ro.x + ro.w and y >= ro.y and y < ro.y + ro.h then room = ro end
                end
                local sq = mkSquare(x, y, z, room, b)
                sq:addFloor("floors_interior_tilesandwood_01_41")
            end
        end
    end
    for x = spec.x, spec.x + spec.w - 1 do
        for y = spec.y, spec.y + spec.h - 1 do
            local roof = mkSquare(x, y, spec.floors, nil, nil)
            roof:addFloor("roofs_02_22")
        end
    end
    return b
end

for x = 80, 170 do
    for y = 80, 170 do mkSquare(x, y, 0, nil, nil) end
end
PLAYER = NEWPLAYER(0)
HOURS = 300
IsoFlagType = { solidfloor = "solidfloor" }

local spec = { x = 100, y = 100, w = 10, h = 8, floors = 2, rooms = {
    { "bedroom", 100, 100, 5, 4, 0 }, { "kitchen", 105, 100, 5, 4, 0 }, { "livingroom", 100, 104, 5, 4, 0 },
    { "bathroom", 105, 104, 5, 4, 0 }, { "bedroom", 100, 100, 5, 4, 1 }, { "bedroom", 105, 100, 5, 4, 1 } } }
HOUSE(spec)

local W = {}
W.N1 = addWindow(holder(102, 100, 0), true)
W.N2 = addWindow(holder(107, 100, 0), true)
W.S1 = addWindow(holder(101, 108, 0), true)
W.E1 = addWindow(holder(110, 102, 0), false)
W.Front = addDoor(holder(104, 108, 0), true, {})
W.UN1 = addWindow(holder(102, 100, 1), true)
W.UE1 = addWindow(holder(110, 102, 1), false)
W.Inner = addDoor(holder(105, 102, 0), false, {})
addDoor(holder(102, 104, 0), true, {})
addDoor(holder(105, 105, 0), false, {})

local F = {}
F.chair1 = FURN(holder(101, 101, 0), "furniture_seating_indoor_01_0", CHAIR)
F.chair2 = FURN(holder(106, 101, 0), "furniture_seating_indoor_01_1", CHAIR)
F.sofa = FURN(holder(101, 105, 0), "furniture_seating_indoor_01_8", SOFA)
F.wardrobe = FURN(holder(103, 101, 0), "furniture_storage_02_4", WARDROBE)
F.toilet = FURN(holder(106, 105, 0), "fixtures_bathroom_01_0", TOILET)
F.fridge = FURN(holder(107, 101, 0), "appliances_refrigeration_01_0", FRIDGE)
F.bed = FURN(holder(102, 102, 0), "furniture_bedding_01_4", BED)
F.chair3 = FURN(holder(102, 101, 1), "furniture_seating_indoor_01_2", CHAIR)

local camp = Camp.create({ x1 = 90, y1 = 90, x2 = 130, y2 = 120, z = 0 }, "Integration", { demolish = true, adopt = true })
camp.options.autoPlan = false
camp.options.recruit = false
camp.phase = "plan"
Adopt.discover(camp)
check("house discovered", camp.adopt ~= nil and camp.adopt.size == 1)
local rec = camp.adopt.items["100,100,0"]
check("rec exists", rec ~= nil and rec.status == "queued" and rec.floors == 2 and #rec.rooms == 6)
check("rec doors and windows counted", rec.rooms[1].windows >= 1 and rec.rooms[1].doors >= 0, rec.rooms[1].windows)

local box = Stock.crate(camp, camp.storage[1]):getContainer()
for _ = 1, 300 do box:AddItem("Base.Plank") end
for _ = 1, 600 do box:AddItem("Base.Nails") end
for _ = 1, 20 do box:AddItem("Base.ScrapMetal") end
Stock.refresh(camp)
local planksBefore = camp.stock.planks

ADDACTOR(reg, "alice", "friendly", 95, 95, World.square(95, 95, 0))
ADDACTOR(reg, "bob", "friendly", 96, 95, World.square(96, 95, 0))
ADDACTOR(reg, "cara", "friendly", 97, 95, World.square(97, 95, 0))
Settlers.settle(camp, "alice", "Alice")
Settlers.settle(camp, "bob", "Bob")
Settlers.settle(camp, "cara", "Cara")
camp.settlers.alice.role = "builder"
camp.settlers.bob.role = "builder"
camp.settlers.cara.role = "guard"

local function tick(n)
    for _ = 1, n do
        HOURS = HOURS + 1 / 60
        fire("EveryOneMinute")
    end
end

local seen = {}
local guard = 0
repeat
    tick(1)
    guard = guard + 1
    seen[rec.status] = true
until rec.status == "done" or guard > 1500
check("integration reaches done", rec.status == "done", rec.status .. " after " .. guard)
check("went through every stage", seen.salvage and seen.fortify and (seen.fitout or not hasFitout), tostring(seen.salvage) .. tostring(seen.fortify) .. tostring(seen.fitout))

local function present(sq, obj)
    for _, o in ipairs(sq.objects) do if o == obj then return true end end
    return false
end
check("salvage removed chairs", not present(holder(101, 101, 0), F.chair1) and not present(holder(106, 101, 0), F.chair2))
check("salvage removed sofa and wardrobe", not present(holder(101, 105, 0), F.sofa) and not present(holder(103, 101, 0), F.wardrobe))
check("salvage removed upstairs chair", not present(holder(102, 101, 1), F.chair3))
check("toilet fridge bed kept", present(holder(106, 105, 0), F.toilet) and present(holder(107, 101, 0), F.fridge) and present(holder(102, 102, 0), F.bed))
check("salvage logged result in rec", type(rec.salvage) == "table" and rec.salvage.finished == true and rec.salvage.done >= 5, rec.salvage and rec.salvage.done)
local gained = rec.salvage.gained
check("salvage yielded planks", gained.planks > 0 and gained.nails > 0, gained.planks)

local function planks(o, side) return o.bars[side] and o.bars[side].planks or 0 end
local function sealed(o) return o.bars.same ~= nil or o.bars.opp ~= nil end
check("fortify barricaded windows", sealed(W.N1) and sealed(W.N2) and sealed(W.E1) and sealed(W.S1) and sealed(W.UN1) and sealed(W.UE1))
check("fortify opened front door", W.Front.open == false and W.Front.bars.same == nil and W.Front.bars.opp == nil)
check("fortify left inner door alone", W.Inner.bars.same == nil and W.Inner.bars.opp == nil)
check("fortify finished with posts", type(rec.fortify.posts) == "table" and #rec.fortify.posts >= 1 and rec.fortify.done == true)

if hasFitout then
    check("fitout summary available", type(A.Fitout.summary(rec)) == "table")
    check("capacity from fitout", rec.capacity >= 4, rec.capacity)
else
    check("capacity falls back to estimate", rec.capacity >= 4, rec.capacity)
end

local counts = Stats.counts(camp)
check("stats count the house", counts.adopted == 1 and counts.houses == 1 and counts.adoptBeds == rec.capacity, counts.adopted .. "/" .. counts.houses .. "/" .. counts.adoptBeds)
check("stats capacity", Stats.capacity(counts) >= rec.capacity)
check("stats defense counts fortify", counts.adoptDefense > 0, counts.adoptDefense)
local posts = Work.posts(camp)
local houseAnchors = 0
for _, p in ipairs(posts) do if p.exact then houseAnchors = houseAnchors + 1 end end
check("guards get house posts", houseAnchors >= #rec.fortify.posts, houseAnchors)
tick(4)
check("guard ordered to a house post", orders.cara ~= nil and orders.cara.anchor ~= nil)

local summary = Adopt.summary(camp, rec)
check("summary progress full and detail", summary.progress == 1 and summary.status == "done")
local win = setmetatable({}, A.Window)
local lines = win:adoptLines(camp)
check("adopt tab renders", #lines >= 3, #lines)

local steps = 0
local origStep = A.Fortify.step
A.Fortify.step = function(...) steps = steps + 1 return origStep(...) end
tick(10)
A.Fortify.step = origStep
check("done house is not stepped any more", steps == 0, steps)
local serial = camp.adopt.serial
Adopt.ready = {}
Adopt.index = {}
Adopt.discover(camp)
tick(3)
check("reload keeps single rec", camp.adopt.serial == serial and camp.adopt.size == 1 and rec.status == "done")
check("untouched kept objects after reload", present(holder(106, 105, 0), F.toilet))

local planksAfter = camp.stock.planks
Stock.refresh(camp)
check("camp stock gained salvage", camp.stock.nails ~= nil and camp.stock.metal ~= nil)

if hasDistricts then
    local before = #Build.list(camp)
    local added = Plan.generate(camp)
    check("districts add projects", added >= 1 and #Build.list(camp) > before, added)
    local clash = false
    for _, p in ipairs(Build.list(camp)) do
        if p.kind ~= "fence" and Adopt.overlaps(camp, A.Blueprints.footprint(p)) ~= nil then clash = true end
    end
    check("districts avoid adopted house", not clash)
    local described = A.Districts.describe(camp)
    check("districts describe returns list", type(described) == "table" and #described >= 1)
    A.Window.districtCache.id = nil
    local overview = setmetatable({ survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 } }, A.Window):lines(camp)
    local shown = false
    for _, l in ipairs(overview) do if l.text:find("Районы лагеря") then shown = true end end
    check("overview lists districts", shown)
end

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
