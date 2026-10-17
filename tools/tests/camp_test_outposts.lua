dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings2.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings3.lua"] = true
SKIPMOD["shared/ALifeCamp/CampScenery.lua"] = true
SKIPMOD["shared/ALifeCamp/CampShells.lua"] = true
SKIPMOD["shared/ALifeCamp/CampTowers.lua"] = true
SKIPMOD["shared/ALifeCamp/CampPerimeter.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Features, Outposts = A.Store, A.Features, A.Outposts

local function keys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function listLen(set)
    return #set.list
end

local KNOWN_OPS = {
    mark_entrances = true, barricade_windows = true, barricade_doors = true,
    entry_barrier = true, yard_barrier = true, fortified_perimeter = true,
    campfire = true, tent = true, object = true, container = true,
    dress_litter = true, radio = true, site_survey = true, site_clearance = true,
    blood = true, items = true, light = true, generator = true,
    guard_tower = true, path = true, pen = true, compound = true, checkpoint = true,
}

local function makePresets(validateResult)
    local Presets = { list = {}, byId = {} }
    Presets.Stores = {
        munitions = { { "Base.Bullets9mm", 6, 15 }, { "Base.556Bullets", 4, 20 } },
        rations = { { "Base.WaterRationCan", 5, 2 }, { "Base.Crackers", 4, 2 } },
        medicine = { { "Base.RippedSheets", 6, 3 }, { "Base.Antibiotics", 1, 1 } },
        hardware = { { "Base.Nails", 4, 25 }, { "Base.Plank", 4, 4 } },
    }
    Presets.Dressing = {
        munitionsCrate = "location_military_generic_01_4",
        rationsCrate = "location_shop_greenes_01_35",
        campBox = "furniture_storage_02_18",
        medicineDrawers = "location_community_medical_01_37",
        hardwareCabinet = "location_business_machinery_01_33",
        roadBlock = { alongX = "street_decoration_01_28", alongY = "street_decoration_01_29" },
        barrier = "fencing_01_100",
        floodlamp = "lighting_outdoor_01_49",
        table = "furniture_tables_low_01_16",
        logPile = { { "camping_01_37", 0, 0 }, { "camping_01_36", 0, 1 } },
        litter = {
            paper = { "d_trash_1_0", "d_trash_1_3" },
            plastic = { "d_trash_1_8", "d_trash_1_12" },
            bags = { "d_trash_1_9", "d_trash_1_10" },
            wood = { "d_trash_1_24" },
        },
    }
    Presets.list[1] = {
        id = "police_station", class = "building",
        roomNames = { "police" }, minArea = 120, maxArea = 2600,
        lifetime = { minHours = 96, maxHours = 240 }, garrison = { min = 4, max = 6 },
        hostileToPlayers = "faction", radio = true, planVersion = 2,
        kit = {
            { op = "mark_entrances" },
            { op = "barricade_doors", planks = 3 },
            { op = "barricade_windows", chance = 100, material = "metal" },
            { op = "entry_barrier", run = 5, standoff = 3, pieces = Presets.Dressing.roadBlock },
            { op = "yard_barrier", span = 4, standoff = 6, sprite = Presets.Dressing.barrier },
            { op = "container", sprite = Presets.Dressing.munitionsCrate, loot = "munitions", draws = 4 },
            { op = "radio", sprite = "appliances_com_01_0", at = "interior" },
        },
    }
    Presets.byId.police_station = Presets.list[1]
    function Presets.get(id) return Presets.byId[tostring(id or "")] end
    if validateResult == false then
        function Presets.validate() return false, { "forced failure" } end
    else
        function Presets.validate()
            local problems = {}
            for _, preset in ipairs(Presets.list) do
                local function fail(what) problems[#problems + 1] = preset.id .. ": " .. what end
                if type(preset.kit) ~= "table" or #preset.kit == 0 then fail("no kit") end
                if preset.class ~= "building" and preset.class ~= "clearing" then fail("bad class") end
                if type(preset.lifetime) ~= "table" or preset.lifetime.minHours >= preset.lifetime.maxHours then fail("bad lifetime") end
                if type(preset.garrison) ~= "table" or preset.garrison.min > preset.garrison.max then fail("bad garrison") end
                if preset.class == "building" and (preset.minArea == nil or preset.maxArea == nil or preset.minArea >= preset.maxArea) then fail("bad area") end
                local entrances = 0
                for _, op in ipairs(preset.kit or {}) do
                    if not KNOWN_OPS[op.op] then fail("unknown op " .. tostring(op.op)) end
                    if op.op == "mark_entrances" then entrances = entrances + 1 end
                    if op.op == "container" and Presets.Stores[op.loot] == nil then fail("unknown store " .. tostring(op.loot)) end
                    if op.op == "container" and type(op.draws) ~= "number" then fail("container without draws") end
                    if (op.op == "object" or op.op == "container" or op.op == "radio" or op.op == "light")
                            and type(op.sprite) ~= "string"
                            and not (op.op == "object" and type(op.pieces) == "table" and #op.pieces > 0) then
                        fail("op without sprite " .. tostring(op.op))
                    end
                    if op.op == "items" and type(op.item) ~= "string" then fail("items op without an item") end
                    if op.op == "entry_barrier" and (type(op.pieces) ~= "table"
                            or type(op.pieces.alongX) ~= "string" or type(op.run) ~= "number") then
                        fail("entry barrier without pieces or run")
                    end
                    if op.op == "yard_barrier" and (type(op.sprite) ~= "string" or type(op.span) ~= "number"
                            or type(op.standoff) ~= "number") then
                        fail("yard barrier without sprite, span or standoff")
                    end
                    if op.op == "dress_litter" then
                        if type(op.heaps) ~= "number" or op.heaps < 1 or type(op.kinds) ~= "table" or #op.kinds == 0 then
                            fail("litter without heaps or kinds")
                        end
                        for _, kind in ipairs(op.kinds or {}) do
                            if type(Presets.Dressing.litter[kind]) ~= "table" then fail("unknown litter " .. tostring(kind)) end
                        end
                    end
                    if op.op == "fortified_perimeter" and op.family ~= "palisade" and op.family ~= "wood" then
                        fail("perimeter without a map wall family")
                    end
                end
                if preset.class == "building" and entrances ~= 1 then fail("a building preset needs exactly one mark_entrances") end
                if preset.radio == true then
                    local hasRadio = false
                    for _, op in ipairs(preset.kit) do
                        if op.op == "radio" then hasRadio = true end
                        if op.op == "compound" then hasRadio = true end
                    end
                    if not hasRadio then fail("radio preset with nothing to broadcast from") end
                end
            end
            for name, rows in pairs(Presets.Stores) do
                for _, row in ipairs(rows) do
                    if type(row[1]) ~= "string" or type(row[2]) ~= "number" or row[2] <= 0 or type(row[3]) ~= "number" then
                        problems[#problems + 1] = "store " .. name .. ": bad row"
                    end
                end
            end
            return #problems == 0, problems
        end
    end
    return Presets
end

local function makeDirector()
    local Director = { enabled = false, settings = { maxSites = 6, perCity = 1, squadsHardCap = 1 }, calls = {} }
    function Director.configure(adapters)
        Director.calls[#Director.calls + 1] = adapters
        local s = Director.settings
        s.squadsHardCap = tonumber(adapters.squadsHardCap) or 1
        if adapters.maxSites ~= nil then s.maxSites = adapters.maxSites end
        Director.enabled = adapters.enabled ~= false and s.maxSites > 0
        return true
    end
    return Director
end

local function makeRegistry(n)
    local sites = {}
    for i = 1, (n or 0) do sites[i] = { id = i } end
    return { count = function() return #sites end, list = function() return sites end }
end

check("module present", Outposts ~= nil and type(Outposts) == "table")
check("api present", type(Outposts.enable) == "function" and type(Outposts.enabled) == "function"
    and type(Outposts.registerPresets) == "function" and type(Outposts.ensureDirector) == "function"
    and type(Outposts.apply) == "function" and type(Outposts.diagnostics) == "function"
    and type(Outposts.disable) == "function")

check("feature seeded off", Features.byKey.outposts ~= nil and Features.byKey.outposts.default == false)
check("off by default", Outposts.enabled() == false)
check("no hooks installed while off", Outposts.installed == false or Outposts.installed == nil)

ProjectALife = nil
check("hasPA false when PA absent", Outposts.hasPA() == false)
check("registerPresets no-op when PA absent", Outposts.registerPresets() == 0)
check("ensureDirector false when PA absent", Outposts.ensureDirector() == false)
check("diagnostics safe while off and no PA", (function() Outposts.diagnostics() return true end)())
check("presetsPresent zero when PA absent", Outposts.presetsPresent() == 0)
check("still not installed", Outposts.installed == false or Outposts.installed == nil)

local PA = makePresets(true)
local Dir = makeDirector()
ProjectALife = { OutpostPresets = PA, OutpostDirector = Dir, OutpostRegistry = makeRegistry(2) }

check("hasPA true when PA present", Outposts.hasPA() == true)
check("nothing registered automatically while off", Outposts.presetsPresent() == 0)
check("director untouched while off", Dir.enabled == false)
check("list only baseline while off", listLen(PA) == 1)

local added = Outposts.registerPresets()
check("registerPresets added three", added == 3)
check("byId has supermarket", PA.byId.alc_supermarket ~= nil)
check("byId has gunstore", PA.byId.alc_gunstore ~= nil)
check("byId has warehouse", PA.byId.alc_warehouse ~= nil)
check("list grew to four", listLen(PA) == 4)

local vok, vproblems = PA.validate()
check("validate passes after insert", vok == true, vproblems ~= nil and table.concat(vproblems, ",") or "")

for _, id in ipairs(Outposts.ourIds) do
    local preset = PA.byId[id]
    check(id .. " is building", preset ~= nil and preset.class == "building")
    check(id .. " lifetime sane", preset.lifetime.minHours < preset.lifetime.maxHours)
    check(id .. " garrison sane", preset.garrison.min <= preset.garrison.max)
    check(id .. " area sane", preset.minArea < preset.maxArea)
    check(id .. " roomNames set", type(preset.roomNames) == "table" and #preset.roomNames > 0)
    check(id .. " hostile by faction", preset.hostileToPlayers == "faction")
    local entrances, hasRadio, badLoot, badDraws, badOp = 0, false, false, false, false
    for _, op in ipairs(preset.kit) do
        if op.op == "mark_entrances" then entrances = entrances + 1 end
        if op.op == "radio" then hasRadio = true end
        if not KNOWN_OPS[op.op] then badOp = true end
        if op.op == "container" then
            if PA.Stores[op.loot] == nil then badLoot = true end
            if type(op.draws) ~= "number" then badDraws = true end
        end
    end
    check(id .. " exactly one mark_entrances", entrances == 1)
    check(id .. " radio flag has radio op", preset.radio == true and hasRadio == true)
    check(id .. " container loot from Stores", not badLoot)
    check(id .. " container draws numeric", not badDraws)
    check(id .. " all ops known", not badOp)
end

local addedAgain = Outposts.registerPresets()
check("registerPresets idempotent", addedAgain == 0 and listLen(PA) == 4)
check("presetsPresent three", Outposts.presetsPresent() == 3)

local badPA = makePresets(false)
local badDir = makeDirector()
ProjectALife = { OutpostPresets = badPA, OutpostDirector = badDir, OutpostRegistry = makeRegistry(0) }
local baseLen = listLen(badPA)
local addedBad = Outposts.registerPresets()
check("rollback adds nothing", addedBad == 0)
check("rollback left no supermarket", badPA.byId.alc_supermarket == nil)
check("rollback left no gunstore", badPA.byId.alc_gunstore == nil)
check("rollback left no warehouse", badPA.byId.alc_warehouse == nil)
check("rollback list unchanged", listLen(badPA) == baseLen)
check("presetsPresent zero after rollback", Outposts.presetsPresent() == 0)

ProjectALife = { OutpostPresets = PA, OutpostDirector = makeDirector(), OutpostRegistry = makeRegistry(0) }
PA.byId.alc_supermarket = nil
PA.byId.alc_gunstore = nil
PA.byId.alc_warehouse = nil
for i = listLen(PA), 2, -1 do PA.list[i] = nil end
local tmpDirNil = ProjectALife.OutpostDirector
ProjectALife.OutpostDirector = nil
check("ensureDirector false without director table", Outposts.ensureDirector() == false)
ProjectALife.OutpostDirector = tmpDirNil
ProjectALife.OutpostDirector.settings.squadsHardCap = 3

Features.set("outposts", true)
check("enable installs hooks", Outposts.installed == true)
check("enabled now true", Outposts.enabled() == true)
check("enable registered presets", Outposts.presetsPresent() == 3)
check("enable turned director on", ProjectALife.OutpostDirector.enabled == true)
check("enable configure called with enabled", (function()
    local calls = ProjectALife.OutpostDirector.calls
    return #calls >= 1 and calls[1].enabled == true
end)())
check("enable did not override good maxSites", ProjectALife.OutpostDirector.settings.maxSites == 6)
check("enable preserved squadsHardCap", ProjectALife.OutpostDirector.settings.squadsHardCap == 3)
check("presetsAdded cache three", Outposts.presetsAdded == 3)

Outposts.apply()
check("apply idempotent presets", Outposts.presetsPresent() == 3 and listLen(ProjectALife.OutpostPresets) == 4)

check("hourly runs clean", (function() Outposts.hourly() return true end)())

Outposts.diagnostics()
local diagSeen, diagOn = false, false
for i = 1, #PRINTS do
    if PRINTS[i]:find("[ALifeCamp:Outposts]", 1, true) then
        diagSeen = true
        if PRINTS[i]:find("on=true", 1, true) and PRINTS[i]:find("paDir=true", 1, true)
                and PRINTS[i]:find("presetsAdded=3", 1, true) then diagOn = true end
    end
end
check("diagnostics printed", diagSeen)
check("diagnostics reports state", diagOn)

local lowSites = makeDirector()
lowSites.settings.maxSites = 0
ProjectALife = { OutpostPresets = makePresets(true), OutpostDirector = lowSites, OutpostRegistry = makeRegistry(0) }
Outposts.ensureDirector()
check("ensureDirector bumps dead maxSites", lowSites.settings.maxSites == 6 and lowSites.enabled == true)

check("texts present", A.TN("Feat_outposts") ~= nil and A.TN("FeatHint_outposts") ~= nil)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
