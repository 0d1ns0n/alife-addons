require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampText"
require "ALifeCamp/CampSettlers"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World

local Markers = { list = {}, signature = "", lastX = nil, lastY = nil, tick = 0 }
ALifeCamp.Markers = Markers

function Markers.clear()
    for i = #Markers.list, 1, -1 do
        pcall(function() Markers.list[i]:remove() end)
        Markers.list[i] = nil
    end
    Markers.signature = ""
end

local function add(x, y, z, color, size)
    local square = World.square(x, y, z)
    if square == nil then return end
    local ok, marker = pcall(function()
        return getWorldMarkers():addGridSquareMarker(square, color.r, color.g, color.b, true, size or 0.55)
    end)
    if ok and marker ~= nil then Markers.list[#Markers.list + 1] = marker end
end

function Markers.wanted(player)
    local wants = {}
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    local flags = Store.pending()
    if #flags >= 1 then
        for _, flag in ipairs(flags) do
            wants[#wants + 1] = { x = flag.x, y = flag.y, z = flag.z or 0, color = Config.pendingColor, size = 0.9 }
        end
    end
    if #flags >= 2 then
        local rect = ALifeCamp.Camp.rectFrom(flags, flags[1].z)
        if rect ~= nil then
            for _, spot in ipairs(Geo.border(rect, Config.markerStep)) do
                if math.abs(spot.x - px) <= Config.markerRange and math.abs(spot.y - py) <= Config.markerRange then
                    wants[#wants + 1] = { x = spot.x, y = spot.y, z = rect.z, color = Config.pendingColor, size = 0.5 }
                end
            end
        end
    end
    for _, camp in ipairs(Store.list()) do
        if camp.options ~= nil and camp.options.border ~= false and Geo.distanceTo(camp, px, py) <= Config.markerRange then
            local count = 0
            for _, spot in ipairs(Geo.border(camp, Config.markerStep)) do
                if math.abs(spot.x - px) <= Config.markerRange and math.abs(spot.y - py) <= Config.markerRange
                        and count < Config.markerLimit then
                    wants[#wants + 1] = { x = spot.x, y = spot.y, z = camp.z, color = Config.border, size = 0.45 }
                    count = count + 1
                end
            end
        end
    end
    return wants
end

function Markers.refresh(player, force)
    player = player or getPlayer()
    if player == nil then return end
    local wants = Markers.wanted(player)
    local parts = {}
    for i = 1, #wants do parts[i] = wants[i].x .. "," .. wants[i].y end
    local signature = table.concat(parts, ";")
    if not force and signature == Markers.signature then return end
    Markers.clear()
    Markers.signature = signature
    for _, want in ipairs(wants) do add(want.x, want.y, want.z, want.color, want.size) end
end

function Markers.onTick()
    Markers.tick = Markers.tick + 1
    if Markers.tick < 45 then return end
    Markers.tick = 0
    local player = getPlayer()
    if player == nil then return end
    local x, y = math.floor(player:getX()), math.floor(player:getY())
    if Markers.lastX == nil or math.abs(x - Markers.lastX) + math.abs(y - Markers.lastY) >= 6 then
        Markers.lastX, Markers.lastY = x, y
        Markers.refresh(player)
    end
end

Markers.haloTick = 0

function Markers.tagSettlers()
    local player = getPlayer()
    if player == nil then return end
    local px, py = player:getX(), player:getY()
    local T = ALifeCamp.T
    for _, camp in ipairs(Store.list()) do
        for uid, settler in pairs(camp.settlers or {}) do
            local shell = ALifeCamp.Settlers.shell(uid)
            if shell ~= nil and math.abs(shell:getX() - px) < 40 and math.abs(shell:getY() - py) < 40 then
                local role = T("Role_" .. tostring(settler.role or "worker"))
                pcall(function() shell:setHaloNote(T("Tag", role), 120, 220, 120, 4) end)
            end
        end
    end
end

function Markers.onHalo()
    Markers.haloTick = Markers.haloTick + 1
    if Markers.haloTick < 120 then return end
    Markers.haloTick = 0
    pcall(Markers.tagSettlers)
end

local function timed(label, fn)
    local hooks = ALifeCamp.Hooks
    if hooks ~= nil and type(hooks.timed) == "function" then return hooks.timed(label, fn) end
    return fn
end

Events.OnTick.Add(timed("markers.tick", Markers.onTick))
Events.OnTick.Add(timed("markers.halo", Markers.onHalo))
Events.OnGameStart.Add(function() Markers.refresh(getPlayer(), true) end)

return Markers
