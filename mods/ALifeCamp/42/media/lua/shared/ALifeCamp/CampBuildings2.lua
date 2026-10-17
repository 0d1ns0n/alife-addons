require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampDistricts"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Entities = ALifeCamp.Entities
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan

local Buildings2 = {}
ALifeCamp.Buildings2 = Buildings2

Buildings2.minSide = 24
Buildings2.barracksMorale = 4
Buildings2.powerMorale = 2
Buildings2.powerDefense = 3

Entities.CampBkLight = { id = "CampBkLight", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 50,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 1, t = { "Base.Nails" } } } }
Entities.CampBkHeavy = { id = "CampBkHeavy", category = "furniture", faces = { S = { { "carpentry_01_19" } } }, time = 50,
    inputs = { { n = 2, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } } } }
Entities.CampBkBunk = { id = "CampBkBunk", category = "furniture", faces = { S = { { "furniture_bedding_01_85" } } }, time = 60,
    inputs = { { n = 2, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } }, { n = 1, t = { "Base.ScrapMetal" } } } }
Entities.CampBkLocker = { id = "CampBkLocker", category = "furniture", faces = { S = { { "location_military_generic_01_22" } } }, time = 50,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } }, { n = 1, t = { "Base.ScrapMetal" } } } }
Entities.CampBkSoft = { id = "CampBkSoft", category = "furniture", faces = { S = { { "floors_rugs_01_72" } } }, time = 20, inputs = {} }
Entities.CampBkGen = { id = "CampBkGen", category = "furniture", faces = { S = { { "appliances_misc_01_1" } } }, time = 80,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 4, t = { "Base.Nails" } }, { n = 3, t = { "Base.ScrapMetal" } } } }
Entities.CampBkTank = { id = "CampBkTank", category = "furniture", faces = { S = { { "industry_03_105" } } }, time = 50,
    inputs = { { n = 2, t = { "Base.Nails" } }, { n = 2, t = { "Base.ScrapMetal" } } } }

local LIGHT, HEAVY, BUNK, LOCKER, SOFT, GEN, TANK = "CampBkLight", "CampBkHeavy", "CampBkBunk", "CampBkLocker", "CampBkSoft", "CampBkGen", "CampBkTank"

local function layout()
    local list = {}
    local self = {}
    function self.put(dx, dy, sprite, cost, container)
        list[#list + 1] = { dx = dx, dy = dy, sprite = sprite, e = cost, container = container }
    end
    function self.row(dx, dy, cost, sprites)
        for index, sprite in ipairs(sprites) do self.put(dx + index - 1, dy, sprite, cost) end
    end
    function self.column(dx, dy, cost, sprites)
        for index, sprite in ipairs(sprites) do self.put(dx, dy + index - 1, sprite, cost) end
    end
    function self.block(dx, dy, columns, cost, sprites)
        for index, sprite in ipairs(sprites) do
            self.put(dx + (index - 1) % columns, dy + math.floor((index - 1) / columns), sprite, cost)
        end
    end
    function self.list()
        return list
    end
    return self
end

local function barracksLayout()
    local l = layout()
    l.put(0, 0, "location_military_generic_01_22", LOCKER)
    l.row(1, 0, HEAVY, { "furniture_storage_01_58", "furniture_storage_01_59" })
    l.row(3, 0, HEAVY, { "furniture_storage_01_58", "furniture_storage_01_59" })
    l.row(5, 0, HEAVY, { "furniture_storage_01_58", "furniture_storage_01_59" })
    l.put(7, 0, "location_military_generic_01_22", LOCKER)
    l.put(8, 0, "furniture_storage_02_0", LOCKER)
    for _, dx in ipairs({ 1, 3, 5, 7 }) do
        l.column(dx, 1, BUNK, { "furniture_bedding_01_85", "furniture_bedding_01_84" })
    end
    l.put(8, 1, "lighting_indoor_02_31", LIGHT)
    l.put(8, 2, "furniture_storage_02_28", HEAVY)
    l.block(2, 3, 4, SOFT, { "floors_rugs_01_72", "floors_rugs_01_73", "floors_rugs_01_74", "floors_rugs_01_75",
        "floors_rugs_01_76", "floors_rugs_01_77", "floors_rugs_01_78", "floors_rugs_01_79" })
    l.row(2, 4, LIGHT, { "furniture_tables_low_01_14", "furniture_tables_low_01_15" })
    l.row(2, 3, LIGHT, { "furniture_seating_indoor_02_9", "furniture_seating_indoor_02_9" })
    l.put(1, 4, "furniture_seating_indoor_02_8", LIGHT)
    l.block(6, 3, 2, SOFT, { "rugs_animals_7", "rugs_animals_6", "rugs_animals_5", "rugs_animals_4" })
    l.put(8, 4, "lighting_indoor_02_29", LIGHT)
    return l.list()
end

local function powerhouseLayout()
    local l = layout()
    l.put(0, 0, "appliances_misc_01_1", GEN)
    l.put(1, 0, "appliances_misc_01_5", GEN)
    l.put(2, 0, "appliances_misc_01_9", GEN)
    l.put(3, 0, "appliances_misc_01_13", GEN)
    l.put(4, 0, "industry_03_105", TANK)
    l.put(5, 0, "industry_03_107", TANK)
    l.put(0, 1, "industry_03_22", LIGHT)
    l.put(5, 1, "industry_03_109", TANK)
    l.put(0, 2, "lighting_outdoor_01_49", GEN)
    l.put(1, 2, "industry_03_100", HEAVY)
    l.put(2, 2, "lighting_indoor_02_31", LIGHT)
    l.put(4, 2, "appliances_com_01_56", LIGHT)
    l.put(5, 2, "lighting_outdoor_01_49", GEN)
    l.put(4, 3, "furniture_seating_indoor_02_11", LIGHT)
    l.put(0, 3, "carpentry_02_59", HEAVY)
    l.put(5, 3, "carpentry_02_59", HEAVY)
    return l.list()
end

local knownSprites = {}

local function known(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

Buildings2.definitions = {
    barracks = { w = 9, h = 6, priority = 4.7, people = 7, dx = -13, dy = 4, radius = 10, furniture = barracksLayout() },
    powerhouse = { w = 6, h = 4, priority = 5.0, people = 9, dx = 12, dy = -9, radius = 9, furniture = powerhouseLayout() },
}

Buildings2.kinds = { "barracks", "powerhouse" }

function Buildings2.furnitureOps(project, kind)
    local def = Buildings2.definitions[kind]
    local ops = {}
    if def == nil then return ops end
    local aisle = {}
    local dw = math.floor(project.w / 2)
    for dy = 0, project.h - 1 do aisle[dw .. ":" .. dy] = true end
    for index, piece in ipairs(def.furniture) do
        if piece.dx < project.w and piece.dy < project.h and known(piece.sprite)
                and not aisle[piece.dx .. ":" .. piece.dy] then
            ops[#ops + 1] = { t = "prop", e = piece.e, sprite = piece.sprite, container = piece.container,
                x = project.x + piece.dx, y = project.y + piece.dy, z = 0, slot = "B" .. index }
        end
    end
    return ops
end

local function stages(project, kind)
    local out = Bp.building(project, kind)
    local extra = Buildings2.furnitureOps(project, kind)
    for _, stage in ipairs(out) do
        if stage.id == "finish" then
            for _, op in ipairs(extra) do stage.ops[#stage.ops + 1] = op end
            return out
        end
    end
    out[#out + 1] = { id = "finish", ops = extra }
    return out
end

local function register(kind)
    local def = Buildings2.definitions[kind]
    Bp.kinds[kind] = { w = def.w, h = def.h, priority = def.priority, build = function(project) return stages(project, kind) end }
    Bp.buildingKinds[kind] = true
    Bp.furniture[kind] = {}
    if ALifeCamp.Site ~= nil and type(ALifeCamp.Site.buildings) == "table" then ALifeCamp.Site.buildings[kind] = true end
end

for _, kind in ipairs(Buildings2.kinds) do register(kind) end

Buildings2.colors = {
    barracks = { 0.45, 0.62, 0.38 },
    powerhouse = { 0.98, 0.84, 0.2 },
}

if ALifeCamp.Districts ~= nil and type(ALifeCamp.Districts.colors) == "table" then
    for kind, color in pairs(Buildings2.colors) do
        ALifeCamp.Districts.colors[kind] = { r = color[1], g = color[2], b = color[3], color[1], color[2], color[3] }
    end
end

function Buildings2.built(camp, kind)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and project.status == "done" and not project.retired then return project end
    end
    return nil
end

function Buildings2.fueled(camp)
    local Stock = ALifeCamp.Stock
    if Stock == nil or type(Stock.kinds) ~= "table" then return true end
    for _, kind in ipairs(Stock.kinds) do
        if kind == "fuel" then
            local stock = type(camp.stock) == "table" and camp.stock or {}
            return (tonumber(stock.fuel) or 0) > 0
        end
    end
    return true
end

function Buildings2.powered(camp)
    return Buildings2.built(camp, "powerhouse") ~= nil and Buildings2.fueled(camp)
end

function Buildings2.displace(camp, kind, ax, ay)
    local buildings = ALifeCamp.Buildings
    if buildings == nil or type(buildings.displace) ~= "function" or type(buildings.definitions) ~= "table" then return nil end
    buildings.definitions[kind] = Buildings2.definitions[kind]
    return buildings.displace(camp, kind, ax, ay)
end

function Buildings2.generate(camp)
    if camp == nil then return 0 end
    if math.min(Geo.width(camp), Geo.height(camp)) < Buildings2.minSide then return 0 end
    local people = Store.settlerCount(camp)
    local cx, cy = Geo.center(camp)
    local added = 0
    local T = ALifeCamp.Tiers
    local function placeOne(kind, def)
        local ax, ay, radius = Plan.anchorFor(camp, kind, cx + def.dx, cy + def.dy, def.radius)
        local project = Plan.place(camp, kind, ax, ay, radius, { door = "S" })
        if project == nil then project = Buildings2.displace(camp, kind, ax, ay) end
        return project
    end
    for _, kind in ipairs(Buildings2.kinds) do
        local def = Buildings2.definitions[kind]
        local want = (T ~= nil and type(T.want) == "function") and T.want(camp, kind) or nil
        if want == nil then
            if people >= def.people and Plan.countKind(camp, kind) < 1 then
                if placeOne(kind, def) ~= nil then added = added + 1 end
            end
        else
            local guard = 0
            while Plan.countKind(camp, kind) < want and guard < want + 4 do
                guard = guard + 1
                if placeOne(kind, def) ~= nil then added = added + 1 else break end
            end
        end
    end
    return added
end

Hooks.add("morale", function(camp)
    local total = 0
    if Buildings2.built(camp, "barracks") ~= nil then total = total + Buildings2.barracksMorale end
    if Buildings2.powered(camp) then total = total + Buildings2.powerMorale end
    return total
end)

Hooks.add("defense", function(camp)
    if Buildings2.powered(camp) then return Buildings2.powerDefense end
    return 0
end)

return Buildings2
