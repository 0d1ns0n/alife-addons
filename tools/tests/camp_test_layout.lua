dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Camp, Build, Plan, Bp, Houses, Geo = A.Camp, A.Build, A.Plan, A.Blueprints, A.Houses, A.Geo

check("plan module", Plan ~= nil)
check("driveway kind", Bp.kinds.driveway ~= nil and type(Bp.kinds.driveway.build) == "function")

for x = 40, 170 do for y = 40, 170 do NEWSQUARE(x, y, 0) end end
for x = 40, 170 do for y = 40, 170 do NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 400

local anchors = Plan.houseAnchors({ x1 = 50, y1 = 50, x2 = 110, y2 = 110, z = 0 }, 60)
check("anchors produced", #anchors >= 8, #anchors)
local byRow = {}
for _, a in ipairs(anchors) do byRow[a[2]] = (byRow[a[2]] or 0) + 1 end
local rows, widest = 0, 0
for _, n in pairs(byRow) do rows = rows + 1 if n > widest then widest = n end end
check("anchors form rows", rows >= 2 and widest >= 2, rows .. "/" .. widest)
local sortedY = {}
for y in pairs(byRow) do sortedY[#sortedY + 1] = y end
table.sort(sortedY)
local evenPitch = true
for i = 2, #sortedY do if sortedY[i] - sortedY[i - 1] ~= (sortedY[2] - sortedY[1]) then evenPitch = false end end
check("rows evenly spaced", evenPitch and #sortedY >= 2, #sortedY)
local avoidsAvenue = true
local gx = 50 + math.floor(61 / 2)
for _, a in ipairs(anchors) do
    local g = Plan.gridSpec({ x1 = 50, y1 = 50, x2 = 110, y2 = 110, z = 0 })
    if a[1] <= gx + 2 and a[1] + g.hw - 1 >= gx - 2 then avoidsAvenue = false end
end
check("anchors clear of avenue", avoidsAvenue)

local camp = Camp.create({ x1 = 50, y1 = 50, x2 = 110, y2 = 110, z = 0 }, "Grid")
camp.options.recruit = false
camp.phase = "plan"
local added = Plan.generate(camp)
check("generate added projects", added >= 8, added)

local list = Build.list(camp)
local kinds = {}
for _, p in ipairs(list) do kinds[p.kind] = (kinds[p.kind] or 0) + 1 end
check("houses placed", (kinds.house_s or 0) + (kinds.house_m or 0) + (kinds.house_l or 0) >= 4, kinds.house_s)
check("grid lanes laid", (kinds.path or 0) >= 3, kinds.path)

local gridLanes, houseDoorsSouth, totalHouses = 0, 0, 0
for _, p in ipairs(list) do
    if p.kind == "path" and p.grid then gridLanes = gridLanes + 1 end
    if p.kind == "house_s" or p.kind == "house_m" or p.kind == "house_l" then
        totalHouses = totalHouses + 1
        if p.door == "S" then houseDoorsSouth = houseDoorsSouth + 1 end
    end
end
check("grid lanes present", gridLanes >= 2, gridLanes)
check("house doors face the street", houseDoorsSouth == totalHouses and totalHouses > 0, houseDoorsSouth .. "/" .. totalHouses)

local clash = false
for i = 1, #list do
    for j = i + 1, #list do
        if list[i].kind ~= "fence" and list[j].kind ~= "fence" and Build.overlaps(Bp.footprint(list[i]), Bp.footprint(list[j])) then clash = true end
    end
    if list[i].kind ~= "fence" then
        local r = Bp.footprint(list[i])
        if r.x1 < camp.x1 or r.y1 < camp.y1 or r.x2 > camp.x2 or r.y2 > camp.y2 then clash = true end
    end
end
check("no overlaps and inside", not clash)

check("streets idempotent", Plan.streets(camp) == 0)
Plan.generate(camp)
Plan.generate(camp)
check("generate converges", Plan.generate(camp) == 0)

local function noFunctions(t, depth)
    if depth > 7 then return false end
    for _, v in pairs(t) do
        if type(v) == "function" or type(v) == "userdata" then return false end
        if type(v) == "table" and not noFunctions(v, depth + 1) then return false end
    end
    return true
end
check("plan serializable", noFunctions(Build.plan(camp), 0))

local dcamp = Camp.create({ x1 = 50, y1 = 115, x2 = 85, y2 = 140, z = 0 }, "Drive")
dcamp.phase = "plan"
local house = Build.add(dcamp, "house_l", 55, 118, { door = "S" })
house.id = 2
house.palette = Houses.pick({ id = 0 })
check("lshape chosen", select(2, Houses.designFor({ id = 0 }, "house_l")) == "lshape")
local made = Plan.driveway(dcamp, { kind = "house_l", id = 0, x = 55, y = 118, w = 8, h = 6 })
check("driveway placed for garage house", made == 1, made)
local foundDrive, concrete = false, false
for _, p in ipairs(Build.list(dcamp)) do
    if p.kind == "driveway" then
        foundDrive = true
        for _, stage in ipairs(Bp.stages(p)) do
            for _, op in ipairs(stage.ops) do
                if op.sprite == "floors_exterior_street_01_0" then concrete = true end
            end
        end
    end
end
check("driveway is concrete", foundDrive and concrete)

local small = Camp.create({ x1 = 120, y1 = 120, x2 = 151, y2 = 145, z = 0 }, "Small")
small.options.recruit = false
small.phase = "plan"
Plan.generate(small)
local smallHouses = 0
for _, p in ipairs(Build.list(small)) do
    if p.kind == "house_s" or p.kind == "house_m" or p.kind == "house_l" then smallHouses = smallHouses + 1 end
end
check("small camp still gets houses", smallHouses >= 1, smallHouses)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
