require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampFeatures"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Features = ALifeCamp.Features

local Power = {}
ALifeCamp.Power = Power

Power.fuseRisk = 14
Power.wearOutput = 0.4
Power.dayStart = 7
Power.dayEnd = 19

Power.kinds = {
    plant = { output = 120, radius = 260, fuel = true, burn = 0.010, baseLoad = 28, wear = 0.0035, name = "PowerKind_plant" },
    hydro = { output = 70, radius = 210, water = true, drain = 0.004, baseLoad = 14, wear = 0.0022, name = "PowerKind_hydro" },
    substation = { output = 45, radius = 150, baseLoad = 9, wear = 0.0030, name = "PowerKind_substation" },
    solar = { output = 24, radius = 95, solar = true, baseLoad = 0, wear = 0.0014, name = "PowerKind_solar" },
}

local function rand(n)
    local value = 0
    pcall(function() value = ZombRand(n) end)
    return value
end

function Power.state()
    local data = Store.data()
    if type(data.power) ~= "table" then data.power = {} end
    local p = data.power
    if type(p.stations) ~= "table" then p.stations = {} end
    if type(p.serial) ~= "number" then p.serial = 0 end
    return p
end

function Power.enabled()
    return Features ~= nil and Features.on("power") == true
end

function Power.cfg(station)
    return Power.kinds[station.kind] or Power.kinds.substation
end

function Power.add(kind, x, y, extra)
    if Power.kinds[kind] == nil then return nil end
    local st = Power.state()
    st.serial = st.serial + 1
    local station = {
        id = st.serial, kind = kind, x = x, y = y, z = 0,
        fuel = 1, water = 1, wear = 0, fuse = false, load = 0, state = "online", age = 0,
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do station[key] = value end
    end
    st.stations[tostring(station.id)] = station
    return station
end

function Power.get(id)
    return Power.state().stations[tostring(id)]
end

function Power.list()
    local out = {}
    for _, station in pairs(Power.state().stations) do out[#out + 1] = station end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Power.radius(station)
    return station.radius or Power.cfg(station).radius
end

function Power.covers(station, x, y)
    local r = Power.radius(station)
    local dx, dy = x - station.x, y - station.y
    return dx * dx + dy * dy <= r * r
end

local function daylight(now)
    local hour
    local ok = pcall(function()
        local gt = getGameTime()
        if gt ~= nil then hour = gt:getHour() end
    end)
    if not ok or hour == nil then
        hour = math.floor((now or 0) % 24)
    end
    if hour < Power.dayStart or hour >= Power.dayEnd then return 0 end
    local mid = (Power.dayStart + Power.dayEnd) / 2
    local span = (Power.dayEnd - Power.dayStart) / 2
    return math.max(0.2, 1 - math.abs(hour - mid) / span)
end

function Power.output(station, now)
    local cfg = Power.cfg(station)
    local base = station.output or cfg.output
    base = base * (1 - Power.wearOutput * (station.wear or 0))
    if cfg.solar then base = base * daylight(now) end
    if base < 0 then base = 0 end
    return base
end

Power.consumerSource = nil

local function allCamps()
    local camps
    local ok = pcall(function()
        if Store ~= nil and type(Store.list) == "function" then camps = Store.list() end
    end)
    if not ok or type(camps) ~= "table" then return {} end
    return camps
end

local function campConsumers()
    local out = {}
    for _, camp in ipairs(allCamps()) do
        local demand = 0
        pcall(function() demand = Power.campDemand(camp) end)
        local cx, cy
        pcall(function()
            if ALifeCamp.Geo ~= nil then cx, cy = ALifeCamp.Geo.center(camp) end
        end)
        if cx ~= nil then out[#out + 1] = { x = cx, y = cy, demand = demand } end
    end
    return out
end

function Power.campDemand(camp)
    local demand = 4
    local plan = type(camp.plan) == "table" and camp.plan.items or nil
    if type(plan) ~= "table" then return demand end
    for _, project in pairs(plan) do
        if not project.retired then
            if project.kind == "lamp" then demand = demand + 0.5 end
            if project.kind == "powerhouse" or project.kind == "infirmary" or project.kind == "forge" then demand = demand + 6 end
            if project.kind == "canteen" or project.kind == "barracks" then demand = demand + 3 end
        end
    end
    return demand
end

function Power.consumers()
    if type(Power.consumerSource) == "function" then
        local ok, list = pcall(Power.consumerSource)
        if ok and type(list) == "table" then return list end
    end
    return campConsumers()
end

function Power.load(station)
    local cfg = Power.cfg(station)
    local load = cfg.baseLoad or 0
    for _, consumer in ipairs(Power.consumers()) do
        if Power.covers(station, consumer.x, consumer.y) then load = load + (consumer.demand or 0) end
    end
    return load
end

function Power.evaluate(station, out, load)
    if (station.wear or 0) >= 1 then return "dead" end
    if station.fuse == true then return "fuse" end
    local cfg = Power.cfg(station)
    if cfg.fuel and (station.fuel or 0) <= 0 then return "nofuel" end
    if cfg.water and (station.water or 0) <= 0 then return "dry" end
    if out <= 0 then return "idle" end
    if load > out then return "overload" end
    return "online"
end

function Power.tickStation(station, dt, now)
    local cfg = Power.cfg(station)
    station.age = (station.age or 0) + dt
    if cfg.fuel then station.fuel = math.max(0, (station.fuel or 1) - cfg.burn * dt) end
    if cfg.water then station.water = math.max(0, (station.water or 1) - cfg.drain * dt) end
    local out = Power.output(station, now)
    local load = Power.load(station)
    station.load = load
    local ratio = out > 0 and load / out or 2
    station.wear = math.min(1, (station.wear or 0) + cfg.wear * dt * (0.5 + math.max(0, ratio)))
    station.state = Power.evaluate(station, out, load)
    if station.state == "overload" and dt > 0 then
        if rand(100) < Power.fuseRisk then
            station.fuse = true
            station.state = "fuse"
        end
    end
    station.outputNow = out
    return station.state
end

function Power.tick(now)
    if not Power.enabled() then return 0 end
    local st = Power.state()
    now = now or Store.hours()
    local dt = now - (st.clock or now)
    if dt < 0 then dt = 0 end
    st.clock = now
    local count = 0
    for _, station in pairs(st.stations) do
        Power.tickStation(station, dt, now)
        count = count + 1
    end
    return count
end

function Power.online(station)
    return station.state == "online"
end

function Power.coverage(x, y)
    local best
    for _, station in ipairs(Power.list()) do
        if Power.online(station) and Power.covers(station, x, y) then
            if best == nil or Power.radius(station) < Power.radius(best) then best = station end
        end
    end
    return best
end

function Power.powered(camp)
    if not Power.enabled() then return false end
    local cx, cy
    local ok = pcall(function()
        if ALifeCamp.Geo ~= nil then cx, cy = ALifeCamp.Geo.center(camp) end
    end)
    if not ok or cx == nil then return false end
    return Power.coverage(cx, cy) ~= nil
end

function Power.replaceFuse(id)
    local station = Power.get(id)
    if station == nil or station.fuse ~= true then return false end
    station.fuse = false
    station.state = Power.evaluate(station, Power.output(station, Store.hours()), station.load or 0)
    return true
end

function Power.refuel(id, amount)
    local station = Power.get(id)
    if station == nil then return false end
    local cfg = Power.cfg(station)
    if cfg.fuel then station.fuel = math.min(1, (station.fuel or 0) + (amount or 1)) end
    if cfg.water then station.water = math.min(1, (station.water or 0) + (amount or 1)) end
    return true
end

function Power.service(id, amount)
    local station = Power.get(id)
    if station == nil then return false end
    station.wear = math.max(0, (station.wear or 0) - (amount or 0.5))
    return true
end

function Power.remove(id)
    Power.state().stations[tostring(id)] = nil
end

function Power.summary()
    local total, online = 0, 0
    for _, station in ipairs(Power.list()) do
        total = total + 1
        if Power.online(station) then online = online + 1 end
    end
    return { total = total, online = online }
end

function Power.kindForCamp(camp)
    local area = 0
    pcall(function() area = ALifeCamp.Geo.width(camp) * ALifeCamp.Geo.height(camp) end)
    if area >= 6000 then return "plant" end
    if area >= 2500 then return "substation" end
    return "solar"
end

function Power.seed()
    local Geo = ALifeCamp.Geo
    local added = 0
    for _, camp in ipairs(allCamps()) do
        local cx, cy
        pcall(function() if Geo ~= nil then cx, cy = Geo.center(camp) end end)
        if cx ~= nil and Power.coverage(cx, cy) == nil then
            if Power.add(Power.kindForCamp(camp), cx, cy, { z = camp.z or 0 }) ~= nil then added = added + 1 end
        end
    end
    return added
end

function Power.update()
    if not Power.enabled() then return 0 end
    Power.seed()
    return Power.tick()
end

local Hooks = ALifeCamp.Hooks
if Hooks ~= nil and type(Hooks.add) == "function" then
    Hooks.add("overview", function(camp)
        if not Power.enabled() then return {} end
        local cx, cy
        pcall(function() cx, cy = ALifeCamp.Geo.center(camp) end)
        if cx == nil then return {} end
        local station = Power.coverage(cx, cy)
        if station == nil then
            return { Hooks.line(ALifeCamp.T("Power_offgrid"), 0.82, 0.55, 0.42) }
        end
        local out = station.outputNow or Power.output(station, Store.hours())
        return { Hooks.line(ALifeCamp.T("Power_oncamp", ALifeCamp.T("PowerKind_" .. station.kind),
            tostring(math.floor((station.load or 0) + 0.5)), tostring(math.floor(out + 0.5))), 0.6, 0.85, 1) }
    end, 13)
end

if Events ~= nil then
    pcall(function()
        Events.EveryHours.Add(function()
            if not Power.enabled() then return end
            if isClient ~= nil and isClient() == true then return end
            pcall(Power.update)
        end)
    end)
end

if Features ~= nil and type(Features.define) == "function" then
    Features.define({
        key = "power",
        name = "Feat_power",
        desc = "FeatHint_power",
        default = false,
        priority = 20,
        after = function(value)
            if value == true then pcall(Power.update) end
        end,
    })
end

return Power
