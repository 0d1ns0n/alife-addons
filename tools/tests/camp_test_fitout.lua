dofile(MOCK)
LOADMOD(ROOT)

local fitoutPath = ROOT .. "/shared/ALifeCamp/CampFitout.lua"
local chunk, loadError = loadfile(fitoutPath)
check("fitout file loads", chunk ~= nil, loadError)
chunk()

local A = ALifeCamp
local Fitout, Bp, Place, Stock, Camp, World = A.Fitout, A.Blueprints, A.Place, A.Stock, A.Camp, A.World

local textKeys = {}
for k in pairs(UIJSON) do
    if k:find("^UI_ALC_Fitout_") or k:find("^UI_ALC_Room_") then textKeys[#textKeys + 1] = k end
end
check("text json present", #textKeys >= 8, #textKeys)

local source = io.open(fitoutPath, "rb"):read("*a")
local nonAscii, commentLines = false, 0
for i = 1, #source do
    if source:byte(i) >= 128 then nonAscii = true end
end
for line in source:gmatch("[^\n]+") do
    if line:find("%-%-") then commentLines = commentLines + 1 end
end
check("no non-ascii in source", not nonAscii)
check("no comments in source", commentLines == 0, commentLines)

check("API present", type(Fitout.analyze) == "function" and type(Fitout.step) == "function" and type(Fitout.summary) == "function"
    and type(Fitout.ops) == "function" and type(Fitout.roleKey) == "function")
check("scan budget is 400", Fitout.scanBudget == 400)

for _, kind in ipairs(Fitout.kinds) do
    local keyName = Fitout.roleKey(kind)
    check("role key " .. kind, keyName == "Room_" .. kind and UIJSON["UI_ALC_" .. keyName] ~= nil, keyName)
end
check("role key unknown", Fitout.roleKey("zzz") == "Room_none" and UIJSON["UI_ALC_Room_none"] ~= nil)

local function K(x, y, z) return x .. "," .. y .. "," .. z end

local CELL, STAIRS, OPEN, MADE, DOORSET = {}, {}, {}, {}, {}
local HIDDEN = {}
local FIXTURES = {}
local CALLS = { count = 0 }

local realGetCell = getCell
function getCell()
    local cell = realGetCell()
    return {
        getGridSquare = function(_, x, y, z)
            CALLS.count = CALLS.count + 1
            if HIDDEN[K(x, y, z)] then return nil end
            return cell:getGridSquare(x, y, z)
        end,
    }
end

local function edgeId(a, b)
    if b.x == a.x + 1 then return K(a.x, a.y, a.z) .. ">E" end
    if b.x == a.x - 1 then return K(b.x, b.y, b.z) .. ">E" end
    if b.y == a.y + 1 then return K(a.x, a.y, a.z) .. ">S" end
    return K(b.x, b.y, b.z) .. ">S"
end

local function decorate(sq)
    function sq:getRoom() return CELL[K(self.x, self.y, self.z)] end
    function sq:hasFloor() return self.floorOn == true end
    function sq:HasStairs() return STAIRS[K(self.x, self.y, self.z)] == true end
    function sq:isWallTo(b)
        local ra, rb = CELL[K(self.x, self.y, self.z)], CELL[K(b.x, b.y, b.z)]
        if ra == rb then return false end
        return OPEN[edgeId(self, b)] ~= true
    end
end

local function mkSquare(x, y, z, floorOn)
    local id = K(x, y, z)
    if MADE[id] ~= nil then
        if floorOn then MADE[id].floorOn = true end
        return MADE[id]
    end
    local sq = NEWSQUARE(x, y, z)
    sq.floorOn = floorOn
    decorate(sq)
    MADE[id] = sq
    return sq
end

local function addOpening(class, x, y, z, north)
    local sq = MADE[K(x, y, z)] or mkSquare(x, y, z, false)
    local o = { class = class, mod = {}, north = north }
    function o:getModData() return self.mod end
    function o:getNorth() return self.north end
    function o:getSquare() return self.square end
    function o:getSprite() return { getName = function() return "walls_x" end, getProperties = function() return { has = function() return false end } end } end
    sq:AddTileObject(o)
    return o
end

local function addFixture(x, y, z, soft)
    local sq = MADE[K(x, y, z)]
    local o = NEWOBJ(sq, "IsoObject", "fixtures_x")
    if soft then
        o.getSprite = function()
            return {
                getName = function() return "fixtures_sinks_01_0" end,
                getProperties = function() return { has = function(_, name) return name == "BlocksPlacement" end } end,
            }
        end
    else
        sq.free = false
    end
    FIXTURES[#FIXTURES + 1] = { x = x, y = y, z = z, soft = soft == true }
end

local function newRoom(name)
    local r = { name = name }
    function r:getName() return self.name end
    return r
end

local function buildHouse(spec)
    local rect = spec.rect
    for x = rect.x1 - 3, rect.x2 + 3 do
        for y = rect.y1 - 3, rect.y2 + 3 do mkSquare(x, y, 0, true) end
    end
    local rooms = {}
    for _, def in ipairs(spec.rooms) do
        local room = newRoom(def.name)
        for x = def.x1, def.x2 do
            for y = def.y1, def.y2 do
                mkSquare(x, y, def.z, true)
                CELL[K(x, y, def.z)] = room
            end
        end
        rooms[#rooms + 1] = { name = def.name, x1 = def.x1, y1 = def.y1, x2 = def.x2, y2 = def.y2, z = def.z,
            area = (def.x2 - def.x1 + 1) * (def.y2 - def.y1 + 1) }
    end
    for _, d in ipairs(spec.doors or {}) do
        addOpening("IsoDoor", d[1], d[2], d[3], d[4])
        local a = { x = d[1], y = d[2], z = d[3] }
        local b = d[4] and { x = d[1], y = d[2] - 1, z = d[3] } or { x = d[1] - 1, y = d[2], z = d[3] }
        DOORSET[edgeId(a, b)] = { a = a, b = b }
    end
    for _, w in ipairs(spec.windows or {}) do addOpening("IsoWindow", w[1], w[2], w[3], w[4]) end
    for _, o in ipairs(spec.opens or {}) do OPEN[K(o[1], o[2], o[3]) .. ">" .. o[4]] = true end
    for _, s in ipairs(spec.stairs or {}) do STAIRS[K(s[1], s[2], s[3])] = true end
    for _, f in ipairs(spec.fixtures or {}) do addFixture(f[1], f[2], f[3], f[4]) end
    return rooms
end

local function house(spec, id, status, extra)
    local rooms = buildHouse(spec)
    local rec = {
        id = id, key = spec.rect.x1 .. "," .. spec.rect.y1 .. ",0", rect = spec.rect, floors = spec.floors or 1, rooms = rooms,
        status = status or "fitout", capacity = 0, keep = {}, salvage = { keptBeds = (extra and extra.kept) or 0 },
    }
    return rec
end

for x = 94, 140 do
    for y = 94, 130 do mkSquare(x, y, 0, true) end
end

local camp = Camp.create({ x1 = 94, y1 = 94, x2 = 140, y2 = 130, z = 0 }, "Fit")
camp.phase = "plan"
check("camp created", camp ~= nil and #camp.storage == 1)

local specA = {
    rect = { x1 = 100, y1 = 100, x2 = 111, y2 = 109, z = 0 }, floors = 2,
    rooms = {
        { name = "livingroom", x1 = 100, y1 = 100, x2 = 104, y2 = 104, z = 0 },
        { name = "kitchen", x1 = 105, y1 = 100, x2 = 107, y2 = 102, z = 0 },
        { name = "diningroom", x1 = 108, y1 = 100, x2 = 111, y2 = 102, z = 0 },
        { name = "bathroom", x1 = 110, y1 = 103, x2 = 111, y2 = 104, z = 0 },
        { name = "hall", x1 = 105, y1 = 103, x2 = 109, y2 = 104, z = 0 },
        { name = "garage", x1 = 100, y1 = 105, x2 = 105, y2 = 108, z = 0 },
        { name = "bedroom", x1 = 106, y1 = 105, x2 = 108, y2 = 108, z = 0 },
        { name = "hall", x1 = 106, y1 = 103, x2 = 108, y2 = 104, z = 1 },
        { name = "bedroom", x1 = 102, y1 = 100, x2 = 105, y2 = 103, z = 1 },
        { name = "bedroom", x1 = 106, y1 = 105, x2 = 108, y2 = 109, z = 1 },
    },
    doors = {
        { 100, 102, 0, false }, { 105, 101, 0, false }, { 108, 101, 0, false }, { 102, 105, 0, true },
        { 107, 105, 0, true }, { 106, 103, 0, true }, { 110, 103, 0, true },
        { 106, 103, 1, false }, { 107, 105, 1, true },
    },
    windows = {
        { 101, 100, 0, true }, { 103, 100, 0, true }, { 106, 100, 0, true }, { 109, 100, 0, true }, { 107, 109, 0, true },
        { 102, 101, 1, false }, { 102, 102, 1, false }, { 103, 100, 1, true },
        { 107, 110, 1, true }, { 109, 107, 1, false },
    },
    opens = { { 104, 103, 0, "E" } },
    stairs = { { 109, 103, 0 }, { 109, 104, 0 } },
    fixtures = {
        { 105, 100, 0 }, { 106, 100, 0 }, { 107, 100, 0 }, { 100, 104, 0, true }, { 110, 104, 0 }, { 111, 104, 0, true },
    },
}

local recA = house(specA, 1, "queued", { kept = 2 })

local before = Fitout.analyze(camp, recA)
check("estimate before scan finished", type(before) == "table" and recA.fitout.phase ~= "ready" or recA.fitout.phase == "ready")

Fitout.reset(recA)
Fitout.scanBudget = 100
CALLS.count = 0
local cost0, work0 = Fitout.analyze(camp, recA)
local run = Fitout.runs[recA.id]
check("first call scans at most the budget", run ~= nil and run.cursor == 100, run and run.cursor)
check("estimate cost is a table", type(cost0) == "table" and type(work0) == "number")
local calls = 1
while recA.fitout.phase ~= "ready" and calls < 60 do
    Fitout.analyze(camp, recA)
    calls = calls + 1
end
check("analysis finished over several calls", recA.fitout.phase == "ready" and calls >= 5, calls)
Fitout.scanBudget = 400
check("queued rec gives provisional plan", recA.fitout.provisional == true)

recA.status = "fitout"
local costA, workA = Fitout.analyze(camp, recA)
check("replan when stage starts", recA.fitout.phase ~= "ready" or recA.fitout.provisional == false)
local guard = 0
while recA.fitout.phase ~= "ready" and guard < 60 do
    costA, workA = Fitout.analyze(camp, recA)
    guard = guard + 1
end
check("ready after replan", recA.fitout.phase == "ready" and recA.fitout.provisional == false, guard)
check("not partial", recA.fitout.partial == false)

local ops = Fitout.ops(camp, recA)
check("ops produced", #ops >= 40, #ops)

local function roleOf(rec, name, z, x1)
    for _, room in ipairs(rec.fitout.rooms) do
        if room.name == name and room.z == z and (x1 == nil or room.x1 == x1) then return room.kind, room end
    end
    return nil
end

check("living is common", roleOf(recA, "livingroom", 0) == "common", roleOf(recA, "livingroom", 0))
check("dining is mess", roleOf(recA, "diningroom", 0) == "mess", roleOf(recA, "diningroom", 0))
check("kitchen untouched", roleOf(recA, "kitchen", 0) == "none", roleOf(recA, "kitchen", 0))
check("bathroom untouched", roleOf(recA, "bathroom", 0) == "none", roleOf(recA, "bathroom", 0))
check("ground hall untouched", roleOf(recA, "hall", 0) == "none", roleOf(recA, "hall", 0))
check("upstairs hall untouched", roleOf(recA, "hall", 1) == "none", roleOf(recA, "hall", 1))
check("garage is workshop", roleOf(recA, "garage", 0) == "workshop", roleOf(recA, "garage", 0))
check("ground bedroom is infirmary", roleOf(recA, "bedroom", 0) == "infirmary", roleOf(recA, "bedroom", 0))
check("best view upstairs is guard", roleOf(recA, "bedroom", 1, 102) == "guard", roleOf(recA, "bedroom", 1, 102))
check("other upstairs bedroom is dorm", roleOf(recA, "bedroom", 1, 106) == "dorm", roleOf(recA, "bedroom", 1, 106))

local opAt = {}
local function opKey(op) return K(op.x, op.y, op.z) end
for i, op in ipairs(ops) do
    opAt[opKey(op)] = op
    if op.slot ~= "F" .. i then check("slot names", false, op.slot) end
end

local covered = {}
for _, f in ipairs(FIXTURES) do
    if opAt[K(f.x, f.y, f.z)] ~= nil then covered[#covered + 1] = K(f.x, f.y, f.z) end
end
check("fixtures never covered", #covered == 0, table.concat(covered, ";"))

local nearKitchen = {}
for _, f in ipairs(FIXTURES) do
    if f.x >= 105 and f.x <= 107 and f.y == 100 and f.z == 0 then
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if opAt[K(f.x + d[1], f.y + d[2], 0)] ~= nil then nearKitchen[#nearKitchen + 1] = K(f.x + d[1], f.y + d[2], 0) end
        end
    end
end


local inBath = 0
for _, op in ipairs(ops) do
    if op.z == 0 and op.x >= 110 and op.x <= 111 and op.y >= 103 and op.y <= 104 then inBath = inBath + 1 end
end
check("bathroom has no ops", inBath == 0)

local blockedDoor = {}
for _, edge in pairs(DOORSET) do
    for _, c in ipairs({ edge.a, edge.b }) do
        if opAt[K(c.x, c.y, c.z)] ~= nil then blockedDoor[#blockedDoor + 1] = K(c.x, c.y, c.z) end
    end
end
for _, c in ipairs({ { 104, 103, 0 }, { 105, 103, 0 } }) do
    if opAt[K(c[1], c[2], c[3])] ~= nil then blockedDoor[#blockedDoor + 1] = K(c[1], c[2], c[3]) end
end
check("door fronts stay free", #blockedDoor == 0, table.concat(blockedDoor, ";"))

local stairFront = {}
for _, c in ipairs({ { 108, 103, 0 }, { 108, 104, 0 }, { 108, 103, 1 }, { 108, 104, 1 }, { 108, 105, 1 } }) do
    if opAt[K(c[1], c[2], c[3])] ~= nil then stairFront[#stairFront + 1] = K(c[1], c[2], c[3]) end
end
check("stairs fronts stay free", #stairFront == 0, table.concat(stairFront, ";"))

local occupied = {}
for _, op in ipairs(ops) do occupied[opKey(op)] = true end
for _, f in ipairs(FIXTURES) do occupied[K(f.x, f.y, f.z)] = true end
for id in pairs(STAIRS) do occupied[id] = true end

local function sameOrDoor(a, b)
    local ra, rb = CELL[K(a.x, a.y, a.z)], CELL[K(b.x, b.y, b.z)]
    if ra == rb and ra ~= nil then return true end
    local id = edgeId(a, b)
    return DOORSET[id] ~= nil or OPEN[id] == true
end

local function bfs(starts)
    local seen = {}
    local queue = {}
    for _, s in ipairs(starts) do
        local id = K(s.x, s.y, s.z)
        if not occupied[id] and not seen[id] then
            seen[id] = true
            queue[#queue + 1] = s
        end
    end
    local head = 1
    while head <= #queue do
        local c = queue[head]
        head = head + 1
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local n = { x = c.x + d[1], y = c.y + d[2], z = c.z }
            local id = K(n.x, n.y, n.z)
            local sq = MADE[id]
            if sq ~= nil and not seen[id] and not occupied[id] and (CELL[id] ~= nil or DOORSET[edgeId(c, n)] ~= nil) and sameOrDoor(c, n) then
                seen[id] = true
                queue[#queue + 1] = n
            end
        end
    end
    return seen
end

local reach0 = bfs({ { x = 99, y = 102, z = 0 } })
local reach1 = bfs({ { x = 108, y = 103, z = 1 } })
local function reached(c) return reach0[K(c.x, c.y, c.z)] or reach1[K(c.x, c.y, c.z)] end

local allDoorsReached = true
for _, edge in pairs(DOORSET) do
    if not reached(edge.a) then allDoorsReached = false end
    if edge.b.x ~= 99 and not reached(edge.b) then allDoorsReached = false end
end
check("every door front reachable", allDoorsReached)
check("stairs landing reachable from entrance", reach0[K(108, 103, 0)] == true)

local pieces = {}
for _, op in ipairs(ops) do
    pieces[op.group] = pieces[op.group] or {}
    table.insert(pieces[op.group], op)
end
local stranded = {}
local pieceCount = 0
for id, list in pairs(pieces) do
    pieceCount = pieceCount + 1
    local ok = false
    for _, op in ipairs(list) do
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local n = { x = op.x + d[1], y = op.y + d[2], z = op.z }
            local from = { x = op.x, y = op.y, z = op.z }
            local own = false
            for _, other in ipairs(list) do
                if other.x == n.x and other.y == n.y then own = true end
            end
            if not own and reached(n) and sameOrDoor(from, n) then ok = true end
        end
    end
    local code = list[1].code
    if code ~= "t" and not ok then stranded[#stranded + 1] = id .. ":" .. list[1].e .. "@" .. list[1].x .. "," .. list[1].y .. "," .. list[1].z end
end
check("every piece reachable", #stranded == 0, table.concat(stranded, ";"))

local fixtureAccess = true
for _, f in ipairs(FIXTURES) do
    if f.x >= 105 and f.x <= 107 and f.y == 100 and f.z == 0 then
        local any = false
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if reach0[K(f.x + d[1], f.y + d[2], 0)] then any = true end
        end
        if not any then fixtureAccess = false end
    end
end
check("kitchen fixtures keep access", fixtureAccess)

local beds, seats, crates, storageOps = 0, 0, 0, 0
for _, op in ipairs(ops) do
    if op.code == "b" then beds = beds + 0.5 end
    if op.code == "s" then seats = seats + 1 end
    if op.code == "c" then crates = crates + 1 end
    if op.storage then storageOps = storageOps + 1 end
end
check("beds placed", beds >= 6, beds)
check("capacity counts beds and kept beds", recA.capacity == beds + 2, recA.capacity .. "/" .. beds)
local sum = Fitout.summary(recA)
check("summary beds equals capacity", sum.beds == recA.capacity and sum.capacity == recA.capacity and sum.bedsNew == beds)
check("summary seats", sum.seats == seats and seats >= 6, sum.seats .. "/" .. seats)
check("summary crates", sum.crates == crates and crates >= 4, sum.crates .. "/" .. crates)
check("summary rooms", sum.rooms.dorm == 1 and sum.rooms.common == 1 and sum.rooms.mess == 1 and sum.rooms.infirmary == 1
    and sum.rooms.workshop == 1 and sum.rooms.guard == 1, sum.rooms.dorm .. sum.rooms.common .. sum.rooms.mess .. sum.rooms.infirmary .. sum.rooms.workshop .. sum.rooms.guard)
check("summary posts", sum.posts == #recA.fitout.posts and sum.posts >= 1, sum.posts)
check("describe text", type(Fitout.describe(recA)) == "string" and Fitout.describe(recA):find("%d") ~= nil)

local garageStorage = 0
for _, op in ipairs(ops) do
    if op.storage and op.z == 0 and op.x >= 100 and op.x <= 105 and op.y >= 105 and op.y <= 108 and op.container == "crate" and op.e == "Wood_Crate_Lvl2" then
        garageStorage = garageStorage + 1
    end
end
check("garage crates are storage", garageStorage >= 2 and garageStorage == storageOps, garageStorage .. "/" .. storageOps)

local formatOk = true
for _, op in ipairs(ops) do
    if op.t ~= "prop" or type(op.sprite) ~= "string" or type(op.x) ~= "number" or type(op.y) ~= "number" or type(op.z) ~= "number" then formatOk = false end
    if op.e ~= nil and A.Entities[op.e] == nil then formatOk = false end
end
check("op format", formatOk)

local spriteOk = true
local seenBed, seenBench, seenChair, seenShelf, seenTable = false, false, false, false, false
for _, op in ipairs(ops) do
    if op.e == "Wood_Bed" then seenBed = true end
    if op.e == nil and op.sprite:find("^furniture_seating_outdoor_01_") then seenBench = true end
    if op.e == "Wood_Chair_Lvl1" then seenChair = true end
    if op.e == "Wood_Shelves_Lvl1" then seenShelf = true end
    if op.e == "Wood_TableLvl1" then seenTable = true end
end
check("furniture variety", seenBed and seenBench and seenChair and seenShelf and seenTable)

local expected = Bp.cost(ops)
local sameCost = true
for kind, amount in pairs(expected) do
    if costA[kind] ~= amount then sameCost = false end
end
for kind, amount in pairs(costA) do
    if expected[kind] ~= amount then sameCost = false end
end
check("analyze cost equals Bp.cost", sameCost and expected.planks ~= nil and expected.nails ~= nil, tostring(expected.planks) .. "/" .. tostring(costA.planks))
check("analyze work equals Bp.work", math.abs(workA - Bp.work(ops)) < 0.001, workA)
check("logs and rope not needed", expected.logs == nil and expected.rope == nil)

local function render(rec, z, rect)
    local lines = {}
    for y = rect.y1, rect.y2 do
        local row = {}
        for x = rect.x1, rect.x2 do
            local id = K(x, y, z)
            local ch = " "
            if CELL[id] ~= nil then ch = "." end
            if STAIRS[id] then ch = "S" end
            for _, f in ipairs(FIXTURES) do
                if f.x == x and f.y == y and f.z == z then ch = f.soft and "f" or "F" end
            end
            local op = opAt[id]
            if op ~= nil then
                if op.code == "b" then ch = "B"
                elseif op.code == "t" then ch = "T"
                elseif op.code == "s" then ch = op.e == nil and "b" or "c"
                elseif op.code == "c" then ch = op.storage and "K" or "C"
                elseif op.code == "h" then ch = "H" end
            end
            for _, p in ipairs(rec.fitout.posts) do
                if p.x == x and p.y == y and p.z == z then ch = "P" end
            end
            row[#row + 1] = ch
        end
        lines[#lines + 1] = table.concat(row)
    end
    return table.concat(lines, "\n")
end

print("GROUND\n" .. render(recA, 0, { x1 = 99, y1 = 100, x2 = 112, y2 = 109 }))
print("UPSTAIRS\n" .. render(recA, 1, { x1 = 99, y1 = 100, x2 = 112, y2 = 110 }))

local posts = recA.fitout.posts
local postsOk = #posts >= 1
for _, p in ipairs(posts) do
    if type(p.x) ~= "number" or type(p.y) ~= "number" or p.z ~= 1 or opAt[K(p.x, p.y, p.z)] ~= nil or p.face == nil then postsOk = false end
end
check("posts recorded upstairs on free tiles", postsOk, #posts)
check("two posts for two directions", #posts == 2, #posts)

local function placed(rec)
    local out, n = {}, 0
    for x = 98, 135 do
        for y = 98, 140 do
            for z = 0, 1 do
                local sq = MADE[K(x, y, z)]
                if sq ~= nil then
                    for i = 0, sq:getObjects():size() - 1 do
                        local o = sq:getObjects():get(i)
                        local tag = World.tag(o)
                        if type(tag) == "table" and tag.project == "A" .. rec.id then
                            out[tag.slot] = o
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    return out, n
end

local box = Stock.crate(camp, camp.storage[1]):getContainer()
Stock.refresh(camp)
check("camp stock empty", (camp.stock.planks or 0) == 0)

local done, progress, spent, waiting = Fitout.step(camp, recA, 3, 1)
check("waits without materials", done == false and type(waiting) == "table" and waiting.planks ~= nil and spent == 0, tostring(done))
check("waiting stored", type(recA.fitout.waiting) == "table")
local _, n0 = placed(recA)
check("nothing placed without materials", n0 == 0, n0)
check("progress is zero", progress == 0, progress)

for _ = 1, 40 do box:AddItem("Base.Plank") end
for _ = 1, 40 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
local totalSpent = 0
local lastWaiting
for _ = 1, 30 do
    local d, p, s, w = Fitout.step(camp, recA, 3, 1)
    totalSpent = totalSpent + s
    lastWaiting = w
    done = d
    progress = p
end
local _, n1 = placed(recA)
check("partial placement when stock is short", n1 > 0 and n1 < #ops and done == false, n1 .. "/" .. #ops)
check("short stock sets waiting", type(lastWaiting) == "table")
Stock.refresh(camp)
check("stock consumed only for placed", camp.stock.planks >= 0 and camp.stock.planks < 40 and totalSpent > 0, camp.stock.planks)
check("progress between 0 and 1", progress > 0 and progress < 1, progress)

local planksBefore, nailsBefore = 0, 0
for _ = 1, 400 do box:AddItem("Base.Plank") end
for _ = 1, 400 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
planksBefore, nailsBefore = camp.stock.planks, camp.stock.nails
local rest = Bp.cost(Fitout.remaining(camp, recA))
local steps = 0
repeat
    done, progress, spent = Fitout.step(camp, recA, 4, 1)
    steps = steps + 1
until done or steps > 200
check("finishes", done == true and progress == 1, steps)
Stock.refresh(camp)
check("materials consumed equal remaining cost", planksBefore - camp.stock.planks == rest.planks and nailsBefore - camp.stock.nails == rest.nails,
    (planksBefore - camp.stock.planks) .. "/" .. tostring(rest.planks))

local objects, count = placed(recA)
check("all ops placed with ALC tags", count == #ops, count .. "/" .. #ops)
local slotsOk = true
for i, op in ipairs(ops) do
    local o = objects[op.slot]
    if o == nil then slotsOk = false
    else
        local tag = World.tag(o)
        if tag.camp ~= camp.id or tag.project ~= "A1" then slotsOk = false end
        if op.storage and tag.kind ~= "storage" then slotsOk = false end
        if not op.storage and tag.kind ~= "built" then slotsOk = false end
        if op.container ~= nil and o:getContainer() == nil then slotsOk = false end
    end
end
check("tags, slots and containers", slotsOk)
check("storage crates registered", #camp.storage == 1 + storageOps, #camp.storage)
local findable = 0
for i = 2, #camp.storage do
    if Stock.crate(camp, camp.storage[i]) ~= nil then findable = findable + 1 end
end
check("registered storage resolvable", findable == storageOps, findable)

check("capacity after completion", recA.capacity == beds + 2, recA.capacity)
local costDone = Fitout.analyze(camp, recA)
check("no cost after completion", ALifeCamp.isEmpty(costDone))
check("summary finished", Fitout.summary(recA).finished == true)

local firstOp = ops[1]
local sq1 = World.square(firstOp.x, firstOp.y, firstOp.z)
local removed = Place.removeSlot(sq1, firstOp.slot, "A1")
check("removeSlot finds the tagged object", removed == 1, removed)
local _, count2 = placed(recA)
check("object removed", count2 == count - 1, count2)

recA.fitout.done = {}
recA.fitout.finished = false
recA.fitout.cursor = 1
Fitout.cache = {}
Fitout.runs = {}
local d2, p2, s2 = false, 0, 0
for _ = 1, 60 do local a, b, c = Fitout.step(camp, recA, 4, 1) d2 = a s2 = s2 + c if a then break end end
local _, count3 = placed(recA)
check("reload keeps placed objects, no duplicates", count3 == count2 + 1 and d2 == true, count3 .. "/" .. count2 .. tostring(d2) .. tostring(s2))
local doneCount = 0
for _ in pairs(recA.fitout.done) do doneCount = doneCount + 1 end
check("reload rebuilds done map", doneCount == count, doneCount)

local specB = {
    rect = { x1 = 120, y1 = 100, x2 = 130, y2 = 106, z = 0 }, floors = 1,
    rooms = {
        { name = "kitchen", x1 = 120, y1 = 100, x2 = 124, y2 = 103, z = 0 },
        { name = "bedroom", x1 = 125, y1 = 100, x2 = 128, y2 = 103, z = 0 },
        { name = "bedroom", x1 = 120, y1 = 104, x2 = 123, y2 = 106, z = 0 },
        { name = "bathroom", x1 = 124, y1 = 104, x2 = 125, y2 = 105, z = 0 },
        { name = "storage", x1 = 126, y1 = 104, x2 = 128, y2 = 105, z = 0 },
    },
    doors = {
        { 120, 101, 0, false }, { 125, 102, 0, false }, { 122, 104, 0, true }, { 124, 104, 0, true }, { 127, 104, 0, true },
    },
    windows = { { 122, 100, 0, true }, { 127, 100, 0, true }, { 120, 105, 0, false } },
    fixtures = { { 120, 100, 0 }, { 121, 100, 0 }, { 122, 100, 0 } },
}
for i = 1, #specB.fixtures do
    local f = specB.fixtures[i]
    if f[1] == 122 then table.remove(specB.fixtures, i) break end
end
table.insert(specB.fixtures, { 123, 100, 0 })
local recB = house(specB, 2, "fitout")
local costB = Fitout.analyze(camp, recB, true)
check("house B analyzed synchronously", recB.fitout.phase == "ready" and type(costB) == "table")
local opsB = Fitout.ops(camp, recB)
local kitchenKind = roleOf(recB, "kitchen", 0)
check("big kitchen becomes mess", kitchenKind == "mess", kitchenKind)
local nearB = 0
local opAtB = {}
for _, op in ipairs(opsB) do opAtB[K(op.x, op.y, op.z)] = op end
for _, f in ipairs({ { 120, 100 }, { 121, 100 }, { 123, 100 } }) do
    if opAtB[K(f[1], f[2], 0)] ~= nil then nearB = nearB + 1 end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        if opAtB[K(f[1] + d[1], f[2] + d[2], 0)] ~= nil then nearB = nearB + 1 end
    end
end
check("mess extension never touches kitchen set", nearB == 0, nearB)
local kitchenOps = 0
for _, op in ipairs(opsB) do
    if op.x >= 120 and op.x <= 124 and op.y >= 100 and op.y <= 103 then kitchenOps = kitchenOps + 1 end
end
check("kitchen got tables and seats", kitchenOps >= 4, kitchenOps)
local storageKind, storageRoom = roleOf(recB, "storage", 0)
check("storage closet is workshop variant", storageKind == "workshop" and storageRoom.crates >= 1, storageKind)
print("HOUSE B\n" .. render(recB, 0, { x1 = 119, y1 = 100, x2 = 130, y2 = 106 }))

local specC = {
    rect = { x1 = 130, y1 = 112, x2 = 139, y2 = 118, z = 0 }, floors = 1,
    rooms = {
        { name = "livingroom", x1 = 130, y1 = 112, x2 = 135, y2 = 116, z = 0 },
        { name = "kitchen", x1 = 136, y1 = 112, x2 = 139, y2 = 115, z = 0 },
    },
    doors = { { 130, 114, 0, false }, { 136, 113, 0, false } },
    windows = { { 132, 112, 0, true }, { 138, 112, 0, true } },
    fixtures = { { 136, 112, 0 }, { 137, 112, 0 } },
}
local recC = house(specC, 3, "fitout")
Fitout.analyze(camp, recC, true)
local sumC = Fitout.summary(recC)
check("home without bedrooms still gets beds", sumC.beds >= 2 and sumC.rooms.dorm == 1, sumC.beds)
local seatsC = 0
for _, op in ipairs(Fitout.ops(camp, recC)) do
    if op.code == "s" then seatsC = seatsC + 1 end
end
check("mixed room has seating too", seatsC >= 3, seatsC)

local specD = {
    rect = { x1 = 100, y1 = 120, x2 = 108, y2 = 126, z = 0 }, floors = 1,
    rooms = {
        { name = "bedroom", x1 = 100, y1 = 120, x2 = 103, y2 = 123, z = 0 },
        { name = "bedroom", x1 = 104, y1 = 120, x2 = 108, y2 = 123, z = 0 },
    },
    doors = { { 104, 121, 0, false }, { 100, 122, 0, false } },
    windows = { { 101, 120, 0, true }, { 106, 120, 0, true } },
}
local recD = house(specD, 4, "fitout")
HIDDEN[K(106, 122, 0)] = true
HIDDEN[K(107, 122, 0)] = true
Fitout.analyze(camp, recD, true)
check("unloaded squares mark partial", recD.fitout.phase == "ready" and recD.fitout.partial == true)
check("partial plan still has ops", #Fitout.ops(camp, recD) >= 2)
HIDDEN[K(106, 122, 0)] = nil
HIDDEN[K(107, 122, 0)] = nil

local recE = house({
    rect = { x1 = 100, y1 = 130, x2 = 108, y2 = 136, z = 0 }, floors = 1,
    rooms = {
        { name = "bedroom", x1 = 100, y1 = 130, x2 = 104, y2 = 133, z = 0 },
        { name = "bedroom", x1 = 105, y1 = 130, x2 = 108, y2 = 133, z = 0 },
    },
    doors = { { 105, 131, 0, false }, { 100, 132, 0, false } },
    windows = { { 101, 130, 0, true }, { 107, 130, 0, true } },
}, 5, "fitout")
Fitout.analyze(camp, recE, true)
local opsE = Fitout.ops(camp, recE)
check("house E planned", #opsE >= 4 and recE.fitout.partial == false, #opsE)
for _ = 1, 600 do box:AddItem("Base.Plank") end
for _ = 1, 600 do box:AddItem("Base.Nails") end
Stock.refresh(camp)
local target = opsE[1]
HIDDEN[K(target.x, target.y, target.z)] = true
local okStep, d5 = pcall(Fitout.step, camp, recE, 40, 5)
check("step tolerates unloaded squares", okStep and d5 == false, tostring(d5))
local _, nE = placed(recE)
check("unloaded group skipped, others placed", nE >= 1 and nE < #opsE, nE)
HIDDEN[K(target.x, target.y, target.z)] = nil
local stepsE = 0
repeat
    d5 = Fitout.step(camp, recE, 4, 1)
    stepsE = stepsE + 1
until d5 == true or stepsE > 100
local _, nE2 = placed(recE)
check("unloaded group completed once loaded", d5 == true and nE2 == #opsE, nE2 .. "/" .. #opsE)

local recF = house({
    rect = { x1 = 110, y1 = 130, x2 = 118, y2 = 136, z = 0 }, floors = 1,
    rooms = {
        { name = "bedroom", x1 = 110, y1 = 130, x2 = 114, y2 = 133, z = 0 },
        { name = "bedroom", x1 = 115, y1 = 130, x2 = 118, y2 = 133, z = 0 },
    },
    doors = { { 115, 131, 0, false }, { 110, 132, 0, false } },
    windows = { { 111, 130, 0, true }, { 117, 130, 0, true } },
}, 6, "fitout")
Fitout.analyze(camp, recF, true)
local opsF = Fitout.ops(camp, recF)
local capBefore = recF.capacity
local victim = opsF[1]
MADE[K(victim.x, victim.y, victim.z)].free = false
local dF, stepsF = false, 0
repeat
    dF = Fitout.step(camp, recF, 4, 1)
    stepsF = stepsF + 1
until dF == true or stepsF > 100
check("blocked square skips the piece", dF == true and recF.fitout.skipped[victim.slot] == true, tostring(dF))
check("capacity drops when a bed is skipped", victim.code ~= "b" or recF.capacity < capBefore, capBefore .. "->" .. recF.capacity)
local _, nF = placed(recF)
check("blocked op not placed", nF < #opsF, nF .. "/" .. #opsF)

local bigStart = CALLS.count
local recG = house({
    rect = { x1 = 100, y1 = 140, x2 = 130, y2 = 150, z = 0 }, floors = 1,
    rooms = {
        { name = "livingroom", x1 = 100, y1 = 140, x2 = 115, y2 = 150, z = 0 },
        { name = "bedroom", x1 = 116, y1 = 140, x2 = 130, y2 = 150, z = 0 },
    },
    doors = { { 116, 145, 0, false }, { 100, 145, 0, false } },
    windows = { { 105, 140, 0, true }, { 120, 140, 0, true } },
}, 7, "fitout")
for x = 96, 134 do
    for y = 136, 154 do mkSquare(x, y, 0, true) end
end
CALLS.count = 0
Fitout.analyze(camp, recG)
local runG = Fitout.runs[recG.id]
check("default call scans at most 400 squares", runG ~= nil and runG.cursor <= 400 and runG.cursor > 0, runG and runG.cursor)
check("square lookups bounded per call", CALLS.count <= 400 * 4, CALLS.count)
local guardG = 0
while recG.fitout.phase ~= "ready" and guardG < 80 do
    Fitout.analyze(camp, recG)
    guardG = guardG + 1
end
check("large building eventually planned", recG.fitout.phase == "ready", guardG)
check("large rooms respect bed cap", Fitout.summary(recG).bedsNew <= Fitout.maxBeds * 2)

local summary0 = Fitout.summary({ id = 99 })
check("summary of untouched rec", summary0.beds == 0 and summary0.rooms.dorm == 0)
check("analyze tolerates bad rec", select(2, Fitout.analyze(camp, { id = 98 })) == 0)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
