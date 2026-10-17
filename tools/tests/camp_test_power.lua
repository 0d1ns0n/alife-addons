dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter", "Houses", "Duty" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Power, Features = A.Power, A.Features

check("power module", Power ~= nil and type(Power.add) == "function")
check("feature registered", Features ~= nil and Features.byKey["power"] ~= nil)
check("feature default off", Features.on("power") == false)
check("tick noop when off", Power.tick(100) == 0)

Features.set("power", true)
check("feature on", Features.on("power") == true)

local plant = Power.add("plant", 1000, 1000)
local solar = Power.add("solar", 5000, 5000)
check("stations added", plant ~= nil and solar ~= nil and #Power.list() == 2)
check("covers inside", Power.covers(plant, 1000, 1100) == true)
check("covers outside", Power.covers(plant, 1000, 2000) == false)

Power.consumerSource = function() return { { x = 1010, y = 1005, demand = 20 } } end
check("load sums base + covered", Power.load(plant) == Power.kinds.plant.baseLoad + 20, Power.load(plant))

Power.tick(100)
check("plant online under load", plant.state == "online", plant.state)
check("solar online by day", solar.state == "online" or solar.state == "overload", solar.state)

-- overload -> blown fuse
Power.consumerSource = function() return { { x = 1010, y = 1005, demand = 400 } } end
Power.fuseRisk = 100
Power.tick(110)
check("overload blows fuse", plant.fuse == true and plant.state == "fuse", plant.state .. "/" .. tostring(plant.fuse))
check("not powered through blown station", Power.coverage(1000, 1000) == nil)

-- replace fuse but still overloaded (disable blow to observe the overload state itself)
check("replace fuse clears flag", Power.replaceFuse(plant.id) == true and plant.fuse == false)
Power.fuseRisk = 0
Power.tick(111)
check("still overload after fuse while overloaded", plant.state == "overload", plant.state)

-- reduce load -> online
Power.consumerSource = function() return { { x = 1010, y = 1005, demand = 10 } } end
Power.fuseRisk = 14
Power.replaceFuse(plant.id)
Power.tick(112)
check("online after load drop", plant.state == "online", plant.state)
check("coverage returns online station", Power.coverage(1000, 1000) == plant)

-- fuel depletion
plant.fuel = 0.001
Power.tick(140)
check("plant out of fuel", plant.state == "nofuel" and plant.fuel == 0, plant.state .. "/" .. tostring(plant.fuel))
check("refuel restores", Power.refuel(plant.id, 1) == true and plant.fuel == 1)
Power.tick(141)
check("online after refuel", plant.state == "online", plant.state)

-- wear / dead + service
plant.wear = 1
check("evaluate dead when worn", Power.evaluate(plant, 100, 10) == "dead")
check("service reduces wear", Power.service(plant.id, 0.6) == true and plant.wear <= 0.4)

-- powered(camp)
local camp = { x1 = 980, y1 = 980, x2 = 1020, y2 = 1020, z = 0, plan = { items = {} } }
plant.wear = 0
Power.replaceFuse(plant.id)
Power.tick(150)
check("camp in coverage is powered", Power.powered(camp) == true)
Features.set("power", false)
check("powered false when feature off", Power.powered(camp) == false)
Features.set("power", true)

-- solar night -> idle
local realGT = getGameTime
local HOURV = 2
getGameTime = function()
    local base = realGT()
    return setmetatable({ getHour = function() return HOURV end }, { __index = base })
end
Power.tick(160)
check("solar idle at night", solar.state == "idle", solar.state)
HOURV = 12
Power.tick(170)
check("solar back online by day", solar.state == "online" or solar.state == "overload", solar.state)
getGameTime = realGT

-- serializable
local function pure(v, d)
    if d > 8 then return false end
    local k = type(v)
    if k == "function" or k == "userdata" then return false end
    if k ~= "table" then return true end
    for _, item in pairs(v) do if not pure(item, d + 1) then return false end end
    return true
end
check("power state serializable", pure(Power.state(), 0))
check("summary works", type(Power.summary()) == "table" and Power.summary().total == 2)

-- seeding covers camps
Power.consumerSource = nil
for _, s in ipairs(Power.list()) do Power.remove(s.id) end
check("cleared stations", #Power.list() == 0)
local Camp = A.Camp
for x = 300, 460 do for y = 300, 460 do NEWSQUARE(x, y, 0) end end
local c1 = Camp.create({ x1 = 310, y1 = 310, x2 = 400, y2 = 400, z = 0 }, "PwrBig")
local seeded = Power.seed()
check("seed placed a station for the camp", seeded >= 1, seeded)
local sc1x, sc1y = A.Geo.center(c1)
check("camp now covered", Power.coverage(sc1x, sc1y) ~= nil)
local before = #Power.list()
check("seed idempotent for covered camp", Power.seed() == 0 and #Power.list() == before)
check("big camp got a plant", Power.kindForCamp(c1) == "plant", Power.kindForCamp(c1))
check("update runs tick", Power.update() >= 1)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
