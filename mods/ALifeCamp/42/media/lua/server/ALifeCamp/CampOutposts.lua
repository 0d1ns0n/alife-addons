require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampFeatures"

ALifeCamp = ALifeCamp or {}

local Features = ALifeCamp.Features

local Outposts = {}
ALifeCamp.Outposts = Outposts

Outposts.key = "outposts"
Outposts.installed = false
Outposts.presetsAdded = 0
Outposts.ourIds = {
    "alc_market_mil", "alc_market_raid", "alc_market_surv",
    "alc_gun_mil", "alc_gun_raid", "alc_gun_surv",
    "alc_depot_mil", "alc_depot_raid", "alc_depot_surv",
}

local RADIO = "appliances_com_01_0"
local SANDBAG = "carpentry_02_13"

function Outposts.enabled()
    return Features ~= nil and Features.on(Outposts.key) == true
end

local function presets()
    local p
    pcall(function()
        local pa = ProjectALife
        if pa == nil then return end
        local set = pa.OutpostPresets
        if type(set) == "table" and type(set.list) == "table" and type(set.byId) == "table"
                and type(set.Stores) == "table" and type(set.Dressing) == "table" then
            p = set
        end
    end)
    return p
end

function Outposts.hasPA()
    return presets() ~= nil
end

function Outposts.presetsPresent()
    local n = 0
    local set = presets()
    if set ~= nil then
        for _, id in ipairs(Outposts.ourIds) do
            if set.byId[id] ~= nil then n = n + 1 end
        end
    end
    return n
end

local function buildDefs(set)
    local D = set.Dressing

    local function mark() return { op = "mark_entrances" } end
    local function doors(p) return { op = "barricade_doors", planks = p } end
    local function windows(chance, material) return { op = "barricade_windows", chance = chance, material = material } end
    local function chicane(run, standoff) return { op = "entry_barrier", run = run, standoff = standoff, pieces = D.roadBlock } end
    local function wall(sprite, span, standoff) return { op = "yard_barrier", sprite = sprite, span = span, standoff = standoff } end
    local function crate(sprite, loot, draws, at) return { op = "container", sprite = sprite, loot = loot, draws = draws, at = at or "interior" } end
    local function lamp(at) return { op = "light", sprite = D.floodlamp, at = at } end
    local function gen(at) return { op = "generator", at = at or "yard" } end
    local function fire(at) return { op = "campfire", at = at or "interior" } end
    local function radio(at) return { op = "radio", sprite = RADIO, at = at or "interior" } end
    local function tower(door, facing) return { op = "guard_tower", door = door, facing = facing, at = "yard" } end
    local function piece(pieces, at) return { op = "object", pieces = pieces, at = at or "interior" } end
    local function litter(heaps, kinds) return { op = "dress_litter", heaps = heaps, kinds = kinds } end
    local function gore(count) return { op = "blood", count = count } end
    local function scatter(item, count, stack, at) return { op = "items", item = item, count = count, stack = stack, at = at or "interior" } end

    local function kit(...)
        local out = {}
        for _, frag in ipairs({ ... }) do
            if frag.op ~= nil then
                out[#out + 1] = frag
            else
                for _, o in ipairs(frag) do out[#out + 1] = o end
            end
        end
        return out
    end

    local cats = {
        market = {
            roomNames = { "grocery", "gigamart", "grocerystorage", "bakery", "convenience" },
            minArea = 150, maxArea = 4000, minDay = 4, lifetime = { minHours = 96, maxHours = 240 },
            squad = { size = { min = 2, max = 3 }, maxLive = 1, maxOffline = 0, intervalHours = { min = 5, max = 11 } },
        },
        gun = {
            roomNames = { "gunstore", "gunstorestorage", "gunstorage", "armystorage", "armysurplus", "hunting" },
            minArea = 40, maxArea = 1400, minDay = 3, lifetime = { minHours = 96, maxHours = 240 },
            squad = { size = { min = 2, max = 4 }, maxLive = 2, maxOffline = 0, intervalHours = { min = 4, max = 10 } },
        },
        depot = {
            roomNames = { "warehouse", "storage", "storageunit", "factory", "loggingwarehouse" },
            minArea = 100, maxArea = 4000, minDay = 5, lifetime = { minHours = 120, maxHours = 264 },
            squad = { size = { min = 2, max = 4 }, maxLive = 2, maxOffline = 1, intervalHours = { min = 4, max = 10 } },
        },
    }

    local weights = {
        mil = { patrol = 45, scavenge = 20, hunt = 35 },
        raid = { patrol = 20, scavenge = 40, hunt = 40 },
        surv = { patrol = 45, scavenge = 45, hunt = 10 },
    }

    local defs = {}
    local function add(id, cat, label, garrison, kind, kitList)
        local base = cats[cat]
        defs[#defs + 1] = {
            id = id, label = label, class = "building",
            roomNames = base.roomNames, minArea = base.minArea, maxArea = base.maxArea,
            minDay = base.minDay, lifetime = base.lifetime,
            garrison = { min = garrison[1], max = garrison[2] },
            squad = {
                size = base.squad.size, maxLive = base.squad.maxLive, maxOffline = base.squad.maxOffline,
                intervalHours = base.squad.intervalHours, taskWeights = weights[kind],
            },
            hostileToPlayers = "faction", radio = true, theftTurnsHostile = true, planVersion = 2,
            kit = kitList,
        }
    end

    add("alc_market_mil", "market", "Market checkpoint", { 4, 5 }, "mil", kit(
        mark(), doors(4), windows(100, "metal"),
        chicane(5, 3), wall(SANDBAG, 4, 2), wall(SANDBAG, 3, 4), wall(D.barrier, 5, 6),
        tower("S", "S"),
        crate(D.rationsCrate, "rations", 5), crate(D.medicineDrawers, "medicine", 3), crate(D.munitionsCrate, "munitions", 2, "yard"),
        gen("yard"), lamp("yard"), lamp("interior"), lamp("yard"),
        gore(2), litter(2, { "paper" }),
        radio("interior")))
    add("alc_gun_mil", "gun", "Armory checkpoint", { 4, 6 }, "mil", kit(
        mark(), doors(4), windows(100, "metal"),
        chicane(5, 3), wall(SANDBAG, 4, 2), wall(SANDBAG, 4, 4), wall(D.barrier, 4, 6),
        tower("S", "S"),
        crate(D.munitionsCrate, "munitions", 5), crate(D.munitionsCrate, "munitions", 3, "yard"), crate(D.medicineDrawers, "medicine", 2),
        gen("yard"), lamp("yard"), lamp("interior"), lamp("yard"),
        gore(3), scatter("Base.556Bullets", 2, 10, "yard"), litter(1, { "paper" }),
        radio("interior")))
    add("alc_depot_mil", "depot", "Depot checkpoint", { 5, 6 }, "mil", kit(
        mark(), doors(4), windows(100, "metal"),
        chicane(6, 3), wall(SANDBAG, 5, 2), wall(SANDBAG, 4, 4), wall(D.barrier, 6, 6),
        tower("S", "S"),
        crate(D.hardwareCabinet, "hardware", 4), crate(D.munitionsCrate, "munitions", 3), crate(D.rationsCrate, "rations", 2),
        gen("yard"), lamp("yard"), lamp("interior"), lamp("yard"),
        gore(2), litter(2, { "paper", "bags" }),
        radio("interior")))

    add("alc_market_raid", "market", "Raider market nest", { 3, 5 }, "raid", kit(
        mark(), doors(3), windows(60),
        chicane(3, 2), wall(D.barrier, 4, 3),
        fire("interior"), piece(D.logPile, "interior"),
        crate(D.rationsCrate, "rations", 4), crate(D.hardwareCabinet, "hardware", 2), crate(D.munitionsCrate, "munitions", 2),
        gen("yard"), lamp("interior"),
        gore(6), scatter("Base.ShotgunShells", 3, 6, "interior"), litter(4, { "paper", "plastic", "bags" }),
        radio("interior")))
    add("alc_gun_raid", "gun", "Bandit armory", { 4, 6 }, "raid", kit(
        mark(), doors(3), windows(65),
        chicane(3, 2), wall(D.barrier, 3, 3),
        fire("interior"), piece(D.logPile, "interior"),
        crate(D.munitionsCrate, "munitions", 4), crate(D.rationsCrate, "rations", 2),
        gen("yard"), lamp("interior"),
        gore(6), scatter("Base.Bullets9mm", 4, 8, "interior"), litter(4, { "paper", "plastic" }),
        radio("interior")))
    add("alc_depot_raid", "depot", "Scavenger warehouse", { 4, 6 }, "raid", kit(
        mark(), doors(3), windows(55),
        chicane(4, 2), wall(D.barrier, 4, 3),
        fire("yard"), piece(D.logPile, "yard"),
        crate(D.hardwareCabinet, "hardware", 4), crate(D.munitionsCrate, "munitions", 2),
        gen("yard"), lamp("interior"),
        gore(5), scatter("Base.Bullets45", 3, 8, "interior"), litter(4, { "bags", "paper", "plastic" }),
        radio("interior")))

    add("alc_market_surv", "market", "Settler market", { 3, 4 }, "surv", kit(
        mark(), doors(3), windows(100),
        chicane(4, 3), wall(D.barrier, 4, 4), piece(D.logPile, "yard"),
        fire("interior"), piece(D.bunk, "interior"),
        crate(D.rationsCrate, "rations", 5), crate(D.rationsCrate, "rations", 3), crate(D.medicineDrawers, "medicine", 3),
        gen("yard"), lamp("interior"), lamp("yard"),
        gore(1), litter(2, { "paper", "bags" }),
        radio("interior")))
    add("alc_gun_surv", "gun", "Militia holdfast", { 4, 5 }, "surv", kit(
        mark(), doors(3), windows(100),
        chicane(4, 3), wall(D.barrier, 3, 4), tower("S", "S"),
        fire("interior"), piece(D.bunk, "interior"),
        crate(D.munitionsCrate, "munitions", 3), crate(D.hardwareCabinet, "hardware", 3), crate(D.medicineDrawers, "medicine", 2),
        gen("yard"), lamp("interior"), lamp("yard"),
        gore(1), litter(2, { "paper" }),
        radio("interior")))
    add("alc_depot_surv", "depot", "Settler depot", { 4, 5 }, "surv", kit(
        mark(), doors(3), windows(100),
        chicane(5, 3), wall(D.barrier, 5, 4), piece(D.logPile, "yard"),
        fire("interior"), piece(D.bunk, "interior"),
        crate(D.hardwareCabinet, "hardware", 4), crate(D.rationsCrate, "rations", 3), crate(D.medicineDrawers, "medicine", 2),
        gen("yard"), lamp("interior"), lamp("yard"),
        gore(1), litter(2, { "bags", "paper" }),
        radio("interior")))

    return defs
end

function Outposts.registerPresets()
    local added = 0
    pcall(function()
        local set = presets()
        if set == nil then return end
        local inserted = {}
        for _, preset in ipairs(buildDefs(set)) do
            if set.byId[preset.id] == nil then
                set.list[#set.list + 1] = preset
                set.byId[preset.id] = preset
                inserted[#inserted + 1] = preset
            end
        end
        if #inserted > 0 and type(set.validate) == "function" then
            local ran, ok = pcall(set.validate)
            if ran and ok ~= true then
                for _, preset in ipairs(inserted) do
                    set.byId[preset.id] = nil
                    for index = #set.list, 1, -1 do
                        if set.list[index] == preset then table.remove(set.list, index) end
                    end
                end
                inserted = {}
                print("[ALifeCamp:Outposts] preset validate failed, rolled back")
            end
        end
        added = #inserted
    end)
    Outposts.presetsAdded = Outposts.presetsPresent()
    return added
end

function Outposts.ensureDirector()
    local on = false
    pcall(function()
        local director = ProjectALife and ProjectALife.OutpostDirector
        if type(director) ~= "table" then return end
        if type(director.configure) == "function" then
            local settings = type(director.settings) == "table" and director.settings or {}
            local adapters = { enabled = true, squadsHardCap = settings.squadsHardCap }
            if type(settings.maxSites) ~= "number" or settings.maxSites < 1 then
                adapters.maxSites = 6
            end
            pcall(director.configure, adapters)
        end
        director.enabled = true
        on = director.enabled == true
    end)
    return on
end

function Outposts.apply()
    if not Outposts.enabled() then return false end
    if not Outposts.hasPA() then return false end
    Outposts.registerPresets()
    Outposts.ensureDirector()
    return true
end

function Outposts.paOutposts()
    local n = 0
    pcall(function()
        local registry = ProjectALife and ProjectALife.OutpostRegistry
        if registry == nil then return end
        if type(registry.count) == "function" then
            n = tonumber(registry.count()) or 0
        elseif type(registry.list) == "function" then
            n = #(registry.list())
        end
    end)
    return n
end

function Outposts.paDirectorOn()
    local on = false
    pcall(function()
        on = ProjectALife ~= nil and ProjectALife.OutpostDirector ~= nil
            and ProjectALife.OutpostDirector.enabled == true
    end)
    return on
end

function Outposts.diagnostics()
    if not Outposts.enabled() then return end
    print("[ALifeCamp:Outposts] on=" .. tostring(Outposts.enabled())
        .. " paDir=" .. tostring(Outposts.paDirectorOn())
        .. " presetsAdded=" .. tostring(Outposts.presetsPresent())
        .. " paOutposts=" .. tostring(Outposts.paOutposts()))
end

function Outposts.hourly()
    if not Outposts.enabled() then return end
    pcall(Outposts.apply)
    pcall(Outposts.diagnostics)
end

function Outposts.install()
    if Outposts.installed then return end
    Outposts.installed = true
    pcall(function() Events.EveryHours.Add(Outposts.hourly) end)
end

function Outposts.enable()
    Outposts.install()
    pcall(Outposts.apply)
end

function Outposts.disable()
    return true
end

pcall(function()
    if Outposts.enabled() then Outposts.install() end
end)

pcall(function()
    Events.OnGameStart.Add(function()
        pcall(function() if Outposts.enabled() then Outposts.enable() end end)
    end)
end)

return Outposts
