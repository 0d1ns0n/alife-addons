require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampGates"
require "ALifeCamp/CampWorld"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Gates = ALifeCamp.Gates
local World = ALifeCamp.World

local SlideGate = {}
ALifeCamp.SlideGate = SlideGate

SlideGate.typeId = "chainlink4"
SlideGate.level = 8
SlideGate.quality = "high"
SlideGate.direction = "forward"

local vWall = { N = 0, S = -1, E = -1, W = 0 }

function SlideGate.ready()
    local ok, yes = pcall(function()
        return SGGate ~= nil and type(SGGate.build) == "function"
            and SGGateTypes ~= nil and type(SGGateTypes[SlideGate.typeId]) == "table"
    end)
    return ok and yes == true
end

function SlideGate.width()
    local w = 0
    pcall(function() w = SGGateTypes[SlideGate.typeId].width or 0 end)
    return w
end

function SlideGate.orientation(side)
    if side == "N" or side == "S" then return "N" end
    return "W"
end

function SlideGate.catcher(geo)
    if type(geo) ~= "table" or geo.side == nil then return nil end
    local side = geo.side
    local cu = (side == "N" or side == "S") and 2 or -2
    local cx, cy = Gates.at(geo, cu, vWall[side] or 0)
    return cx, cy, SlideGate.orientation(side)
end

local function heavyGates(camp)
    local out = {}
    local plan = camp.plan
    if type(plan) ~= "table" or type(plan.items) ~= "table" then return out end
    for _, project in pairs(plan.items) do
        if project.kind == "fence" and not project.retired and project.status == "done" then
            for _, gate in ipairs(Gates.of(project)) do
                if gate.main == true then out[#out + 1] = Gates.geometry(project, gate) end
            end
        end
    end
    return out
end

local function registered(id)
    local yes = false
    pcall(function() yes = SGGate.registry()[id] ~= nil end)
    return yes
end

function SlideGate.place(camp, geo)
    local z = camp.z or 0
    local cx, cy, ori = SlideGate.catcher(geo)
    if cx == nil then return nil end
    local id = cx .. "," .. cy .. "," .. z
    if registered(id) then return id end
    if World.square(cx, cy, z) == nil then return nil end
    if World.isWater(cx, cy, z) == true then return nil end
    local built
    pcall(function()
        built = SGGate.build(World.square(cx, cy, z), SlideGate.typeId, SlideGate.level, ori, SlideGate.direction, SlideGate.quality)
    end)
    if type(built) == "string" then return built end
    return nil
end

function SlideGate.sync(camp)
    if not SlideGate.ready() then return 0 end
    camp.slideGates = camp.slideGates or {}
    local present = {}
    local made = 0
    for _, geo in ipairs(heavyGates(camp)) do
        present[geo.key] = true
        if camp.slideGates[geo.key] == nil then
            local id = SlideGate.place(camp, geo)
            if id ~= nil then
                camp.slideGates[geo.key] = id
                made = made + 1
            end
        end
    end
    local stale = {}
    for key, _ in pairs(camp.slideGates) do
        if not present[key] then stale[#stale + 1] = key end
    end
    for _, key in ipairs(stale) do
        pcall(function() SGGate.remove(camp.slideGates[key]) end)
        camp.slideGates[key] = nil
    end
    return made
end

function SlideGate.count(camp)
    local n = 0
    if type(camp.slideGates) == "table" then
        for _ in pairs(camp.slideGates) do n = n + 1 end
    end
    return n
end

local lastHour = {}

function SlideGate.onMinute(camp)
    if camp.raid ~= nil then return end
    if not SlideGate.ready() then return end
    SlideGate.sync(camp)
    if Store ~= nil then
        local hour = math.floor(Store.hours())
        if lastHour[camp.id] ~= hour then
            lastHour[camp.id] = hour
            print("[ALifeCamp:SlideGate] mod=1 width=" .. SlideGate.width() .. " gates=" .. SlideGate.count(camp))
        end
    end
end

function SlideGate.overview(camp)
    local n = SlideGate.count(camp)
    if n == 0 then return {} end
    return { Hooks.line(ALifeCamp.T("SlideGate_overview", tostring(n)), 0.6, 0.72, 0.82) }
end

if Hooks ~= nil then
    Hooks.add("minute", SlideGate.onMinute, 76)
    Hooks.add("overview", SlideGate.overview, 13)
end

return SlideGate
