require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampLand"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local World = ALifeCamp.World
local Land = ALifeCamp.Land
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build

local Plan = {}
ALifeCamp.Plan = Plan

Plan.UNKNOWN = 0
Plan.FREE = 1
Plan.BLOCKED = 2
Plan.BUILDING = 3
Plan.WATER = 4
Plan.BUILT = 5
Plan.ADOPTED = 6

local knownSprites = {}
local function known(name)
    if name == nil then return false end
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local CONCRETE = "floors_exterior_street_01_0"

function Plan.anchorFor(camp, kind, ax, ay, radius)
    local zones = ALifeCamp.Zones
    if zones ~= nil and type(zones.anchorFor) == "function" then
        local ok, zx, zy, zr = pcall(zones.anchorFor, camp, kind, ax, ay, radius)
        if ok and type(zx) == "number" and type(zy) == "number" then return zx, zy, zr or radius end
    end
    return ax, ay, radius
end

local function roadSquare(square)
    local road = false
    pcall(function()
        local floor = square:getFloor()
        local sprite = floor ~= nil and floor:getSprite() or nil
        local name = sprite ~= nil and sprite:getName() or nil
        if type(name) == "string" and string.sub(name, 1, 22) == "floors_exterior_street" then road = true end
    end)
    return road
end

function Plan.detectGateSide(camp)
    local z = camp.z or 0
    local best, side, index
    local function scan(name)
        local count, positions = 0, {}
        if name == "S" or name == "N" then
            local y = name == "S" and camp.y2 or camp.y1
            for x = camp.x1, camp.x2 do
                local square = World.square(x, y, z)
                if square ~= nil and roadSquare(square) then count = count + 1 positions[#positions + 1] = x - camp.x1 end
            end
        else
            local x = name == "E" and camp.x2 or camp.x1
            for y = camp.y1, camp.y2 do
                local square = World.square(x, y, z)
                if square ~= nil and roadSquare(square) then count = count + 1 positions[#positions + 1] = y - camp.y1 end
            end
        end
        if count > (best or 0) then
            table.sort(positions)
            best, side, index = count, name, positions[math.floor(#positions / 2) + 1]
        end
    end
    for _, name in ipairs({ "S", "E", "N", "W" }) do scan(name) end
    if best ~= nil and best >= 2 then return side, index end
    return nil
end

local function houseExtent()
    local hw, hh = 0, 0
    for _, kind in ipairs({ "house_s", "house_m", "house_l" }) do
        local def = Bp.kinds[kind]
        if def ~= nil then
            if def.w + 1 > hw then hw = def.w + 1 end
            if def.h + 1 > hh then hh = def.h + 1 end
        end
    end
    if hw < 5 then hw = 5 end
    if hh < 5 then hh = 5 end
    return hw, hh
end

function Plan.gridSpec(camp)
    local hw, hh = houseExtent()
    local cx, cy = Geo.center(camp)
    local w = Geo.width(camp)
    return {
        hw = hw, hh = hh, colStep = hw + 2, laneH = 2, rowPitch = hh + 2,
        cx = cx, cy = cy, gx = camp.x1 + math.floor(w / 2),
        left = camp.x1 + 3, right = camp.x2 - 3, top = camp.y1 + 3, bottom = camp.y2 - 3,
    }
end

local function plazaRadius(camp)
    local minDim = math.min(Geo.width(camp), Geo.height(camp))
    if minDim >= 80 then return 6 end
    if minDim >= 40 then return 5 end
    if minDim >= 24 then return 4 end
    if minDim >= 16 then return 3 end
    return 0
end

function Plan.newGrid(camp)
    return { w = Geo.width(camp), h = Geo.height(camp), cells = {}, cursor = 0, passes = 0 }
end

local function waterAt(square)
    return ALifeCamp.World.isWaterSquare(square)
end

function Plan.cellState(camp, x, y)
    local square = World.square(x, y, camp.z)
    if square == nil then return Plan.UNKNOWN end
    local state = Plan.FREE
    pcall(function()
        if square:getBuilding() ~= nil then state = Plan.BUILDING end
        if waterAt(square) then state = Plan.WATER return end
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local tag = World.tag(object)
            if type(tag) == "table" then
                if state ~= Plan.BUILDING then state = Plan.BUILT end
            elseif state == Plan.FREE and Land.classify(object) ~= nil then
                state = Plan.BLOCKED
            end
        end
        if square:getVehicleContainer() ~= nil then state = Plan.BLOCKED end
    end)
    local adopt = ALifeCamp.Adopt
    if adopt ~= nil and adopt.covered(camp, x, y) ~= nil then state = Plan.ADOPTED end
    return state
end

function Plan.scanStep(camp, grid, budget)
    local total = grid.w * grid.h
    local done = 0
    while done < budget do
        local i = grid.cursor
        local x = camp.x1 + i % grid.w
        local y = camp.y1 + math.floor(i / grid.w)
        grid.cells[i + 1] = Plan.cellState(camp, x, y)
        grid.cursor = i + 1
        done = done + 1
        if grid.cursor >= total then
            grid.cursor = 0
            grid.passes = grid.passes + 1
            break
        end
    end
    return done
end

function Plan.cell(grid, camp, x, y)
    return grid.cells[(y - camp.y1) * grid.w + (x - camp.x1) + 1] or Plan.UNKNOWN
end

local function doorToward(project, cx, cy)
    local px = project.x + project.w / 2
    local py = project.y + project.h / 2
    local dx, dy = cx - px, cy - py
    if math.abs(dx) > math.abs(dy) then return dx > 0 and "E" or "W" end
    return dy > 0 and "S" or "N"
end

function Plan.place(camp, kind, ax, ay, radius, extra)
    local def = Bp.kinds[kind]
    if def == nil then return nil, "kind" end
    local cx, cy = Geo.center(camp)
    radius = radius or 8
    for r = 0, radius do
        for dx = -r, r do
            for dy = -r, r do
                if r == 0 or math.abs(dx) == r or math.abs(dy) == r then
                    local x, y = ax + dx, ay + dy
                    local probe = { x = x, y = y, w = def.w, h = def.h }
                    local door = nil
                    if Bp.buildingKinds[kind] then
                        if kind == "shed" then door = doorToward(probe, cx, cy) else door = "S" end
                    end
                    if Build.fits(camp, kind, x, y, def.w, def.h, nil, door) then
                        local options = { door = door }
                        if extra ~= nil then for key, value in pairs(extra) do options[key] = value end end
                        return Build.add(camp, kind, x, y, options)
                    end
                end
            end
        end
    end
    return nil, "nospace"
end

function Plan.hasKind(camp, kind)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and not project.retired then return true end
    end
    return false
end

function Plan.countKind(camp, kind, plain)
    local n = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == kind and not project.retired and not (plain and project.gkey ~= nil) then n = n + 1 end
    end
    return n
end

function Plan.targets(camp)
    local T = ALifeCamp.Tiers
    if T ~= nil and type(T.want) == "function" and T.on(camp) then
        local hs = T.want(camp, "house_s") or 0
        local hm = T.want(camp, "house_m") or 0
        local hl = T.want(camp, "house_l") or 0
        local houses = hs + hm + hl
        if ALifeCamp.Adopt ~= nil then houses = ALifeCamp.Adopt.reduce(camp, houses) end
        return {
            houses = houses, house_s = hs, house_m = hm, house_l = hl,
            farms = T.want(camp, "farm") or 0, towers = T.want(camp, "tower") or 0,
            sheds = T.want(camp, "shed") or 0, campfires = T.want(camp, "campfire") or 1,
            large = hl > 0,
        }
    end
    local w, h = Geo.width(camp), Geo.height(camp)
    local area = w * h
    local houses = math.max(1, math.min(80, math.floor(area / 140)))
    local farms = area >= 250 and math.max(1, math.min(30, math.floor(area / 350))) or 0
    local towers = 0
    if w >= 16 and h >= 16 then towers = 2 end
    if w >= 28 and h >= 28 then towers = 4 end
    towers = math.min(32, math.max(towers, math.floor(2 * (w + h) / 40)))
    local sheds = 1
    if ALifeCamp.Adopt ~= nil then houses = ALifeCamp.Adopt.reduce(camp, houses) end
    return { houses = houses, farms = farms, towers = towers, sheds = sheds, large = area >= 1200 }
end

function Plan.houseAnchors(camp, count)
    local w, h = Geo.width(camp), Geo.height(camp)
    if w * h <= 2400 then
        local list = {}
        local row = math.max(9, w - 6)
        for n = 0, (count or 1) - 1 do
            list[#list + 1] = { camp.x1 + 2 + ((n * 9) % row), camp.y1 + 2 + math.floor((n * 9) / row) * 8 }
        end
        return list
    end
    local g = Plan.gridSpec(camp)
    local rr = plazaRadius(camp) + 1
    local rx1, ry1, rx2, ry2 = g.cx - rr, g.cy - rr, g.cx + rr, g.cy + rr
    local avx1, avx2 = g.gx - 2, g.gx + 2
    local cols = {}
    local x = avx2 + 1
    while x + g.hw - 1 <= g.right do cols[#cols + 1] = x x = x + g.colStep end
    x = avx1 - g.hw
    while x >= g.left do cols[#cols + 1] = x x = x - g.colStep end
    local tops = {}
    local y = g.top
    while y + g.hh - 1 <= g.bottom - g.laneH do tops[#tops + 1] = y y = y + g.rowPitch end
    local slots = {}
    for _, ty in ipairs(tops) do
        for _, cx0 in ipairs(cols) do
            local hit = cx0 <= rx2 and cx0 + g.hw - 1 >= rx1 and ty <= ry2 and ty + g.hh - 1 >= ry1
            if not hit then
                local mx, my = cx0 + g.hw / 2, ty + g.hh / 2
                slots[#slots + 1] = { cx0, ty, (mx - g.cx) * (mx - g.cx) + (my - g.cy) * (my - g.cy) }
            end
        end
    end
    table.sort(slots, function(a, b)
        if a[3] ~= b[3] then return a[3] < b[3] end
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a[2] < b[2]
    end)
    local list = {}
    local limit = count ~= nil and math.min(count, #slots) or #slots
    for i = 1, limit do list[i] = { slots[i][1], slots[i][2] } end
    return list
end

function Plan.towerNear(camp, x, y, dist)
    dist = dist or 4
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "tower" and project.gkey == nil and not project.retired then
            if math.abs(project.x - x) <= dist and math.abs(project.y - y) <= dist then return true end
        end
    end
    return false
end

function Plan.towerSpots(camp, count)
    local x1, y1, x2, y2 = camp.x1, camp.y1, camp.x2, camp.y2
    local sz = (ALifeCamp.Blueprints.kinds.tower and ALifeCamp.Blueprints.kinds.tower.w) or 6
    local loX, loY = x1 + 1, y1 + 1
    local hiX, hiY = x2 - sz, y2 - sz
    if hiX < loX then hiX = loX end
    if hiY < loY then hiY = loY end
    local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
    local spots = { { loX, loY }, { hiX, hiY }, { hiX, loY }, { loX, hiY } }
    if count <= 4 then return spots end
    local w, h = hiX - loX, hiY - loY
    local length = 2 * (w + h)
    local extra = count - 4
    for i = 1, extra do
        local d = math.floor(length * i / (extra + 1))
        local x, y
        if d < w then
            x, y = loX + d, loY
        elseif d < w + h then
            x, y = hiX, loY + (d - w)
        elseif d < 2 * w + h then
            x, y = hiX - (d - w - h), hiY
        else
            x, y = loX, hiY - (d - 2 * w - h)
        end
        spots[#spots + 1] = { clamp(x, loX, hiX), clamp(y, loY, hiY) }
    end
    return spots
end

ALifeCamp.Options.define({ key = "wallTier", group = "camp", kind = "cycle", values = { 0, 1, 2, 3 }, default = 0, priority = 20 })

function Plan.fenceTier(camp)
    local chosen = ALifeCamp.Options.number(camp, "wallTier")
    if chosen >= 1 and chosen <= 3 then return math.floor(chosen) end
    local level = tonumber(camp.level) or 1
    if level >= 3 then return 3 end
    if level == 2 then return 2 end
    return 1
end

local function drivewayStages(project)
    local ops = {}
    if known(CONCRETE) then
        for dx = 0, project.w - 1 do
            for dy = 0, project.h - 1 do
                ops[#ops + 1] = { t = "dirt", sprite = CONCRETE, x = project.x + dx, y = project.y + dy, z = 0, slot = "C" .. dx .. ":" .. dy }
            end
        end
    end
    return { { id = "pave", ops = ops } }
end

Bp.kinds.driveway = { w = 3, h = 2, priority = 7, build = drivewayStages }

local COURT = { "floors_exterior_tilesandstone_01_7" }

local function courtStages(project)
    local ops = {}
    for dx = 0, project.w - 1 do
        for dy = 0, project.h - 1 do
            local x, y = project.x + dx, project.y + dy
            local name = COURT[(x * 7 + y * 3) % #COURT + 1]
            if known(name) then
                ops[#ops + 1] = { t = "dirt", sprite = name, x = x, y = y, z = 0, slot = "Q" .. dx .. ":" .. dy }
            end
        end
    end
    return { { id = "pave", ops = ops } }
end

Bp.kinds.court = { w = 1, h = 1, priority = 7, build = courtStages }

local function cellKey(x, y) return x * 100000 + y end

local function occupancy(camp)
    local occ = {}
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind ~= "fence" and not project.retired then
            local rect = Bp.footprint(project)
            for ox = rect.x1, rect.x2 do
                for oy = rect.y1, rect.y2 do occ[cellKey(ox, oy)] = true end
            end
        end
    end
    return occ
end

local function pathClear(camp, occ, x, y)
    if not Geo.contains(camp, x, y) then return false end
    if occ[cellKey(x, y)] then return false end
    local state = Plan.cellState(camp, x, y)
    return state == Plan.FREE or state == Plan.UNKNOWN
end

local function laneClear(camp, occ, x, y, laneH)
    for oy = y, y + laneH - 1 do
        if not pathClear(camp, occ, x, oy) then return false end
    end
    return true
end

local function markRect(occ, x, y, w, h)
    for ox = x, x + w - 1 do
        for oy = y, y + h - 1 do occ[cellKey(ox, oy)] = true end
    end
end

local function layStripH(camp, occ, xa, xb, y, laneH, fields)
    local added, runStart = 0, nil
    for x = xa, xb + 1 do
        local ok = x <= xb and laneClear(camp, occ, x, y, laneH)
        if ok then
            if runStart == nil then runStart = x end
        else
            if runStart ~= nil and x - runStart >= 2 then
                local project = Build.add(camp, "path", runStart, y, { w = x - runStart, h = laneH })
                if project ~= nil then
                    for name, value in pairs(fields) do project[name] = value end
                    markRect(occ, runStart, y, x - runStart, laneH)
                    added = added + 1
                end
            end
            runStart = nil
        end
    end
    return added
end

local function layStripV(camp, occ, x, ya, yb, avW, fields)
    local function rowClear(yy)
        for ox = x, x + avW - 1 do
            if not pathClear(camp, occ, ox, yy) then return false end
        end
        return true
    end
    local added, runStart = 0, nil
    for y = ya, yb + 1 do
        local ok = y <= yb and rowClear(y)
        if ok then
            if runStart == nil then runStart = y end
        else
            if runStart ~= nil and y - runStart >= 2 then
                local project = Build.add(camp, "path", x, runStart, { w = avW, h = y - runStart })
                if project ~= nil then
                    for name, value in pairs(fields) do project[name] = value end
                    markRect(occ, x, runStart, avW, y - runStart)
                    added = added + 1
                end
            end
            runStart = nil
        end
    end
    return added
end

local HOUSE_KIND = { house_s = true, house_m = true, house_l = true }

function Plan.streets(camp)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "path" and project.grid and not project.retired then return 0 end
    end
    local g = Plan.gridSpec(camp)
    local pr = plazaRadius(camp)
    local occ = occupancy(camp)
    local rows, order, minY, maxY = {}, {}, nil, nil
    for _, project in ipairs(Build.list(camp)) do
        if HOUSE_KIND[project.kind] then
            local r = rows[project.y]
            if r == nil then
                r = { x1 = project.x, x2 = project.x + project.w, sy = project.y + project.h }
                rows[project.y] = r
                order[#order + 1] = project.y
            else
                if project.x < r.x1 then r.x1 = project.x end
                if project.x + project.w > r.x2 then r.x2 = project.x + project.w end
                if project.y + project.h > r.sy then r.sy = project.y + project.h end
            end
            if minY == nil or project.y < minY then minY = project.y end
            if maxY == nil or project.y + project.h > maxY then maxY = project.y + project.h end
        end
    end
    if minY == nil then return 0 end
    table.sort(order)
    local added = 0
    local avW = 3
    local ax = g.gx - 1
    added = added + layStripV(camp, occ, ax, minY - 1, g.cy - pr - 1, avW, { grid = true, style = "lane", serves = "grid" })
    if ALifeCamp.Districts == nil then
        added = added + layStripV(camp, occ, ax, g.cy + pr + 1, maxY + 1, avW, { grid = true, style = "street", serves = "gate" })
    end
    for _, topY in ipairs(order) do
        local r = rows[topY]
        local ly = r.sy + 1
        added = added + layStripH(camp, occ, r.x1, ax - 1, ly, g.laneH, { grid = true, style = "lane" })
        added = added + layStripH(camp, occ, ax + avW, r.x2, ly, g.laneH, { grid = true, style = "lane" })
    end
    print("[ALifeCamp:Plan] streets=" .. added .. " rows=" .. #order)
    return added
end

function Plan.paths(camp)
    for _, p in pairs(Build.plan(camp).items) do
        if p.kind == "path" and p.serves == "spine" and not p.retired then return 0 end
    end
    local g = Plan.gridSpec(camp)
    local pr = plazaRadius(camp)
    local occ = occupancy(camp)
    local ax, avW = g.gx - 1, 3
    local added = 0
    added = added + layStripV(camp, occ, ax, camp.y1 + 1, g.cy - pr - 1, avW, { grid = true, style = "street", serves = "spine" })
    added = added + layStripV(camp, occ, ax, g.cy + pr + 1, camp.y2 - 1, avW, { grid = true, style = "street", serves = "spine" })
    added = added + layStripH(camp, occ, camp.x1 + 1, ax - 1, g.cy, avW, { grid = true, style = "street", serves = "spine" })
    added = added + layStripH(camp, occ, ax + avW, camp.x2 - 1, g.cy, avW, { grid = true, style = "street", serves = "spine" })
    print("[ALifeCamp:Plan] paths spine=" .. added)
    return added
end

function Plan.driveway(camp, project)
    if project == nil or project.kind ~= "house_l" or ALifeCamp.Houses == nil then return 0 end
    local _, name = ALifeCamp.Houses.designFor(project, "house_l")
    if name ~= "lshape" or not known(CONCRETE) then return 0 end
    local gx = project.x + 5
    for h = 2, 1, -1 do
        local drive = Build.add(camp, "driveway", gx, project.y + project.h + 1, { w = 3, h = h })
        if drive ~= nil then
            drive.grid = true
            return 1
        end
    end
    return 0
end

function Plan.pave(camp)
    local occ = occupancy(camp)
    local cache = {}
    local function free(x, y)
        if not Geo.contains(camp, x, y) then return false end
        local k = cellKey(x, y)
        if occ[k] then return false end
        local c = cache[k]
        if c == nil then
            local s = Plan.cellState(camp, x, y)
            c = (s == Plan.FREE or s == Plan.UNKNOWN)
            cache[k] = c
        end
        return c
    end
    local x1, y1 = camp.x1 + 1, camp.y1 + 1
    local x2, y2 = camp.x2 - 1, camp.y2 - 1
    local rects, open = {}, {}
    for y = y1, y2 do
        local active, x = {}, x1
        while x <= x2 do
            if free(x, y) then
                local xa = x
                while x + 1 <= x2 and free(x + 1, y) do x = x + 1 end
                local kk = xa .. ":" .. x
                active[kk] = true
                if open[kk] == nil then open[kk] = { xa = xa, xb = x, ys = y } end
            end
            x = x + 1
        end
        for kk, o in pairs(open) do
            if not active[kk] then
                rects[#rects + 1] = { x = o.xa, y = o.ys, w = o.xb - o.xa + 1, h = y - o.ys }
                open[kk] = nil
            end
        end
    end
    for _, o in pairs(open) do
        rects[#rects + 1] = { x = o.xa, y = o.ys, w = o.xb - o.xa + 1, h = y2 - o.ys + 1 }
    end
    table.sort(rects, function(a, b) return a.w * a.h > b.w * b.h end)
    local total = 0
    for _ in pairs(Build.plan(camp).items) do total = total + 1 end
    local budget = math.min(260, Build.maxProjects - total - 20)
    local added = 0
    for _, r in ipairs(rects) do
        if budget <= 0 then break end
        local p = Build.add(camp, "court", r.x, r.y, { w = r.w, h = r.h })
        if p ~= nil then
            p.fill = true
            p.serves = "ground"
            p.grid = true
            markRect(occ, r.x, r.y, r.w, r.h)
            budget = budget - 1
            added = added + 1
        end
    end
    print("[ALifeCamp:Plan] pave courts=" .. added .. " rects=" .. #rects)
    return added
end

function Plan.generate(camp)
    if ALifeCamp.Adopt ~= nil and ALifeCamp.Adopt.enabled(camp) then
        pcall(ALifeCamp.Adopt.discover, camp)
    end
    Plan.clearFill(camp)
    local want = Plan.targets(camp)
    local x1, y1, x2, y2 = camp.x1, camp.y1, camp.x2, camp.y2
    local cx, cy = Geo.center(camp)
    local added = 0
    local function put(kind, ax, ay, radius, extra)
        local project = Plan.place(camp, kind, ax, ay, radius, extra)
        if project ~= nil then added = added + 1 end
        return project
    end
    if not Plan.hasKind(camp, "fence") then
        local gate, gateIndex = "S", nil
        local ok, side, index = pcall(Plan.detectGateSide, camp)
        if ok and type(side) == "string" then gate, gateIndex = side, index end
        local fence = Build.add(camp, "fence", x1, y1, { w = Geo.width(camp), h = Geo.height(camp), gate = gate, wall = Plan.fenceTier(camp) })
        if fence ~= nil then
            fence.gates = ALifeCamp.Gates.layout(fence.w, fence.h, gate, gateIndex)
            added = added + 1
        end
    end
    for _ = Plan.countKind(camp, "campfire") + 1, (want.campfires or 1) do put("campfire", cx - 1, cy - 1, 6) end
    for _ = Plan.countKind(camp, "shed") + 1, want.sheds do put("shed", cx - 7, cy - 1, 10) end
    local posts = ALifeCamp.Posts
    if posts ~= nil then
        local ok, extra = pcall(posts.generate, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] posts failed: " .. tostring(extra)) end
    end
    local sanitary = ALifeCamp.Sanitary
    if sanitary ~= nil and type(sanitary.reserve) == "function" then
        local ok, extra = pcall(sanitary.reserve, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] sanitary failed: " .. tostring(extra)) end
    end
    local buildings = ALifeCamp.Buildings
    if buildings ~= nil and type(buildings.generate) == "function" then
        local ok, extra = pcall(buildings.generate, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] buildings failed: " .. tostring(extra)) end
    end
    local buildings2 = ALifeCamp.Buildings2
    if buildings2 ~= nil and type(buildings2.generate) == "function" then
        local ok, extra = pcall(buildings2.generate, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] buildings2 failed: " .. tostring(extra)) end
    end
    local buildings3 = ALifeCamp.Buildings3
    if buildings3 ~= nil and type(buildings3.generate) == "function" then
        local ok, extra = pcall(buildings3.generate, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] buildings3 failed: " .. tostring(extra)) end
    end
    if want.house_s ~= nil then
        local have = {
            house_l = Plan.countKind(camp, "house_l"),
            house_m = Plan.countKind(camp, "house_m"),
            house_s = Plan.countKind(camp, "house_s"),
        }
        local order = { { "house_l", want.house_l or 0 }, { "house_m", want.house_m or 0 }, { "house_s", want.house_s or 0 } }
        local anchors = Plan.houseAnchors(camp, (want.houses or 0) + 8)
        local index, misses = 0, 0
        for _, pair in ipairs(order) do
            local kind, target = pair[1], pair[2]
            while have[kind] < target and index < #anchors and misses < 24 do
                index = index + 1
                local anchor = anchors[index]
                local project = put(kind, anchor[1], anchor[2], 9)
                if project ~= nil then
                    have[kind] = have[kind] + 1
                    added = added + Plan.driveway(camp, project)
                else
                    misses = misses + 1
                end
            end
        end
    else
        local houses = Plan.countKind(camp, "house_s") + Plan.countKind(camp, "house_m") + Plan.countKind(camp, "house_l")
        local anchors = Plan.houseAnchors(camp, want.houses + 40)
        local index = houses
        local misses = 0
        while houses < want.houses and index < #anchors and misses < 40 do
            index = index + 1
            local roll = houses % 6
            local kind = "house_s"
            if houses == 0 or roll == 3 then kind = "house_m" end
            if want.large and roll == 1 then kind = "house_l" end
            local anchor = anchors[index]
            local project = put(kind, anchor[1], anchor[2], 9)
            if project ~= nil then
                houses = houses + 1
                added = added + Plan.driveway(camp, project)
            else
                misses = misses + 1
            end
        end
    end
    for i = Plan.countKind(camp, "farm") + 1, want.farms do
        local fx, fy, fr = Plan.anchorFor(camp, "farm", x2 - 7 - ((i - 1) % 2) * 7, y2 - 6 - math.floor((i - 1) / 2) * 5, 10)
        put("farm", fx, fy, fr)
    end
    local spots = Plan.towerSpots(camp, want.towers)
    for _, spot in ipairs(spots) do
        if Plan.countKind(camp, "tower", true) >= want.towers then break end
        if not Plan.towerNear(camp, spot[1], spot[2]) then put("tower", spot[1], spot[2], 3) end
    end
    local okStreets, streets = pcall(Plan.streets, camp)
    if okStreets and type(streets) == "number" then added = added + streets end
    if not okStreets then print("[ALifeCamp] streets failed: " .. tostring(streets)) end
    local okPaths, paths = pcall(Plan.paths, camp)
    if okPaths and type(paths) == "number" then added = added + paths end
    if not okPaths then print("[ALifeCamp] paths failed: " .. tostring(paths)) end
    local districts = ALifeCamp.Districts
    if districts ~= nil and type(districts.generate) == "function" then
        local ok, extra = pcall(districts.generate, camp)
        if ok and type(extra) == "number" then added = added + extra end
        if not ok then print("[ALifeCamp] districts failed: " .. tostring(extra)) end
    end
    local okPave, paved = pcall(Plan.pave, camp)
    if okPave and type(paved) == "number" then added = added + paved end
    if not okPave then print("[ALifeCamp] pave failed: " .. tostring(paved)) end
    if ALifeCamp.DESIGN_VERSION ~= nil then camp.designVer = ALifeCamp.DESIGN_VERSION end
    return added
end

function Plan.clearPlanned(camp)
    local removed = 0
    for key, project in pairs(Build.plan(camp).items) do
        if project.status == "planned" and project.stage == 1 and not project.paid then
            Build.plan(camp).items[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

function Plan.clearFill(camp)
    local items = Build.plan(camp).items
    local removed = 0
    for key, p in pairs(items) do
        if p.kind == "court" and not p.retired then
            if ALifeCamp.Site ~= nil then pcall(ALifeCamp.Site.clear, camp, p) end
            items[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

return Plan
