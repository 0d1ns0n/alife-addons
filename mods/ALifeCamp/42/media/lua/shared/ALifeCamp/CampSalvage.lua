require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock

local Salvage = {}
ALifeCamp.Salvage = Salvage

Salvage.version = 1
Salvage.rate = 1
Salvage.maxCells = 400
Salvage.maxExamine = 60
Salvage.maxRemovals = 40
Salvage.maxCredit = 120
Salvage.maxFailures = 3
Salvage.retryHours = 0.25
Salvage.cacheLimit = 4000

local function newSession()
    local stamp = 0
    pcall(function() stamp = getTimestampMs() end)
    return tostring(stamp) .. ":" .. tostring(ZombRand ~= nil and ZombRand(1000000) or 0)
end

Salvage.session = newSession()

Salvage.work = { tiny = 1, small = 2, medium = 5, large = 9, huge = 14 }

Salvage.amounts = {
    tiny = { planks = 0, nails = 0, metal = 1, rags = 1 },
    small = { planks = 1, nails = 1, metal = 1, rags = 1 },
    medium = { planks = 2, nails = 2, metal = 2, rags = 2 },
    large = { planks = 4, nails = 3, metal = 3, rags = 3 },
    huge = { planks = 6, nails = 4, metal = 5, rags = 4 },
}

Salvage.items = {
    planks = "Base.Plank",
    nails = "Base.Nails",
    scrap = "Base.ScrapMetal",
    sheet = "Base.SmallSheetMetal",
    rags = "Base.RippedSheets",
}

Salvage.kinds = {
    chair = { size = "small", mats = "wood" },
    armchair = { size = "medium", mats = "wood", cloth = true, planks = 2, nails = 2, rags = 3 },
    sofa = { size = "medium", mats = "wood", cloth = true, planks = 3, nails = 2, rags = 4 },
    wardrobe = { size = "large", mats = "wood" },
    dresser = { size = "medium", mats = "wood" },
    nightstand = { size = "small", mats = "wood" },
    shelf = { size = "auto", mats = "wood" },
    cabinet = { size = "auto", mats = "wood" },
    locker = { size = "large", mats = "metal" },
    table = { size = "auto", mats = "wood" },
    desk = { size = "auto", mats = "wood" },
    lamp = { size = "tiny" },
    rug = { size = "tiny", cloth = true },
    plant = { size = "tiny" },
    mannequin = { size = "medium" },
    piano = { size = "huge", mats = "wood", planks = 6, nails = 4 },
    box = { size = "small", mats = "wood" },
    decor = { size = "small" },
}

Salvage.removeNames = {
    chair = "chair", chairs = "chair", stool = "chair", seat = "chair", seating = "chair", bench = "chair",
    pew = "chair", ottoman = "chair", ["school bench"] = "chair", ["bar stool"] = "chair",
    ["blue bar stool"] = "chair", ["50s barstool"] = "chair", ["medical stool"] = "chair",
    couch = "sofa",
    wardrobe = "wardrobe",
    drawers = "dresser",
    shelves = "shelf", shelf = "shelf", rack = "shelf", ["magazine shelf"] = "shelf", ["magazine stand"] = "shelf",
    ["gun shelves"] = "shelf", ["clothes stand"] = "shelf",
    cabinet = "cabinet", ["tool cabinet"] = "cabinet",
    locker = "locker", chest = "locker",
    table = "table", ["low table"] = "table", ["picknic table"] = "table", ["round table"] = "table",
    ["fancy table"] = "table", ["dark round table"] = "table", ["light round table"] = "table",
    ["oak round table"] = "table", ["poor quality table"] = "table", ["shoddy table"] = "table",
    ["exceptional table"] = "table", ["fancy dark table"] = "table",
    desk = "desk",
    lamp = "lamp",
    ficus = "plant", ["dragon tree"] = "plant", ["snake plant"] = "plant", ["cast iron plant"] = "plant",
    ["chinese evergreen"] = "plant", ["bonsai tree"] = "plant", fern = "plant", cactus = "plant",
    ["green plant"] = "plant", ["purple plant"] = "plant", ["yellow plant"] = "plant", ["white plant"] = "plant",
    ["orange plant"] = "plant", ["brown plant"] = "plant", ["small yellow plant"] = "plant",
    ["venus fly trap"] = "plant", ["voilet flowers"] = "plant",
    mannequin = "mannequin", ["mannequin stand"] = "mannequin",
    piano = "piano", ["grand piano"] = "piano", organ = "piano",
    crate = "box", cartbox = "box", ["small crate"] = "box", box = "box", basket = "box",
    statue = "decor", ["female statue"] = "decor", ["male statue"] = "decor", bust = "decor",
    amphora = "decor", ["the gnome"] = "decor",
}

Salvage.removeContainers = {
    wardrobe = "wardrobe", clothingrack = "shelf", dresser = "dresser", sidetable = "nightstand",
    shelves = "shelf", metal_shelves = "shelf", shelvesmag = "shelf", locker = "locker",
    militarylocker = "locker", filingcabinet = "cabinet", dishescabinet = "cabinet", desk = "desk",
    toolcabinet = "cabinet", smallbox = "box", smallcrate = "box", crate = "box", militarycrate = "box",
    cardboardbox = "box",
}

Salvage.keepNames = {
    toilet = "toilet", ["gallery toilet"] = "toilet", sink = "sink", bath = "bath", shower = "shower",
    fridge = "fridge", freezer = "fridge", oven = "stove", microwave = "microwave", dishwasher = "dishwasher",
    hood = "hood", counter = "counter", toaster = "appliance", conditioner = "appliance",
    ["washing machine"] = "laundry", ["clothing dryer"] = "laundry", ["combo washer dryer"] = "laundry",
    fireplace = "heating", barbecue = "heating", brazier = "heating", ["cooking pit"] = "heating",
    campfire = "heating", ["charcoal burner"] = "heating", forge = "heating",
    generator = "generator", radio = "media", television = "media", jukebox = "media",
    ["walkie talkie"] = "media", switch = "switch", workbench = "workbench",
}

Salvage.keepContainers = {
    fridge = "fridge", stove = "stove", woodstove = "heating", stonefurnace = "heating", microwave = "microwave",
    dishwasher = "dishwasher", clothingwasher = "laundry", clothingdryer = "laundry", clothingdryerbasic = "laundry",
    fireplace = "heating", barbecue = "heating", barbecuepropane = "heating", campfire = "heating",
    brazier = "heating", counter = "counter", overhead = "counter", medicine = "medicine",
    cashregister = "register", vendingpop = "vending", vendingsnack = "vending", postbox = "mail",
}

Salvage.keepTypes = {
    IsoStove = "stove", IsoFireplace = "heating", IsoBarbecue = "heating", IsoRadio = "media",
    IsoTelevision = "media", IsoClothingWasher = "laundry", IsoClothingDryer = "laundry",
    IsoCombinationWasherDryer = "laundry", IsoCompost = "garden", IsoFeedingTrough = "garden",
}

Salvage.ignoreNames = {
    door = "structure", doorframe = "structure", window = "structure", windowframe = "structure",
    wall = "structure", curtain = "curtain", trash = "litter", glass = "litter", hide = "litter",
    ["hay floor"] = "litter",
}

Salvage.bedNames = {
    bed = true, beds = true, mattress = true, ["sleeping bag"] = true, ["cheap sleeping bag"] = true,
    ["plaid sleeping bag"] = true, ["high quality sleeping bag"] = true, ["spiffo sleeping bag"] = true,
}

Salvage.roomRules = {
    kitchen = {
        chair = true, armchair = true, sofa = true, wardrobe = true, nightstand = true, desk = true, plant = true,
        mannequin = true, piano = true, box = true, lamp = true, rug = true, decor = true,
    },
    laundry = {
        chair = true, armchair = true, sofa = true, wardrobe = true, nightstand = true, desk = true, plant = true,
        mannequin = true, piano = true, box = true, lamp = true, rug = true, decor = true,
    },
    bath = {
        chair = true, armchair = true, sofa = true, table = true, desk = true, wardrobe = true, plant = true,
        mannequin = true, piano = true, box = true, lamp = true,
    },
}

Salvage.guards = {
    { "IsoThumpable", "keep", "built" },
    { "IsoWorldInventoryObject", "ignore", "item" },
    { "IsoMovingObject", "ignore", "living" },
    { "IsoDeadBody", "ignore", "item" },
    { "IsoTree", "ignore", "tree" },
    { "IsoDoor", "ignore", "structure" },
    { "IsoWindow", "ignore", "structure" },
    { "IsoWindowFrame", "ignore", "structure" },
    { "IsoBarricade", "ignore", "structure" },
    { "IsoCurtain", "ignore", "curtain" },
    { "IsoLightSwitch", "keep", "switch" },
    { "IsoStove", "keep", "stove" },
    { "IsoFireplace", "keep", "heating" },
    { "IsoBarbecue", "keep", "heating" },
    { "IsoRadio", "keep", "media" },
    { "IsoTelevision", "keep", "media" },
    { "IsoWaveSignal", "keep", "media" },
    { "IsoJukebox", "keep", "media" },
    { "IsoClothingWasher", "keep", "laundry" },
    { "IsoClothingDryer", "keep", "laundry" },
    { "IsoCombinationWasherDryer", "keep", "laundry" },
    { "IsoStackedWasherDryer", "keep", "laundry" },
    { "IsoGenerator", "keep", "generator" },
    { "IsoCarBatteryCharger", "keep", "generator" },
    { "IsoFeedingTrough", "keep", "garden" },
    { "IsoCompost", "keep", "garden" },
    { "IsoHutch", "keep", "garden" },
    { "IsoWheelieBin", "keep", "garden" },
}

Salvage.structureFlags = {
    "WallN", "WallW", "WallNW", "WallSE", "WallNTrans", "WallWTrans", "WallNWTrans", "DoorWallN", "DoorWallW",
    "WindowN", "WindowW", "windowN", "windowW", "doorN", "doorW", "doorFrN", "doorFrW", "solidfloor",
    "stairsTN", "stairsTW", "stairsMN", "stairsMW", "stairsBN", "stairsBW",
}

Salvage.structurePrefixes = { "floors_", "walls_", "roofs_", "blends_" }

Salvage.armchairGroups = { "comfy", "lazy", "rattan", "theatre" }

local woodMaterials = { Wood = true, Log = true }
local scrapMaterials = {
    MetalScrap = true, MetalBars = true, MetalPipe = true, Steel = true, AluminumScrap = true, Pipes = true,
    MetalWire = true,
}
local sheetMaterials = { MetalPlates = true, SmallMetalPlates = true }
local clothMaterials = { Fabric = true, Leather = true, Foam = true }

local snapCache = {}
local snapCount = 0

local function lower(value)
    if value == nil then return nil end
    return string.lower(tostring(value))
end

local function contains(text, part)
    return text ~= nil and string.find(text, part, 1, true) ~= nil
end

local function startsWith(text, prefixes)
    for i = 1, #prefixes do
        if string.sub(text, 1, #prefixes[i]) == prefixes[i] then return true end
    end
    return false
end

local function propertyFlag(props, name)
    local on = false
    pcall(function()
        local key = IsoFlagType ~= nil and IsoFlagType[name] or nil
        if key ~= nil and props:has(key) == true then on = true end
        if not on then on = props:has(name) == true end
    end)
    return on
end

local function propertyValue(props, name)
    local value
    pcall(function()
        if props:has(name) == true then value = props:get(name) end
    end)
    if value == "" then return nil end
    return value
end

local function spriteName(object)
    local name = ""
    pcall(function()
        local sprite = object:getSprite()
        if sprite ~= nil then name = sprite:getName() or "" end
    end)
    return name
end

local function tagged(object)
    local present = true
    pcall(function()
        if object:hasModData() == false then present = false end
    end)
    if not present then return false end
    return type(World.tag(object)) == "table"
end

local function materialsOf(list)
    local out = { known = false }
    for _, name in ipairs(list) do
        if name ~= "Undefined" then
            out.known = true
            if woodMaterials[name] then out.wood = true end
            if scrapMaterials[name] then out.scrap = true end
            if sheetMaterials[name] then out.sheet = true end
            if clothMaterials[name] then out.cloth = true end
        end
    end
    return out
end

local function isRugName(name)
    return contains(name, "rug") or contains(name, "carpet") or contains(name, "mat")
end

local function isArmchair(snap)
    if not snap.mats.cloth then return false end
    if (snap.weight or 0) >= 100 then return true end
    for _, token in ipairs(Salvage.armchairGroups) do
        if contains(snap.group, token) then return true end
    end
    return false
end

local function refine(kind, snap)
    if kind == "chair" and isArmchair(snap) then return "armchair" end
    if kind == "dresser" and snap.container == "sidetable" then return "nightstand" end
    return kind
end

local function decide(snap)
    if snap.structure then return { "ignore", "structure" } end
    local name, container = snap.custom, snap.container
    if name ~= nil and Salvage.ignoreNames[name] ~= nil then return { "ignore", Salvage.ignoreNames[name] } end
    if snap.streetlight then return { "ignore", "structure" } end
    if snap.isoType ~= nil and Salvage.keepTypes[snap.isoType] ~= nil then
        return { "keep", Salvage.keepTypes[snap.isoType] }
    end
    if container ~= nil and Salvage.keepContainers[container] ~= nil then
        return { "keep", Salvage.keepContainers[container] }
    end
    if snap.fridge then return { "keep", "fridge" } end
    if snap.signal ~= nil then return { "keep", "media" } end
    if name ~= nil and Salvage.bedNames[name] then return { "keep", "bed" } end
    if name ~= nil and Salvage.keepNames[name] ~= nil then return { "keep", Salvage.keepNames[name] } end
    if snap.plumbed then return { "keep", "plumbing" } end
    local mount = snap.moveType
    if (mount == "wallobject" and container == nil) or mount == "windowobject" or mount == "window" then
        return { "ignore", "wall" }
    end
    local kind = name ~= nil and Salvage.removeNames[name] or nil
    if kind == nil and name == nil and container ~= nil then kind = Salvage.removeContainers[container] end
    if kind == nil and mount == "floorrug" and isRugName(name) then kind = "rug" end
    if kind == nil and snap.isoType == "IsoMannequin" then kind = "mannequin" end
    if kind ~= nil then
        if not snap.movable then return { "keep", "fixed" } end
        return { "remove", refine(kind, snap) }
    end
    if snap.movable then return { "keep", "other" } end
    if name ~= nil or container ~= nil then return { "keep", "fixed" } end
    return { "ignore", "other" }
end

local function readSnap(object, name)
    local snap = { name = name, cells = 1, anchor = true, mats = { known = false }, surface = 0 }
    pcall(function()
        local sprite = object:getSprite()
        local props = sprite:getProperties()
        if props == nil then return end
        snap.custom = lower(propertyValue(props, "CustomName"))
        snap.group = lower(propertyValue(props, "GroupName"))
        snap.container = lower(propertyValue(props, "container"))
        snap.moveType = lower(propertyValue(props, "MoveType"))
        snap.isoType = propertyValue(props, "IsoType")
        snap.signal = propertyValue(props, "signal")
        snap.weight = tonumber(propertyValue(props, "PickUpWeight"))
        snap.scrapSize = lower(propertyValue(props, "ScrapSize"))
        snap.surface = tonumber(propertyValue(props, "Surface")) or 0
        snap.gridPos = propertyValue(props, "SpriteGridPos")
        snap.movable = propertyFlag(props, "IsMoveAble")
        snap.fridge = propertyFlag(props, "IsFridge") or propertyFlag(props, "Freezer") or propertyFlag(props, "Microwave")
        snap.plumbed = propertyFlag(props, "waterPiped")
        snap.streetlight = propertyFlag(props, "streetlight") and not propertyFlag(props, "IsMoveAble")
        local list = {}
        for _, key in ipairs({ "Material", "Material2", "Material3" }) do
            local material = propertyValue(props, key)
            if material ~= nil then list[#list + 1] = material end
        end
        snap.mats = materialsOf(list)
        for _, flagName in ipairs(Salvage.structureFlags) do
            if propertyFlag(props, flagName) then snap.structure = true break end
        end
    end)
    if not snap.movable and startsWith(name, Salvage.structurePrefixes) then snap.structure = true end
    if snap.gridPos ~= nil then snap.anchor = string.sub(snap.gridPos, 1, 3) == "0,0" end
    pcall(function()
        local grid = object:getSprite():getSpriteGrid()
        if grid ~= nil then snap.cells = math.max(1, grid:getSpriteCount()) end
    end)
    pcall(function()
        local sprite = object:getSprite()
        local grid = sprite:getSpriteGrid()
        if grid ~= nil then
            snap.anchor = grid:getSpriteGridPosX(sprite) == 0 and grid:getSpriteGridPosY(sprite) == 0
        end
    end)
    snap.verdict = decide(snap)
    return snap
end

local function snapshot(object)
    local name = spriteName(object)
    if name == "" then return nil end
    local snap = snapCache[name]
    if snap ~= nil then return snap end
    snap = readSnap(object, name)
    if snapCount >= Salvage.cacheLimit then
        snapCache = {}
        snapCount = 0
    end
    snapCache[name] = snap
    snapCount = snapCount + 1
    return snap
end

Salvage.snapshot = snapshot

function Salvage.resetCache()
    snapCache = {}
    snapCount = 0
end

function Salvage.roomClass(name)
    if name == nil or name == "" then return "other" end
    local text = string.lower(name)
    if contains(text, "kitchen") then return "kitchen" end
    if contains(text, "bath") or contains(text, "toilet") or contains(text, "restroom") or contains(text, "shower")
            or contains(text, "washroom") then
        return "bath"
    end
    if contains(text, "laundry") then return "laundry" end
    return "other"
end

function Salvage.allowed(roomName, kind)
    local rules = Salvage.roomRules[Salvage.roomClass(roomName)]
    if rules == nil then return true end
    return rules[kind] == true
end

local function sizeOf(def, snap)
    local size = def.size or "small"
    if size ~= "auto" then return size end
    local weight = snap.weight
    if snap.scrapSize == "large" then return "large" end
    if weight == nil then return "medium" end
    if weight <= 60 then return "small" end
    if weight <= 120 then return "medium" end
    if weight <= 250 then return "large" end
    return "huge"
end

local function groupsOf(snap, def)
    if snap.mats.known then return snap.mats end
    local out = {}
    if def.mats == "wood" then out.wood = true end
    if def.mats == "metal" then out.scrap = true end
    if def.cloth then out.cloth = true end
    return out
end

function Salvage.yield(kind, snap)
    local out = { planks = 0, nails = 0, scrap = 0, sheet = 0, rags = 0 }
    local def = Salvage.kinds[kind]
    if def == nil or snap == nil then return out, "small" end
    local size = sizeOf(def, snap)
    local base = Salvage.amounts[size]
    local groups = groupsOf(snap, def)
    local piece = { planks = 0, nails = 0, scrap = 0, sheet = 0, rags = 0 }
    if groups.wood then
        piece.planks = def.planks or base.planks
        piece.nails = def.nails or base.nails
    end
    local metal = def.metal or base.metal
    if groups.scrap and groups.sheet then
        piece.scrap = math.ceil(metal / 2)
        piece.sheet = math.ceil(metal / 2)
    elseif groups.scrap then
        piece.scrap = metal
    elseif groups.sheet then
        piece.sheet = metal
    end
    if groups.cloth then piece.rags = def.rags or base.rags end
    local cells = snap.cells or 1
    for key, amount in pairs(piece) do
        local share = math.floor(amount / cells)
        if snap.anchor then share = amount - share * (cells - 1) end
        out[key] = share
    end
    return out, size
end

function Salvage.workOf(size, snap)
    local base = Salvage.work[size] or Salvage.work.small
    local cells = snap ~= nil and snap.cells or 1
    return math.max(1, math.ceil(base / cells))
end

local function guardOf(object)
    for _, guard in ipairs(Salvage.guards) do
        local hit = false
        pcall(function() hit = instanceof(object, guard[1]) == true end)
        if hit then return guard end
    end
    return nil
end

local function judge(object, roomName)
    if object == nil then return "ignore", "none" end
    if tagged(object) then return "keep", "tagged" end
    local snap = snapshot(object)
    if snap == nil then return "ignore", "none" end
    local verdict = snap.verdict
    if verdict[1] ~= "remove" then return verdict[1], verdict[2], nil, snap end
    local guard = guardOf(object)
    if guard ~= nil then return guard[2], guard[3], nil, snap end
    local kind = verdict[2]
    if not Salvage.allowed(roomName, kind) then return "keep", kind, nil, snap end
    local def = Salvage.kinds[kind]
    if def == nil then return "keep", kind, nil, snap end
    return "remove", kind, sizeOf(def, snap), snap
end

function Salvage.classify(object, roomName)
    local action, kind, size = judge(object, roomName)
    return action, kind, size
end

local function roomNameOf(rec, square, x, y, z)
    local name
    pcall(function()
        local room = square:getRoom()
        if room ~= nil then name = room:getName() end
    end)
    if name ~= nil and name ~= "" then return name end
    if type(rec.rooms) == "table" then
        for _, room in ipairs(rec.rooms) do
            if (room.z or z) == z and x >= room.x1 and x <= room.x2 and y >= room.y1 and y <= room.y2 then
                return room.name
            end
        end
    end
    return nil
end

local function insideBuilding(square, roomName)
    if roomName ~= nil then return true end
    local inside = false
    pcall(function() inside = square:getBuilding() ~= nil end)
    return inside
end

local function reserved(rec, x, y, z)
    return type(rec.keep) == "table" and rec.keep[x .. "," .. y .. "," .. z] == true
end

local function freshState()
    return {
        v = Salvage.version,
        session = Salvage.session,
        cursor = 0,
        queue = {},
        total = 0,
        done = 0,
        failed = 0,
        credit = 0,
        passes = 0,
        scanned = false,
        partial = false,
        finished = false,
        gained = { planks = 0, nails = 0, metal = 0, rags = 0, rope = 0 },
        removed = {},
        yields = { planks = 0, nails = 0, metal = 0, rags = 0, rope = 0 },
        left = { planks = 0, nails = 0, metal = 0, rags = 0, work = 0 },
        kept = {},
        keptBeds = 0,
        pass = { kept = {}, beds = 0, partial = false },
    }
end

function Salvage.state(rec)
    local state = rec.salvage
    if type(state) ~= "table" or state.v ~= Salvage.version or type(state.queue) ~= "table" then
        state = freshState()
        rec.salvage = state
    end
    if type(state.gained) ~= "table" then state.gained = freshState().gained end
    if type(state.removed) ~= "table" then state.removed = {} end
    if type(state.kept) ~= "table" then state.kept = {} end
    if type(state.pass) ~= "table" then state.pass = { kept = {}, beds = 0, partial = false } end
    if type(state.pass.kept) ~= "table" then state.pass.kept = {} end
    return state
end

function Salvage.reset(rec)
    rec.salvage = nil
end

local function refresh(state)
    local left = { planks = 0, nails = 0, metal = 0, rags = 0, work = 0 }
    for _, entry in ipairs(state.queue) do
        left.planks = left.planks + (entry.p or 0)
        left.nails = left.nails + (entry.a or 0)
        left.metal = left.metal + (entry.m or 0)
        left.rags = left.rags + (entry.r or 0)
        left.work = left.work + (entry.w or 0)
    end
    state.left = left
    state.total = state.done + #state.queue
    state.yields = {
        planks = state.gained.planks + left.planks,
        nails = state.gained.nails + left.nails,
        metal = state.gained.metal + left.metal,
        rags = state.gained.rags + left.rags,
        rope = state.gained.rope or 0,
    }
end

local function makeEntry(x, y, z, cell, object, kind, size, snap)
    local yield = Salvage.yield(kind, snap)
    return {
        x = x, y = y, z = z, c = cell, n = spriteName(object), k = kind,
        w = Salvage.workOf(size, snap),
        p = yield.planks, a = yield.nails, m = yield.scrap + yield.sheet, r = yield.rags,
    }
end

local function inspectSquare(rec, state, square, x, y, z, cell)
    local entries = {}
    local roomName = roomNameOf(rec, square, x, y, z)
    if not insideBuilding(square, roomName) then return entries end
    local pass = state.pass
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local action, kind, size, snap = judge(object, roomName)
            if action == "remove" then
                entries[#entries + 1] = makeEntry(x, y, z, cell, object, kind, size, snap)
            elseif action == "keep" then
                pass.kept[kind] = (pass.kept[kind] or 0) + 1
                if kind == "bed" and snap ~= nil and snap.anchor then pass.beds = pass.beds + 1 end
            end
        end
    end)
    return entries
end

local function mergeChunk(state, first, last, fresh, skipped)
    local old = state.queue
    local count = #old
    local out = {}
    local i = 1
    while i <= count and old[i].c < first do
        out[#out + 1] = old[i]
        i = i + 1
    end
    local carried = {}
    while i <= count and old[i].c < last do
        if skipped[old[i].c] then carried[#carried + 1] = old[i] end
        i = i + 1
    end
    local a, b = 1, 1
    while a <= #carried or b <= #fresh do
        if b > #fresh or (a <= #carried and carried[a].c <= fresh[b].c) then
            out[#out + 1] = carried[a]
            a = a + 1
        else
            out[#out + 1] = fresh[b]
            b = b + 1
        end
    end
    while i <= count do
        out[#out + 1] = old[i]
        i = i + 1
    end
    state.queue = out
    state.at = nil
end

local function finishPass(state)
    state.kept = state.pass.kept
    state.keptBeds = state.pass.beds
    state.partial = state.pass.partial
    state.scanned = true
    state.scannedAt = Store.hours()
    state.passes = state.passes + 1
end

local function beginPass(state)
    state.cursor = 0
    state.scanned = false
    state.session = Salvage.session
    state.pass = { kept = {}, beds = 0, partial = false }
end

local function scanChunk(camp, rec, state, cells)
    local rect = rec.rect
    if type(rect) ~= "table" or rect.x1 == nil or rect.x2 == nil or rect.y1 == nil or rect.y2 == nil then
        finishPass(state)
        return
    end
    local width = rect.x2 - rect.x1 + 1
    local height = rect.y2 - rect.y1 + 1
    local floors = math.max(1, math.floor(rec.floors or 1))
    local baseZ = rect.z or rec.z or camp.z or 0
    local area = width * height
    local total = area * floors
    local first = state.cursor
    local last = math.min(total, first + math.max(1, cells))
    local fresh, skipped = {}, {}
    local unloaded = false
    for cell = first, last - 1 do
        local level = math.floor(cell / area)
        local rest = cell - level * area
        local row = math.floor(rest / width)
        local x = rect.x1 + (rest - row * width)
        local y = rect.y1 + row
        local z = baseZ + level
        local square = World.square(x, y, z)
        if square == nil then
            if World.square(x, y, 0) == nil and World.square(x, y, baseZ) == nil then
                skipped[cell] = true
                unloaded = true
            end
        elseif not reserved(rec, x, y, z) then
            local found = inspectSquare(rec, state, square, x, y, z, cell)
            for _, entry in ipairs(found) do fresh[#fresh + 1] = entry end
        end
    end
    mergeChunk(state, first, last, fresh, skipped)
    state.cursor = last
    if unloaded then state.pass.partial = true end
    if state.passes == 0 then state.keptBeds = state.pass.beds end
    if last >= total then finishPass(state) end
    refresh(state)
end

local function advance(camp, rec, state, cells)
    if state.scanned then
        local due = state.session ~= Salvage.session
        if not due and state.partial and Store.hours() - (state.scannedAt or 0) >= Salvage.retryHours then due = true end
        if not due then return false end
        beginPass(state)
    end
    state.session = Salvage.session
    scanChunk(camp, rec, state, cells)
    return true
end

local function progressOf(state)
    local total = state.done + #state.queue
    if total == 0 then
        if state.finished then return 1 end
        if state.scanned and not state.partial then return 1 end
        return 0
    end
    local progress = state.done / total
    if not state.scanned or state.partial then progress = math.min(progress, 0.99) end
    return progress
end

local function inspect(camp, rec, cells)
    local state = Salvage.state(rec)
    if state.finished then return {}, 0, true end
    advance(camp, rec, state, cells or Salvage.maxCells)
    refresh(state)
    return {}, state.left.work / math.max(Salvage.rate, 0.01), state.scanned
end

function Salvage.analyze(camp, rec, cells)
    local ok, cost, minutes, scanned = pcall(inspect, camp, rec, cells)
    if ok then return cost, minutes, scanned end
    return {}, 0, false
end

local function locate(rec, square, entry)
    local roomName = roomNameOf(rec, square, entry.x, entry.y, entry.z)
    local found, foundKind, foundSnap
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if spriteName(object) == entry.n then
                local action, kind, _, snap = judge(object, roomName)
                if action == "remove" then
                    found, foundKind, foundSnap = object, kind, snap
                    return
                end
            end
        end
    end)
    return found, foundKind, foundSnap
end

local function storageBox(camp)
    if type(camp.storage) ~= "table" then return nil end
    for _, entry in ipairs(camp.storage) do
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then
            local box
            pcall(function() box = crate:getContainer() end)
            if box ~= nil then return box end
        end
    end
    return nil
end

local function containersOf(object)
    local list = {}
    pcall(function()
        local first = object:getContainer()
        if first ~= nil then list[1] = first end
    end)
    pcall(function()
        for i = 0, object:getContainerCount() - 1 do
            local box = object:getContainerByIndex(i)
            local known = false
            for _, other in ipairs(list) do
                if other == box then known = true end
            end
            if box ~= nil and not known then list[#list + 1] = box end
        end
    end)
    return list
end

local function evacuate(container, box, square)
    local ok = true
    pcall(function()
        local items = container:getItems()
        for i = items:size() - 1, 0, -1 do
            local item = items:get(i)
            container:Remove(item)
            local stored = false
            if box ~= nil then
                pcall(function()
                    box:AddItem(item)
                    stored = true
                end)
            end
            if not stored then
                pcall(function()
                    square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                    stored = true
                end)
            end
            if not stored then
                pcall(function() container:AddItem(item) end)
                ok = false
                return
            end
        end
    end)
    return ok
end

local function sweep(square, box)
    pcall(function()
        local list = square:getWorldObjects()
        for i = list:size() - 1, 0, -1 do
            local world = list:get(i)
            local item = world:getItem()
            square:transmitRemoveItemFromSquare(world)
            pcall(function() world:removeFromWorld() end)
            pcall(function() world:removeFromSquare() end)
            pcall(function() world:setSquare(nil) end)
            pcall(function() item:setWorldItem(nil) end)
            local stored = false
            pcall(function()
                box:AddItem(item)
                stored = true
            end)
            if not stored then pcall(function() square:AddWorldInventoryItem(item, 0.5, 0.5, 0) end) end
        end
    end)
end

local function holds(square, object)
    local present = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            if objects:get(i) == object then
                present = true
                return
            end
        end
    end)
    return present
end

local function detach(square, object)
    ALifeCamp.World.removeHard(square, object)
    local gone = not holds(square, object)
    if gone then
        pcall(function() square:RecalcProperties() end)
        pcall(function() square:RecalcAllWithNeighbours(true) end)
    end
    return gone
end

local function surfaceLeft(square)
    local left = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local snap = snapshot(objects:get(i))
            if snap ~= nil and snap.movable and (snap.surface > 0 or snap.container ~= nil) then
                left = true
                return
            end
        end
    end)
    return left
end

local function deposit(camp, state, yield)
    local plan = {
        { Salvage.items.planks, yield.planks, "planks" },
        { Salvage.items.nails, yield.nails, "nails" },
        { Salvage.items.scrap, yield.scrap, "metal" },
        { Salvage.items.sheet, yield.sheet, "metal" },
        { Salvage.items.rags, yield.rags, "rags" },
    }
    for _, row in ipairs(plan) do
        if row[2] > 0 then
            Stock.deposit(camp, row[1], row[2])
            state.gained[row[3]] = state.gained[row[3]] + row[2]
        end
    end
end

local function dismantle(camp, state, square, object, kind, snap)
    local box = storageBox(camp)
    local carried = snap.surface > 0 or snap.container ~= nil
    for _, container in ipairs(containersOf(object)) do
        if not evacuate(container, box, square) then return false end
    end
    if not detach(square, object) then return false end
    deposit(camp, state, (Salvage.yield(kind, snap)))
    state.removed[kind] = (state.removed[kind] or 0) + 1
    if carried and box ~= nil and not surfaceLeft(square) then sweep(square, box) end
    return true
end

local function finishIfDone(camp, state)
    if state.finished then return end
    if state.scanned and not state.partial and #state.queue == 0 then
        state.finished = true
        if state.done > 0 then
            pcall(function() Store.log(camp, "salvaged", state.done, state.gained.planks) end)
        end
    end
end

local function run(camp, rec, labor, minutes)
    local state = Salvage.state(rec)
    if state.finished then return true, 1, 0 end
    advance(camp, rec, state, Salvage.maxCells)
    if type(camp.storage) ~= "table" or camp.storage[1] == nil then
        state.blocked = "storage"
        refresh(state)
        return false, progressOf(state), 0
    end
    state.blocked = nil
    local budget = math.max(0, (tonumber(labor) or 0) * (tonumber(minutes) or 0) * Salvage.rate)
    state.credit = math.min(Salvage.maxCredit, state.credit + budget)
    local queue = state.queue
    local spent, removals, examined = 0, 0, 0
    local index = state.at or 1
    if index > #queue then index = 1 end
    state.waiting = false
    while examined < Salvage.maxExamine and removals < Salvage.maxRemovals and queue[index] ~= nil do
        examined = examined + 1
        local entry = queue[index]
        local square = World.square(entry.x, entry.y, entry.z)
        if reserved(rec, entry.x, entry.y, entry.z) then
            table.remove(queue, index)
        elseif square == nil then
            state.waiting = true
            index = index + 1
        else
            local object, kind, snap = locate(rec, square, entry)
            if object == nil then
                table.remove(queue, index)
            elseif state.credit < entry.w then
                break
            elseif dismantle(camp, state, square, object, kind, snap) then
                state.credit = state.credit - entry.w
                spent = spent + entry.w
                removals = removals + 1
                state.done = state.done + 1
                table.remove(queue, index)
            else
                entry.f = (entry.f or 0) + 1
                if entry.f >= Salvage.maxFailures then
                    state.failed = state.failed + 1
                    table.remove(queue, index)
                else
                    index = index + 1
                end
            end
        end
    end
    state.at = queue[index] ~= nil and index or 1
    if #queue == 0 then state.credit = 0 end
    refresh(state)
    finishIfDone(camp, state)
    return state.finished, progressOf(state), spent
end

function Salvage.step(camp, rec, labor, minutes)
    local ok, done, progress, spent = pcall(run, camp, rec, labor, minutes)
    if ok then return done, progress, spent end
    local progressNow = 0
    pcall(function() progressNow = progressOf(Salvage.state(rec)) end)
    return false, progressNow, 0
end

function Salvage.summary(rec)
    local state = type(rec) == "table" and rec.salvage or nil
    local out = {
        total = 0, done = 0, planks = 0, nails = 0, metal = 0, rags = 0, keptBeds = 0,
        gotPlanks = 0, gotNails = 0, gotMetal = 0, gotRags = 0, left = 0, scanned = 0, partial = 0,
        waiting = 0, blocked = 0, failed = 0,
    }
    if type(state) ~= "table" or type(state.queue) ~= "table" then return out end
    local yields = state.yields or {}
    local gained = state.gained or {}
    out.done = state.done or 0
    out.total = out.done + #state.queue
    out.left = #state.queue
    out.planks = yields.planks or 0
    out.nails = yields.nails or 0
    out.metal = yields.metal or 0
    out.rags = yields.rags or 0
    out.keptBeds = state.keptBeds or 0
    out.gotPlanks = gained.planks or 0
    out.gotNails = gained.nails or 0
    out.gotMetal = gained.metal or 0
    out.gotRags = gained.rags or 0
    out.scanned = state.scanned and 1 or 0
    out.partial = state.partial and 1 or 0
    out.waiting = state.waiting and 1 or 0
    out.blocked = state.blocked ~= nil and 1 or 0
    out.failed = state.failed or 0
    return out
end

return Salvage
