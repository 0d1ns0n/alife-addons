require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"

ALifeCamp = ALifeCamp or {}

local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Place = ALifeCamp.Place
local Bp = ALifeCamp.Blueprints
local Entities = ALifeCamp.Entities

local Fitout = {}
ALifeCamp.Fitout = Fitout

Fitout.version = 1
Fitout.scanBudget = 400
Fitout.roomBudget = 2
Fitout.maxCells = 700
Fitout.retries = 3
Fitout.minSeats = 3
Fitout.maxBeds = 16
Fitout.maxPosts = 2
Fitout.maxCarry = 12
Fitout.kinds = { "dorm", "common", "mess", "infirmary", "workshop", "guard" }
Fitout.runs = {}
Fitout.cache = {}

local STRIDE = 32768
local DELTA = { -STRIDE, 1, STRIDE, -1 }
local OPPOSITE = { 3, 4, 1, 2 }
local DIRNAME = { "N", "E", "S", "W" }
local DX = { 0, 1, 0, -1 }
local DY = { -1, 0, 1, 0 }

local roleKeys = {
    dorm = "Room_dorm", common = "Room_common", mess = "Room_mess",
    infirmary = "Room_infirmary", workshop = "Room_workshop", guard = "Room_guard",
}

local kindRank = { dorm = 1, guard = 2, infirmary = 3, common = 4, mess = 5, workshop = 6, none = 9 }

local classRules = {
    { "bath", "bath" }, { "toilet", "bath" }, { "restroom", "bath" }, { "shower", "bath" }, { "washroom", "bath" },
    { "kitchen", "kitchen" },
    { "dining", "dining" },
    { "living", "living" }, { "lounge", "living" }, { "cinema", "living" }, { "recreation", "living" },
    { "sitting", "living" }, { "sunroom", "living" },
    { "hall", "hall" }, { "foyer", "hall" }, { "corridor", "hall" }, { "lobby", "hall" },
    { "bed", "bed" }, { "dorm", "bed" }, { "attic", "bed" },
    { "garage", "work" }, { "workshop", "work" }, { "laundry", "work" }, { "shed", "work" },
    { "tool", "work" }, { "utility", "work" },
    { "basement", "basement" }, { "cellar", "basement" },
    { "storage", "store" }, { "closet", "store" }, { "pantry", "store" },
    { "office", "office" }, { "study", "office" }, { "library", "office" },
}

local commonRank = { living = 1, hall = 2, office = 3 }

local function try(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function lowerName(value)
    return string.lower(tostring(value or ""))
end

local function key(x, y, z)
    return ((z + 8) * STRIDE + y) * STRIDE + x
end

local function unkey(k)
    local x = k % STRIDE
    local rest = (k - x) / STRIDE
    local y = rest % STRIDE
    return x, y, (rest - y) / STRIDE - 8
end

local function xy(k)
    return k % STRIDE, math.floor(k / STRIDE) % STRIDE
end

local function classify(name)
    for i = 1, #classRules do
        if string.find(name, classRules[i][1], 1, true) ~= nil then return classRules[i][2] end
    end
    return "other"
end

local function faceSprite(entityId, face)
    local entity = Entities[entityId]
    local rows = entity ~= nil and entity.faces ~= nil and entity.faces[face] or nil
    local row = rows ~= nil and rows[1] or nil
    return row ~= nil and row[1] or nil
end

local function facings(entityId)
    local out = {}
    local names = { "N", "E", "S", "W" }
    for i = 1, 4 do
        out[i] = faceSprite(entityId, names[i])
        if out[i] == nil then return nil end
    end
    return out
end

local function twoTile(entityId)
    local entity = Entities[entityId]
    if entity == nil or entity.faces == nil then return nil end
    local south = entity.faces.S ~= nil and entity.faces.S[1] or nil
    local east = entity.faces.E
    if south == nil or south[2] == nil or east == nil or east[1] == nil or east[2] == nil then return nil end
    return { H = { south[1], south[2] }, V = { east[1][1], east[2][1] } }
end

local function benchSprites()
    local first = Bp.sprites ~= nil and Bp.sprites.bench ~= nil and Bp.sprites.bench[1] or nil
    if first == nil then return nil end
    local prefix, index = string.match(first, "^(.-)(%d+)$")
    if prefix == nil then return nil end
    local base = tonumber(index)
    local function name(offset) return prefix .. (base + offset) end
    return { { name(4), name(5) }, { name(3), name(2) }, { name(0), name(1) }, { name(7), name(6) } }
end

local CAT = {}

local function buildCatalog()
    CAT.bed = twoTile("Wood_Bed")
    if CAT.bed ~= nil then CAT.bed.e = "Wood_Bed" end
    CAT.table = twoTile("Wood_TableLvl1")
    if CAT.table ~= nil then CAT.table.e = "Wood_TableLvl1" end
    CAT.chair = facings("Wood_Chair_Lvl1")
    CAT.shelf = facings("Wood_Shelves_Lvl1")
    CAT.bench = benchSprites()
    local c1, c2 = faceSprite("Wood_Crate_Lvl1", "S"), faceSprite("Wood_Crate_Lvl2", "S")
    CAT.crate1 = c1 ~= nil and { e = "Wood_Crate_Lvl1", sprite = c1 } or nil
    CAT.crate2 = c2 ~= nil and { e = "Wood_Crate_Lvl2", sprite = c2 } or nil
end

buildCatalog()

Fitout.catalog = CAT

local pieceCodes = { bed = "b", table = "t", seat = "s", crate = "c", shelf = "h" }

local function newPiece(kind, e, cells, sprites, extra)
    local piece = { kind = kind, e = e, cells = cells, sprites = sprites, access = true, code = pieceCodes[kind] }
    if extra ~= nil then
        for name, value in pairs(extra) do piece[name] = value end
    end
    piece.set = {}
    for i = 1, #cells do piece.set[cells[i]] = true end
    return piece
end

local function hasFloor(sq)
    local value
    local ok = pcall(function() value = sq:hasFloor() end)
    if not ok then pcall(function() value = sq:getFloor() ~= nil end) end
    return value == true
end

local function blockingObject(object)
    local blocked = false
    pcall(function()
        local sprite = object:getSprite()
        if sprite == nil then return end
        local props = sprite:getProperties()
        if props ~= nil and props:has("BlocksPlacement") == true then blocked = true end
    end)
    return blocked
end

local function squareFree(sq)
    local free = false
    pcall(function() free = sq:isFree(false) == true end)
    if not free then return false end
    local blocked = false
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            if blockingObject(objects:get(i)) then
                blocked = true
                return
            end
        end
    end)
    return not blocked
end

local function openingKind(object)
    local kind
    pcall(function()
        if instanceof(object, "IsoDoor") then
            kind = "door"
        elseif instanceof(object, "IsoWindow") or instanceof(object, "IsoWindowFrame") then
            kind = "window"
        elseif instanceof(object, "IsoThumpable") then
            if object:isDoor() == true then
                kind = "door"
            elseif object:isWindowN() == true or object:isWindowW() == true then
                kind = "window"
            end
        end
    end)
    return kind
end

local function openingsOf(sq)
    local north, west
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local kind = openingKind(object)
            if kind ~= nil then
                local isNorth
                pcall(function() isNorth = object:getNorth() end)
                local code = kind == "door" and 2 or 3
                if isNorth == true then
                    if north ~= 2 then north = code end
                elseif isNorth == false then
                    if west ~= 2 then west = code end
                end
            end
        end
    end)
    return north, west
end

local function wallBetween(a, b)
    local value = try(function() return a:isWallTo(b) end)
    if value == false then return 0 end
    return 1
end

local function edgeAt(run, k, d)
    if d == 1 then
        local o = run.oN[k]
        if o ~= nil then return o end
        return run.wS[k - STRIDE] or 1
    elseif d == 2 then
        local o = run.oW[k + 1]
        if o ~= nil then return o end
        return run.wE[k] or 1
    elseif d == 3 then
        local o = run.oN[k + STRIDE]
        if o ~= nil then return o end
        return run.wS[k] or 1
    end
    local o = run.oW[k]
    if o ~= nil then return o end
    return run.wE[k - 1] or 1
end

local function passable(run, k, d)
    local e = edgeAt(run, k, d)
    return e == 0 or e == 2
end

local function wallWeight(R, k, d)
    local e = edgeAt(R.run, k, d)
    if e == 1 then return 1 end
    if e == 3 then return 0.4 end
    return 0
end

local function link(R, k, d)
    local nk = k + DELTA[d]
    if R.st[nk] == nil then return nil end
    if not passable(R.run, k, d) then return nil end
    return nk
end

local function walkable(R, k)
    local s = R.st[k]
    return s == 1 or s == 2
end

local function flood(R, sources)
    local seen = {}
    local queue = {}
    local comp = 0
    for s = 1, #sources do
        local start = sources[s]
        if seen[start] == nil and walkable(R, start) then
            comp = comp + 1
            seen[start] = comp
            local head, tail = 1, 1
            queue[1] = start
            while head <= tail do
                local k = queue[head]
                head = head + 1
                for d = 1, 4 do
                    local nk = link(R, k, d)
                    if nk ~= nil and seen[nk] == nil and walkable(R, nk) then
                        seen[nk] = comp
                        tail = tail + 1
                        queue[tail] = nk
                    end
                end
            end
        end
    end
    return seen
end

local function reachOk(R)
    local seen = flood(R, R.sources)
    if R.main ~= nil then
        local id = seen[R.main]
        if id == nil then return false end
        for i = 1, #R.must do
            if seen[R.must[i]] ~= id then return false end
        end
    end
    for i = 1, #R.needFix do
        local k = R.needFix[i]
        local ok = false
        for d = 1, 4 do
            local nk = link(R, k, d)
            if nk ~= nil and seen[nk] ~= nil then
                ok = true
                break
            end
        end
        if not ok then return false end
    end
    for i = 1, #R.pieces do
        local p = R.pieces[i]
        if p.access then
            local ok = false
            for j = 1, #p.cells do
                local c = p.cells[j]
                for d = 1, 4 do
                    local nk = link(R, c, d)
                    if nk ~= nil and not p.set[nk] and seen[nk] ~= nil then
                        ok = true
                        break
                    end
                end
                if ok then break end
            end
            if not ok then return false end
        end
    end
    return true
end

local function commit(R, piece)
    for i = 1, #piece.cells do
        if R.st[piece.cells[i]] ~= 1 then return false end
    end
    for i = 1, #piece.cells do
        R.st[piece.cells[i]] = 4
        R.at[piece.cells[i]] = piece
    end
    R.pieces[#R.pieces + 1] = piece
    if reachOk(R) then return true end
    R.pieces[#R.pieces] = nil
    for i = 1, #piece.cells do
        R.st[piece.cells[i]] = 1
        R.at[piece.cells[i]] = nil
    end
    return false
end

local function snapshot(R)
    local st, at = {}, {}
    for k, v in pairs(R.st) do st[k] = v end
    for k, v in pairs(R.at) do at[k] = v end
    return { st = st, at = at, pieces = #R.pieces, must = #R.must }
end

local function restore(R, snap)
    local st, at = {}, {}
    for k, v in pairs(snap.st) do st[k] = v end
    for k, v in pairs(snap.at) do at[k] = v end
    R.st, R.at = st, at
    for i = #R.pieces, snap.pieces + 1, -1 do R.pieces[i] = nil end
    for i = #R.must, snap.must + 1, -1 do R.must[i] = nil end
end

local function entryDistance(R, k)
    local best = 9
    local x, y = xy(k)
    for i = 1, #R.entries do
        local ex, ey = xy(R.entries[i])
        local dist = math.abs(ex - x) + math.abs(ey - y)
        if dist < best then best = dist end
    end
    return best
end

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

local function bedPiece(k1, k2, orient)
    return newPiece("bed", CAT.bed.e, { k1, k2 }, CAT.bed[orient], { head = k1 })
end

local bedStrategies = {
    { H = 0.5, V = 0, adj = 0.8 },
    { H = 0, V = 0.5, adj = 0.8 },
    { H = 0.2, V = 0.2, adj = 1.6 },
}

local function scoreBed(R, k1, k2, orient, params)
    local head = orient == "H" and 4 or 1
    local foot = orient == "H" and 2 or 3
    local sideA = orient == "H" and 1 or 4
    local sideB = orient == "H" and 3 or 2
    local score = 4 * wallWeight(R, k1, head) + wallWeight(R, k2, foot)
    for i = 1, 2 do
        local c = i == 1 and k1 or k2
        score = score + 1.2 * (wallWeight(R, c, sideA) + wallWeight(R, c, sideB))
        for d = 1, 4 do
            local piece = R.at[c + DELTA[d]]
            if piece ~= nil and piece.kind == "bed" then score = score + (params.adj or 0.8) end
        end
    end
    local dist = math.min(entryDistance(R, k1), entryDistance(R, k2))
    if dist <= 1 then
        score = score - 3
    elseif dist == 2 then
        score = score - 1
    end
    return score + (params[orient] or 0)
end

local function byScore(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.k ~= b.k then return a.k < b.k end
    return (a.tie or 0) < (b.tie or 0)
end

local function fillBeds(R, limit, params)
    if CAT.bed == nil then return 0 end
    local placed = 0
    while placed < limit do
        local cands = {}
        for i = 1, #R.order do
            local k = R.order[i]
            if R.st[k] == 1 then
                if R.st[k + 1] == 1 and passable(R.run, k, 2) then
                    cands[#cands + 1] = { k = k, k2 = k + 1, orient = "H", tie = 1, score = scoreBed(R, k, k + 1, "H", params) }
                end
                if R.st[k + STRIDE] == 1 and passable(R.run, k, 3) then
                    cands[#cands + 1] = { k = k, k2 = k + STRIDE, orient = "V", tie = 2, score = scoreBed(R, k, k + STRIDE, "V", params) }
                end
            end
        end
        table.sort(cands, byScore)
        local ok = false
        for i = 1, math.min(#cands, 8) do
            local c = cands[i]
            if commit(R, bedPiece(c.k, c.k2, c.orient)) then
                ok = true
                break
            end
        end
        if not ok then break end
        placed = placed + 1
    end
    return placed
end

local function bestBeds(R, limit)
    local bestN, bestIndex = -1, 1
    for i = 1, #bedStrategies do
        local snap = snapshot(R)
        local n = fillBeds(R, limit, bedStrategies[i])
        restore(R, snap)
        if n > bestN then
            bestN, bestIndex = n, i
        end
    end
    return fillBeds(R, limit, bedStrategies[bestIndex])
end

local function crateOf(cat, k, storage)
    return newPiece("crate", cat.e, { k }, { cat.sprite }, { container = "crate", storage = storage })
end

local function shelfOf(k, wall)
    return newPiece("shelf", "Wood_Shelves_Lvl1", { k }, { CAT.shelf[OPPOSITE[wall]] }, { container = "shelves" })
end

local function nightstands(R)
    local beds = {}
    for i = 1, #R.pieces do
        if R.pieces[i].kind == "bed" then beds[#beds + 1] = R.pieces[i] end
    end
    local want = math.ceil(#beds / 2)
    for n = 1, want do
        local bed = beds[n * 2 - 1]
        local options = {}
        for ci = 1, 2 do
            local c = bed.cells[ci]
            for d = 1, 4 do
                local nk = c + DELTA[d]
                if R.st[nk] == 1 and passable(R.run, c, d) and not bed.set[nk] then
                    local wall
                    for w = 1, 4 do
                        if edgeAt(R.run, nk, w) == 1 then wall = wall or w end
                    end
                    options[#options + 1] = { k = nk, wall = wall, score = (ci == 1 and 2 or 0) + (wall ~= nil and 1 or 0), tie = d }
                end
            end
        end
        table.sort(options, byScore)
        for i = 1, math.min(#options, 6) do
            local o = options[i]
            local piece
            if n % 2 == 0 and o.wall ~= nil and CAT.shelf ~= nil then
                piece = shelfOf(o.k, o.wall)
            elseif CAT.crate1 ~= nil then
                piece = crateOf(CAT.crate1, o.k, false)
            end
            if piece ~= nil and commit(R, piece) then break end
        end
    end
end

local function crateScore(R, k)
    local score = 0
    local walls = 0
    for d = 1, 4 do
        local w = wallWeight(R, k, d)
        score = score + 3 * w
        if w >= 1 then walls = walls + 1 end
        local piece = R.at[k + DELTA[d]]
        if piece ~= nil and piece.kind == "crate" then score = score + 1.5 end
    end
    if walls >= 2 then score = score + 2 end
    return score + 0.2 * math.min(entryDistance(R, k), 5)
end

local function fillCrates(R, count, cat, storage)
    if cat == nil then return 0 end
    local placed = 0
    while placed < count do
        local cands = {}
        for i = 1, #R.order do
            local k = R.order[i]
            if R.st[k] == 1 and entryDistance(R, k) >= 2 then
                cands[#cands + 1] = { k = k, score = crateScore(R, k) }
            end
        end
        table.sort(cands, byScore)
        local ok = false
        for i = 1, math.min(#cands, 8) do
            if commit(R, crateOf(cat, cands[i].k, storage)) then
                ok = true
                break
            end
        end
        if not ok then break end
        placed = placed + 1
    end
    return placed
end

local function fillShelves(R, count)
    if CAT.shelf == nil then return 0 end
    local placed = 0
    while placed < count do
        local cands = {}
        for i = 1, #R.order do
            local k = R.order[i]
            if R.st[k] == 1 and entryDistance(R, k) >= 2 then
                local walls = 0
                for d = 1, 4 do
                    if edgeAt(R.run, k, d) == 1 then walls = walls + 1 end
                end
                if walls > 0 then
                    for d = 1, 4 do
                        if edgeAt(R.run, k, d) == 1 then
                            local near = 0
                            for n = 1, 4 do
                                if R.at[k + DELTA[n]] ~= nil then near = near + 1 end
                            end
                            cands[#cands + 1] = { k = k, wall = d, tie = d, score = walls + 0.5 * near + 0.2 * math.min(entryDistance(R, k), 5) }
                        end
                    end
                end
            end
        end
        table.sort(cands, byScore)
        local ok = false
        for i = 1, math.min(#cands, 8) do
            local c = cands[i]
            if commit(R, shelfOf(c.k, c.wall)) then
                ok = true
                break
            end
        end
        if not ok then break end
        placed = placed + 1
    end
    return placed
end

local function tableSpan(R, k, orient, len)
    local step = orient == "H" and 1 or STRIDE
    local dir = orient == "H" and 2 or 3
    local cells = {}
    for i = 0, len - 1 do
        local c = k + i * step
        if R.st[c] ~= 1 then return nil end
        if i > 0 and not passable(R.run, c - step, dir) then return nil end
        cells[#cells + 1] = c
    end
    return cells
end

local function tablePiece(c1, c2, orient)
    return newPiece("table", CAT.table.e, { c1, c2 }, CAT.table[orient], { access = false })
end

local function benchPiece(c1, c2, facing)
    if CAT.bench == nil then return nil end
    return newPiece("seat", nil, { c1, c2 }, CAT.bench[facing], { bench = true })
end

local function chairPiece(c, facing)
    if CAT.chair == nil then return nil end
    return newPiece("seat", "Wood_Chair_Lvl1", { c }, { CAT.chair[facing] })
end

local function seatModules(R, cells, orient, units)
    local run = R.run
    local step = orient == "H" and 1 or STRIDE
    local axis = orient == "H" and 2 or 3
    local sides = orient == "H" and { 1, 3 } or { 4, 2 }
    local mods, seats = {}, 0
    for si = 1, 2 do
        local side = sides[si]
        for u = 0, units - 1 do
            local t1, t2 = cells[u * 2 + 1], cells[u * 2 + 2]
            local c1, c2 = t1 + DELTA[side], t2 + DELTA[side]
            local ok1 = R.st[c1] == 1 and passable(run, t1, side)
            local ok2 = R.st[c2] == 1 and passable(run, t2, side)
            if ok1 and ok2 and passable(run, c1, axis) and CAT.bench ~= nil then
                mods[#mods + 1] = { bench = true, c1 = c1, c2 = c2, facing = OPPOSITE[side] }
                seats = seats + 2
            else
                if ok1 then
                    mods[#mods + 1] = { c1 = c1, facing = OPPOSITE[side] }
                    seats = seats + 1
                end
                if ok2 then
                    mods[#mods + 1] = { c1 = c2, facing = OPPOSITE[side] }
                    seats = seats + 1
                end
            end
        end
    end
    local first, last = cells[1], cells[#cells]
    local headCell, tailCell = first - step, last + step
    if R.st[headCell] == 1 and passable(run, first, OPPOSITE[axis]) then
        mods[#mods + 1] = { c1 = headCell, facing = axis }
        seats = seats + 1
    end
    if R.st[tailCell] == 1 and passable(run, last, axis) then
        mods[#mods + 1] = { c1 = tailCell, facing = OPPOSITE[axis] }
        seats = seats + 1
    end
    return mods, seats
end

local function scoreSet(R, cells, mods, seats)
    local footprint = {}
    local count = 0
    local sx, sy = 0, 0
    local near = false
    for i = 1, #cells do footprint[cells[i]] = true end
    for i = 1, #mods do
        footprint[mods[i].c1] = true
        if mods[i].c2 ~= nil then footprint[mods[i].c2] = true end
    end
    local ring = {}
    for k in pairs(footprint) do
        count = count + 1
        local x, y = xy(k)
        sx, sy = sx + x, sy + y
        if entryDistance(R, k) <= 1 then near = true end
        for d = 1, 4 do
            local nk = link(R, k, d)
            if nk ~= nil and not footprint[nk] and walkable(R, nk) then ring[nk] = true end
        end
    end
    local open = 0
    for _ in pairs(ring) do open = open + 1 end
    local score = seats * 10 + 0.5 * open - 0.4 * (math.abs(sx / count - R.cx) + math.abs(sy / count - R.cy))
    if near then score = score - 4 end
    return score
end

local function tableSetCandidates(R, units)
    local out = {}
    if CAT.table == nil then return out end
    local len = units * 2
    for i = 1, #R.order do
        local k = R.order[i]
        if R.st[k] == 1 then
            for o = 1, 2 do
                local orient = o == 1 and "H" or "V"
                local cells = tableSpan(R, k, orient, len)
                if cells ~= nil then
                    local mods, seats = seatModules(R, cells, orient, units)
                    if seats >= Fitout.minSeats then
                        out[#out + 1] = {
                            cells = cells, orient = orient, units = units, mods = mods, seats = seats, k = k, tie = o,
                            score = scoreSet(R, cells, mods, seats),
                        }
                    end
                end
            end
        end
    end
    table.sort(out, byScore)
    return out
end

local function tryTableSet(R, cand)
    local snap = snapshot(R)
    for u = 0, cand.units - 1 do
        local piece = tablePiece(cand.cells[u * 2 + 1], cand.cells[u * 2 + 2], cand.orient)
        if not commit(R, piece) then
            restore(R, snap)
            return 0
        end
    end
    local seats = 0
    for i = 1, #cand.mods do
        local m = cand.mods[i]
        local piece
        if m.bench then
            piece = benchPiece(m.c1, m.c2, m.facing)
        else
            piece = chairPiece(m.c1, m.facing)
        end
        if piece ~= nil and commit(R, piece) then seats = seats + #piece.cells end
    end
    if seats < Fitout.minSeats then
        restore(R, snap)
        return 0
    end
    return seats
end

local function fillTables(R, target, maxSets)
    local total = 0
    for _ = 1, maxSets do
        if total >= target or (total > 0 and target - total < 3) then break end
        local got = 0
        for ui = 1, 2 do
            local cands = tableSetCandidates(R, ui == 1 and 2 or 1)
            for i = 1, math.min(#cands, 6) do
                got = tryTableSet(R, cands[i])
                if got > 0 then break end
            end
            if got > 0 then break end
        end
        if got == 0 then break end
        total = total + got
    end
    return total
end

local function fillBench(R)
    if CAT.table == nil then return 0 end
    local cands = {}
    for i = 1, #R.order do
        local k = R.order[i]
        if R.st[k] == 1 then
            for o = 1, 2 do
                local orient = o == 1 and "H" or "V"
                local cells = tableSpan(R, k, orient, 2)
                if cells ~= nil then
                    local sides = orient == "H" and { 1, 3 } or { 4, 2 }
                    local walls = 0
                    local chair
                    for si = 1, 2 do
                        local side = sides[si]
                        local w = wallWeight(R, cells[1], side) + wallWeight(R, cells[2], side)
                        walls = walls + w
                        if w == 0 then
                            local c = cells[1] + DELTA[side]
                            if R.st[c] == 1 and passable(R.run, cells[1], side) then
                                chair = { cell = c, facing = OPPOSITE[side] }
                            end
                        end
                    end
                    if walls >= 1 then
                        cands[#cands + 1] = {
                            k = k, tie = o, cells = cells, orient = orient, chair = chair,
                            score = walls * 3 + (chair ~= nil and 2 or 0) + 0.2 * math.min(entryDistance(R, k), 5),
                        }
                    end
                end
            end
        end
    end
    table.sort(cands, byScore)
    for i = 1, math.min(#cands, 6) do
        local c = cands[i]
        local snap = snapshot(R)
        if commit(R, tablePiece(c.cells[1], c.cells[2], c.orient)) then
            if c.chair ~= nil then
                local piece = chairPiece(c.chair.cell, c.chair.facing)
                if piece ~= nil then commit(R, piece) end
            end
            return 1
        end
        restore(R, snap)
    end
    return 0
end

local function planPost(R, w)
    local run = R.run
    local c, d = w.k, w.d
    if R.st[c] ~= 1 or CAT.chair == nil or CAT.table == nil then return nil end
    local sides = { (d % 4) + 1, ((d + 2) % 4) + 1, OPPOSITE[d] }
    local clean = snapshot(R)
    R.st[c] = 2
    R.must[#R.must + 1] = c
    local reserved = snapshot(R)
    local options = {}
    for si = 1, 3 do
        local side = sides[si]
        local a = c + DELTA[side]
        if R.st[a] == 1 and passable(run, c, side) then
            for o = 1, 2 do
                local orient = o == 1 and "H" or "V"
                local step = o == 1 and 1 or STRIDE
                for sj = 1, 3 do
                    local other = sides[sj]
                    local t = c + DELTA[other]
                    if other ~= side and t ~= a and R.st[t] == 1 and passable(run, c, other) then
                        for shift = 0, 1 do
                            local cells = tableSpan(R, t - shift * step, orient, 2)
                            if cells ~= nil and not contains(cells, a) and not contains(cells, c) then
                                local score = (si <= 2 and 2 or 0) + (sj <= 2 and 1 or 0)
                                for d2 = 1, 4 do
                                    score = score + 0.5 * (wallWeight(R, cells[1], d2) + wallWeight(R, cells[2], d2))
                                end
                                options[#options + 1] = {
                                    k = a * 4 + sj * 2 + shift, tie = o, chair = a, cells = cells, orient = orient, score = score,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(options, byScore)
    for i = 1, math.min(#options, 10) do
        local o = options[i]
        restore(R, reserved)
        if commit(R, tablePiece(o.cells[1], o.cells[2], o.orient)) then
            local chair = chairPiece(o.chair, d)
            if chair ~= nil and commit(R, chair) then
                local x, y, z = unkey(c)
                return { x = x, y = y, z = z, face = DIRNAME[d], room = R.name }
            end
        end
    end
    restore(R, clean)
    return nil
end

local function fillPosts(R)
    local windows = {}
    for i = 1, #R.windows do windows[#windows + 1] = R.windows[i] end
    table.sort(windows, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.k < b.k
    end)
    local made = 0
    local used = {}
    for i = 1, #windows do
        local w = windows[i]
        if made >= Fitout.maxPosts then break end
        if not used[w.d] then
            local post = planPost(R, w)
            if post ~= nil then
                made = made + 1
                used[w.d] = true
                R.run.posts[#R.run.posts + 1] = post
            end
        end
    end
    return made
end

local function planRoom(R)
    local kind = R.kind
    local free = R.free
    if kind == "dorm" then
        if R.mixed then fillTables(R, 6, 1) end
        bestBeds(R, Fitout.maxBeds)
        nightstands(R)
    elseif kind == "guard" then
        if fillPosts(R) == 0 then R.kind = "dorm" end
        bestBeds(R, Fitout.maxBeds)
        nightstands(R)
    elseif kind == "infirmary" then
        bestBeds(R, 2)
        fillShelves(R, 2)
        fillCrates(R, 1, CAT.crate1, false)
    elseif kind == "common" then
        fillTables(R, clamp(math.floor(free / 2.2), 4, 12), 2)
        fillShelves(R, 2)
    elseif kind == "mess" then
        fillTables(R, clamp(math.floor(free / 2.5), 3, 12), 2)
    elseif kind == "workshop" then
        if R.variant == "store" then
            fillCrates(R, clamp(math.floor(free / 2), 1, 4), CAT.crate2, true)
            fillShelves(R, 2)
        else
            fillCrates(R, clamp(math.floor(free / 5), 2, 8), CAT.crate2, true)
            if free >= 8 then fillBench(R) end
            fillShelves(R, 3)
        end
    end
    if #R.pieces == 0 then R.kind = "none" end
end

local function inRoomList(run, name, x, y, z)
    local list = run.rec.rooms
    if type(list) ~= "table" or #list == 0 then return true end
    for i = 1, #list do
        local r = list[i]
        if r.name == name and (r.z or run.base) == z and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
            return true
        end
    end
    return false
end

local function groupFor(run, room, x, y, z)
    local g = run.groupOf[room]
    if g ~= nil then return g or nil end
    local name = lowerName(try(function() return room:getName() end))
    if not inRoomList(run, name, x, y, z) then
        run.groupOf[room] = false
        return nil
    end
    local index = #run.groups + 1
    run.groups[index] = { name = name, z = z }
    run.groupOf[room] = index
    return index
end

local function newRun(camp, rec)
    local rect = rec.rect
    local base = rect.z or camp.z or 0
    local zlo, zhi = base, base + math.max(1, rec.floors or 1) - 1
    for _, room in ipairs(rec.rooms or {}) do
        if type(room.z) == "number" then
            zlo = math.min(zlo, room.z)
            zhi = math.max(zhi, room.z)
        end
    end
    local width = rect.x2 - rect.x1 + 3
    local height = rect.y2 - rect.y1 + 3
    return {
        id = rec.id, rec = rec, base = base, zlo = zlo, zhi = zhi,
        x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2,
        width = width, per = width * height, total = width * height * (zhi - zlo + 1),
        cursor = 0, phase = "scan", cell = {}, oN = {}, oW = {}, wE = {}, wS = {},
        groups = {}, groupOf = {}, stairs = {}, entrances = {}, posts = {}, missing = {}, retry = 0,
        partial = false, ux = 0, uy = 0, ex = 0, ey = 0,
    }
end

local function scanSquare(run, x, y, z, index)
    local sq = World.square(x, y, z)
    local inside = x >= run.x1 and x <= run.x2 and y >= run.y1 and y <= run.y2
    if sq == nil then
        if inside and (z == run.base or World.square(x, y, run.base) == nil) then
            run.missing[#run.missing + 1] = index
        end
        return
    end
    local k = key(x, y, z)
    local north, west = openingsOf(sq)
    run.oN[k] = north
    run.oW[k] = west
    local east = World.square(x + 1, y, z)
    if east ~= nil then run.wE[k] = wallBetween(sq, east) end
    local south = World.square(x, y + 1, z)
    if south ~= nil then run.wS[k] = wallBetween(sq, south) end
    if not inside then return end
    local room = try(function() return sq:getRoom() end)
    if room == nil or not hasFloor(sq) then return end
    local g = groupFor(run, room, x, y, z)
    if g == nil then return end
    local stairs = try(function() return sq:HasStairs() end) == true
    if stairs then run.stairs[#run.stairs + 1] = { x = x, y = y, z = z } end
    run.cell[k] = { g = g, stairs = stairs, free = (not stairs) and squareFree(sq) }
end

local function scanIndex(run, index)
    local zi = math.floor(index / run.per)
    local rest = index - zi * run.per
    local yi = math.floor(rest / run.width)
    local xi = rest - yi * run.width
    scanSquare(run, run.x1 - 1 + xi, run.y1 - 1 + yi, run.zlo + zi, index)
end

local function scanSome(run, budget)
    local used = 0
    while used < budget do
        local index
        if run.queue ~= nil then
            index = run.queue[run.qi]
            if index == nil then break end
            run.qi = run.qi + 1
        else
            if run.cursor >= run.total then break end
            index = run.cursor
            run.cursor = run.cursor + 1
        end
        used = used + 1
        scanIndex(run, index)
    end
    if run.queue ~= nil then
        if run.queue[run.qi] ~= nil then return false end
    elseif run.cursor < run.total then
        return false
    end
    if #run.missing > 0 and run.retry < Fitout.retries then
        run.retry = run.retry + 1
        run.queue = run.missing
        run.qi = 1
        run.missing = {}
        return false
    end
    run.partial = #run.missing > 0
    return true
end

local function newRoomModel(run, g)
    local info = run.groups[g]
    return {
        run = run, g = g, name = info.name, z = info.z, cls = classify(info.name), order = {}, st = {}, at = {},
        pieces = {}, entries = {}, entryAt = {}, must = {}, fixtures = {}, windows = {}, needFix = {}, kind = "none",
    }
end

local function addEntry(R, k)
    if R.entryAt[k] then return end
    R.entryAt[k] = true
    R.entries[#R.entries + 1] = k
    if R.st[k] == 1 then R.st[k] = 2 end
end

local function reserveAt(run, rooms, k)
    local c = run.cell[k]
    if c ~= nil then addEntry(rooms[c.g], k) end
end

local function markKeep(run, rooms)
    local keep = run.rec.keep
    if type(keep) ~= "table" then return end
    for text, flag in pairs(keep) do
        if flag then
            local x, y, z = string.match(tostring(text), "^(-?%d+),(-?%d+),(-?%d+)$")
            if x ~= nil then
                local k = key(tonumber(x), tonumber(y), tonumber(z))
                local c = run.cell[k]
                if c ~= nil and rooms[c.g].st[k] == 1 then rooms[c.g].st[k] = 2 end
            end
        end
    end
end

local function buildModels(run)
    local rooms = {}
    for g = 1, #run.groups do rooms[g] = newRoomModel(run, g) end
    for z = run.zlo, run.zhi do
        for y = run.y1, run.y2 do
            for x = run.x1, run.x2 do
                local k = key(x, y, z)
                local c = run.cell[k]
                if c ~= nil then
                    local R = rooms[c.g]
                    R.order[#R.order + 1] = k
                    R.st[k] = c.free and 1 or 3
                    if not c.free and not c.stairs then R.fixtures[#R.fixtures + 1] = k end
                end
            end
        end
    end
    for g = 1, #rooms do
        local R = rooms[g]
        for i = 1, #R.order do
            local k = R.order[i]
            for d = 1, 4 do
                local e = edgeAt(run, k, d)
                local other = run.cell[k + DELTA[d]]
                if e == 2 then
                    addEntry(R, k)
                    if other == nil then run.entrances[#run.entrances + 1] = { k = k, d = d } end
                elseif e == 0 and (other == nil or other.g ~= g) then
                    addEntry(R, k)
                elseif e == 3 and other == nil then
                    R.windows[#R.windows + 1] = { k = k, d = d, score = 1 }
                end
            end
        end
    end
    for i = 1, #run.stairs do
        local s = run.stairs[i]
        for d = 1, 4 do reserveAt(run, rooms, key(s.x + DX[d], s.y + DY[d], s.z)) end
        for dx = -1, 1 do
            for dy = -1, 1 do reserveAt(run, rooms, key(s.x + dx, s.y + dy, s.z + 1)) end
        end
    end
    markKeep(run, rooms)
    return rooms
end

local function prepareRoom(R)
    local run = R.run
    if R.cls == "kitchen" then
        for i = 1, #R.fixtures do
            local k = R.fixtures[i]
            for d = 1, 4 do
                local nk = k + DELTA[d]
                if R.st[nk] == 1 then R.st[nk] = 2 end
            end
        end
    end
    table.sort(R.entries)
    local walk = {}
    for i = 1, #R.entries do
        if walkable(R, R.entries[i]) then walk[#walk + 1] = R.entries[i] end
    end
    if #walk > 0 then
        R.sources, R.main = walk, walk[1]
    else
        R.sources, R.main = R.order, nil
    end
    local seen = flood(R, R.sources)
    if R.main ~= nil then
        local id = seen[R.main]
        for i = 1, #walk do
            if seen[walk[i]] == id then R.must[#R.must + 1] = walk[i] end
        end
    end
    for i = 1, #R.fixtures do
        local k = R.fixtures[i]
        for d = 1, 4 do
            local nk = link(R, k, d)
            if nk ~= nil and seen[nk] ~= nil then
                R.needFix[#R.needFix + 1] = k
                break
            end
        end
    end
    local free, sx, sy = 0, 0, 0
    local minX, maxX, minY, maxY
    for i = 1, #R.order do
        local k = R.order[i]
        local s = R.st[k]
        if s == 1 or s == 2 then
            local x, y = xy(k)
            minX = minX == nil and x or math.min(minX, x)
            maxX = maxX == nil and x or math.max(maxX, x)
            minY = minY == nil and y or math.min(minY, y)
            maxY = maxY == nil and y or math.max(maxY, y)
            if s == 1 then
                free = free + 1
                sx, sy = sx + x, sy + y
            end
        end
    end
    R.free = free
    R.cx = free > 0 and sx / free or 0
    R.cy = free > 0 and sy / free or 0
    R.dimMin = minX ~= nil and math.min(maxX - minX + 1, maxY - minY + 1) or 0
    R.bounds = minX ~= nil and { x1 = minX, y1 = minY, x2 = maxX, y2 = maxY } or { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
end

local function computeView(run)
    local sx, sy, n = 0, 0, 0
    for i = 1, #run.entrances do
        local x, y = xy(run.entrances[i].k)
        sx, sy, n = sx + x, sy + y, n + 1
    end
    local cx, cy = (run.x1 + run.x2) / 2, (run.y1 + run.y2) / 2
    run.ex, run.ey = cx, cy
    run.ux, run.uy = 0, 0
    if n == 0 then return end
    run.ex, run.ey = sx / n, sy / n
    local dx, dy = run.ex - cx, run.ey - cy
    local len = math.sqrt(dx * dx + dy * dy)
    if len >= 0.5 then run.ux, run.uy = dx / len, dy / len end
end

local function viewScore(run, R)
    local scores = {}
    local dirs = {}
    local distinct = 0
    for i = 1, #R.windows do
        local w = R.windows[i]
        local x, y = xy(w.k)
        local dot = DX[w.d] * run.ux + DY[w.d] * run.uy
        local ddx, ddy = x - run.ex, y - run.ey
        w.score = 1 + 1.5 * math.max(0, dot) + 2 / (1 + math.sqrt(ddx * ddx + ddy * ddy) / 6)
        scores[#scores + 1] = w.score
        if not dirs[w.d] then
            dirs[w.d] = true
            distinct = distinct + 1
        end
    end
    table.sort(scores, function(a, b) return a > b end)
    local total = 0
    for i = 1, math.min(3, #scores) do total = total + scores[i] end
    return total + 0.5 * distinct + (R.z > run.base and 1.5 or 0)
end

local function firstKey(R)
    return R.order[1] or 0
end

local function assignRoles(run, rooms)
    local base = run.base
    local pool = {}
    for _, R in ipairs(rooms) do
        local cls = R.cls
        R.kind = "none"
        if R.free < 2 or R.n > Fitout.maxCells then
            R.kind = "none"
        elseif cls == "bath" then
            R.kind = "none"
        elseif cls == "kitchen" then
            R.kind = R.free >= 4 and "mess" or "none"
        elseif cls == "dining" then
            R.kind = "mess"
        elseif cls == "bed" then
            R.kind = "dorm"
        elseif cls == "work" or cls == "basement" then
            R.kind = "workshop"
        elseif cls == "store" then
            R.kind = "workshop"
            R.variant = "store"
        elseif cls == "living" or cls == "hall" or cls == "office" then
            local thick = R.dimMin >= 3 and R.free >= 9
            if R.z == base then
                if cls == "hall" and not thick then
                    R.kind = "none"
                else
                    pool[#pool + 1] = R
                end
            else
                R.kind = thick and "dorm" or "none"
            end
        elseif R.free >= 8 then
            R.kind = "dorm"
        else
            R.kind = "workshop"
            R.variant = "store"
        end
    end
    table.sort(pool, function(a, b)
        local ra, rb = commonRank[a.cls] or 9, commonRank[b.cls] or 9
        if ra ~= rb then return ra < rb end
        if a.free ~= b.free then return a.free > b.free end
        return firstKey(a) < firstKey(b)
    end)
    for i, R in ipairs(pool) do
        if i == 1 then
            R.kind = "common"
        elseif R.free >= 6 then
            R.kind = "dorm"
        else
            R.kind = "none"
        end
    end
    local best, bestScore
    for _, R in ipairs(rooms) do
        if R.kind == "dorm" and #R.windows > 0 then
            local score = viewScore(run, R)
            if bestScore == nil or score > bestScore then best, bestScore = R, score end
        end
    end
    if best ~= nil then best.kind = "guard" end
    local counted, dorms = 0, 0
    for _, R in ipairs(rooms) do
        if R.cls ~= "bath" and R.free >= 2 then counted = counted + 1 end
        if R.kind == "dorm" then dorms = dorms + 1 end
    end
    if counted >= 3 and dorms + (best ~= nil and 1 or 0) >= 2 then
        local choices = {}
        for _, R in ipairs(rooms) do
            if R.kind == "dorm" and R.free >= 6 and R.free <= 30 then choices[#choices + 1] = R end
        end
        if #choices >= 1 and dorms >= 2 then
            table.sort(choices, function(a, b)
                local ga, gb = a.z == base and 0 or 1, b.z == base and 0 or 1
                if ga ~= gb then return ga < gb end
                local da, db = math.abs(a.free - 12), math.abs(b.free - 12)
                if da ~= db then return da < db end
                return firstKey(a) < firstKey(b)
            end)
            choices[1].kind = "infirmary"
        end
    end
    local sleeping = false
    for _, R in ipairs(rooms) do
        if R.kind == "dorm" or R.kind == "guard" or R.kind == "infirmary" then sleeping = true end
    end
    if not sleeping then
        local pick
        for _, R in ipairs(rooms) do
            if R.cls ~= "bath" and R.free >= 6 and R.n <= Fitout.maxCells and (pick == nil or R.free > pick.free) then pick = R end
        end
        if pick ~= nil then
            pick.kind = "dorm"
            pick.mixed = pick.cls ~= "bed"
            pick.variant = nil
        end
    end
end

local function encodeTile(piece, index, k, group)
    local x, y, z = unkey(k)
    local parts = #piece.cells > 1 and #piece.cells or 0
    return table.concat({
        piece.e or "", piece.sprites[index], tostring(x), tostring(y), tostring(z), tostring(parts),
        piece.container or "", piece.storage and "1" or "0", tostring(group), piece.code,
    }, "|")
end

local function decodeOp(line, index)
    local fields = {}
    local pos = 1
    while true do
        local cut = string.find(line, "|", pos, true)
        if cut == nil then
            fields[#fields + 1] = string.sub(line, pos)
            break
        end
        fields[#fields + 1] = string.sub(line, pos, cut - 1)
        pos = cut + 1
    end
    local parts = tonumber(fields[6]) or 0
    local op = {
        t = "prop", sprite = fields[2], x = tonumber(fields[3]), y = tonumber(fields[4]), z = tonumber(fields[5]),
        slot = "F" .. index, group = tonumber(fields[9]), code = fields[10],
    }
    if fields[1] ~= "" then op.e = fields[1] end
    if parts > 1 then op.parts = parts end
    if fields[7] ~= "" then op.container = fields[7] end
    if fields[8] == "1" then op.storage = true end
    return op
end

local function keptBeds(rec)
    local value = type(rec.salvage) == "table" and rec.salvage.keptBeds or nil
    if type(value) == "number" then return value end
    if type(value) == "table" then
        local n = 0
        for _ in pairs(value) do n = n + 1 end
        return n
    end
    return 0
end

local function decoded(rec)
    local f = rec.fitout
    if type(f) ~= "table" or type(f.ops) ~= "table" then return {}, {} end
    local cached = Fitout.cache[rec.id]
    if cached ~= nil and cached.source == f.ops and cached.count == #f.ops then return cached.ops, cached.groups end
    local ops = {}
    local groups = {}
    local last
    for i = 1, #f.ops do
        local op = decodeOp(f.ops[i], i)
        ops[i] = op
        if last == nil or last.id ~= op.group then
            last = { id = op.group, first = i, last = i }
            groups[#groups + 1] = last
        else
            last.last = i
        end
    end
    Fitout.cache[rec.id] = { source = f.ops, count = #f.ops, ops = ops, groups = groups }
    return ops, groups
end

function Fitout.ops(camp, rec)
    local ops = decoded(rec)
    return ops
end

local function tally(rec, f, ops)
    local plan = { beds = 0, seats = 0, crates = 0, shelves = 0, tables = 0 }
    local have = { beds = 0, seats = 0, crates = 0, shelves = 0, tables = 0 }
    local names = { b = "beds", s = "seats", c = "crates", h = "shelves", t = "tables" }
    local weight = { b = 0.5, s = 1, c = 1, h = 1, t = 0.5 }
    local done, gone = 0, 0
    for i = 1, #ops do
        local op = ops[i]
        if f.skipped[op.slot] then
            gone = gone + 1
        else
            local name = names[op.code]
            if name ~= nil then
                plan[name] = plan[name] + weight[op.code]
                if f.done[op.slot] then have[name] = have[name] + weight[op.code] end
            end
            if f.done[op.slot] then done = done + 1 end
        end
    end
    for name, value in pairs(plan) do plan[name] = math.floor(value + 0.001) end
    for name, value in pairs(have) do have[name] = math.floor(value + 0.001) end
    f.counts, f.have = plan, have
    f.total, f.finishedOps, f.skippedOps = #ops, done, gone
    rec.capacity = plan.beds + keptBeds(rec)
end

local function finalize(camp, rec, run, rooms)
    local f = rec.fitout
    table.sort(rooms, function(a, b)
        local ra, rb = kindRank[a.kind] or 9, kindRank[b.kind] or 9
        if ra ~= rb then return ra < rb end
        if a.free ~= b.free then return a.free > b.free end
        return firstKey(a) < firstKey(b)
    end)
    local ops, summary = {}, {}
    local group = 0
    for _, R in ipairs(rooms) do
        local beds, seats, crates = 0, 0, 0
        for _, piece in ipairs(R.pieces) do
            group = group + 1
            for i = 1, #piece.cells do ops[#ops + 1] = encodeTile(piece, i, piece.cells[i], group) end
            if piece.kind == "bed" then beds = beds + 1 end
            if piece.kind == "seat" then seats = seats + #piece.cells end
            if piece.kind == "crate" then crates = crates + 1 end
        end
        summary[#summary + 1] = {
            kind = R.kind, name = R.name, z = R.z, x1 = R.bounds.x1, y1 = R.bounds.y1, x2 = R.bounds.x2, y2 = R.bounds.y2,
            beds = beds, seats = seats, crates = crates,
        }
    end
    f.ops = ops
    f.rooms = summary
    f.posts = run.posts
    f.done, f.skipped, f.fails = {}, {}, {}
    f.carry, f.cursor = 0, 1
    f.partial = run.partial
    f.provisional = rec.status ~= "fitout"
    f.finished = false
    f.waiting = nil
    f.phase = "ready"
    Fitout.cache[rec.id] = nil
    Fitout.runs[rec.id] = nil
    local list = decoded(rec)
    tally(rec, f, list)
    if #list == 0 then f.finished = true end
end

local function advance(camp, rec, f, budget)
    local run = Fitout.runs[rec.id]
    if run == nil then
        run = newRun(camp, rec)
        Fitout.runs[rec.id] = run
        f.phase = "scan"
    end
    if run.phase == "scan" then
        local finished = scanSome(run, budget)
        local covered = run.queue ~= nil and run.total or run.cursor
        f.scanProgress = clamp(covered / math.max(1, run.total), 0, 1)
        if not finished then return end
        run.rooms = buildModels(run)
        computeView(run)
        for _, R in ipairs(run.rooms) do
            R.n = #R.order
            prepareRoom(R)
        end
        assignRoles(run, run.rooms)
        run.phase = "plan"
        run.index = 1
        f.phase = "plan"
        return
    end
    local planned = 0
    local rooms = run.rooms
    while run.index <= #rooms and planned < Fitout.roomBudget do
        local R = rooms[run.index]
        run.index = run.index + 1
        if R.kind ~= "none" then
            planRoom(R)
            planned = planned + 1
        end
    end
    if run.index > #rooms then finalize(camp, rec, run, rooms) end
end

local function newState()
    return {
        version = Fitout.version, phase = "scan", done = {}, skipped = {}, fails = {}, ops = {}, rooms = {}, posts = {},
        counts = {}, have = {}, scanProgress = 0,
    }
end

local function estimateOps(rec)
    local ops = {}
    for _, room in ipairs(rec.rooms or {}) do
        local cls = classify(lowerName(room.name))
        local area = tonumber(room.area) or 0
        local beds, seats = 0, 0
        if cls == "bed" then
            beds = clamp(math.floor(area / 3), 1, 6)
        elseif cls == "living" or cls == "dining" or cls == "kitchen" then
            seats = clamp(math.floor(area / 3), 0, 8)
        end
        for _ = 1, beds do
            ops[#ops + 1] = { t = "prop", e = "Wood_Bed", parts = 2 }
            ops[#ops + 1] = { t = "prop", e = "Wood_Bed", parts = 2 }
        end
        for _ = 1, seats do ops[#ops + 1] = { t = "prop", e = "Wood_Chair_Lvl1" } end
    end
    return ops
end

local function pending(f, ops)
    local out = {}
    for i = 1, #ops do
        local slot = ops[i].slot
        if not f.done[slot] and not f.skipped[slot] then out[#out + 1] = ops[i] end
    end
    return out
end

function Fitout.remaining(camp, rec)
    local f = rec.fitout
    if type(f) ~= "table" then return {} end
    return pending(f, (decoded(rec)))
end

local function costOf(rec, f)
    if f.phase ~= "ready" then
        local ops = estimateOps(rec)
        return Bp.cost(ops), Bp.work(ops)
    end
    local list = pending(f, (decoded(rec)))
    return Bp.cost(list), Bp.work(list)
end

function Fitout.reset(rec)
    if type(rec) ~= "table" then return end
    rec.fitout = nil
    if rec.id ~= nil then
        Fitout.runs[rec.id] = nil
        Fitout.cache[rec.id] = nil
    end
end

function Fitout.analyze(camp, rec, full)
    if type(rec) ~= "table" or type(rec.rect) ~= "table" then return {}, 0 end
    local f = rec.fitout
    if type(f) ~= "table" or f.version ~= Fitout.version then
        Fitout.reset(rec)
        f = newState()
        rec.fitout = f
    end
    if f.phase == "ready" and f.provisional and rec.status == "fitout" then
        Fitout.reset(rec)
        f = newState()
        rec.fitout = f
    end
    if f.phase ~= "ready" then
        local rounds = full and 400 or 1
        local budget = full and 100000000 or Fitout.scanBudget
        while rounds > 0 do
            advance(camp, rec, f, budget)
            rounds = rounds - 1
            if f.phase == "ready" then break end
        end
    end
    return costOf(rec, f)
end

local function existing(square, slot, pid)
    local found = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local tag = World.tag(objects:get(i))
            if type(tag) == "table" and tag.slot == slot and tag.project == pid then
                found = true
                return
            end
        end
    end)
    return found
end

local function registerStorage(camp, op)
    camp.storage = camp.storage or {}
    for _, entry in ipairs(camp.storage) do
        if entry.x == op.x and entry.y == op.y and (entry.z or camp.z) == op.z then return end
    end
    camp.storage[#camp.storage + 1] = { x = op.x, y = op.y, z = op.z }
end

local function placeOp(camp, project, op)
    local tag = Place.tag(project, op.slot, "built")
    local object, why = Place.prop(op.sprite, op.x, op.y, op.z, tag, op.container)
    if object == nil then return false, why end
    if op.storage then
        pcall(function()
            object:getModData().ALC = { kind = "storage", camp = camp.id, project = project.id, slot = op.slot }
        end)
        registerStorage(camp, op)
    end
    return true
end

local function shortage(camp, cost)
    local missing
    local have = camp.stock or {}
    for kind, amount in pairs(cost) do
        local short = amount - (have[kind] or 0)
        if short > 0 then
            missing = missing or {}
            missing[kind] = short
        end
    end
    return missing
end

local function groupOpen(f, ops, group)
    for i = group.first, group.last do
        local slot = ops[i].slot
        if not f.done[slot] and not f.skipped[slot] then return true end
    end
    return false
end

function Fitout.step(camp, rec, labor, minutes)
    local f = rec.fitout
    if type(f) ~= "table" or f.phase ~= "ready" then
        Fitout.analyze(camp, rec)
        f = rec.fitout
        local progress = type(f) == "table" and (f.scanProgress or 0) * 0.05 or 0
        return false, progress, 0, nil
    end
    local ops, groups = decoded(rec)
    if f.finished or #ops == 0 then
        f.finished = true
        tally(rec, f, ops)
        return true, 1, 0, nil
    end
    local project = { camp = camp.id, id = "A" .. tostring(rec.id) }
    f.carry = math.min(Fitout.maxCarry, (f.carry or 0) + math.max(0, labor or 0) * math.max(0, minutes or 0))
    local spent = 0
    local waiting
    local unloaded = false
    local stop = false
    local index = f.cursor or 1
    while index <= #groups and groups[index] ~= nil and not groupOpen(f, ops, groups[index]) do index = index + 1 end
    f.cursor = index
    for gi = index, #groups do
        if stop then break end
        local group = groups[gi]
        if groupOpen(f, ops, group) then
            local squares, open = {}, {}
            local missingSquare = false
            for i = group.first, group.last do
                local op = ops[i]
                if not f.done[op.slot] and not f.skipped[op.slot] then
                    local sq = Place.square(op.x, op.y, op.z)
                    if sq == nil then
                        missingSquare = true
                    elseif existing(sq, op.slot, project.id) then
                        f.done[op.slot] = true
                        if op.storage then registerStorage(camp, op) end
                    else
                        squares[#squares + 1] = sq
                        open[#open + 1] = op
                    end
                end
            end
            if missingSquare then
                unloaded = true
            elseif #open > 0 then
                local blocked = false
                for i = 1, #squares do
                    if not squareFree(squares[i]) then blocked = true end
                end
                if blocked then
                    for i = 1, #open do f.skipped[open[i].slot] = true end
                else
                    local cost = Bp.cost(open)
                    local short = shortage(camp, cost)
                    local work = math.min(Bp.work(open), Fitout.maxCarry)
                    if short ~= nil then
                        waiting = short
                        stop = true
                    elseif f.carry < work then
                        stop = true
                    else
                        f.carry = f.carry - work
                        for i = 1, #open do
                            local op = open[i]
                            local ok, why = placeOp(camp, project, op)
                            if ok then
                                f.done[op.slot] = true
                                for kind, amount in pairs(Bp.opCost(op)) do
                                    Stock.consume(camp, kind, amount)
                                    spent = spent + amount
                                end
                            elseif why == "unloaded" then
                                unloaded = true
                            else
                                f.fails[op.slot] = (f.fails[op.slot] or 0) + 1
                                if f.fails[op.slot] >= 3 then f.skipped[op.slot] = true end
                            end
                        end
                    end
                end
            end
        end
    end
    f.waiting = waiting
    f.unloaded = unloaded
    tally(rec, f, ops)
    local complete = true
    for gi = 1, #groups do
        if groupOpen(f, ops, groups[gi]) then
            complete = false
            break
        end
    end
    if complete then
        f.finished = true
        f.waiting = nil
        return true, 1, spent, nil
    end
    local progress = clamp((f.finishedOps + f.skippedOps) / math.max(1, f.total), 0, 0.999)
    return false, progress, spent, waiting
end

function Fitout.roleKey(kind)
    return roleKeys[kind] or "Room_none"
end

function Fitout.summary(rec)
    local out = {
        beds = 0, bedsNew = 0, kept = 0, seats = 0, crates = 0, shelves = 0, tables = 0, posts = 0, capacity = 0,
        rooms = { dorm = 0, common = 0, mess = 0, infirmary = 0, workshop = 0, guard = 0 },
        ready = false, partial = false, finished = false, waiting = false,
    }
    if type(rec) ~= "table" then return out end
    out.kept = keptBeds(rec)
    out.beds = out.kept
    out.capacity = out.kept
    local f = rec.fitout
    if type(f) ~= "table" or f.phase ~= "ready" then return out end
    local counts = f.counts or {}
    out.ready = true
    out.partial = f.partial == true
    out.finished = f.finished == true
    out.waiting = type(f.waiting) == "table"
    out.bedsNew = counts.beds or 0
    out.beds = out.bedsNew + out.kept
    out.capacity = out.beds
    out.seats = counts.seats or 0
    out.crates = counts.crates or 0
    out.shelves = counts.shelves or 0
    out.tables = counts.tables or 0
    out.posts = #(f.posts or {})
    out.placed = f.have or {}
    for _, room in ipairs(f.rooms or {}) do
        if out.rooms[room.kind] ~= nil then out.rooms[room.kind] = out.rooms[room.kind] + 1 end
    end
    return out
end

function Fitout.describe(rec)
    local s = Fitout.summary(rec)
    return ALifeCamp.T("Fitout_Line", tostring(s.beds), tostring(s.seats), tostring(s.crates), tostring(s.posts))
end

return Fitout
