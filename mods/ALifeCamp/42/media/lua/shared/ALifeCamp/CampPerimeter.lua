require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampGates"
require "ALifeCamp/CampBlueprints"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Build = ALifeCamp.Build
local Gates = ALifeCamp.Gates
local Bp = ALifeCamp.Blueprints

local Perimeter = {}
ALifeCamp.Perimeter = Perimeter

Perimeter.prefix = "PM"
Perimeter.buffer = 1

local Dir = {
    N = { 0, -1, "N" },
    S = { 0, 1, "N" },
    W = { -1, 0, "W" },
    E = { 1, 0, "W" },
}

local Art = {
    wire = { N = "fencing_01_108", W = "fencing_01_109" },
    jersey = { N = "street_decoration_01_28", W = "street_decoration_01_29" },
    sandbag = { N = "carpentry_02_13", W = "carpentry_02_12" },
    hesco = { "fencing_01_96", "fencing_01_97", "fencing_01_100", "fencing_01_101", "fencing_01_102", "fencing_01_103" },
    stake = "fencing_01_19",
}

local knownSprites = {}

local function known(name)
    if name == nil then return false end
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function hash(x, y)
    local v = x * 131 + y * 57
    if v < 0 then v = -v end
    return v
end

local function key(x, y)
    return x .. ":" .. y
end

local function gateZone(project)
    local zone = {}
    local list = {}
    local ok = pcall(function() list = Gates.of(project) or {} end)
    if not ok then return zone end
    for _, gate in ipairs(list) do
        local span = tonumber(gate.span) or Gates.span
        local half = math.floor(span / 2) + Perimeter.buffer
        for k = -half, half do
            zone[gate.side .. ":" .. (gate.index + k)] = true
        end
    end
    return zone
end

local function heavy(face, h)
    local pick = h - math.floor(h / 3) * 3
    if pick == 0 then
        local idx = (math.floor(h / 3)) - math.floor(math.floor(h / 3) / #Art.hesco) * #Art.hesco + 1
        return Art.hesco[idx], { metal = 2 }
    elseif pick == 1 then
        return Art.jersey[face], { metal = 1 }
    end
    return Art.sandbag[face], { rope = 1 }
end

local function apronStages(project)
    if tonumber(project.wall) == nil or tonumber(project.wall) < 1 then return {} end
    local slots = Bp.fenceSlots(project)
    local walls = {}
    for _, slot in ipairs(slots) do walls[key(slot.x, slot.y)] = true end
    local zone = gateZone(project)
    local ring, bulwark = {}, {}
    local used = {}
    local n = 0
    local function slotId()
        n = n + 1
        return Perimeter.prefix .. n
    end
    for _, slot in ipairs(slots) do
        local dir = Dir[slot.side]
        if not slot.gate and dir ~= nil and not zone[slot.side .. ":" .. slot.index] then
            local ax, ay = slot.x + dir[1], slot.y + dir[2]
            local cell = key(ax, ay)
            if not walls[cell] and not used[cell] then
                used[cell] = true
                local face = dir[3]
                local wire = Art.wire[face]
                if known(wire) then
                    ring[#ring + 1] = { t = "prop", sprite = wire, x = ax, y = ay, z = 0, slot = slotId(), cost = { rope = 1 } }
                end
                local h = hash(ax, ay)
                if h - math.floor(h / 3) * 3 == 0 then
                    local sprite, cost = heavy(face, h)
                    if known(sprite) then
                        bulwark[#bulwark + 1] = { t = "prop", sprite = sprite, x = ax, y = ay, z = 0, slot = slotId(), cost = cost }
                    end
                elseif h - math.floor(h / 5) * 5 == 0 and known(Art.stake) then
                    bulwark[#bulwark + 1] = { t = "prop", sprite = Art.stake, x = ax, y = ay, z = 0, slot = slotId(), cost = {} }
                end
            end
        end
    end
    local stages = {}
    if #ring > 0 then stages[#stages + 1] = { id = "apron", ops = ring } end
    if #bulwark > 0 then stages[#stages + 1] = { id = "bulwark", ops = bulwark } end
    return stages
end

Perimeter.stages = apronStages

local function wrap()
    local def = Bp.kinds and Bp.kinds.fence
    if def == nil or def.build == nil or def.perimeterBuild ~= nil then return false end
    local original = def.build
    def.perimeterBuild = original
    def.build = function(project)
        local stages = original(project)
        local ok, extra = pcall(apronStages, project)
        if ok and type(extra) == "table" then
            for _, stage in ipairs(extra) do stages[#stages + 1] = stage end
        end
        return stages
    end
    return true
end

Perimeter.wrapped = wrap()

local lastHour = {}

Hooks.add("minute", function(camp)
    local hour = math.floor(Store.hours())
    if lastHour[camp.id] == hour then return end
    lastHour[camp.id] = hour
    local fenced = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and tonumber(project.wall) ~= nil and tonumber(project.wall) >= 1 and not project.retired then
            fenced = fenced + 1
        end
    end
    print("[ALifeCamp:Perimeter] wrapped=" .. tostring(Perimeter.wrapped) .. " heavyFences=" .. fenced)
end, 73)

return Perimeter
