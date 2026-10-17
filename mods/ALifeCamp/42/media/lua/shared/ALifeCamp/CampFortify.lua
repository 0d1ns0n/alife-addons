require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local T = ALifeCamp.T

local Fortify = {}
ALifeCamp.Fortify = Fortify

Fortify.version = 1
Fortify.scanBudget = 400
Fortify.maxEntries = 160
Fortify.rescanHours = 0.25
Fortify.partialRounds = 3
Fortify.maxCarry = 60
Fortify.setupWork = 6
Fortify.plankWork = 2
Fortify.repairWork = 2
Fortify.fixWork = 2
Fortify.metalWork = 6
Fortify.nailsPerPlank = 2
Fortify.groundPlanks = 4
Fortify.watchPlanks = 2
Fortify.upperPlanks = 2
Fortify.postPlanks = 1
Fortify.doorPlanks = 4
Fortify.watchRadius = 3
Fortify.maxPosts = 8
Fortify.metalReserve = 10
Fortify.metalSheetCost = 2
Fortify.metalBarCost = 3
Fortify.metalCap = 6
Fortify.failLimit = 3
Fortify.homeSamples = 200

local function ask(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
end

local function squareKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function edgeKey(e)
    return e.x .. "," .. e.y .. "," .. e.z .. (e.n and "N" or "W")
end

local function baseOf(camp, rec)
    return rec.rect.z or camp.z or 0
end

local function signature(camp, rec)
    local r = rec.rect
    return table.concat({ r.x1, r.y1, r.x2, r.y2, baseOf(camp, rec), rec.floors or 1 }, ",")
end

local function blank(sig)
    return {
        v = Fortify.version, sig = sig, list = {}, posts = {}, weak = 0, carry = 0, planks = 0, rounds = 0,
        partial = true, scanning = true,
        scan = { i = 0, total = 0, done = false, unloaded = 0, seen = 0 },
    }
end

local function ensure(camp, rec, force)
    if type(rec) ~= "table" or type(rec.rect) ~= "table" then return nil end
    local sig = signature(camp, rec)
    local fort = rec.fortify
    if type(fort) == "table" and fort.v == Fortify.version and fort.sig == sig and type(fort.scan) == "table" and not force then
        return fort
    end
    local fresh = blank(sig)
    if type(fort) ~= "table" then
        rec.fortify = fresh
        return fresh
    end
    local keys = {}
    for key in pairs(fort) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do fort[key] = nil end
    for key, value in pairs(fresh) do fort[key] = value end
    return fort
end

local function indexOf(list)
    local map = {}
    for _, e in ipairs(list) do map[edgeKey(e)] = e end
    return map
end

local function kindOf(object)
    local kind
    pcall(function()
        if instanceof(object, "IsoWindow") then
            kind = "w"
        elseif instanceof(object, "IsoDoor") then
            kind = "d"
        elseif instanceof(object, "IsoThumpable") then
            if object:isDoor() == true then kind = "d" end
        elseif instanceof(object, "IsoWindowFrame") then
            if object:hasWindow() ~= true then kind = "f" end
        end
    end)
    return kind
end

local function northOf(object)
    return ask(function() return object:getNorth() end) == true
end

local function hasProperty(object, name)
    return ask(function() return object:getProperties():has(name) end) == true
end

local function barricadable(object)
    return ask(function() return object:isBarricadeAllowed() end) == true
end

local function sides(e)
    local fx, fy = e.x, e.y
    if e.n then fy = fy - 1 else fx = fx - 1 end
    if e.o then return fx, fy, e.x, e.y end
    return e.x, e.y, fx, fy
end

local function facing(e)
    if e.n then return e.o and "S" or "N" end
    return e.o and "E" or "W"
end

local function indoor(square, home)
    if square == nil then return false end
    if ask(function() return square:getRoom() end) ~= nil then return true end
    if home ~= nil and ask(function() return square:getBuilding() end) == home then return true end
    return false
end

local function homeBuilding(camp, rec)
    local r = rec.rect
    local z = baseOf(camp, rec)
    local counts, best, bestCount = {}, nil, 0
    local area = (r.x2 - r.x1 + 1) * (r.y2 - r.y1 + 1)
    local stride = math.max(1, math.ceil(math.sqrt(area / Fortify.homeSamples)))
    for x = r.x1, r.x2, stride do
        for y = r.y1, r.y2, stride do
            local square = World.square(x, y, z)
            if square ~= nil then
                local building = ask(function() return square:getBuilding() end)
                if building ~= nil then
                    local n = (counts[building] or 0) + 1
                    counts[building] = n
                    if n > bestCount then best, bestCount = building, n end
                end
            end
        end
    end
    return best
end

local function consider(ctx, square, object, x, y, z)
    local kind = kindOf(object)
    if kind == nil or World.tag(object) ~= nil then return end
    local fort = ctx.fort
    local north = northOf(object)
    local fx, fy = x, y
    if north then fy = fy - 1 else fx = fx - 1 end
    local far = World.square(fx, fy, z)
    local nearIn = indoor(square, ctx.home)
    local farIn = indoor(far, ctx.home)
    if nearIn == farIn then return end
    if far == nil and (z == ctx.base or World.square(fx, fy, ctx.base) == nil) then
        fort.scan.unloaded = fort.scan.unloaded + 1
        return
    end
    local inner = nearIn and square or far
    if ctx.home ~= nil then
        local building = ask(function() return inner:getBuilding() end)
        if building ~= nil and building ~= ctx.home then return end
    end
    if ctx.keep[squareKey(x, y, z)] then return end
    local e = { x = x, y = y, z = z, n = north, k = kind, o = not nearIn }
    if barricadable(object) then
        e.b = true
    else
        e.q = 1
        if hasProperty(object, "GarageDoorMiddle") or hasProperty(object, "GarageDoorRight") or hasProperty(object, "DoubleDoor2") then
            e.q = 0
        end
    end
    if kind == "d" and hasProperty(object, "GarageDoor") then e.g = true end
    local key = edgeKey(e)
    local old = ctx.map[key]
    if old ~= nil then
        old.k, old.o, old.b, old.q, old.g = e.k, e.o, e.b, e.q, e.g
        return
    end
    if #fort.list >= Fortify.maxEntries then
        fort.overflow = (fort.overflow or 0) + 1
        return
    end
    ctx.map[key] = e
    fort.list[#fort.list + 1] = e
end

local function scanSquare(ctx, square, x, y, z)
    local objects = ask(function() return square:getObjects() end)
    if objects == nil then return end
    local count = ask(function() return objects:size() end) or 0
    for i = 0, count - 1 do
        local object = ask(function() return objects:get(i) end)
        if object ~= nil then consider(ctx, square, object, x, y, z) end
    end
end

local function advanceScan(camp, rec, fort)
    local scan = fort.scan
    local r = rec.rect
    local base = baseOf(camp, rec)
    local floors = math.max(1, math.floor(tonumber(rec.floors) or 1))
    local width = r.x2 - r.x1 + 2
    local height = r.y2 - r.y1 + 2
    local layer = width * height
    local total = layer * floors
    scan.total = total
    local ctx = {
        fort = fort, base = base, home = homeBuilding(camp, rec), map = indexOf(fort.list),
        keep = type(rec.keep) == "table" and rec.keep or {},
    }
    local used = 0
    while scan.i < total and used < Fortify.scanBudget do
        local i = scan.i
        scan.i = i + 1
        used = used + 1
        local level = math.floor(i / layer)
        local rem = i - level * layer
        local z = base + level
        local x = r.x1 + rem % width
        local y = r.y1 + math.floor(rem / width)
        local square = World.square(x, y, z)
        if square ~= nil then
            if level == 0 then scan.seen = scan.seen + 1 end
            scanSquare(ctx, square, x, y, z)
        elseif level == 0 then
            scan.unloaded = scan.unloaded + 1
        end
    end
    fort.lastScan = used
    if scan.i >= total then
        scan.done = true
        scan.at = Store.hours()
        fort.rounds = (fort.rounds or 0) + 1
        fort.partial = scan.unloaded > 0
        fort.scanning = false
    else
        fort.partial = true
        fort.scanning = true
    end
end

local function restartScan(fort)
    fort.scan = { i = 0, total = fort.scan.total or 0, done = false, unloaded = 0, seen = 0 }
    fort.scanning = true
end

local function wantsRescan(fort)
    if not fort.scan.done or fort.partial ~= true then return false end
    if (fort.rounds or 0) >= Fortify.partialRounds and (fort.scan.seen or 0) > 0 then return false end
    return Store.hours() - (fort.scan.at or 0) >= Fortify.rescanHours
end

local function locate(e)
    local square = World.square(e.x, e.y, e.z)
    if square == nil then return nil, false end
    local found, frame
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local kind = kindOf(object)
            if kind ~= nil and World.tag(object) == nil and northOf(object) == e.n then
                if e.k == "d" then
                    if kind == "d" then
                        found = object
                        return
                    end
                elseif kind == "w" then
                    found = object
                    return
                elseif kind == "f" then
                    frame = frame or object
                end
            end
        end
    end)
    return found or frame, true
end

local function barricadeOn(object, opposite)
    return ask(function()
        if opposite then return object:getBarricadeOnOppositeSquare() end
        return object:getBarricadeOnSameSquare()
    end)
end

local function planksOf(barricade)
    if barricade == nil then return 0 end
    return ask(function() return barricade:getNumPlanks() end) or 0
end

local function metalOf(barricade)
    if barricade == nil then return 0 end
    if ask(function() return barricade:isMetal() end) == true then return 1 end
    if ask(function() return barricade:isMetalBar() end) == true then return 2 end
    return 0
end

local function read(e)
    local object, loaded = locate(e)
    if not loaded then
        e.u = true
        return false
    end
    e.u = nil
    if object == nil then
        e.gone = true
        e.h, e.m, e.ob, e.sm = 0, 0, nil, nil
        return true
    end
    e.gone = nil
    e.k = kindOf(object) or e.k
    local inner = barricadeOn(object, e.o == true)
    e.h = planksOf(inner)
    e.m = metalOf(inner)
    if e.k == "d" then
        local outer = barricadeOn(object, e.o ~= true)
        e.ob = (planksOf(outer) > 0 or metalOf(outer) > 0) or nil
        e.lk = (ask(function() return object:isLocked() end) == true or ask(function() return object:isLockedByKey() end) == true) or nil
        e.op = ask(function() return object:IsOpen() end) == true or nil
        local health = ask(function() return object:getHealth() end)
        local limit = ask(function() return object:getMaxHealth() end)
        e.dm = (health ~= nil and limit ~= nil and health < limit) or nil
    elseif e.k == "w" then
        e.sm = ask(function() return object:isSmashed() end) == true or nil
    end
    return true
end

local function judge(e)
    if e.u then return end
    if e.bad then
        e.d = true
        return
    end
    if e.gone or e.r == "x" then
        e.d = true
    elseif e.r == "l" then
        e.d = (e.lk == true and e.op ~= true) or false
    elseif e.r == "e" then
        e.d = ((e.h or 0) == 0 and (e.m or 0) == 0 and e.ob ~= true and e.lk ~= true and e.op ~= true
            and (e.dm ~= true or e.rp == true)) or false
    else
        local strong = (e.m or 0) > 0 or (e.h or 0) >= (e.t or 0)
        e.d = (strong and e.sm ~= true) or false
    end
    if e.d then e.fail = nil end
end

local function distance2(e, x, y)
    if x == nil then return 0 end
    local ix, iy = sides(e)
    return (ix - x) * (ix - x) + (iy - y) * (iy - y)
end

local function hintOf(camp, rec)
    local hint = rec.entrance
    if type(hint) == "table" and type(hint.x) == "number" and type(hint.y) == "number" then return hint.x, hint.y end
    if type(camp.x1) == "number" and type(camp.x2) == "number" and type(camp.y1) == "number" and type(camp.y2) == "number" then
        return Geo.center(camp)
    end
    return Geo.center(rec.rect)
end

local function chooseEntrance(fort, base, hx, hy)
    local map = indexOf(fort.list)
    if fort.started and fort.entranceKey ~= nil then
        local kept = map[fort.entranceKey]
        if kept ~= nil and kept.k == "d" and kept.gone ~= true then return kept end
    end
    local level
    for _, e in ipairs(fort.list) do
        if e.k == "d" and e.g ~= true and e.gone ~= true then
            if e.z == base then
                level = base
                break
            end
            if level == nil or e.z < level then level = e.z end
        end
    end
    if level == nil then return nil end
    local best, bestScore, bestKey
    for _, e in ipairs(fort.list) do
        if e.k == "d" and e.g ~= true and e.gone ~= true and e.z == level then
            local _, _, ox, oy = sides(e)
            local score = (ox - hx) * (ox - hx) + (oy - hy) * (oy - hy)
            local key = edgeKey(e)
            if best == nil or score < bestScore or (score == bestScore and key < bestKey) then
                best, bestScore, bestKey = e, score, key
            end
        end
    end
    return best
end

local function assign(fort, base, entrance)
    local eix, eiy
    if entrance ~= nil then eix, eiy = sides(entrance) end
    for _, e in ipairs(fort.list) do
        e.p, e.w = nil, nil
        if e == entrance then
            e.r, e.t = "e", 0
        elseif e.k == "d" then
            if e.b == true then e.r, e.t = "s", Fortify.doorPlanks else e.r, e.t = "l", 0 end
        elseif e.b ~= true then
            e.r, e.t = "x", 0
        elseif e.z == base then
            local near = false
            if entrance ~= nil and e.z == entrance.z then
                local ix, iy = sides(e)
                near = math.max(math.abs(ix - eix), math.abs(iy - eiy)) <= Fortify.watchRadius
            end
            e.r = "g"
            e.t = near and Fortify.watchPlanks or Fortify.groundPlanks
            if near then e.w = true end
        else
            e.r, e.t = "u", Fortify.upperPlanks
        end
    end
end

local function freeSquare(square)
    return ask(function() return square:isFree(false) end) == true
end

local function standPoint(rec, e)
    local ix, iy = sides(e)
    local keep = type(rec.keep) == "table" and rec.keep or {}
    local inner = World.square(ix, iy, e.z)
    if inner == nil then return ix, iy end
    if not keep[squareKey(ix, iy, e.z)] and freeSquare(inner) then return ix, iy end
    local room = ask(function() return inner:getRoom() end)
    if room == nil then return ix, iy end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nx, ny = ix + d[1], iy + d[2]
        local square = World.square(nx, ny, e.z)
        if square ~= nil and not keep[squareKey(nx, ny, e.z)] and ask(function() return square:getRoom() end) == room
                and freeSquare(square) then
            return nx, ny
        end
    end
    return ix, iy
end

local bucketOrder = { "N", "E", "S", "W" }
local bucketVector = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }

local function choosePosts(rec, fort, entrance, hx, hy)
    local posts, seen = {}, {}
    local eix, eiy
    if entrance ~= nil then eix, eiy = sides(entrance) end
    local watch, upper = {}, {}
    for _, e in ipairs(fort.list) do
        if e.b == true and e.k ~= "d" then
            if e.r == "g" and e.w == true then
                watch[#watch + 1] = e
            elseif e.r == "u" then
                upper[#upper + 1] = e
            end
        end
    end
    table.sort(watch, function(a, b)
        local da, db = distance2(a, eix, eiy), distance2(b, eix, eiy)
        if da ~= db then return da < db end
        return edgeKey(a) < edgeKey(b)
    end)
    local function add(e)
        if #posts >= Fortify.maxPosts then return end
        local px, py = standPoint(rec, e)
        local key = squareKey(px, py, e.z)
        if seen[key] then return end
        seen[key] = true
        posts[#posts + 1] = { x = px, y = py, z = e.z, d = facing(e) }
        e.p = true
    end
    if watch[1] ~= nil then add(watch[1]) end
    if #upper == 0 then
        for i = 2, #watch do add(watch[i]) end
    end
    local buckets = { N = {}, E = {}, S = {}, W = {} }
    for _, e in ipairs(upper) do
        local bucket = buckets[facing(e)]
        bucket[#bucket + 1] = e
    end
    local r = rec.rect
    local vx, vy = hx - (r.x1 + r.x2) / 2, hy - (r.y1 + r.y2) / 2
    local names = {}
    for _, name in ipairs(bucketOrder) do
        if #buckets[name] > 0 then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        local sa = vx * bucketVector[a][1] + vy * bucketVector[a][2]
        local sb = vx * bucketVector[b][1] + vy * bucketVector[b][2]
        if sa ~= sb then return sa > sb end
        return a < b
    end)
    local queues = {}
    for _, name in ipairs(names) do
        local list = buckets[name]
        table.sort(list, function(a, b) return edgeKey(a) < edgeKey(b) end)
        local mid = math.ceil(#list / 2)
        local queue = { list[mid] }
        for i, e in ipairs(list) do
            if i ~= mid then queue[#queue + 1] = e end
        end
        queues[name] = queue
    end
    local moved = true
    while moved and #posts < Fortify.maxPosts do
        moved = false
        for _, name in ipairs(names) do
            local e = table.remove(queues[name], 1)
            if e ~= nil then
                moved = true
                add(e)
            end
        end
    end
    return posts
end

local function assignStyle(camp, fort, entrance)
    local budget = ((camp.stock and camp.stock.metal) or 0) - Fortify.metalReserve
    local eix, eiy
    if entrance ~= nil then eix, eiy = sides(entrance) end
    local fresh = {}
    for _, e in ipairs(fort.list) do
        if e.s == nil then
            e.s = "p"
            if (e.h or 0) == 0 and (e.m or 0) == 0 then fresh[#fresh + 1] = e end
        end
    end
    table.sort(fresh, function(a, b)
        local da, db = distance2(a, eix, eiy), distance2(b, eix, eiy)
        if da ~= db then return da > db end
        return edgeKey(a) < edgeKey(b)
    end)
    local used = 0
    for _, e in ipairs(fresh) do
        if used >= Fortify.metalCap or budget < Fortify.metalSheetCost then break end
        if e.r == "g" and e.w ~= true then
            e.s = "s"
            budget = budget - Fortify.metalSheetCost
            used = used + 1
        end
    end
    for _, e in ipairs(fresh) do
        if used >= Fortify.metalCap or budget < Fortify.metalBarCost then break end
        if e.s == "p" and e.p == true then
            e.s = "b"
            budget = budget - Fortify.metalBarCost
            used = used + 1
        end
    end
end

local function priority(e, base)
    if e.r == "s" then return e.z == base and 1 or 3 end
    if e.r == "g" then return 2 end
    if e.r == "u" then return 4 end
    if e.r == "l" then return 5 end
    if e.r == "e" then return 6 end
    return 9
end

local function sortList(fort, base)
    table.sort(fort.list, function(a, b)
        local pa, pb = priority(a, base), priority(b, base)
        if pa ~= pb then return pa < pb end
        return edgeKey(a) < edgeKey(b)
    end)
end

local function weakOf(fort)
    local n = fort.overflow or 0
    for _, e in ipairs(fort.list) do
        if e.r ~= "e" then
            if e.b ~= true then
                n = n + (e.q or 0)
            elseif e.bad or e.gone then
                n = n + 1
            end
        end
    end
    return n
end

local function plan(camp, rec, fort, base, hx, hy)
    local entrance = chooseEntrance(fort, base, hx, hy)
    if entrance ~= nil then
        local ix, iy, ox, oy = sides(entrance)
        fort.entrance = { x = entrance.x, y = entrance.y, z = entrance.z, n = entrance.n, ix = ix, iy = iy, ox = ox, oy = oy }
        fort.entranceKey = edgeKey(entrance)
    else
        fort.entrance = nil
        fort.entranceKey = nil
    end
    assign(fort, base, entrance)
    fort.posts = choosePosts(rec, fort, entrance, hx, hy)
    for _, e in ipairs(fort.list) do
        if e.p == true and e.r == "u" then e.t = Fortify.postPlanks end
    end
    assignStyle(camp, fort, entrance)
    sortList(fort, base)
    fort.weak = weakOf(fort)
end

local function needs(fort, e)
    if e.d then return 0, 0, 0 end
    local work = 0
    if fort.setup ~= edgeKey(e) then work = Fortify.setupWork end
    if e.sm then work = work + Fortify.repairWork end
    if e.r == "e" then return 0, 0, work + Fortify.fixWork end
    if e.r == "l" then return 0, 0, work end
    if (e.h or 0) == 0 and (e.m or 0) == 0 then
        if e.s == "s" then return 0, Fortify.metalSheetCost, work + Fortify.metalWork end
        if e.s == "b" then return 0, Fortify.metalBarCost, work + Fortify.metalWork end
    end
    local planks = math.max(0, (e.t or 0) - (e.h or 0))
    return planks, 0, work + planks * Fortify.plankWork
end

local function totals(fort)
    local planks, metal, work = 0, 0, 0
    for _, e in ipairs(fort.list) do
        local p, m, w = needs(fort, e)
        planks, metal, work = planks + p, metal + m, work + w
    end
    local cost = {}
    if planks > 0 then
        cost.planks = planks
        cost.nails = planks * Fortify.nailsPerPlank
    end
    if metal > 0 then cost.metal = metal end
    return cost, work
end

local function settle(fort)
    local open
    for index, e in ipairs(fort.list) do
        if not e.d or e.u then
            open = index
            break
        end
    end
    fort.cur = open or (#fort.list + 1)
    local trusted = fort.partial ~= true or ((fort.rounds or 0) >= Fortify.partialRounds and (fort.scan.seen or 0) > 0)
    fort.done = open == nil and fort.scan.done == true and trusted and (fort.scan.seen or 0) > 0
    return fort.done
end

local function finalize(camp, rec, fort)
    local base = baseOf(camp, rec)
    for _, e in ipairs(fort.list) do read(e) end
    local hx, hy = hintOf(camp, rec)
    plan(camp, rec, fort, base, hx, hy)
    local planks = 0
    for _, e in ipairs(fort.list) do
        judge(e)
        planks = planks + (e.h or 0)
    end
    fort.planks = planks
    settle(fort)
end

local function units(e)
    if e.r == "e" then return 2 end
    if e.r == "l" then return 1 end
    if e.r == "x" or e.gone then return 0 end
    return 1 + (e.t or 0)
end

local function progressOf(fort)
    if fort.done then return 1 end
    if not fort.scan.done then
        local total = math.max(1, fort.scan.total or 1)
        return 0.1 * math.min(1, fort.scan.i / total)
    end
    local total, got = 0, 0
    for _, e in ipairs(fort.list) do
        local u = units(e)
        total = total + u
        if e.d then
            got = got + u
        else
            got = got + math.min(e.h or 0, e.t or 0)
        end
    end
    if total <= 0 then return 0.1 end
    return 0.1 + 0.9 * (got / total)
end

local function available(camp, kind)
    return (camp.stock and camp.stock[kind]) or 0
end

local function refund(camp, planks, nails, metal)
    if planks > 0 then Stock.deposit(camp, "Base.Plank", planks) end
    if nails > 0 then Stock.deposit(camp, "Base.Nails", nails) end
    if metal > 0 then Stock.deposit(camp, "Base.ScrapMetal", metal) end
end

local function newBarricade(object, opposite)
    local barricade
    pcall(function() barricade = IsoBarricade.AddBarricadeToObject(object, opposite) end)
    return barricade
end

local function dropIfEmpty(barricade)
    if planksOf(barricade) > 0 or metalOf(barricade) > 0 then return end
    pcall(function() barricade:getSquare():transmitRemoveItemFromSquare(barricade) end)
end

local function addPlank(object, e)
    local barricade = newBarricade(object, e.o == true)
    if barricade == nil then return false end
    local before = planksOf(barricade)
    local item
    pcall(function() item = instanceItem("Base.Plank") end)
    pcall(function() barricade:addPlank(nil, item) end)
    if planksOf(barricade) <= before then pcall(function() barricade:addPlank(nil, nil) end) end
    if planksOf(barricade) <= before then
        dropIfEmpty(barricade)
        return false
    end
    pcall(function() barricade:transmitCompleteItemToClients() end)
    return true
end

local function addMetal(object, e, bars)
    local barricade = newBarricade(object, e.o == true)
    if barricade == nil then return false end
    pcall(function()
        if bars then barricade:addMetalBar(nil, nil) else barricade:addMetal(nil, nil) end
    end)
    local want = bars and 2 or 1
    if metalOf(barricade) ~= want then
        dropIfEmpty(barricade)
        return false
    end
    pcall(function() barricade:transmitCompleteItemToClients() end)
    return true
end

local function clearBarricade(object, opposite)
    local barricade = barricadeOn(object, opposite)
    if barricade == nil then return 0, 0 end
    local planks, sheets = 0, 0
    for _ = 1, 6 do
        local before = planksOf(barricade)
        if before <= 0 then break end
        pcall(function() barricade:removePlank(nil) end)
        if planksOf(barricade) >= before then break end
        planks = planks + 1
    end
    local metal = metalOf(barricade)
    if metal == 1 then
        pcall(function() barricade:removeMetal(nil) end)
        if metalOf(barricade) == 0 then sheets = 1 end
    elseif metal == 2 then
        pcall(function() barricade:removeMetalBar(nil) end)
    end
    dropIfEmpty(barricade)
    return planks, sheets
end

local function repairWindow(object)
    pcall(function() object:setSmashed(false) end)
    if ask(function() return object:isGlassRemoved() end) == true then
        pcall(function() object:setGlassRemoved(false) end)
    end
    pcall(function() object:getSquare():removeGlassAttachments(object) end)
end

local function closeDoor(object)
    if ask(function() return object:IsOpen() end) == true then
        pcall(function() object:ToggleDoorSilent() end)
    end
end

local function failed(fort, e)
    e.fail = (e.fail or 0) + 1
    if e.fail >= Fortify.failLimit then
        e.d, e.bad = true, true
        fort.weak = weakOf(fort)
    end
    return "failed"
end

local function finishEntry(fort, e)
    judge(e)
    if e.d then
        fort.setup = nil
        return "done"
    end
    return failed(fort, e)
end

local function openEntrance(camp, fort, e, object, ctx)
    if fort.carry < Fortify.fixWork then return "labor" end
    fort.carry = fort.carry - Fortify.fixWork
    ctx.spent = ctx.spent + Fortify.fixWork
    local planks, sheets = 0, 0
    for _, opposite in ipairs({ e.o == true, e.o ~= true }) do
        local p, s = clearBarricade(object, opposite)
        planks, sheets = planks + p, sheets + s
    end
    if planks > 0 then Stock.deposit(camp, "Base.Plank", planks) end
    if sheets > 0 then Stock.deposit(camp, "Base.SheetMetal", sheets) end
    ctx.refunded = ctx.refunded + planks
    pcall(function() object:setLockedByKey(false) end)
    pcall(function() object:setIsLocked(false) end)
    closeDoor(object)
    local health = ask(function() return object:getMaxHealth() end)
    if health ~= nil then pcall(function() object:setHealth(health) end) end
    e.rp = true
    read(e)
    return finishEntry(fort, e)
end

local function lockDoor(fort, e, object)
    closeDoor(object)
    pcall(function() object:setLockedByKey(true) end)
    read(e)
    return finishEntry(fort, e)
end

local function seal(camp, fort, e, object, ctx)
    if e.k == "d" then closeDoor(object) end
    if (e.m or 0) == 0 and (e.h or 0) == 0 and (e.s == "s" or e.s == "b") then
        local bars = e.s == "b"
        local cost = bars and Fortify.metalBarCost or Fortify.metalSheetCost
        if available(camp, "metal") >= cost then
            if fort.carry < Fortify.metalWork then return "labor" end
            local got = Stock.consume(camp, "metal", cost)
            if got < cost then
                refund(camp, 0, 0, got)
                e.s = "p"
            elseif addMetal(object, e, bars) then
                fort.carry = fort.carry - Fortify.metalWork
                ctx.spent = ctx.spent + Fortify.metalWork
                ctx.metal = ctx.metal + cost
                read(e)
                return finishEntry(fort, e)
            else
                refund(camp, 0, 0, got)
                e.s = "p"
            end
        else
            e.s = "p"
        end
    end
    while (e.h or 0) < (e.t or 0) do
        if fort.carry < Fortify.plankWork then return "labor" end
        if available(camp, "planks") < 1 or available(camp, "nails") < Fortify.nailsPerPlank then return "stock" end
        local planks = Stock.consume(camp, "planks", 1)
        local nails = Stock.consume(camp, "nails", Fortify.nailsPerPlank)
        if planks < 1 or nails < Fortify.nailsPerPlank then
            refund(camp, planks, nails, 0)
            return "stock"
        end
        if not addPlank(object, e) then
            refund(camp, planks, nails, 0)
            return failed(fort, e)
        end
        fort.carry = fort.carry - Fortify.plankWork
        ctx.spent = ctx.spent + Fortify.plankWork
        ctx.planks = ctx.planks + 1
        ctx.nails = ctx.nails + nails
        local before = e.h or 0
        read(e)
        if (e.h or 0) <= before then return failed(fort, e) end
    end
    return finishEntry(fort, e)
end

local function process(camp, fort, e, ctx)
    if not read(e) then return "unloaded" end
    judge(e)
    if e.d then return "done" end
    local object = locate(e)
    if object == nil then
        e.d = true
        return "done"
    end
    local key = edgeKey(e)
    if fort.setup ~= key then
        if fort.carry < Fortify.setupWork then return "labor" end
        fort.carry = fort.carry - Fortify.setupWork
        ctx.spent = ctx.spent + Fortify.setupWork
        fort.setup = key
        fort.started = true
    end
    if e.sm then
        if fort.carry < Fortify.repairWork then return "labor" end
        fort.carry = fort.carry - Fortify.repairWork
        ctx.spent = ctx.spent + Fortify.repairWork
        repairWindow(object)
        read(e)
        if e.sm then return failed(fort, e) end
    end
    if e.r == "e" then return openEntrance(camp, fort, e, object, ctx) end
    if e.r == "l" then return lockDoor(fort, e, object) end
    return seal(camp, fort, e, object, ctx)
end

local function shortfall(camp, fort)
    local cost = totals(fort)
    local out = {}
    for _, kind in ipairs({ "planks", "nails" }) do
        local lack = (cost[kind] or 0) - available(camp, kind)
        if lack > 0 then out[kind] = lack end
    end
    if ALifeCamp.isEmpty(out) then out.planks = 1 end
    return out
end

function Fortify.analyze(camp, rec, force)
    local fort = ensure(camp, rec, force)
    if fort == nil then return {}, 0 end
    if wantsRescan(fort) then restartScan(fort) end
    if not fort.scan.done then advanceScan(camp, rec, fort) end
    if fort.scan.done then finalize(camp, rec, fort) end
    return totals(fort)
end

function Fortify.step(camp, rec, labor, minutes)
    local fort = ensure(camp, rec, false)
    if fort == nil then return true, 1, 0, nil end
    if not fort.scan.done or wantsRescan(fort) then
        if fort.scan.done then restartScan(fort) end
        advanceScan(camp, rec, fort)
        if not fort.scan.done then return false, progressOf(fort), 0, nil end
        finalize(camp, rec, fort)
    end
    fort.waiting = nil
    if fort.done then return true, 1, 0, nil end
    labor = tonumber(labor) or 0
    minutes = tonumber(minutes) or 0
    if labor <= 0 or minutes <= 0 then return false, progressOf(fort), 0, nil end
    fort.carry = math.min(Fortify.maxCarry, (fort.carry or 0) + labor * minutes)
    local ctx = { spent = 0, planks = 0, nails = 0, metal = 0, refunded = 0 }
    local stalled = false
    for index = fort.cur or 1, #fort.list do
        local e = fort.list[index]
        if not e.d then
            local status = process(camp, fort, e, ctx)
            if status == "labor" then
                break
            elseif status == "stock" then
                stalled = true
                break
            end
        end
    end
    local planks = 0
    for _, e in ipairs(fort.list) do planks = planks + (e.h or 0) end
    fort.planks = planks
    fort.weak = weakOf(fort)
    settle(fort)
    fort.last = { planks = ctx.planks, nails = ctx.nails, metal = ctx.metal, work = ctx.spent, refunded = ctx.refunded }
    local paid = fort.paid or { planks = 0, nails = 0, metal = 0 }
    paid.planks, paid.nails, paid.metal = paid.planks + ctx.planks, paid.nails + ctx.nails, paid.metal + ctx.metal
    fort.paid = paid
    if stalled then fort.waiting = shortfall(camp, fort) end
    if fort.done then return true, 1, ctx.spent, nil end
    return false, progressOf(fort), ctx.spent, fort.waiting
end

function Fortify.summary(rec)
    local fort = type(rec) == "table" and rec.fortify or nil
    if type(fort) ~= "table" then
        return { openings = 0, done = 0, planks = 0, weak = 0, posts = 0, entrance = false }
    end
    local done = 0
    local list = type(fort.list) == "table" and fort.list or {}
    for _, e in ipairs(list) do
        if e.d then done = done + 1 end
    end
    return {
        openings = #list, done = done, planks = fort.planks or 0, weak = fort.weak or 0,
        posts = type(fort.posts) == "table" and #fort.posts or 0, entrance = fort.entrance ~= nil,
    }
end

function Fortify.describe(rec)
    local fort = type(rec) == "table" and rec.fortify or nil
    if type(fort) ~= "table" or type(fort.scan) ~= "table" or not fort.scan.done then return T("FortifyScan") end
    local s = Fortify.summary(rec)
    if type(fort.waiting) == "table" then return T("FortifyWait", fort.waiting.planks or 0, fort.waiting.nails or 0) end
    if fort.done then return T("FortifyDone", s.openings, s.planks, s.weak) end
    return T("FortifyProgress", s.done, s.openings)
end

function Fortify.reset(rec)
    if type(rec) == "table" then rec.fortify = nil end
end

return Fortify
