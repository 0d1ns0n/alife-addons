require "ALifeCamp/CampConfig"

ALifeCamp = ALifeCamp or {}

local PowerMap = {}
ALifeCamp.PowerMap = PowerMap

PowerMap.colors = {
    online = { r = 0.35, g = 0.85, b = 0.4, a = 0.9 },
    overload = { r = 0.95, g = 0.6, b = 0.2, a = 0.9 },
    idle = { r = 0.6, g = 0.6, b = 0.65, a = 0.75 },
    fuse = { r = 0.9, g = 0.3, b = 0.3, a = 0.9 },
    nofuel = { r = 0.9, g = 0.3, b = 0.3, a = 0.9 },
    dry = { r = 0.9, g = 0.3, b = 0.3, a = 0.9 },
    dead = { r = 0.55, g = 0.2, b = 0.2, a = 0.85 },
}

function PowerMap.color(state)
    return PowerMap.colors[state] or PowerMap.colors.idle
end

local function circle(map, cx, cy, radius, col, thickness)
    local segments = 32
    local prevx, prevy
    for i = 0, segments do
        local angle = (i / segments) * 2 * math.pi
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius
        if prevx ~= nil then
            map.javaObject:DrawLine(nil, prevx, prevy, x, y, thickness or 2, col.r, col.g, col.b, col.a)
        end
        prevx, prevy = x, y
    end
end

function PowerMap.draw(map)
    local Power = ALifeCamp.Power
    if Power == nil or type(Power.enabled) ~= "function" or not Power.enabled() then return end
    local api = map.mapAPI
    if api == nil then return end
    local width, height = map:getWidth(), map:getHeight()
    local font = UIFont.Small
    for _, station in ipairs(Power.list()) do
        local cx = api:worldToUIX(station.x, station.y)
        local cy = api:worldToUIY(station.x, station.y)
        local edge = api:worldToUIX(station.x + Power.radius(station), station.y)
        local uiR = math.abs(edge - cx)
        if uiR >= 3 and cx > -uiR and cy > -uiR and cx < width + uiR and cy < height + uiR then
            local col = PowerMap.color(station.state)
            circle(map, cx, cy, uiR, col, 2)
            local fill = { r = col.r, g = col.g, b = col.b, a = 0.12 }
            map:drawRect(cx - uiR, cy - uiR, uiR * 2, uiR * 2, fill.a, fill.r, fill.g, fill.b)
            map:drawRect(cx - 4, cy - 4, 8, 8, col.a, col.r, col.g, col.b)
            map:drawRectBorder(cx - 4, cy - 4, 8, 8, 1, 0, 0, 0)
            local label = ALifeCamp.T("PowerKind_" .. station.kind)
            local state = ALifeCamp.TN("PowerState_" .. station.state)
            if state ~= nil then label = label .. " (" .. state .. ")" end
            map:drawTextCentre(label, cx, cy - 20, 1, 1, 1, 1, font)
        end
    end
end

local function install()
    if ISWorldMap == nil or type(ISWorldMap.render) ~= "function" or ISWorldMap.alcPowerWrapped == true then return end
    ISWorldMap.alcPowerWrapped = true
    local base = ISWorldMap.render
    function ISWorldMap:render()
        base(self)
        pcall(function() PowerMap.draw(self) end)
    end
end

install()
if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(install) end)
end

return PowerMap
