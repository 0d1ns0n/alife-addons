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

local Buildings = {}
ALifeCamp.Buildings = Buildings

Buildings.minSide = 24
Buildings.forgeRecycle = 1.15

Entities.CampFurnLight = { id = "CampFurnLight", category = "furniture", faces = { S = { { "carpentry_01_36" } } }, time = 50,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 1, t = { "Base.Nails" } } } }
Entities.CampFurnHeavy = { id = "CampFurnHeavy", category = "furniture", faces = { S = { { "carpentry_01_19" } } }, time = 50,
    inputs = { { n = 2, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } } } }
Entities.CampFurnBed = { id = "CampFurnBed", category = "furniture", faces = { S = { { "carpentry_02_72" } } }, time = 50,
    inputs = { { n = 2, t = { "Base.Plank" } }, { n = 1, t = { "Base.Nails" } } } }
Entities.CampFurnIron = { id = "CampFurnIron", category = "furniture", faces = { S = { { "crafted_01_16" } } }, time = 50,
    inputs = { { n = 1, t = { "Base.Plank" } }, { n = 2, t = { "Base.Nails" } }, { n = 1, t = { "Base.ScrapMetal" } } } }

local LIGHT, HEAVY, BED, IRON = "CampFurnLight", "CampFurnHeavy", "CampFurnBed", "CampFurnIron"

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
    function self.list()
        return list
    end
    return self
end

local function canteenLayout()
    local l = layout()
    l.put(0, 0, "appliances_refrigeration_01_8", IRON)
    l.put(1, 0, "carpentry_02_29", HEAVY)
    l.put(2, 0, "fixtures_sinks_01_33", HEAVY)
    l.put(3, 0, "carpentry_02_29", HEAVY)
    l.put(4, 0, "appliances_cooking_01_17", IRON)
    l.put(5, 0, "carpentry_02_29", HEAVY)
    l.row(6, 0, HEAVY, { "furniture_storage_02_34", "furniture_storage_02_35" })
    l.put(8, 0, "appliances_refrigeration_01_12", IRON)
    l.row(1, 2, LIGHT, { "furniture_seating_indoor_02_5", "furniture_seating_indoor_02_5" })
    l.row(4, 2, LIGHT, { "furniture_seating_indoor_02_60", "furniture_seating_indoor_02_61" })
    l.row(7, 2, LIGHT, { "furniture_seating_indoor_02_5", "furniture_seating_indoor_02_5" })
    l.row(1, 3, LIGHT, { "carpentry_01_32", "carpentry_01_33" })
    l.row(4, 3, LIGHT, { "furniture_tables_high_02_8", "furniture_tables_high_02_9", "furniture_tables_high_02_10" })
    l.row(7, 3, LIGHT, { "carpentry_01_32", "carpentry_01_33" })
    for _, dx in ipairs({ 1, 2, 4, 5, 6, 7, 8 }) do l.put(dx, 4, "furniture_seating_indoor_02_7", LIGHT) end
    return l.list()
end

local function infirmaryLayout()
    local l = layout()
    l.put(0, 0, "location_community_medical_01_88", LIGHT)
    l.row(1, 0, HEAVY, { "location_community_medical_01_154", "location_community_medical_01_155" })
    l.row(3, 0, LIGHT, { "location_community_medical_01_80", "location_community_medical_01_81" })
    l.put(4, 0, "fixtures_counters_01_37", HEAVY)
    l.put(5, 0, "fixtures_sinks_01_33", HEAVY)
    l.put(7, 0, "location_community_medical_01_102", HEAVY)
    for _, dx in ipairs({ 1, 4 }) do
        l.column(dx, 1, BED, { "furniture_bedding_01_65", "furniture_bedding_01_64" })
    end
    l.column(7, 1, BED, { "location_community_medical_01_17", "location_community_medical_01_16" })
    for _, dx in ipairs({ 3, 6 }) do
        l.column(dx, 1, LIGHT, { "location_community_medical_01_44", "location_community_medical_01_45",
            "location_community_medical_01_47", "location_community_medical_01_46" })
    end
    l.put(2, 3, "location_community_medical_01_25", LIGHT)
    l.put(5, 3, "location_community_medical_01_25", LIGHT)
    l.row(4, 4, LIGHT, { "furniture_tables_high_01_34", "furniture_tables_high_01_35" })
    l.row(0, 5, LIGHT, { "location_community_medical_01_58", "location_community_medical_01_59" })
    return l.list()
end

local function forgeLayout()
    local l = layout()
    l.row(0, 0, IRON, { "location_business_machinery_01_32", "location_business_machinery_01_32" })
    l.row(3, 0, HEAVY, { "location_business_machinery_01_16", "location_business_machinery_01_17" })
    l.row(3, 0, LIGHT, { "location_business_machinery_01_24", "location_business_machinery_01_25" })
    l.row(5, 0, HEAVY, { "crafted_02_0", "crafted_02_1" })
    l.row(5, 0, LIGHT, { "location_business_machinery_01_24", "location_business_machinery_01_25" })
    l.row(7, 0, IRON, { "crafted_01_16", "crafted_01_17" })
    l.put(1, 2, "crafted_01_18", IRON)
    l.put(2, 2, "crafted_02_52", IRON)
    l.put(8, 2, "crafted_01_24", LIGHT)
    l.put(3, 3, "crafted_01_38", LIGHT)
    l.put(5, 3, "carpentry_01_16", HEAVY, "crate")
    l.put(7, 3, "industry_04_20", IRON)
    l.put(8, 3, "crafted_01_26", LIGHT)
    l.put(0, 4, "crafted_01_72", HEAVY)
    l.put(6, 4, "carpentry_01_19", HEAVY, "crate")
    l.put(8, 5, "location_business_machinery_01_44", LIGHT)
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

Buildings.definitions = {
    canteen = { w = 9, h = 6, priority = 4.5, people = 5, dx = 3, dy = -3, radius = 9, furniture = canteenLayout() },
    infirmary = { w = 9, h = 6, priority = 4.6, people = 6, dx = -5, dy = -10, radius = 9, furniture = infirmaryLayout() },
    forge = { w = 9, h = 6, priority = 5.2, people = 8, dx = 3, dy = 5, radius = 10, furniture = forgeLayout() },
}

Buildings.kinds = { "canteen", "infirmary", "forge" }

function Buildings.furnitureOps(project, kind)
    local def = Buildings.definitions[kind]
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
    local extra = Buildings.furnitureOps(project, kind)
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
    local def = Buildings.definitions[kind]
    Bp.kinds[kind] = { w = def.w, h = def.h, priority = def.priority, build = function(project) return stages(project, kind) end }
    Bp.buildingKinds[kind] = true
    Bp.furniture[kind] = {}
    if ALifeCamp.Site ~= nil and type(ALifeCamp.Site.buildings) == "table" then ALifeCamp.Site.buildings[kind] = true end
end

for _, kind in ipairs(Buildings.kinds) do register(kind) end

Buildings.colors = {
    canteen = { 0.95, 0.72, 0.3 },
    infirmary = { 0.5, 0.82, 0.95 },
    forge = { 0.78, 0.4, 0.28 },
}

if ALifeCamp.Districts ~= nil and type(ALifeCamp.Districts.colors) == "table" then
    for kind, color in pairs(Buildings.colors) do
        ALifeCamp.Districts.colors[kind] = { r = color[1], g = color[2], b = color[3], color[1], color[2], color[3] }
    end
end

function Buildings.built(camp, kind)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and project.status == "done" and not project.retired then return project end
    end
    return nil
end

Buildings.loose = { house_s = 3, house_m = 3, house_l = 3, market = 1, workyard = 1, well = 1, garden = 1, memorial = 1, path = 1, lamp = 1, plaza = 1 }
Buildings.displaceRadius = 14
Buildings.displaceBudget = 14

local function untouched(project)
    return Buildings.loose[project.kind] ~= nil and project.status == "planned" and project.stage == 1 and not project.paid
        and not project.prepared and not project.retired and project.gkey == nil
end

local function displaceScore(camp, kind, def, x, y)
    local rect = Bp.footprint({ kind = kind, x = x, y = y, w = def.w, h = def.h })
    if rect.x1 < camp.x1 or rect.y1 < camp.y1 or rect.x2 > camp.x2 or rect.y2 > camp.y2 then return nil end
    local score, victims = 0, {}
    for _, other in pairs(Build.plan(camp).items) do
        if other.kind ~= "fence" and not other.retired and Build.overlaps(rect, Bp.footprint(other)) then
            if not untouched(other) then return nil end
            score = score + Buildings.loose[other.kind]
            victims[#victims + 1] = other.id
        end
    end
    return score, victims, rect
end

local function clearGround(camp, rect)
    local adopt = ALifeCamp.Adopt
    if adopt ~= nil and adopt.overlaps(camp, rect) ~= nil then return false end
    for px = rect.x1, rect.x2 do
        for py = rect.y1, rect.y2 do
            if ALifeCamp.World.square(px, py, camp.z) ~= nil and ALifeCamp.Place.blocked(px, py, camp.z) then return false end
        end
    end
    return true
end

function Buildings.displace(camp, kind, ax, ay)
    local def = Buildings.definitions[kind]
    local spots = {}
    local reach = Buildings.displaceRadius
    for dx = -reach, reach do
        for dy = -reach, reach do
            local score, victims = displaceScore(camp, kind, def, ax + dx, ay + dy)
            if score ~= nil and score <= Buildings.displaceBudget then
                spots[#spots + 1] = { x = ax + dx, y = ay + dy, score = score + (dx * dx + dy * dy) / 1000, victims = victims }
            end
        end
    end
    table.sort(spots, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    for index = 1, math.min(#spots, 12) do
        local spot = spots[index]
        local rect = Bp.footprint({ kind = kind, x = spot.x, y = spot.y, w = def.w, h = def.h })
        if clearGround(camp, rect) then
            for _, id in ipairs(spot.victims) do Build.remove(camp, id) end
            local project = Build.add(camp, kind, spot.x, spot.y, { door = "S" })
            if project ~= nil then return project end
        end
    end
    return nil
end

function Buildings.generate(camp)
    if camp == nil then return 0 end
    if math.min(Geo.width(camp), Geo.height(camp)) < Buildings.minSide then return 0 end
    local people = Store.settlerCount(camp)
    local cx, cy = Geo.center(camp)
    local added = 0
    local T = ALifeCamp.Tiers
    local function placeOne(kind, def)
        local ax, ay, radius = Plan.anchorFor(camp, kind, cx + def.dx, cy + def.dy, def.radius)
        local project = Plan.place(camp, kind, ax, ay, radius, { door = "S" })
        if project == nil then project = Buildings.displace(camp, kind, ax, ay) end
        return project
    end
    for _, kind in ipairs(Buildings.kinds) do
        local def = Buildings.definitions[kind]
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

Hooks.add("recycle", function(camp)
    if Buildings.built(camp, "forge") ~= nil then return Buildings.forgeRecycle end
    return 1
end)

return Buildings
