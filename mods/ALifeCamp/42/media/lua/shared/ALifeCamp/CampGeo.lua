ALifeCamp = ALifeCamp or {}

local Geo = {}
ALifeCamp.Geo = Geo

function Geo.bounds(points)
    local x1, y1, x2, y2
    for i = 1, #points do
        local p = points[i]
        x1 = x1 == nil and p.x or math.min(x1, p.x)
        y1 = y1 == nil and p.y or math.min(y1, p.y)
        x2 = x2 == nil and p.x or math.max(x2, p.x)
        y2 = y2 == nil and p.y or math.max(y2, p.y)
    end
    return x1, y1, x2, y2
end

function Geo.width(c) return c.x2 - c.x1 + 1 end

function Geo.height(c) return c.y2 - c.y1 + 1 end

function Geo.area(c) return Geo.width(c) * Geo.height(c) end

function Geo.contains(c, x, y)
    return x >= c.x1 and x <= c.x2 and y >= c.y1 and y <= c.y2
end

function Geo.center(c)
    return math.floor((c.x1 + c.x2) / 2), math.floor((c.y1 + c.y2) / 2)
end

function Geo.overlaps(a, b)
    return a.x1 <= b.x2 and a.x2 >= b.x1 and a.y1 <= b.y2 and a.y2 >= b.y1
end

function Geo.distanceTo(c, x, y)
    local dx = math.max(c.x1 - x, 0, x - c.x2)
    local dy = math.max(c.y1 - y, 0, y - c.y2)
    return math.sqrt(dx * dx + dy * dy)
end

function Geo.onBorder(c, x, y)
    if not Geo.contains(c, x, y) then return false end
    return x == c.x1 or x == c.x2 or y == c.y1 or y == c.y2
end

function Geo.border(c, step)
    step = math.max(1, math.floor(step or 1))
    local out = {}
    for x = c.x1, c.x2, step do
        out[#out + 1] = { x = x, y = c.y1 }
        if c.y2 ~= c.y1 then out[#out + 1] = { x = x, y = c.y2 } end
    end
    for y = c.y1 + step, c.y2 - 1, step do
        out[#out + 1] = { x = c.x1, y = y }
        if c.x2 ~= c.x1 then out[#out + 1] = { x = c.x2, y = y } end
    end
    return out
end

function Geo.corners(c)
    return { { x = c.x1, y = c.y1 }, { x = c.x2, y = c.y1 }, { x = c.x2, y = c.y2 }, { x = c.x1, y = c.y2 } }
end

function Geo.expanded(c, north, south, west, east)
    return { x1 = c.x1 - (west or 0), y1 = c.y1 - (north or 0), x2 = c.x2 + (east or 0), y2 = c.y2 + (south or 0), z = c.z }
end

function Geo.valid(c, config)
    local w, h = Geo.width(c), Geo.height(c)
    if w < config.minSide or h < config.minSide then return false, "small" end
    if w > config.maxSide or h > config.maxSide then return false, "large" end
    if w * h > config.maxArea then return false, "large" end
    return true
end

function Geo.copy(c)
    return { x1 = c.x1, y1 = c.y1, x2 = c.x2, y2 = c.y2, z = c.z }
end

return Geo
