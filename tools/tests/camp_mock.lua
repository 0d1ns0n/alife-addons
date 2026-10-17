unpack = unpack or table.unpack
next = nil
math.random = nil
math.randomseed = nil
string.rep = nil
local zombSeed = 12345
ZombRand = ZombRand or function(a, b)
    zombSeed = (zombSeed * 1103515245 + 12345) % 2147483648
    local r = math.floor(zombSeed / 65536)
    if b ~= nil then return a + r % math.max(1, b - a) end
    return r % math.max(1, a or 1)
end
LOG = {}
FAILS = {}
function check(name, cond, detail)
    LOG[#LOG + 1] = (cond and "ok   " or "FAIL ") .. name .. (detail ~= nil and (" | " .. tostring(detail)) or "")
    if not cond then FAILS[#FAILS + 1] = name end
end

SILENT = {}
local realpcall = pcall
pcall = function(f, ...)
    local r = { realpcall(f, ...) }
    if not r[1] then SILENT[#SILENT + 1] = tostring(r[2]) end
    return unpack(r)
end

PRINTS = {}
function print(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end PRINTS[#PRINTS + 1] = table.concat(t, ' ') end

require = function() return true end

function getText(key, ...)
    local text = UIJSON[key]
    if text == nil then MISSING[key] = true return key end
    local args = { ... }
    for i = 1, #args do text = text:gsub("%%" .. i, function() return tostring(args[i]) end) end
    return text
end
MISSING = {}
function getTextOrNull(key) return UIJSON[key] end

local handlers = {}
Events = setmetatable({}, { __index = function(t, k)
    local ev = { Add = function(fn) handlers[k] = handlers[k] or {} table.insert(handlers[k], fn) end, Remove = function() end }
    rawset(t, k, ev)
    return ev
end })
function fire(name, ...)
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
end

local store = {}
ModData = { getOrCreate = function(name) store[name] = store[name] or {} return store[name] end }

HOURS = 100
function getGameTime() return { getWorldAgeHours = function() return HOURS end, getHour = function() return 12 end } end
function getTimestampMs() return 5000 end

function instanceof(o, c) return type(o) == "table" and (o.class == c or (o.classes ~= nil and o.classes[c] == true)) end

local function newContainer(kind)
    local c = { items = {}, kind = kind }
    function c:getItems() local l = self.items return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function c:AddItem(t) local it = type(t) == 'table' and t or NEWITEM(t) it.container = self table.insert(self.items, it) return it end
    function c:Remove(it) for i = #self.items, 1, -1 do if self.items[i] == it then table.remove(self.items, i) end end end
    function c:setType() end
    function c:setCapacity() end
    function c:setExplored() end
    return c
end

function NEWITEM(fullType, calories)
    local it = { full = fullType, calories = calories, class = calories and "Food" or "Item" }
    if calories then it.classes = { Food = true } end
    function it:getFullType() return self.full end
    function it:getDisplayCategory() return self.cat or "" end
    function it:getCalories() return self.calories or 0 end
    function it:getFluidContainer() return nil end
    function it:getContainer() return self.container end
    function it:getModData() self.mod = self.mod or {} return self.mod end
    return it
end

ItemContainer = { new = function(kind) return newContainer(kind) end }

local squares = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
function NEWSQUARE(x, y, z)
    local sq = { x = x, y = y, z = z, objects = {}, outside = true, free = true, wobjects = {}, bodies = {}, moving = {} }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return self.z end
    function sq:getObjects() local l = self.objects return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function sq:getWorldObjects() local l = self.wobjects return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function sq:getDeadBodys() local l = self.bodies return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function sq:getMovingObjects() local l = self.moving return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function sq:getBuilding() return self.building end
    function sq:getVehicleContainer() return self.vehicle end
    function sq:removeCorpse(body) for i = #self.bodies, 1, -1 do if self.bodies[i] == body then table.remove(self.bodies, i) end end end
    function sq:addFloor(name)
        local o = IsoObject.new(nil, self, { name = name })
        o.class = "IsoObject"
        o.isFloor = true
        self.floorName = name
        self.floorObj = o
        self:AddTileObject(o)
        return o
    end
    function sq:AddTileObject(o) o.square = self table.insert(self.objects, o) end
    function sq:RecalcProperties() end
    function sq:RecalcAllWithNeighbours() end
    function sq:transmitRemoveItemFromSquare(o)
        for i = #self.objects, 1, -1 do if self.objects[i] == o then table.remove(self.objects, i) end end
        for i = #self.wobjects, 1, -1 do if self.wobjects[i] == o then table.remove(self.wobjects, i) end end
    end
    function sq:isFree() return self.free end
    function sq:AddSpecialObject(o) o.square = self table.insert(self.objects, o) o.special = true end
    function sq:getSpecialObjects() local l = {} for _, o in ipairs(self.objects) do if o.special then l[#l + 1] = o end end return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    function sq:getWallFull() return false end
    function sq:getFloor() return self.floorObj end
    function sq:isOutside() return self.outside end
    function sq:getChunk() return {} end
    squares[key(x, y, z)] = sq
    return sq
end
function getCell() return { getGridSquare = function(_, x, y, z) return squares[key(x, y, z)] end } end
function getSprite(name) return { name = name } end
IsoObject = { new = function(cell, square, sprite)
    local o = { class = "IsoObject", sprite = sprite, mod = {} }
    function o:getModData() return self.mod end
    function o:getSquare() return self.square end
    function o:setContainer(c) self.container = c end
    function o:getContainer() return self.container end
    function o:getSprite() return { getName = function() return sprite.name end, getProperties = function() return { has = function() return false end } end } end
    return o
end }
function NEWTREE(square)
    local o = IsoObject.new(nil, square, { name = "vegetation_trees_01_1" })
    o.class = "IsoTree"
    square:AddTileObject(o)
    return o
end

UIPOP = {}
ISModalDialog = { new = function(self, x, y, w, h, text, yesno, target, onclick, player)
    local m = { text = text, yesno = yesno, onclick = onclick }
    function m:initialise() end
    function m:addToUIManager() UIPOP[#UIPOP + 1] = self end
    return m
end }
ISTextBox = { new = function(self, x, y, w, h, text, default, target, onclick, player)
    local m = { text = text, default = default, onclick = onclick }
    function m:initialise() end
    function m:addToUIManager() UIPOP[#UIPOP + 1] = self end
    return m
end }

local function derive(name)
    local cls = { type = name }
    cls.__index = cls
    function cls:derive(n) return derive(n) end
    function cls:new(...) local o = setmetatable({}, self) return o end
    return cls
end
ISBaseTimedAction = derive("ISBaseTimedAction")
function ISBaseTimedAction.new(self, character) local o = setmetatable({}, self) o.character = character return o end
function ISBaseTimedAction.stop() end
function ISBaseTimedAction.perform() end
local function noop() return nil end
ISCollapsableWindow = derive("ISCollapsableWindow")
setmetatable(ISCollapsableWindow, { __index = function(_, k) if k == "instance" or k == "current" or k == "tabIds" then return nil end return noop end })
function ISCollapsableWindow:new(x, y, w, h)
    local o = { x = x, y = y, width = w, height = h, children = {} }
    return setmetatable(o, ISCollapsableWindow)
end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISCollapsableWindow:resizeWidgetHeight() return 10 end
function ISCollapsableWindow:getIsVisible() return self.visible ~= false end
function ISCollapsableWindow:setVisible(v) self.visible = v end
function ISCollapsableWindow:addChild(c) table.insert(self.children, c) end
function ISCollapsableWindow:derive(n)
    local cls = { type = n }
    cls.__index = cls
    return setmetatable(cls, { __index = ISCollapsableWindow })
end
function ISCollapsableWindow:createChildren() end
ISButton = { new = function(self, x, y, w, h, title, target, onclick)
    local b = { title = title, target = target, onclick = onclick, x = x, y = y, width = w, height = h }
    return setmetatable(b, { __index = function(_, k) return noop end })
end }
ISContextMenu = derive("ISContextMenu")
UIFont = { Small = "Small", Medium = "Medium" }
Keyboard = { KEY_F6 = 64 }
getTextManager = function() return { getFontHeight = function() return 14 end, MeasureStringX = function(_, _, t) return #t * 7 end } end
getCore = function() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
getTexture = function() return {} end
luautils = { walkAdj = function() return true end }
ISTimedActionQueue = { added = {}, add = function(a) table.insert(ISTimedActionQueue.added, a) end }

MARKERS = {}
getWorldMarkers = function() return { addGridSquareMarker = function(_, sq)
    local m = { square = sq, removed = false }
    function m:remove() self.removed = true end
    table.insert(MARKERS, m)
    return m
end } end

function NEWPLAYER(flags)
    local inv = newContainer("main")
    for _ = 1, flags do inv:AddItem("ALifeCamp.CampFlag") end
    function inv:getCountTypeRecurse(t) local n = 0 for _, it in ipairs(self.items) do if it.full == t then n = n + 1 end end return n end
    function inv:getFirstTypeRecurse(t) for _, it in ipairs(self.items) do if it.full == t then return it end end end
    function inv:AddItems(t, n) for _ = 1, n do self:AddItem(t) end end
    local p = { inv = inv, x = 105, y = 105, notes = {} }
    function p:getInventory() return self.inv end
    function p:setHaloNote(t) table.insert(self.notes, t) end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getPlayerNum() return 0 end
    function p:isTimedActionInstant() return false end
    return p
end
function getPlayer() return PLAYER end
function getSpecificPlayer() return PLAYER end

SKIPMOD = SKIPMOD or {}

function LOADMOD(root)
    local function exists(path)
        local handle = io.open(path, "r")
        if handle == nil then return false end
        handle:close()
        return true
    end
    local optional = {
        ["shared/ALifeCamp/CampSalvage.lua"] = true, ["shared/ALifeCamp/CampFortify.lua"] = true,
        ["shared/ALifeCamp/CampSanitary.lua"] = true, ["shared/ALifeCamp/CampHealth.lua"] = true, ["shared/ALifeCamp/CampLife.lua"] = true, ["shared/ALifeCamp/CampProgress.lua"] = true, ["shared/ALifeCamp/CampCouncil.lua"] = true, ["shared/ALifeCamp/CampHouses.lua"] = true, ["shared/ALifeCamp/CampBuildings.lua"] = true, ["shared/ALifeCamp/CampBuildings2.lua"] = true, ["shared/ALifeCamp/CampBuildings3.lua"] = true, ["shared/ALifeCamp/CampScenery.lua"] = true, ["shared/ALifeCamp/CampShells.lua"] = true, ["shared/ALifeCamp/CampTowers.lua"] = true, ["shared/ALifeCamp/CampPerimeter.lua"] = true, ["shared/ALifeCamp/CampFortress.lua"] = true, ["shared/ALifeCamp/CampDuty.lua"] = true,
        ["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true, ["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true, ["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true, ["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true, ["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true, ["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true,
        ["shared/ALifeCamp/CampFitout.lua"] = true, ["shared/ALifeCamp/CampDistricts.lua"] = true, ["shared/ALifeCamp/CampPosts.lua"] = true, ["shared/ALifeCamp/CampSlideGate.lua"] = true, ["shared/ALifeCamp/CampSkills.lua"] = true, ["shared/ALifeCamp/CampMotor.lua"] = true, ["@addon/shared/ALifeCampCheats/CampCheats.lua"] = true, ["@addon/server/ALifeCampCheats/CampCheatsHooks.lua"] = true,
        ["shared/ALifeCamp/CampFeatures.lua"] = true, ["server/ALifeCamp/CampOutposts.lua"] = true,
        ["shared/ALifeCamp/CampZones.lua"] = true, ["shared/ALifeCamp/CampYards.lua"] = true,
        ["shared/ALifeCamp/CampPower.lua"] = true, ["shared/ALifeCamp/CampRegen.lua"] = true,
        ["shared/ALifeCamp/CampTiers.lua"] = true,
    }
    for _, rel in ipairs({
        "shared/ALifeCamp/CampConfig.lua", "shared/ALifeCamp/CampText.lua", "shared/ALifeCamp/CampHooks.lua", "shared/ALifeCamp/CampOptions.lua", "shared/ALifeCamp/CampGeo.lua",
        "shared/ALifeCamp/CampStore.lua", "shared/ALifeCamp/CampFeatures.lua", "shared/ALifeCamp/CampPower.lua", "shared/ALifeCamp/CampWorld.lua", "shared/ALifeCamp/CampStock.lua", "shared/ALifeCamp/CampRecycle.lua", "shared/ALifeCamp/CampSkills.lua",
        "shared/ALifeCamp/CampEntities.lua", "shared/ALifeCamp/CampLand.lua", "shared/ALifeCamp/CampClear.lua", "shared/ALifeCamp/CampSettlers.lua", "shared/ALifeCamp/CampDuty.lua", "shared/ALifeCamp/CampSupply.lua", "shared/ALifeCamp/CampNeeds.lua", "shared/ALifeCamp/Camp.lua",
        "shared/ALifeCamp/CampPlace.lua", "shared/ALifeCamp/CampGates.lua", "shared/ALifeCamp/CampBlueprints.lua", "shared/ALifeCamp/CampBuild.lua", "shared/ALifeCamp/CampPlan.lua", "shared/ALifeCamp/CampZones.lua", "shared/ALifeCamp/CampStats.lua", "shared/ALifeCamp/CampTiers.lua", "shared/ALifeCamp/CampExpand.lua", "shared/ALifeCamp/CampReset.lua", "shared/ALifeCamp/CampRegen.lua", "shared/ALifeCamp/CampSite.lua",
        "shared/ALifeCamp/CampAdopt.lua",
        "shared/ALifeCamp/CampSalvage.lua", "shared/ALifeCamp/CampFortify.lua", "shared/ALifeCamp/CampFitout.lua", "shared/ALifeCamp/CampDistricts.lua", "shared/ALifeCamp/CampYards.lua", "shared/ALifeCamp/CampPosts.lua", "shared/ALifeCamp/CampSlideGate.lua", "shared/ALifeCamp/CampMotor.lua",
        "shared/ALifeCamp/CampSanitary.lua", "shared/ALifeCamp/CampHealth.lua", "shared/ALifeCamp/CampLife.lua", "shared/ALifeCamp/CampProgress.lua", "shared/ALifeCamp/CampCouncil.lua", "shared/ALifeCamp/CampHouses.lua", "shared/ALifeCamp/CampBuildings.lua", "shared/ALifeCamp/CampBuildings2.lua", "shared/ALifeCamp/CampBuildings3.lua", "shared/ALifeCamp/CampScenery.lua", "shared/ALifeCamp/CampShells.lua", "shared/ALifeCamp/CampTowers.lua", "shared/ALifeCamp/CampPerimeter.lua", "shared/ALifeCamp/CampFortress.lua",
        "client/ALifeCamp/CampMarkers.lua", "client/ALifeCamp/CampCalm.lua", "client/ALifeCamp/CampActions.lua", "client/ALifeCamp/CampFlags.lua",
        "client/ALifeCamp/CampMenu.lua", "client/ALifeCamp/CampPlanner.lua", "client/ALifeCamp/CampWindow.lua", "server/ALifeCamp/CampRelations.lua", "server/ALifeCamp/CampDirector.lua", "server/ALifeCamp/CampWork.lua", "server/ALifeCamp/CampOutposts.lua",
        "@addon/shared/ALifeCampCheats/CampCheats.lua", "@addon/server/ALifeCampCheats/CampCheatsHooks.lua",
        "@addon/shared/ALifeCampCheats/CheatsSanitary.lua", "@addon/shared/ALifeCampCheats/CheatsHealth.lua", "@addon/shared/ALifeCampCheats/CheatsLife.lua", "@addon/shared/ALifeCampCheats/CheatsProgress.lua", "@addon/shared/ALifeCampCheats/CheatsCouncil.lua", "@addon/shared/ALifeCampCheats/CheatsFortress.lua",
    }) do
        local path = string.sub(rel, 1, 7) == "@addon/" and (ADDON .. "/" .. string.sub(rel, 8)) or (root .. "/" .. rel)
        if not optional[rel] or (exists(path) and not SKIPMOD[rel]) then
            local f, err = loadfile(path)
            if f == nil then error(err) end
            f()
        end
    end
end


function NEWOBJ(square, class, spriteName)
    local o = IsoObject.new(nil, square, { name = spriteName or "x" })
    o.class = class
    square:AddTileObject(o)
    return o
end

function NEWWORLDITEM(square, fullType)
    local item = NEWITEM(fullType)
    local wo = { class = "IsoWorldInventoryObject", item = item }
    function wo:getItem() return self.item end
    function wo:removeFromWorld() end
    function wo:removeFromSquare() end
    table.insert(square.wobjects, wo)
    return wo
end

function NEWSHELL(uid, x, y)
    local shell = { mod = { ProjectALifeOwned = true, ProjectALifeUID = uid, ProjectALifeGeneration = 1 }, px = x, py = y, pz = 0, lines = {} }
    function shell:getModData() return self.mod end
    function shell:getX() return self.px end
    function shell:getY() return self.py end
    function shell:getZ() return self.pz end
    function shell:getDescriptor() return { getForename = function() return "Ivan" end, getSurname = function() return uid end } end
    function shell:addLineChatElement(text) table.insert(self.lines, text) end
    ZombRand = function() return 0 end
    return shell
end

function MOCKALIFE()
    local reg = { records = {} }
    function reg.peek(uid) return reg.records[uid] end
    function reg.update(uid, rev, fn)
        local r = reg.records[uid]
        if r == nil or r.revision ~= rev then return nil end
        fn(r)
        r.revision = r.revision + 1
        return r
    end
    local orders = {}
    ProjectALife = {
        ActorRegistry = reg,
        DecisionLoop = { orders = orders, setOrder = function(uid, gen, order)
            local r = reg.records[uid]
            if r == nil or r.lifecycle ~= "active" or r.generation ~= gen then return false end
            orders[uid] = order
            return true
        end },
        Watchdog = { bindings = {} },
        Relations = { playerStance = function(record) return (record.memory and record.memory.stance) or "neutral" end },
        Catalog = { npc = function(id) return { general = { name = "Profile " .. id } } end },
    }
    return reg, orders
end

function ADDACTOR(reg, uid, stance, x, y, square)
    reg.records[uid] = { uid = uid, revision = 1, generation = 1, lifecycle = "active", profileId = "p_" .. uid, factionId = "f", worldPosition = { x = x, y = y, z = 0 }, memory = { stance = stance } }
    local shell = NEWSHELL(uid, x, y)
    ProjectALife.Watchdog.bindings[uid] = { shell = shell }
    if square ~= nil then table.insert(square.moving, shell) end
    return shell
end


local function permissive(o)
    return setmetatable(o, { __index = function(t, k) return function() return nil end end })
end
function THUMP(sprite, north, class)
    local o = { class = class or "IsoThumpable", sprite = { name = sprite }, north = north, mod = {} }
    function o:getModData() return self.mod end
    function o:getNorth() return self.north end
    function o:getSquare() return self.square end
    function o:getContainer() return self.container end
    function o:getSprite() return { getName = function() return sprite end, getProperties = function() return { has = function() return false end } end } end
    return permissive(o)
end
IsoThumpable = { new = function(cell, square, sprite, a, b, c)
    local closed, open, north = sprite, nil, nil
    if type(a) == "string" then open, north = a, b else north = a end
    local o = THUMP(closed, north)
    o.openSprite = open
    return o
end }
IsoWindow = { new = function(cell, square, sprite, north)
    local o = THUMP(sprite.name, north, "IsoWindow")
    return o
end }
getWorld = function() return { isValidSquare = function() return true end } end

ISPanel = derive("ISPanel")
function ISPanel:new(x, y, w, h) return setmetatable({ x = x, y = y, width = w, height = h }, ISPanel) end
