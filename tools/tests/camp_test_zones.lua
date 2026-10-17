dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Life", "Progress", "Council", "Fortress", "Shells", "Towers", "Perimeter" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Build, Bp, Plan, Settlers, Zones, Geo = A.Store, A.Camp, A.Build, A.Blueprints, A.Plan, A.Settlers, A.Zones, A.Geo
local reg = MOCKALIFE()

check("zones module", Zones ~= nil and type(Zones.anchorFor) == "function")
check("plan anchorFor", type(Plan.anchorFor) == "function")
check("plan detectGateSide", type(Plan.detectGateSide) == "function")

for x = 40, 170 do for y = 40, 170 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 600

local function settle(camp, count)
    local have = Store.settlerCount(camp)
    for i = have + 1, count do
        local uid = "z" .. i
        ADDACTOR(reg, uid, "friendly", camp.x1 + 2 + i, camp.y1 + 2, A.World.square(camp.x1 + 2 + i, camp.y1 + 2, 0))
        Settlers.settle(camp, uid, uid)
    end
end

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 139, y2 = 139, z = 0 }, "Zoned")
camp.options.recruit = false
camp.phase = "plan"
settle(camp, 14)
for _ = 1, 4 do Plan.generate(camp) end

local cx, cy = Geo.center(camp)
check("gate defaults south without roads", Zones.frontSide(camp) == "S")
check("no road: detect nil", Plan.detectGateSide(camp) == nil)

local function first(kind)
    for _, p in pairs(Build.plan(camp).items) do
        if p.kind == kind and not p.retired then return p end
    end
    return nil
end
local function cxy(p) return p.x + p.w / 2, p.y + p.h / 2 end

local placed = {}
for _, kind in ipairs({ "canteen", "infirmary", "forge", "powerhouse", "barracks", "greenhouse", "farm" }) do
    placed[kind] = first(kind)
    check("zoned building placed: " .. kind, placed[kind] ~= nil)
end

if placed.forge then
    local fx, fy = cxy(placed.forge)
    check("forge in industry corner (back-left)", fx < cx and fy < cy + 8, math.floor(fx) .. "," .. math.floor(fy) .. " c " .. cx .. "," .. cy)
end
if placed.powerhouse then
    local px, py = cxy(placed.powerhouse)
    check("powerhouse in industry corner", px < cx + 4 and py < cy, math.floor(px) .. "," .. math.floor(py))
end
if placed.greenhouse then
    local gx, gy = cxy(placed.greenhouse)
    check("greenhouse in agriculture corner (back-right)", gx > cx and gy < cy + 8, math.floor(gx) .. "," .. math.floor(gy))
end
if placed.farm then
    local ax, ay = cxy(placed.farm)
    check("farm on agriculture side (right/back)", ax > cx - 4, math.floor(ax) .. "," .. math.floor(ay))
end
if placed.barracks then
    local bx = select(1, cxy(placed.barracks))
    check("barracks on residential flank (right)", bx > cx, math.floor(bx))
end
if placed.canteen and placed.infirmary then
    local qx = select(1, cxy(placed.canteen))
    local ix = select(1, cxy(placed.infirmary))
    local _, qy = cxy(placed.canteen)
    check("civic pair central", math.abs(qy - cy) <= Geo.height(camp) * 0.3, math.floor(qy) .. " c " .. cy)
    check("civic pair split left/right", qx <= ix + 2, math.floor(qx) .. "/" .. math.floor(ix))
end

local function disjoint()
    local list = {}
    for _, p in pairs(Build.plan(camp).items) do if p.kind ~= "fence" then list[#list + 1] = Bp.footprint(p) end end
    for i = 1, #list do for j = i + 1, #list do if Build.overlaps(list[i], list[j]) then return false end end end
    return true
end
check("zoned plan no overlaps", disjoint())
check("zoned generate converges", Plan.generate(camp) == 0)

local function pure(value, depth)
    if depth > 8 then return false end
    local kind = type(value)
    if kind == "function" or kind == "userdata" then return false end
    if kind ~= "table" then return true end
    for _, item in pairs(value) do if not pure(item, depth + 1) then return false end end
    return true
end
check("zoned plan serializable", pure(Build.plan(camp), 0))

local road = Camp.create({ x1 = 60, y1 = 150, x2 = 95, y2 = 169, z = 0 }, "RoadCamp")
for y = road.y1, road.y2 do
    local sq = A.World.square(road.x1, y, 0)
    if sq ~= nil then sq:addFloor("floors_exterior_street_01_0") end
end
local side, index = Plan.detectGateSide(road)
check("road detected on west edge", side == "W", tostring(side))
check("road index within side", type(index) == "number" and index >= 0, tostring(index))

local anchorX, anchorY, anchorR = Zones.anchorFor(camp, "forge", cx, cy, 10)
check("anchorFor returns radius", type(anchorX) == "number" and type(anchorR) == "number" and anchorR >= 8)
check("anchorFor unknown kind nil", Zones.anchorFor(camp, "house_s", cx, cy, 9) == nil)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
