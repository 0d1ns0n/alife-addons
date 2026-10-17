ALifeCamp = ALifeCamp or {}

local Gates = {}
ALifeCamp.Gates = Gates

Gates.span = 3
Gates.mainSpan = 5
Gates.spacing = 90
Gates.maxCount = 16
Gates.minSide = 14
Gates.margin = 14
Gates.minMargin = 6

local cycle = { "S", "E", "N", "W" }
local forward = { S = 1, E = -1, N = -1, W = 1 }
local opposite = { N = "S", S = "N", E = "W", W = "E" }

local function sideLength(side, w, h)
    if side == "N" or side == "S" then return w end
    return h
end

local function cycleFrom(side)
    local start = 1
    for i, name in ipairs(cycle) do
        if name == side then start = i end
    end
    local out = {}
    for i = 0, 3 do out[#out + 1] = cycle[(start - 1 + i) % 4 + 1] end
    return out
end

function Gates.opposite(side)
    return opposite[side] or "N"
end

function Gates.count(w, h)
    if math.min(w, h) < Gates.minSide then return 1 end
    local perimeter = 2 * (w + h)
    return math.max(2, math.min(Gates.maxCount, math.ceil(perimeter / Gates.spacing)))
end

function Gates.marginFor(w, h)
    if math.min(w, h) >= 40 then return Gates.margin end
    return Gates.minMargin
end

local function locate(order, w, h, mainIndex, distance)
    local side = order[1]
    local len = sideLength(side, w, h)
    local dir = forward[side]
    local lastIndex = dir > 0 and len - 1 or 0
    local first = math.abs(lastIndex - mainIndex) + 1
    if distance < first then return side, mainIndex + dir * distance end
    local rest = distance - first
    for step = 2, 4 do
        local name = order[step]
        local length = sideLength(name, w, h)
        if rest < length then
            if forward[name] > 0 then return name, rest end
            return name, length - 1 - rest
        end
        rest = rest - length
    end
    local back = dir > 0 and rest or len - 1 - rest
    return side, back
end

function Gates.layout(w, h, mainSide, mainIndex)
    mainSide = mainSide or "S"
    local count = Gates.count(w, h)
    local order = cycleFrom(mainSide)
    local mainLen = sideLength(mainSide, w, h)
    local span = Gates.span
    local mainSpan = Gates.mainSpan or span
    if type(mainIndex) ~= "number" then mainIndex = math.floor(mainLen / 2) end
    mainIndex = math.max(mainSpan, math.min(mainLen - 1 - mainSpan, math.floor(mainIndex)))
    local margin = Gates.marginFor(w, h)
    local perimeter = 2 * (w + h)
    local gates = { { id = "g1", side = mainSide, index = mainIndex, main = true, span = mainSpan } }
    for i = 1, count - 1 do
        local distance = math.floor(i * perimeter / count + 0.5)
        local side, index = locate(order, w, h, mainIndex, distance % perimeter)
        local len = sideLength(side, w, h)
        local low, high = margin, len - 1 - margin
        if high < low then
            index = math.floor(len / 2)
        else
            index = math.max(low, math.min(high, index))
        end
        local clash = false
        for _, other in ipairs(gates) do
            if other.side == side and math.abs(other.index - index) < span + margin then clash = true end
        end
        if not clash then gates[#gates + 1] = { id = "g" .. (#gates + 1), side = side, index = index } end
    end
    return gates
end

function Gates.of(project)
    if type(project.gates) == "table" and #project.gates > 0 then return project.gates end
    local side = project.gate or "S"
    return { { id = "g1", side = side, index = math.floor(sideLength(side, project.w, project.h) / 2), main = true, span = Gates.mainSpan or Gates.span } }
end

function Gates.upgrade(project)
    if type(project) ~= "table" or project.kind ~= "fence" or type(project.gates) == "table" then return false end
    if (project.stage or 1) > 1 or not ALifeCamp.isEmpty(project.done) then return false end
    project.gates = Gates.layout(project.w, project.h, project.gate or "S")
    return true
end

function Gates.frame(side, x, y)
    local out = { side = side, x = x, y = y, out = side, ["in"] = opposite[side] }
    if side == "S" then
        out.dx, out.dy, out.lx, out.ly = 0, -1, 1, 0
    elseif side == "N" then
        out.dx, out.dy, out.lx, out.ly = 0, 1, 1, 0
    elseif side == "E" then
        out.dx, out.dy, out.lx, out.ly = -1, 0, 0, 1
    else
        out.dx, out.dy, out.lx, out.ly = 1, 0, 0, 1
    end
    out.key = side .. ":" .. x .. ":" .. y
    out.laneDoor = (side == "N" or side == "S") and "E" or "S"
    return out
end

function Gates.geometry(project, gate)
    local x1, y1 = project.x, project.y
    local x2, y2 = project.x + project.w - 1, project.y + project.h - 1
    local side, index = gate.side, gate.index
    local gx, gy
    if side == "S" then
        gx, gy = x1 + index, y2
    elseif side == "N" then
        gx, gy = x1 + index, y1
    elseif side == "E" then
        gx, gy = x2, y1 + index
    else
        gx, gy = x1, y1 + index
    end
    local out = Gates.frame(side, gx, gy)
    out.id, out.index, out.main, out.span = gate.id, index, gate.main == true, gate.span or Gates.span
    return out
end

function Gates.at(geo, u, v)
    return geo.x + geo.lx * u + geo.dx * v, geo.y + geo.ly * u + geo.dy * v
end

function Gates.toLocal(geo, x, y)
    local rx, ry = x - geo.x, y - geo.y
    return rx * geo.lx + ry * geo.ly, rx * geo.dx + ry * geo.dy
end

function Gates.rect(geo, u1, v1, u2, v2)
    local ax, ay = Gates.at(geo, u1, v1)
    local bx, by = Gates.at(geo, u2, v2)
    return math.min(ax, bx), math.min(ay, by), math.abs(ax - bx) + 1, math.abs(ay - by) + 1
end

function Gates.list(camp)
    local out = {}
    local plan = camp.plan
    if type(plan) ~= "table" or type(plan.items) ~= "table" then return out end
    for _, project in pairs(plan.items) do
        if project.kind == "fence" and not project.retired then
            for _, gate in ipairs(Gates.of(project)) do out[#out + 1] = Gates.geometry(project, gate) end
        end
    end
    table.sort(out, function(a, b)
        if a.main ~= b.main then return a.main end
        return a.key < b.key
    end)
    return out
end

return Gates
