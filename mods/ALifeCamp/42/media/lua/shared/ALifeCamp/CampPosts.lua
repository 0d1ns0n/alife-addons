require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampGates"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampDistricts"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Geo = ALifeCamp.Geo
local Gates = ALifeCamp.Gates
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan
local Districts = ALifeCamp.Districts

local Posts = {}
ALifeCamp.Posts = Posts

local Ground = {
    lane = { "blends_street_01_55", "blends_street_01_54", "blends_street_01_53", "blends_street_01_48" },
    apron = { "blends_street_01_32", "blends_street_01_37" },
    line = { "blends_street_01_16", "blends_street_01_21" },
    gravel = { "blends_natural_01_96", "blends_natural_01_101" },
}

local Prop = {
    barrier = { "fencing_01_96", "fencing_01_102", "fencing_01_103", "fencing_01_96" },
    hesco = { "fencing_01_96", "fencing_01_97", "fencing_01_100", "fencing_01_101", "fencing_01_102", "fencing_01_103" },
    jerseyAlongY = "street_decoration_01_29",
    jerseyAlongX = "street_decoration_01_28",
    boomBase = { N = 64, S = 64, E = 56, W = 56 },
    sandbagRow = "carpentry_02_13",
    sandbagColumn = "carpentry_02_12",
    cone = "street_decoration_01_26",
    stop = "street_decoration_01_0",
    lamp = "carpentry_02_61",
    brazier = "crafted_02_42",
    crate = { "location_military_generic_01_0", "location_military_generic_01_2", "location_military_generic_01_4", "location_military_generic_01_8" },
    barrel = { "location_military_generic_01_6", "location_military_generic_01_14" },
    tires = { "location_business_machinery_01_50", "location_business_machinery_01_51", "location_business_machinery_01_52" },
    target = { "location_military_generic_01_68", "location_military_generic_01_69" },
}

local Cost = {
    free = { e = "DirtFloor" },
    crate = { e = "Wood_Crate_Lvl1", parts = 4 },
    lamp = { e = "Wood_Shelves_Lvl1" },
    sandbag = { e = "SandbagWall" },
    fire = { e = "Campfire" },
    wire = { e = "BarbedWireFence" },
}

local nadoba = { N = "street_decoration_01_28", W = "street_decoration_01_29" }
local barbwire = { N = "fencing_01_21", W = "fencing_01_20" }
local outStart = { S = 2, E = 2, N = 1, W = 1 }

Posts.sprites = { ground = Ground, props = Prop }

Posts.apronRows = {
    "HHJ...JHH",
    "HHP...JHH",
    "KLJ...JLK",
    ".sJ...JH.",
    "n.J...J.n",
    ".t.....t.",
}

Posts.bayRows = {
    "c...Z",
    "....Z",
    "....Z",
    "....Z",
    "....Z",
    "...KZ",
    "...nZ",
    "LSSSS",
}

Posts.rangeRows = {
    "SSSSSSSSSS",
    ".T.T.T.T..",
    "..........",
    "..........",
    "S.S..n.S.S",
    "LKt....tKL",
}

Posts.poolRows = {
    "L..........L",
    "............",
    "............",
    "............",
    "............",
    "............",
    "............",
    "nt..cc..cc.K",
}

Posts.apronLeft, Posts.apronRight, Posts.apronDepth = -4, 4, 5
Posts.bayLeft, Posts.bayRight, Posts.bayDepth = 5, 9, 7
Posts.bayCenter = { 7, 3 }
Posts.houseLeft, Posts.houseRight, Posts.houseDepth = -10, -5, 4
Posts.towerLeft = { -13, 0, -12, 1 }
Posts.towerRight = { 11, 0, 12, 1 }
Posts.poolSize = { 12, 8 }
Posts.poolBays = 3
Posts.garageSize = { 8, 6 }

local knownSprites = {}

local function known(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function hash(x, y, salt)
    return (math.abs(x) * 73856093 + math.abs(y) * 19349663 + (salt or 0) * 83492791) % 2147483647
end

local function pick(list, x, y, salt)
    return list[hash(x, y, salt) % #list + 1]
end

local function sink()
    local self = { ops = {}, count = 0 }
    function self.ground(x, y, name)
        self.count = self.count + 1
        if known(name) then
            self.ops[#self.ops + 1] = { t = "dirt", sprite = name, x = x, y = y, z = 0, slot = "G" .. self.count }
        end
    end
    function self.prop(x, y, name, cost, container)
        self.count = self.count + 1
        if known(name) then
            self.ops[#self.ops + 1] = {
                t = "prop", e = cost.e, parts = cost.parts, sprite = name, x = x, y = y, z = 0, slot = "P" .. self.count,
                container = container,
            }
        end
    end
    return self
end

local function stages(pave, furnish)
    local out = { { id = "pave", ops = pave.ops } }
    if #furnish.ops > 0 then out[2] = { id = "furnish", ops = furnish.ops } end
    return out
end

local function across(side)
    if side == "N" or side == "S" then return Prop.sandbagRow end
    return Prop.sandbagColumn
end

local function along(side)
    if side == "N" or side == "S" then return Prop.sandbagColumn end
    return Prop.sandbagRow
end

local function jersey(side)
    if side == "N" or side == "S" then return Prop.jerseyAlongY end
    return Prop.jerseyAlongX
end

local function boom(side, step)
    return "street_decoration_01_" .. (Prop.boomBase[side] + step)
end

local function furnishToken(furnish, side, token, x, y)
    if token == "H" then
        furnish.prop(x, y, pick(Prop.hesco, x, y, 17), Cost.sandbag)
    elseif token == "J" then
        furnish.prop(x, y, jersey(side), Cost.free)
    elseif token == "P" then
        furnish.prop(x, y, boom(side, 0), Cost.free)
    elseif token == "1" or token == "2" or token == "3" then
        furnish.prop(x, y, boom(side, tonumber(token)), Cost.free)
    elseif token == "S" then
        furnish.prop(x, y, across(side), Cost.sandbag)
    elseif token == "Z" then
        furnish.prop(x, y, along(side), Cost.sandbag)
    elseif token == "B" then
        furnish.prop(x, y, pick(Prop.barrier, x, y, 3), Cost.sandbag)
    elseif token == "c" then
        furnish.prop(x, y, Prop.cone, Cost.free)
    elseif token == "s" then
        furnish.prop(x, y, Prop.stop, Cost.free)
    elseif token == "L" then
        furnish.prop(x, y, Prop.lamp, Cost.lamp)
    elseif token == "F" then
        furnish.prop(x, y, Prop.brazier, Cost.fire)
    elseif token == "K" then
        furnish.prop(x, y, pick(Prop.crate, x, y, 7), Cost.crate, "crate")
    elseif token == "n" then
        furnish.prop(x, y, pick(Prop.barrel, x, y, 9), Cost.crate)
    elseif token == "t" then
        furnish.prop(x, y, pick(Prop.tires, x, y, 11), Cost.free)
    elseif token == "T" then
        furnish.prop(x, y, pick(Prop.target, x, y, 13), Cost.free)
    end
end

local function tokenAt(rows, row, col)
    local line = rows[row]
    if line == nil then return "." end
    local token = string.sub(line, col, col)
    if token == "" then return "." end
    return token
end

local function faceOf(side)
    if side == "N" or side == "S" then return "N" end
    return "W"
end

function Posts.outFrame(side, gx, gy)
    local inFrame = Gates.frame(side, gx, gy)
    local ox, oy = Gates.at(inFrame, 0, -(outStart[side] or 2))
    return {
        side = side, x = ox, y = oy, out = inFrame.out, ["in"] = inFrame["in"],
        dx = -inFrame.dx, dy = -inFrame.dy, lx = inFrame.lx, ly = inFrame.ly,
        key = inFrame.key, laneDoor = inFrame.laneDoor,
    }
end

local function streetRow(out, pave, furnish)
    local face = faceOf(out.side)
    local v = Posts.apronDepth + 1
    for u = Posts.apronLeft, Posts.apronRight do
        local x, y = Gates.at(out, u, v)
        pave.ground(x, y, pick(math.abs(u) <= 1 and Ground.lane or Ground.apron, x, y, 7))
        if math.abs(u) > 1 then
            if (u - Posts.apronLeft) % 2 == 0 then
                furnish.prop(x, y, nadoba[face], Cost.sandbag)
            else
                furnish.prop(x, y, barbwire[face], Cost.wire)
            end
        end
    end
end

local function wings(out, pave, furnish)
    for v = 2, Posts.apronDepth + 1 do
        local step = math.floor((v - 2) / 2) + 1
        local lu, ru = Posts.apronLeft - step, Posts.apronRight + step
        local lx, ly = Gates.at(out, lu, v)
        local rx, ry = Gates.at(out, ru, v)
        pave.ground(lx, ly, pick(Ground.apron, lx, ly, 7))
        pave.ground(rx, ry, pick(Ground.apron, rx, ry, 7))
        furnish.prop(lx, ly, pick(Prop.hesco, lx, ly, 19), Cost.sandbag)
        furnish.prop(rx, ry, pick(Prop.hesco, rx, ry, 23), Cost.sandbag)
    end
end

local function postStages(project)
    local out = Posts.outFrame(project.gside, project.gx, project.gy)
    local pave, furnish = sink(), sink()
    for u = Posts.apronLeft, Posts.apronRight do
        for v = 0, Posts.apronDepth do
            local x, y = Gates.at(out, u, v)
            local lane = math.abs(u) <= 1
            pave.ground(x, y, pick(lane and Ground.lane or Ground.apron, x, y, 5))
            furnishToken(furnish, out.side, tokenAt(Posts.apronRows, v + 1, u - Posts.apronLeft + 1), x, y)
        end
    end
    for v = -2, -1 do
        for u = -1, 1 do
            local x, y = Gates.at(out, u, v)
            pave.ground(x, y, pick(Ground.lane, x, y, 5))
        end
    end
    streetRow(out, pave, furnish)
    wings(out, pave, furnish)
    return stages(pave, furnish)
end

local function bayStages(project)
    local frame = Gates.frame(project.gside, project.gx, project.gy)
    local pave, furnish = sink(), sink()
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local u, v = Gates.toLocal(frame, x, y)
            local edge = u == Posts.bayLeft or u == Posts.bayRight
            pave.ground(x, y, pick(edge and Ground.line or Ground.apron, x, y, 6))
            furnishToken(furnish, frame.side, tokenAt(Posts.bayRows, v + 1, u - Posts.bayLeft + 1), x, y)
        end
    end
    return stages(pave, furnish)
end

local function poolStages(project)
    local pave, furnish = sink(), sink()
    local bayWidth = math.floor(project.w / Posts.poolBays)
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local line = dx % bayWidth == 0 and dy >= 1 and dy <= project.h - 2
            local aisle = dy == 0 or dy == project.h - 1
            local list = line and Ground.line or (aisle and Ground.lane or Ground.apron)
            pave.ground(x, y, pick(list, x, y, 8))
            furnishToken(furnish, "N", tokenAt(Posts.poolRows, dy + 1, dx + 1), x, y)
        end
    end
    return stages(pave, furnish)
end

local function rangeStages(project)
    local pave, furnish = sink(), sink()
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            pave.ground(x, y, pick(Ground.gravel, x, y, 10))
            furnishToken(furnish, "N", tokenAt(Posts.rangeRows, dy + 1, dx + 1), x, y)
        end
    end
    return stages(pave, furnish)
end

Bp.furniture.guard = {
    { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 0, dy = 0, parts = 2 },
    { e = "Wood_Bed", sprites = { "carpentry_02_72", "carpentry_02_73" }, dx = 2, dy = 0, parts = 2 },
    { e = "Wood_TableLvl1", sprites = { "carpentry_01_24", "carpentry_01_25" }, dx = 0, dy = 2, parts = 2 },
    { e = "Wood_Chair_Lvl1", sprites = { "carpentry_01_36" }, dx = 2, dy = 2 },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_0" }, dx = 3, dy = 3, container = "crate" },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_2" }, dx = 4, dy = 3, container = "crate" },
    { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 4, dy = 0 },
}

Bp.furniture.garage = {
    { e = "Wood_TableLvl1", sprites = { "crafted_04_96", "crafted_04_97" }, dx = 0, dy = 0, parts = 2 },
    { e = "Wood_TableLvl1", sprites = { "crafted_04_96", "crafted_04_97" }, dx = 2, dy = 0, parts = 2 },
    { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 5, dy = 0 },
    { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 6, dy = 0 },
    { e = "Wood_Crate_Lvl2", sprites = { "location_business_machinery_01_32" }, dx = 7, dy = 0, container = "crate" },
    { e = "Wood_Crate_Lvl1", sprites = { "location_business_machinery_01_52" }, dx = 0, dy = 5 },
    { e = "Wood_Crate_Lvl1", sprites = { "location_business_machinery_01_51" }, dx = 1, dy = 5 },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_8" }, dx = 7, dy = 5, container = "crate" },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_10" }, dx = 7, dy = 4, container = "crate" },
}

Bp.furniture.vault = {
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_1" }, dx = 0, dy = 0, container = "crate", storage = true },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_3" }, dx = 1, dy = 0, container = "crate", storage = true },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_5" }, dx = 2, dy = 0, container = "crate", storage = true },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_9" }, dx = 3, dy = 0, container = "crate", storage = true },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_11" }, dx = 4, dy = 0, container = "crate", storage = true },
    { e = "Wood_Crate_Lvl2", sprites = { "location_military_generic_01_13" }, dx = 5, dy = 0, container = "crate", storage = true },
    { e = "Wood_Shelves_Lvl1", sprites = { "location_military_generic_01_22" }, dx = 0, dy = 3, container = "crate" },
    { e = "Wood_Shelves_Lvl1", sprites = { "location_military_generic_01_30" }, dx = 1, dy = 3, container = "crate" },
    { e = "Wood_Shelves_Lvl1", sprites = { "crafted_05_41" }, dx = 5, dy = 3 },
}

Bp.buildingKinds.vault = true
Bp.buildingKinds.guardhouse = true
Bp.buildingKinds.garage = true

Bp.kinds.post = { w = 9, h = 6, priority = 3.3, build = postStages }
Bp.kinds.guardhouse = { w = 5, h = 4, priority = 3.6, build = function(project) return Bp.building(project, "guard") end }
Bp.kinds.bay = { w = 5, h = 8, priority = 3.7, build = bayStages }
Bp.kinds.garage = { w = 8, h = 6, priority = 5.5, build = function(project) return Bp.building(project, "garage") end }
Bp.kinds.motorpool = { w = 12, h = 8, priority = 5.6, build = poolStages }
Bp.kinds.range = { w = 10, h = 6, priority = 6.5, build = rangeStages }
Bp.kinds.vault = { w = 6, h = 4, priority = 2.5, build = function(project) return Bp.building(project, "vault") end }

Posts.kinds = { "post", "guardhouse", "bay", "garage", "motorpool", "range", "vault" }

local kindSet = {}
for _, kind in ipairs(Posts.kinds) do kindSet[kind] = true end

function Posts.isPostKind(kind)
    return kindSet[kind] == true
end

Posts.colors = {
    post = { 0.58, 0.68, 0.86 },
    guardhouse = { 0.86, 0.7, 0.4 },
    bay = { 0.48, 0.62, 0.5 },
    garage = { 0.78, 0.5, 0.28 },
    motorpool = { 0.56, 0.58, 0.64 },
    range = { 0.7, 0.4, 0.4 },
    vault = { 0.45, 0.5, 0.35 },
}

if Districts ~= nil then
    for kind, color in pairs(Posts.colors) do
        Districts.colors[kind] = { r = color[1], g = color[2], b = color[3], color[1], color[2], color[3] }
    end
    Districts.districtOf = Districts.districtOf or {}
    Districts.districtOf.post = "posts"
    Districts.districtOf.guardhouse = "posts"
    Districts.districtOf.bay = "posts"
    Districts.districtOf.garage = "depot"
    Districts.districtOf.motorpool = "depot"
    Districts.districtOf.range = "training"
    Districts.districtOf.vault = "depot"
    Districts.order[#Districts.order + 1] = "posts"
    Districts.order[#Districts.order + 1] = "depot"
    Districts.order[#Districts.order + 1] = "training"
end

function Posts.tier(camp)
    local smallest = math.min(Geo.width(camp), Geo.height(camp))
    if smallest >= 40 then return 2 end
    if smallest >= 20 then return 1 end
    return 0
end

local function fenceOf(camp)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and not project.retired then return project end
    end
    return nil
end

local function hasPart(camp, gkey, part)
    for _, project in pairs(Build.plan(camp).items) do
        if project.gkey == gkey and project.part == part and not project.retired then return project end
    end
    return nil
end

local function addAt(camp, geo, spec)
    if hasPart(camp, geo.key, spec.part) ~= nil then return 0 end
    local x, y, w, h = Gates.rect(geo, spec.u1, spec.v1, spec.u2, spec.v2)
    local options = { w = w, h = h, door = spec.door }
    if spec.building then options.w, options.h = w - 1, h - 1 end
    if spec.fixed then options.w, options.h = nil, nil end
    local project = Build.add(camp, spec.kind, x, y, options)
    if project == nil then return 0 end
    project.gside, project.gx, project.gy, project.gkey, project.part = geo.side, geo.x, geo.y, geo.key, spec.part
    return 1
end

function Posts.specs(geo, tier)
    local list = {
        { kind = "post", part = "post", u1 = Posts.apronLeft, v1 = 0, u2 = Posts.apronRight, v2 = Posts.apronDepth },
    }
    if tier >= 2 then
        list[#list + 1] = {
            kind = "guardhouse", part = "guard", building = true, door = geo.laneDoor,
            u1 = Posts.houseLeft, v1 = 0, u2 = Posts.houseRight, v2 = Posts.houseDepth,
        }
        list[#list + 1] = { kind = "bay", part = "bay", u1 = Posts.bayLeft, v1 = 0, u2 = Posts.bayRight, v2 = Posts.bayDepth }
        local l, r = Posts.towerLeft, Posts.towerRight
        list[#list + 1] = { kind = "tower", part = "towerL", fixed = true, u1 = l[1], v1 = l[2], u2 = l[3], v2 = l[4] }
        list[#list + 1] = { kind = "tower", part = "towerR", fixed = true, u1 = r[1], v1 = r[2], u2 = r[3], v2 = r[4] }
    else
        list[#list + 1] = { kind = "tower", part = "towerL", fixed = true, u1 = -7, v1 = 0, u2 = -6, v2 = 1 }
        list[#list + 1] = { kind = "tower", part = "towerR", fixed = true, u1 = 6, v1 = 0, u2 = 7, v2 = 1 }
    end
    return list
end

local function placeNear(camp, kind, geo, u, v, radius, extra)
    local ax, ay = Gates.at(geo, u, v)
    local project = Plan.place(camp, kind, ax - math.floor(Bp.kinds[kind].w / 2), ay - math.floor(Bp.kinds[kind].h / 2), radius, extra)
    if project ~= nil then
        project.gside, project.gx, project.gy, project.gkey = geo.side, geo.x, geo.y, geo.key
    end
    return project
end

function Posts.depot(camp, tier)
    if tier < 2 then return 0 end
    local gates = Gates.list(camp)
    if #gates == 0 then return 0 end
    local area = Geo.width(camp) * Geo.height(camp)
    local wantPools = math.max(1, math.min(3, math.floor(area / 20000) + 1))
    local wantGarages = math.max(1, math.min(2, math.floor(area / 30000) + 1))
    local pools, garages = Plan.countKind(camp, "motorpool"), Plan.countKind(camp, "garage")
    local added = 0
    for _, geo in ipairs(gates) do
        if pools < wantPools and hasPart(camp, geo.key, "pool") == nil then
            local project = placeNear(camp, "motorpool", geo, 10, 13, 8)
            if project ~= nil then
                project.part = "pool"
                pools = pools + 1
                added = added + 1
            end
        end
        if garages < wantGarages and hasPart(camp, geo.key, "garage") == nil then
            local project = placeNear(camp, "garage", geo, -9, 13, 8)
            if project ~= nil then
                project.part = "garage"
                garages = garages + 1
                added = added + 1
            end
        end
    end
    return added
end

function Posts.range(camp)
    local area = Geo.width(camp) * Geo.height(camp)
    if area < 1500 then return 0 end
    local T = ALifeCamp.Tiers
    local want
    if T ~= nil and type(T.want) == "function" and T.on(camp) then want = T.want(camp, "range") or 0
    else want = area >= 12000 and 2 or 1 end
    local have = Plan.countKind(camp, "range")
    local cx, cy = Geo.center(camp)
    local added = 0
    local spots = { { cx + 12, cy - 12 }, { cx - 22, cy + 10 } }
    while have < want do
        local spot = spots[have + 1]
        local ax, ay, radius = Plan.anchorFor(camp, "range", spot[1], spot[2], 14)
        if Plan.place(camp, "range", ax, ay, radius) == nil then break end
        have = have + 1
        added = added + 1
    end
    return added
end

function Posts.vaults(camp)
    local area = Geo.width(camp) * Geo.height(camp)
    if area < 3000 then return 0 end
    local T = ALifeCamp.Tiers
    local want
    if T ~= nil and type(T.want) == "function" and T.on(camp) then want = T.want(camp, "vault") or 0
    else want = math.max(1, math.min(4, math.floor(area / 8000))) end
    local have = Plan.countKind(camp, "vault")
    local cx, cy = Geo.center(camp)
    local spots = { { cx - 12, cy + 8 }, { cx + 14, cy + 10 }, { cx - 14, cy - 12 }, { cx + 6, cy - 16 } }
    local added = 0
    while have < want do
        local spot = spots[have + 1]
        local ax, ay, radius = Plan.anchorFor(camp, "vault", spot[1], spot[2], 14)
        if Plan.place(camp, "vault", ax, ay, radius, { level = 2 }) == nil then break end
        have = have + 1
        added = added + 1
    end
    return added
end

function Posts.generate(camp)
    local fence = fenceOf(camp)
    if fence == nil then return 0 end
    Gates.upgrade(fence)
    local tier = Posts.tier(camp)
    if tier == 0 then return 0 end
    local T = ALifeCamp.Tiers
    local tierOn = T ~= nil and type(T.want) == "function" and T.on(camp)
    local added = 0
    for _, geo in ipairs(Gates.list(camp)) do
        for _, spec in ipairs(Posts.specs(geo, tier)) do
            if not (tierOn and spec.kind == "tower") then
                added = added + addAt(camp, geo, spec)
            end
        end
    end
    added = added + Posts.depot(camp, tier)
    added = added + Posts.range(camp)
    added = added + Posts.vaults(camp)
    return added
end

function Posts.projects(camp, kind)
    local out = {}
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and not project.retired then out[#out + 1] = project end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Posts.bays(camp)
    local out = {}
    for _, project in ipairs(Posts.projects(camp, "bay")) do
        if project.status == "done" and project.gside ~= nil then
            local frame = Gates.frame(project.gside, project.gx, project.gy)
            local x, y = Gates.at(frame, Posts.bayCenter[1], Posts.bayCenter[2])
            out[#out + 1] = {
                key = "bay:" .. project.id, x = x, y = y, z = camp.z or 0, dir = frame.out, kind = "post",
                gate = project.gkey, project = project.id,
            }
        end
    end
    for _, project in ipairs(Posts.projects(camp, "motorpool")) do
        if project.status == "done" then
            local bayWidth = math.floor(project.w / Posts.poolBays)
            for k = 0, Posts.poolBays - 1 do
                out[#out + 1] = {
                    key = "pool:" .. project.id .. ":" .. k, x = project.x + math.floor(bayWidth / 2) + bayWidth * k,
                    y = project.y + math.floor(project.h / 2) - 1, z = camp.z or 0, dir = "N", kind = "pool", project = project.id,
                }
            end
        end
    end
    return out
end

function Posts.guardPoints(camp)
    local out = {}
    for _, project in ipairs(Posts.projects(camp, "post")) do
        if project.status == "done" and project.gside ~= nil then
            local frame = Posts.outFrame(project.gside, project.gx, project.gy)
            for _, sign in ipairs({ -1, 1 }) do
                local x, y = Gates.at(frame, sign * 3, 3)
                out[#out + 1] = { x = x, y = y, z = camp.z or 0 }
            end
        end
    end
    return out
end

function Posts.garageDone(camp)
    for _, project in ipairs(Posts.projects(camp, "garage")) do
        if project.status == "done" then return project end
    end
    return nil
end

function Posts.gateSites(camp)
    local out = {}
    local built = {}
    for _, project in ipairs(Posts.projects(camp, "post")) do
        if project.status == "done" then built[project.gkey] = true end
    end
    for _, geo in ipairs(Gates.list(camp)) do
        local frame = Posts.outFrame(geo.side, geo.x, geo.y)
        local x, y = Gates.at(frame, 0, 3)
        out[#out + 1] = { x = x, y = y, z = camp.z or 0, key = geo.key, main = geo.main, post = built[geo.key] == true }
    end
    return out
end

function Posts.innerEnd(camp, geo)
    local post = hasPart(camp, geo.key, "post")
    if post == nil then return nil end
    local x, y = Gates.at(geo, 0, Posts.apronDepth + 1)
    return { x = x, y = y }
end

function Posts.summary(camp)
    local out = { gates = #Gates.list(camp), posts = 0, postsPlanned = 0, bays = 0, vehicles = 0, armored = 0, garage = false, pools = 0 }
    for _, project in ipairs(Posts.projects(camp, "post")) do
        out.postsPlanned = out.postsPlanned + 1
        if project.status == "done" then out.posts = out.posts + 1 end
    end
    out.bays = #Posts.bays(camp)
    out.garage = Posts.garageDone(camp) ~= nil
    for _, project in ipairs(Posts.projects(camp, "motorpool")) do
        if project.status == "done" then out.pools = out.pools + 1 end
    end
    local motor = camp.motor
    if type(motor) == "table" and type(motor.parked) == "table" then
        for _, entry in pairs(motor.parked) do
            out.vehicles = out.vehicles + 1
            if entry.military then out.armored = out.armored + 1 end
        end
    end
    return out
end

local clearIndex = {}
local lastHour = {}

local function outsideRect(project)
    local out = Posts.outFrame(project.gside, project.gx, project.gy)
    local x, y, w, h = Gates.rect(out, Posts.apronLeft - 1, 0, Posts.apronRight + 1, Posts.apronDepth + 1)
    return { x1 = x, y1 = y, x2 = x + w - 1, y2 = y + h - 1, z = project.camp and (project.z or 0) or 0 }
end

if Hooks ~= nil then
    Hooks.add("overview", function(camp)
        local posts = Posts.projects(camp, "post")
        if #posts == 0 then return {} end
        local done = 0
        for _, project in ipairs(posts) do
            if project.status == "done" then done = done + 1 end
        end
        return { Hooks.line(ALifeCamp.T("Checkpoint_overview", tostring(done), tostring(#posts)), 0.58, 0.68, 0.86) }
    end, 12)
    Hooks.add("minute", function(camp)
        if camp.raid ~= nil then return end
        local posts = Posts.projects(camp, "post")
        local n = #posts
        if n > 0 and ALifeCamp.Clear ~= nil then
            local i = (clearIndex[camp.id] or 0) % n
            clearIndex[camp.id] = i + 1
            local project = posts[i + 1]
            if project.gside ~= nil and project.status ~= "done" then
                pcall(function() ALifeCamp.Clear.prepare(camp, outsideRect(project), 24) end)
            end
        end
        if Store ~= nil then
            local hour = math.floor(Store.hours())
            if lastHour[camp.id] ~= hour then
                lastHour[camp.id] = hour
                local done = 0
                for _, project in ipairs(posts) do
                    if project.status == "done" then done = done + 1 end
                end
                print("[ALifeCamp:Checkpoint] gates=" .. #Gates.list(camp) .. " posts=" .. n .. " done=" .. done .. " outward=1")
            end
        end
    end, 74)
end

return Posts
