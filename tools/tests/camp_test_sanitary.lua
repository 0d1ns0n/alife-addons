dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Hooks, Options, Settlers, Skills, Work, Plan, Build, Bp, World, Gates, Expand, Stats, T =
    A.Store, A.Geo, A.Camp, A.Hooks, A.Options, A.Settlers, A.Skills, A.Work, A.Plan, A.Build, A.Blueprints, A.World, A.Gates, A.Expand, A.Stats, A.T
local San = A.Sanitary
local reg, orders = MOCKALIFE()

PLAYER = NEWPLAYER(0)
HOURS = 300

local HIDDEN = {}
local GRID = 0
local baseCell = getCell()
function getCell()
    return {
        getGridSquare = function(self, x, y, z)
            GRID = GRID + 1
            if HIDDEN[x .. "," .. y .. "," .. z] then return nil end
            return baseCell.getGridSquare(self, x, y, z)
        end,
    }
end

local CREATED = {}
local baseThumpable = IsoThumpable.new
IsoThumpable.new = function(cell, square, sprite, a, b, c)
    local o = baseThumpable(cell, square, sprite, a, b, c)
    o.spriteName = sprite
    o.infoTable = type(a) == "boolean" and b or nil
    o.setName = function(self, name) self.nm = name end
    o.setIsThumpable = function(self, value) self.thump = value end
    o.setCanBarricade = function(self, value) self.barricade = value end
    CREATED[#CREATED + 1] = o
    return o
end

local function newBody(square, data)
    local b = { class = "IsoDeadBody", md = data or {}, sq = square }
    function b:getModData() return self.md end
    function b:getSquare() return self.sq end
    function b:getDescriptor() return nil end
    square.bodies[#square.bodies + 1] = b
    return b
end

local SQMETA = {}
function SQMETA.haveBlood(self) return self.blood == true end
function SQMETA.removeBlood(self) self.blood = false self.washes = (self.washes or 0) + 1 end
function SQMETA.disableErosion(self) self.erosionOff = true end
function SQMETA.addCorpse(self) return newBody(self, {}) end
local METATABLE = { __index = SQMETA }

local function decorate(square)
    square.blood = false
    return setmetatable(square, METATABLE)
end

function addBloodSplat(square, n) square.blood = true end

for x = 40, 260 do
    for y = 40, 260 do decorate(NEWSQUARE(x, y, 0)) end
end
for x = 100, 109 do
    for y = 100, 109 do decorate(NEWSQUARE(x, y, 1)) end
end

local function sq(x, y, z) return World.square(x, y, z or 0) end
local function body(x, y, data, z) return newBody(sq(x, y, z), data) end
local function blood(x, y, z) sq(x, y, z).blood = true end

local function tick(c, n)
    for _ = 1, n do
        HOURS = HOURS + 1 / 60
        Hooks.each("minute", c, 1)
    end
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function plain(value, seen, path)
    local kind = type(value)
    if kind == "function" or kind == "userdata" or kind == "thread" then return false, path end
    if kind ~= "table" then return true end
    seen = seen or {}
    if seen[value] then return false, path .. "(cycle)" end
    seen[value] = true
    local numeric, top = 0, 0
    for k, v in pairs(value) do
        if type(k) == "number" then
            numeric = numeric + 1
            if k > top then top = k end
        elseif type(k) ~= "string" then
            return false, path .. "(key)"
        end
        local ok, where = plain(v, seen, path .. "." .. tostring(k))
        if not ok then return false, where end
    end
    seen[value] = nil
    if numeric > 0 and numeric ~= top then return false, path .. "(holes)" end
    return true
end

local function specials(square)
    local out = {}
    local list = square:getObjects()
    for i = 0, list:size() - 1 do
        local o = list:get(i)
        local tag = World.tag(o)
        if type(tag) == "table" and tag.kind == "grave" and o.isFloor ~= true then out[#out + 1] = o end
    end
    return out
end

local function graveObjects(c)
    local out = {}
    local p = San.plot(c)
    if p == nil then return out end
    for x = p.x, p.x + p.w - 1 do
        for y = p.y, p.y + p.h - 1 do
            for _, o in ipairs(specials(sq(x, y))) do out[#out + 1] = { o = o, x = x, y = y } end
        end
    end
    return out
end

local function pits(c)
    local out = {}
    for _, entry in ipairs(graveObjects(c)) do
        if entry.o.spriteName ~= nil then out[#out + 1] = entry end
    end
    return out
end

local CEM = "location_community_cemetary_01_"

local function signsOf(c, numbers)
    local count = 0
    for _, entry in ipairs(graveObjects(c)) do
        if entry.o.spriteName == nil and entry.o.sprite ~= nil then
            for _, n in ipairs(numbers) do
                if entry.o.sprite.name == CEM .. n then count = count + 1 end
            end
        end
    end
    return count
end

local function zoneCount(c)
    local zone = San.zone(c)
    local bodies, bloods = 0, 0
    for x = zone.x1, zone.x2 do
        for y = zone.y1, zone.y2 do
            local s = sq(x, y)
            if s ~= nil then
                bodies = bodies + #s.bodies
                if s.blood then bloods = bloods + 1 end
            end
        end
    end
    return bodies, bloods
end

local function join(c, uid, role, x, y)
    ADDACTOR(reg, uid, "friendly", x, y, sq(x, y))
    Settlers.settle(c, uid, "Name" .. uid)
    c.settlers[uid].role = role
end

local function follow(shell, c, uid)
    local t = c.settlers[uid].san
    if t ~= nil then
        shell.px = t.x
        shell.py = t.y
    end
end

local camp, plot, state, lifeTab, layout, Cheats

do
    check("module exported", San ~= nil and type(San.score) == "function" and type(San.stats) == "function" and type(San.reserve) == "function")
    local sanitation, ring = Options.byKey.sanitation, Options.byKey.sanitaryRing
    check("option sanitation", sanitation ~= nil and sanitation.kind == "toggle" and sanitation.group == "life" and sanitation.default == true)
    check("option ring", ring ~= nil and ring.kind == "cycle" and ring.group == "life" and ring.default == 25 and table.concat(ring.values, ",") == "0,10,25,50")
    check("role registered", contains(Settlers.roles, "sanitary"))
    check("skill registered", contains(Skills.list, "clean") and Skills.primary.sanitary == "clean")
    check("cemetery kind", Bp.kinds.cemetery ~= nil and Bp.kinds.cemetery.build ~= nil)
    check("hooks registered", #(Hooks.lists.minute or {}) >= 1 and #(Hooks.lists.anchor or {}) >= 1 and #(Hooks.lists.morale or {}) >= 1
        and #(Hooks.lists.died or {}) >= 1 and #(Hooks.lists.raidend or {}) >= 1 and #(Hooks.lists.roles or {}) >= 1 and #(Hooks.lists.settlerInfo or {}) >= 1)
    local priority
    for _, entry in ipairs(Hooks.lists.anchor or {}) do priority = entry.priority end
    check("anchor priority 30", priority == 30, priority)
    lifeTab = Hooks.tab("life")
    local found = false
    for _, section in ipairs(lifeTab.sections) do
        if section.title == "SanTitle" and section.priority == 30 then found = true end
    end
    check("life section registered", found)
    check("no forbidden calls", next == nil and math.random == nil and string.rep == nil)

    local ok, sizes = true, {}
    for _, size in ipairs({ { 17, 11 }, { 13, 9 }, { 9, 9 }, { 9, 7 }, { 7, 5 }, { 5, 4 }, { 5, 3 } }) do
        local lay = San.layout(size[1], size[2])
        sizes[#sizes + 1] = #lay.slots
        local seen = {}
        for _, slot in ipairs(lay.slots) do
            for dx = 0, 1 do
                local key = (slot.dx + dx) .. ":" .. slot.dy
                if seen[key] or slot.dx + dx == lay.cx or slot.dx < 0 or slot.dx + 1 > size[1] - 1 or slot.dy < 2 or slot.dy > size[2] - 1 then ok = false end
                seen[key] = true
            end
        end
    end
    check("layout slots disjoint and off the lane", ok)
    check("layout capacities", table.concat(sizes, ",") == "40,24,16,12,4,2,2", table.concat(sizes, ","))
    check("biggest plot matches the grave cap", sizes[1] == San.graveCap)
end

do
    camp = Camp.create({ x1 = 100, y1 = 100, x2 = 169, y2 = 159, z = 0 }, "San")
    camp.phase = "plan"
    camp.options.recruit = false
    camp.options.raids = false
    check("camp created", camp ~= nil)
    check("no plot before plan", San.plot(camp) == nil)
    check("reserve needs a fence", San.reserve(camp, true) == 0 and San.plot(camp) == nil)
    local added = Plan.generate(camp)
    check("plan generated", added > 10, added)
    plot = San.plot(camp)
    check("plan reserves cemetery", plot ~= nil and plot.kind == "cemetery", plot and plot.kind)
    local clash, inside = false, true
    local rect = Bp.footprint(plot)
    for _, p in ipairs(Build.list(camp)) do
        if p ~= plot and p.kind ~= "fence" and Build.overlaps(rect, Bp.footprint(p)) then clash = true end
    end
    if rect.x1 < camp.x1 or rect.y1 < camp.y1 or rect.x2 > camp.x2 or rect.y2 > camp.y2 then inside = false end
    check("plot overlaps no project", not clash)
    check("plot inside camp", inside)
    check("plot size scales with camp", plot.w == 13 and plot.h == 9, plot.w .. "x" .. plot.h)
    check("plot already done", plot.status == "done" and plot.prepared == true)
    local lane = false
    for _, geo in ipairs(Gates.list(camp)) do
        local x, y, w, h = Gates.rect(geo, -6, -1, 6, 11)
        if rect.x1 <= x + w - 1 and rect.x2 >= x and rect.y1 <= y + h - 1 and rect.y2 >= y then lane = true end
    end
    check("plot stays out of gate lanes", not lane)
    local corners = {
        { camp.x1, camp.y1, camp.x1 + 4, camp.y1 + 4 }, { camp.x2 - 4, camp.y1, camp.x2, camp.y1 + 4 },
        { camp.x1, camp.y2 - 4, camp.x1 + 4, camp.y2 }, { camp.x2 - 4, camp.y2 - 4, camp.x2, camp.y2 },
    }
    local towerClash = false
    for _, c in ipairs(corners) do
        if rect.x1 <= c[3] and rect.x2 >= c[1] and rect.y1 <= c[4] and rect.y2 >= c[2] then towerClash = true end
    end
    check("plot keeps corner tower spots free", not towerClash)
    local towers = 0
    for _, p in ipairs(Build.list(camp)) do if p.kind == "tower" then towers = towers + 1 end end
    check("towers still planned", towers >= 4, towers)
    for _ = 1, 3 do Plan.generate(camp) end
    local plots = 0
    for _, p in ipairs(Build.list(camp)) do if p.kind == "cemetery" then plots = plots + 1 end end
    check("exactly one cemetery", plots == 1, plots)
    check("reserve is idempotent", San.reserve(camp, true) == 0)
    check("stage list is valid", #Bp.stages(plot) == 1 and #Bp.stages(plot)[1].ops == 0)
    check("planner color registered", A.Districts ~= nil and A.Districts.colors.cemetery ~= nil)
    layout = San.layout(plot.w, plot.h)

    local big = Camp.create({ x1 = 300, y1 = 300, x2 = 399, y2 = 399, z = 0 }, "Big")
    big.phase = "plan"
    big.options.recruit = false
    Plan.generate(big)
    local bigPlot = San.plot(big)
    check("huge camps get the big cemetery", bigPlot ~= nil and bigPlot.w == 17 and bigPlot.h == 11, bigPlot and (bigPlot.w .. "x" .. bigPlot.h))
end

do
    local growCamp = Camp.create({ x1 = 190, y1 = 100, x2 = 229, y2 = 129, z = 0 }, "Grow")
    growCamp.phase = "plan"
    growCamp.options.recruit = false
    Plan.generate(growCamp)
    local growPlot = San.plot(growCamp)
    check("grow camp has plot", growPlot ~= nil)
    local gx, gy, gw, gh = growPlot.x, growPlot.y, growPlot.w, growPlot.h
    local expanded = 0
    for _, side in ipairs({ "N", "W", "S", "E" }) do
        if Expand.apply(growCamp, side) then
            expanded = expanded + 1
            growCamp.options.autoPlan = true
            Expand.finish(growCamp)
        end
    end
    local after = San.plot(growCamp)
    check("expansion happened", expanded >= 2, expanded)
    check("plot survives expansion in place", after ~= nil and after.id == growPlot.id and after.x == gx and after.y == gy and after.w == gw and after.h == gh)
    check("plot inside expanded camp", after.x >= growCamp.x1 and after.y >= growCamp.y1 and after.x + after.w - 1 <= growCamp.x2 and after.y + after.h - 1 <= growCamp.y2)
    local count = 0
    for _, p in ipairs(Build.list(growCamp)) do if p.kind == "cemetery" then count = count + 1 end end
    check("expansion adds no second plot", count == 1, count)

    local tiny = Camp.create({ x1 = 240, y1 = 240, x2 = 249, y2 = 247, z = 0 }, "Tiny")
    tiny.phase = "plan"
    tiny.options.recruit = false
    local okTiny, errTiny = pcall(Plan.generate, tiny)
    check("tiny camp plans without error", okTiny, errTiny)
    local tinyPlot = San.plot(tiny)
    check("tiny plot fits or is absent", tinyPlot == nil or (tinyPlot.x >= tiny.x1 and tinyPlot.x + tinyPlot.w - 1 <= tiny.x2 and tinyPlot.y >= tiny.y1 and tinyPlot.y + tinyPlot.h - 1 <= tiny.y2))

    local crowded = Camp.create({ x1 = 60, y1 = 180, x2 = 99, y2 = 219, z = 0 }, "Crowded")
    crowded.phase = "plan"
    crowded.options.recruit = false
    Build.add(crowded, "farm", crowded.x1, crowded.y1, { w = Geo.width(crowded), h = Geo.height(crowded) })
    Plan.generate(crowded)
    check("no space means no plot", San.plot(crowded) == nil)
    check("retry is throttled", San.reserve(crowded, false) == 0)
    HOURS = HOURS + 2
    check("full camp still has no plot", San.reserve(crowded, false) == 0 and San.plot(crowded) == nil)
    local createdBefore = #CREATED
    check("honor without plot is a mass grave", San.honor(crowded, "Mass Man") == "done")
    local stats = San.stats(crowded)
    check("mass grave counted", stats.buried == 1 and stats.graves == 0 and stats.mass == 1 and stats.fallen == 1)
    check("no objects without plot", #CREATED == createdBefore)
end

do
    ADDACTOR(reg, "u3", "friendly", 140, 140, sq(140, 140))
    Settlers.settle(camp, "u3", "Nameu3")
    camp.settlers.u3.role = "guard"
    state = San.state(camp)
    check("state defaults", state.removed == 0 and state.buried == 0 and state.graves == 0 and #state.points == 0 and state.cursor == 0)

    local zone = San.zone(camp)
    check("zone with ring 25", zone.w == 70 + 50 and zone.h == 60 + 50 and zone.ring == 25, zone.w .. "x" .. zone.h)
    Options.set(camp, "sanitaryRing", 0)
    local flat = San.zone(camp)
    check("zone without ring", flat.w == 70 and flat.h == 60 and flat.x1 == 100)
    Options.set(camp, "sanitaryRing", 10)
    check("zone ring 10", San.zone(camp).w == 90)
    Options.set(camp, "sanitaryRing", 50)
    check("zone ring 50", San.zone(camp).w == 170)
    Options.set(camp, "sanitaryRing", 25)
    check("ring option cycles", Options.cycle(camp, "sanitaryRing") == 50 and Options.cycle(camp, "sanitaryRing") == 0
        and Options.cycle(camp, "sanitaryRing") == 10 and Options.cycle(camp, "sanitaryRing") == 25)

    body(140, 130, {})
    blood(150, 135)
    body(102, 102, {}, 1)
    body(95, 130, {})
    blood(95, 130)
    body(80, 130, {})
    body(60, 130, {})
    blood(60, 131)

    local start = state.cursor
    local before = GRID
    tick(camp, 1)
    local used = GRID - before
    check("one minute stays within a few hundred checks", used > 0 and used <= 400, used)
    check("cursor advances", state.cursor > start)
    local minutes = 1
    while state.passes < 1 and minutes < 140 do
        tick(camp, 1)
        minutes = minutes + 1
    end
    check("full pass completes", state.passes >= 1, minutes)
    local keys = {}
    for _, p in ipairs(state.points) do keys[p.key] = p end
    check("finds body inside camp", keys["140:130:0"] ~= nil and keys["140:130:0"].c == 1)
    check("finds blood inside camp", keys["150:135:0"] ~= nil and keys["150:135:0"].b == 1)
    check("finds body upstairs inside camp", keys["102:102:1"] ~= nil)
    check("finds body and blood in ring", keys["95:130:0"] ~= nil and keys["95:130:0"].c == 1 and keys["95:130:0"].b == 1)
    check("finds far ring body", keys["80:130:0"] ~= nil)
    check("ignores beyond the ring", keys["60:130:0"] == nil and keys["60:131:0"] == nil)
    check("point count", #state.points == 5, #state.points)
    check("guard alone does not clean", state.removed == 0 and state.washed == 0 and #sq(140, 130).bodies == 1)
    local stats0 = San.stats(camp)
    check("stats shape", type(stats0.score) == "number" and type(stats0.corpses) == "number" and type(stats0.blood) == "number" and type(stats0.removed) == "number"
        and type(stats0.buried) == "number" and type(stats0.graves) == "number" and type(stats0.fallen) == "number")
    check("stats counts known dirt", stats0.corpses == 4 and stats0.blood == 2, stats0.corpses .. "/" .. stats0.blood)
    check("score reflects dirt", stats0.score < 100 and stats0.score > 50, stats0.score)

    Options.set(camp, "sanitaryRing", 0)
    tick(camp, 1)
    local noRing = {}
    for _, p in ipairs(state.points) do noRing[p.key] = true end
    check("shrinking the ring drops outside points", noRing["95:130:0"] == nil and noRing["80:130:0"] == nil and noRing["140:130:0"] == true)
    check("rezone restarts the cursor", state.sig == San.zone(camp).sig)
    Options.set(camp, "sanitaryRing", 25)
    tick(camp, 1)

    local function listed(key)
        for _, p in ipairs(state.points) do if p.key == key then return true end end
        return false
    end
    HIDDEN["140,130,0"] = true
    tick(camp, 3)
    check("unloaded square keeps its point for a while", listed("140:130:0"))
    tick(camp, 50)
    check("long unloaded point is forgotten", not listed("140:130:0"))
    check("unloaded body is untouched", #baseCell.getGridSquare(nil, 140, 130, 0).bodies == 1)
    HIDDEN["140,130,0"] = nil

    for i = 1, 30 do body(105 + i, 140, {}) end
    tick(camp, 20)
    check("point list is capped", #state.points <= 20, #state.points)
    local frozen = state.cursor
    tick(camp, 2)
    check("full list stalls the cursor", state.cursor == frozen)

    local cleaned = San.cleanAll(camp)
    local leftBodies, leftBlood = zoneCount(camp)
    check("cleanAll empties the zone", leftBodies == 0 and leftBlood == 0 and #state.points == 0, leftBodies .. "/" .. leftBlood)
    check("cleanAll counted work", cleaned >= 36, cleaned)
    check("beyond the zone survives", #sq(60, 130).bodies == 1 and sq(60, 131).blood == true)
    check("cleanAll removed counter", state.removed >= 34, state.removed)
    check("clean zone scores full", San.score(camp) == 100)
    sq(60, 130).bodies = {}
    sq(60, 131).blood = false
end

local san1
do
    san1 = ADDACTOR(reg, "u1", "friendly", 130, 130, sq(130, 130))
    Settlers.settle(camp, "u1", "Nameu1")
    camp.settlers.u1.role = "sanitary"
    join(camp, "u2", "builder", 128, 140)
    join(camp, "u4", "farmer", 126, 142)
    join(camp, "u5", "medic", 124, 142)
    join(camp, "u6", "medic", 122, 142)
    ADDACTOR(reg, "ally1", "friendly", 80, 80, nil)
    ADDACTOR(reg, "ally2", "friendly", 81, 80, nil)
    ADDACTOR(reg, "raider1", "hostile", 82, 80, nil)
    ADDACTOR(reg, "wander", "neutral", 83, 80, nil)
    for _, uid in ipairs({ "ally1", "ally2", "raider1", "wander" }) do ProjectALife.Watchdog.bindings[uid] = nil end

    local rows = Hooks.collect("roles", camp)
    check("roles hook offers sanitary", #rows == 1 and rows[1][1] == "sanitary" and rows[1][2] == 0.12, rows[1] and rows[1][2])
    local saved = state.points
    state.points = {}
    for i = 1, 8 do state.points[i] = { key = "k" .. i, x = 100 + i, y = 100, z = 0, c = 2, b = 0, w = 0 } end
    local heavy = Hooks.collect("roles", camp)
    state.points = saved
    check("role share rises with filth", heavy[1][2] == 0.25)

    local pickCamp = Camp.create({ x1 = 120, y1 = 225, x2 = 159, y2 = 254, z = 0 }, "Pick")
    local layoutRoles = { "builder", "builder", "builder", "farmer", "farmer", "guard", "guard", "scavenger", "medic" }
    for i, role in ipairs(layoutRoles) do pickCamp.settlers["p" .. i] = { name = "p" .. i, role = role, since = 0 } end
    check("pickRole picks sanitary when it is the biggest gap", Work.pickRole(pickCamp) == "sanitary", Work.pickRole(pickCamp))
    pickCamp.settlers.p10 = { name = "p10", role = "sanitary", since = 0 }
    check("pickRole stops once sanitary is covered", Work.pickRole(pickCamp) ~= "sanitary", Work.pickRole(pickCamp))
    local smallPick = Camp.create({ x1 = 170, y1 = 225, x2 = 199, y2 = 254, z = 0 }, "SmallPick")
    for i = 1, 3 do smallPick.settlers["s" .. i] = { name = "s" .. i, role = "guard", since = 0 } end
    check("tiny crews get no sanitary row", #Hooks.collect("roles", smallPick) == 0)
end

do
    local zombie = body(128, 128, {})
    local raider = body(131, 128, { ProjectALifeCorpseOf = "raider1", ProjectALifeUID = "raider1" })
    local wanderer = body(133, 130, { ProjectALifeCorpseOf = "wander" })
    local animal = body(132, 132, { isAnimal = true })
    local thumpsBefore = #CREATED
    local pitsBefore = #pits(camp)
    local removedBefore, buriedBefore, fallenBefore = state.removed, state.buried, state.lost
    for _, spot in ipairs({ { 128, 128 }, { 131, 128 }, { 133, 130 }, { 132, 132 } }) do
        San.note(camp, state, spot[1], spot[2], 0, 1, false)
    end
    check("four bodies noted", #state.points == 4)
    local crew = San.crew(camp)
    check("crew has one sanitary", crew.sanitary == 1 and #crew.list == 1 and crew.weight == 1)
    tick(camp, 1)
    local target = camp.settlers.u1.san
    check("sanitary is assigned a target", type(target) == "table" and type(target.x) == "number")
    local anchor = Hooks.first("anchor", camp, "u1", camp.settlers.u1, { x = 1, y = 1, z = 0 })
    check("anchor hook returns exact target", anchor ~= nil and anchor.x == target.x and anchor.y == target.y and anchor.exact == true and anchor.z == 0)
    check("anchor not for other roles", Hooks.first("anchor", camp, "u2", camp.settlers.u2, { x = 1, y = 1, z = 0 }) == nil)
    check("anchor not for guards", Hooks.first("anchor", camp, "u3", camp.settlers.u3, { x = 1, y = 1, z = 0 }) == nil)
    check("settler info notes the work", (function()
        local rows = Hooks.collect("settlerInfo", camp, "u1", camp.settlers.u1)
        return #rows >= 1 and rows[#rows] == T("SanDoingClean")
    end)())
    check("settler info silent for idle people", #Hooks.collect("settlerInfo", camp, "u2", camp.settlers.u2) == 0)
    camp.raid = { at = HOURS, people = 5, site = { x = 135, y = 160, z = 0 } }
    check("anchor silent during a raid", Hooks.first("anchor", camp, "u1", camp.settlers.u1, { x = 1, y = 1, z = 0 }) == nil)
    local frozenBank = state.bank
    tick(camp, 3)
    check("cleaning pauses during a raid", #zombie.sq.bodies == 1 and state.bank == frozenBank)
    camp.raid = nil
    camp.orderClock = 100
    Work.orders(camp, 3)
    local issued = orders.u1
    check("orders pass the anchor to the sanitary", issued ~= nil and issued.kind == "patrol" and issued.anchor.x == camp.settlers.u1.san.x and issued.anchor.y == camp.settlers.u1.san.y)

    for _ = 1, 4 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("near sanitary removes the first body quickly", state.removed >= removedBefore + 1 and state.removed <= removedBefore + 3, state.removed - removedBefore)
    for _ = 1, 30 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("all four bodies removed", #zombie.sq.bodies == 0 and #raider.sq.bodies == 0 and #wanderer.sq.bodies == 0 and #animal.sq.bodies == 0)
    check("enemies and zombies counted as removed only", state.removed == removedBefore + 4, state.removed - removedBefore)
    check("no burial for enemies", state.buried == buriedBefore and state.lost == fallenBefore and state.graves == 0)
    check("no graves were created for enemies", #CREATED == thumpsBefore and #pits(camp) == pitsBefore)
    check("no fallen entries for enemies", #state.fallen == 0)
    check("points list drained", #state.points == 0, #state.points)
    check("cleaning trains the clean skill", (Skills.data(camp.settlers.u1).clean or 0) > 0)
    check("sanitary spoke while working", #san1.lines >= 1)
    HOURS = HOURS + 1 / 60
    check("clean score back to full", San.score(camp) >= 99)

    local spot = sq(133, 134)
    spot.blood = true
    San.note(camp, state, 133, 134, 0, 0, true)
    local washBefore = state.washed
    for _ = 1, 8 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("blood is washed", spot.blood == false and state.washed == washBefore + 1 and (spot.washes or 0) == 1)
    check("cleaned sanitary is released", camp.settlers.u1.san == nil)

    local far = body(150, 150, {})
    San.note(camp, state, 150, 150, 0, 1, false)
    san1.px, san1.py = 400, 400
    tick(camp, 5)
    check("far sanitary waits before cleaning", #far.sq.bodies == 1)
    tick(camp, 8)
    check("timer cleans a point after eight minutes", #far.sq.bodies == 0)
    check("timer cleaning counts as removal", state.removed >= removedBefore + 5)

    local polite = body(152, 152, {})
    San.note(camp, state, 152, 152, 0, 1, false)
    local oldX, oldY = PLAYER.x, PLAYER.y
    PLAYER.x, PLAYER.y = 152.5, 152.5
    san1.px, san1.py = 152, 153
    tick(camp, 12)
    check("sanitary waits while the player stands at the body", #polite.sq.bodies == 1)
    PLAYER.x, PLAYER.y = oldX, oldY
    for _ = 1, 8 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("sanitary cleans once the player steps away", #polite.sq.bodies == 0)
end

do
    local memberBody = body(120, 120, { ProjectALifeCorpseOf = "u2" })
    local allyBody = body(122, 120, { ProjectALifeCorpseOf = "ally1" })
    function allyBody:getDescriptor()
        return { getForename = function() return "Ally" end, getSurname = function() return "One" end }
    end
    local markedBody = body(124, 120, { ALCcomrade = true, ALCname = "Marked Man" })
    local uidOnly = body(126, 120, { ProjectALifeUID = "ally2" })
    local rogue = body(128, 120, { ProjectALifeCorpseOf = "raider1" })
    for _, spot in ipairs({ { 120, 120 }, { 122, 120 }, { 124, 120 }, { 126, 120 }, { 128, 120 } }) do
        San.note(camp, state, spot[1], spot[2], 0, 1, false)
    end
    san1.px, san1.py = 124, 121
    local buriedFrom, removedFrom, lostFrom = state.buried, state.removed, state.lost
    local sawJob, carrying, carryTarget = false, false, nil
    for _ = 1, 60 do
        follow(san1, camp, "u1")
        tick(camp, 1)
        if #state.jobs > 0 then
            sawJob = true
            local t = camp.settlers.u1.san
            if t ~= nil and string.sub(t.k, 1, 1) == "j" then
                carrying = true
                carryTarget = t
            end
        end
    end
    check("comrade bodies became carry jobs", sawJob)
    check("sanitary walks the body to the cemetery", carrying and carryTarget ~= nil and carryTarget.x >= plot.x and carryTarget.x <= plot.x + plot.w and carryTarget.y >= plot.y and carryTarget.y <= plot.y + plot.h)
    check("all comrade bodies removed from the ground", #memberBody.sq.bodies == 0 and #allyBody.sq.bodies == 0 and #markedBody.sq.bodies == 0 and #uidOnly.sq.bodies == 0 and #rogue.sq.bodies == 0)
    check("four comrades buried", state.buried == buriedFrom + 4, state.buried - buriedFrom)
    check("one more plain removal for the raider", state.removed == removedFrom + 1, state.removed - removedFrom)
    check("four graves", state.graves == 4, state.graves)
    check("four fallen entries", state.lost == lostFrom + 4 and #state.fallen == 4, #state.fallen)
    local names = {}
    for _, entry in ipairs(state.fallen) do names[entry.name] = entry end
    check("fallen names recorded", names["Nameu2"] ~= nil and names["Ally One"] ~= nil and names["Marked Man"] ~= nil and names["Profile p_ally2"] ~= nil)
    check("fallen entries carry the day", names["Nameu2"].day == Store.day(camp) and type(names["Nameu2"].day) == "number")
    check("fallen entries keep uid", names["Nameu2"].uid == "u2" and names["Ally One"].uid == "ally1")
    check("no memorial flag on real burials", names["Nameu2"].mem == nil)

    local halves = pits(camp)
    check("eight pit halves", #halves == 8, #halves)
    local west, east, typesOk, filledOk, tagOk, nameOk, thumpOk = 0, 0, true, true, true, true, true
    for _, entry in ipairs(halves) do
        local o = entry.o
        if o.spriteName == CEM .. "40" then west = west + 1 end
        if o.spriteName == CEM .. "41" then east = east + 1 end
        local data = o:getModData()
        if o.spriteName == CEM .. "41" and data.spriteType ~= "sprite1" then typesOk = false end
        if o.spriteName == CEM .. "40" and data.spriteType ~= "sprite2" then typesOk = false end
        if data.corpses ~= 1 or data.filled ~= true then filledOk = false end
        if type(data.ALC) ~= "table" or data.ALC.kind ~= "grave" or data.ALC.camp ~= camp.id then tagOk = false end
        if o.nm ~= "EmptyGraves" or type(o.infoTable) ~= "table" or o.infoTable.name ~= "EmptyGraves" then nameOk = false end
        if o.thump ~= false or o.barricade ~= false then thumpOk = false end
    end
    check("pit sprites are the filled variants", west == 4 and east == 4, west .. "/" .. east)
    check("pit halves use sprite1 and sprite2", typesOk)
    check("each grave holds one corpse and is filled", filledOk)
    check("graves are tagged for the camp", tagOk)
    check("graves are named like vanilla", nameOk)
    check("graves are not thumpable", thumpOk)
    local tiles, separate = {}, true
    for _, entry in ipairs(halves) do
        local key = entry.x .. ":" .. entry.y
        if tiles[key] then separate = false end
        tiles[key] = true
    end
    check("every grave has its own tiles", separate)
    local neighbours = true
    for _, entry in ipairs(halves) do
        if entry.o.spriteName == CEM .. "41" then
            local mate = false
            for _, other in ipairs(halves) do
                if other.o.spriteName == CEM .. "40" and other.y == entry.y and other.x == entry.x - 1 then mate = true end
            end
            if not mate then neighbours = false end
        end
    end
    check("pit halves are neighbours west to east", neighbours)
    check("stones for members and crosses for allies", signsOf(camp, { "22", "23" }) == 2 and signsOf(camp, { "1", "3", "5", "9" }) == 2,
        signsOf(camp, { "22", "23" }) .. "/" .. signsOf(camp, { "1", "3", "5", "9" }))
    check("monument was raised once", signsOf(camp, { "11" }) == 1, signsOf(camp, { "11" }))
    local flowers = 0
    for _, entry in ipairs(graveObjects(camp)) do
        if entry.o.sprite ~= nil and entry.o.spriteName == nil and string.find(entry.o.sprite.name, "vegetation_ornamental", 1, true) then flowers = flowers + 1 end
    end
    check("monument flowers", flowers == 2, flowers)
    local cx = layout.cx
    local laneTiles = 0
    for dy = 1, plot.h - 1 do
        local floor = sq(plot.x + cx, plot.y + dy).floorObj
        if floor ~= nil and type(World.tag(floor)) == "table" and World.tag(floor).kind == "grave" then laneTiles = laneTiles + 1 end
    end
    check("lane laid", laneTiles == plot.h - 1, laneTiles)
    local founded = false
    for _, entry in ipairs(camp.log) do if entry.k == "san_cemetery" then founded = true end end
    check("cemetery founding logged", founded)
    check("graves counted in stats", San.stats(camp).graves == 4 and San.stats(camp).buried >= 4)
end

do
    local u2entries = 0
    reg.records.u2.lifecycle = "dead"
    ProjectALife.Watchdog.bindings.u2 = nil
    Work.upkeep(camp)
    check("dead settler leaves the camp", camp.settlers.u2 == nil)
    for _, entry in ipairs(state.fallen) do if entry.uid == "u2" then u2entries = u2entries + 1 end end
    check("no duplicate entry for an already buried member", u2entries == 1 and state.dead.u2 == nil, u2entries)
    tick(camp, 130)
    u2entries = 0
    for _, entry in ipairs(state.fallen) do if entry.uid == "u2" then u2entries = u2entries + 1 end end
    check("still a single entry later", u2entries == 1, u2entries)

    local u4body = body(126, 150, { ProjectALifeCorpseOf = "u4" })
    reg.records.u4.lifecycle = "dead"
    reg.records.u4.worldPosition = { x = 126, y = 150, z = 0 }
    ProjectALife.Watchdog.bindings.u4 = nil
    local buriedMid, gravesMid = state.buried, state.graves
    Work.upkeep(camp)
    check("death recorded for later", state.dead.u4 ~= nil and state.dead.u4.name == "Nameu4" and state.dead.u4.st == "wait")
    tick(camp, 1)
    check("body of the fallen is located", state.dead.u4.st == "body")
    for _ = 1, 40 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("fallen settler is buried", state.buried == buriedMid + 1 and state.graves == gravesMid + 1 and #u4body.sq.bodies == 0)
    local u4entry
    for _, entry in ipairs(state.fallen) do if entry.uid == "u4" then u4entry = entry end end
    check("burial entry names the settler", u4entry ~= nil and u4entry.name == "Nameu4" and u4entry.mem == nil)

    reg.records.u5.lifecycle = "dead"
    reg.records.u5.worldPosition = { x = 130, y = 152, z = 0 }
    ProjectALife.Watchdog.bindings.u5 = nil
    local memorialsBefore, markersBefore, buriedBeforeMemory = state.memorials, state.markers, state.buried
    local stonesBeforeMemory = signsOf(camp, { "1", "3", "5", "9" })
    Work.upkeep(camp)
    tick(camp, 2)
    check("memorial waits through the grace period", state.dead.u5 ~= nil and state.dead.u5.st == "wait" and state.memorials == memorialsBefore)
    for _ = 1, 20 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("missing body gets a memorial", state.memorials == memorialsBefore + 1 and state.markers == markersBefore + 1 and state.buried == buriedBeforeMemory)
    local u5entry
    for _, entry in ipairs(state.fallen) do if entry.uid == "u5" then u5entry = entry end end
    check("memorial entry is flagged", u5entry ~= nil and u5entry.mem == true and u5entry.name == "Nameu5")
    check("memorial cairn placed", signsOf(camp, { "30" }) == 1, signsOf(camp, { "30" }))
    check("memorial gets a headstone too", signsOf(camp, { "1", "3", "5", "9" }) == stonesBeforeMemory + 1)
    check("memorial leaves no pit", #pits(camp) == 10, #pits(camp))
    check("memorial does not count as burial", San.stats(camp).fallen == state.lost and state.lost == 6 and state.buried == buriedBeforeMemory, state.lost)

    local savedUnloaded = San.unloadedMinutes
    San.unloadedMinutes = 10
    reg.records.u6.lifecycle = "dead"
    reg.records.u6.worldPosition = { x = 160, y = 140, z = 0 }
    ProjectALife.Watchdog.bindings.u6 = nil
    for dx = -2, 2 do for dy = -2, 2 do HIDDEN[(160 + dx) .. "," .. (140 + dy) .. ",0"] = true end end
    Work.upkeep(camp)
    local memoriesBefore = state.memorials
    tick(camp, 5)
    check("unloaded death waits", state.dead.u6 ~= nil and state.dead.u6.st == "wait" and state.memorials == memoriesBefore)
    tick(camp, 8)
    for _ = 1, 20 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("unloaded death ends with a memorial", state.memorials == memoriesBefore + 1)
    San.unloadedMinutes = savedUnloaded
    for dx = -2, 2 do for dy = -2, 2 do HIDDEN[(160 + dx) .. "," .. (140 + dy) .. ",0"] = nil end end
    San.onDied(camp, { name = "Again" }, "u6")
    check("died hook ignores recorded uid", state.dead.u6 == nil or state.dead.u6.name == "Nameu6")
end

do
    local slotsUsed = state.slot - 1
    check("slots consumed in order", slotsUsed == state.graves + state.markers, slotsUsed .. "/" .. state.graves .. "/" .. state.markers)
    local firstDef = layout.slots[1]
    local firstPit
    for _, entry in ipairs(pits(camp)) do
        if entry.x == plot.x + firstDef.dx + 1 and entry.y == plot.y + firstDef.dy then firstPit = entry end
    end
    check("first grave in first slot", firstPit ~= nil and firstPit.o.spriteName == CEM .. "41")

    local blockedSlot = layout.slots[state.slot]
    local blockedSquare = sq(plot.x + blockedSlot.dx + 1, plot.y + blockedSlot.dy)
    NEWTREE(blockedSquare)
    local slotBefore, gravesBefore = state.slot, state.graves
    San.honor(camp, "Past The Tree")
    check("blocked slot is skipped", state.slot == slotBefore + 2 and state.graves == gravesBefore + 1, state.slot .. " vs " .. slotBefore)
    local treeStill = false
    local list = blockedSquare:getObjects()
    for i = 0, list:size() - 1 do if list:get(i).class == "IsoTree" then treeStill = true end end
    check("blocking tree is left alone", treeStill)

    local grassDef = layout.slots[state.slot]
    local grassSquare = sq(plot.x + grassDef.dx, plot.y + grassDef.dy)
    NEWOBJ(grassSquare, "IsoObject", "vegetation_grass_01_5")
    local grassSlot, grassGraves = state.slot, state.graves
    San.honor(camp, "Weedy")
    local grassLeft = false
    local grassList = grassSquare:getObjects()
    for i = 0, grassList:size() - 1 do
        local o = grassList:get(i)
        if o.sprite ~= nil and o.sprite.name == "vegetation_grass_01_5" then grassLeft = true end
    end
    check("grass on a slot is cleared", not grassLeft)
    check("slot with grass is still used", state.slot == grassSlot + 1 and state.graves == grassGraves + 1)
    check("erosion is switched off on graves", grassSquare.erosionOff == true)

    local capBefore = San.graveCap
    San.graveCap = state.graves + state.markers + 1
    local massBefore = state.mass
    San.honor(camp, "Within Cap")
    San.honor(camp, "Beyond Cap")
    San.honor(camp, "Beyond Cap Two")
    check("grave cap stops visual graves", state.graves + state.markers <= San.graveCap and state.mass == massBefore + 2, state.mass - massBefore)
    San.graveCap = capBefore
    local keepBefore = San.fallenKeep
    San.fallenKeep = 5
    San.honor(camp, "Trim A")
    check("fallen list is trimmed", #state.fallen == 5)
    San.fallenKeep = keepBefore

    local hidden = layout.slots[state.slot]
    local hx, hy = plot.x + hidden.dx, plot.y + hidden.dy
    HIDDEN[hx .. "," .. hy .. ",0"] = true
    local job = { id = 900, name = "Late", day = 3, at = Store.hours(), w = 0, x = hx, y = hy, z = 0 }
    state.jobs[#state.jobs + 1] = job
    local jobsBefore, buriedBefore = #state.jobs, state.buried
    san1.px, san1.py = hx, hy
    for _ = 1, 4 do tick(camp, 1) end
    check("job waits while the plot is unloaded", #state.jobs == jobsBefore and state.buried == buriedBefore)
    HIDDEN[hx .. "," .. hy .. ",0"] = nil
    for _ = 1, 6 do
        follow(san1, camp, "u1")
        tick(camp, 1)
    end
    check("job finishes once the plot loads", #state.jobs == jobsBefore - 1 and state.buried == buriedBefore + 1)
    state.jobs = {}
end

do
    local statePlain, where = plain(camp.sanitary, nil, "sanitary")
    check("state is plain data", statePlain, where)
    local settlerPlain, where2 = plain(camp.settlers.u1, nil, "u1")
    check("settler fields are plain data", settlerPlain, where2)
    local arrayOk = true
    for _, key in ipairs({ "points", "jobs", "fallen" }) do
        local list = camp.sanitary[key]
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        if n ~= #list then arrayOk = false end
    end
    check("lists are dense arrays", arrayOk)
    local rerun = camp.sanitary
    camp.sanitary = nil
    check("state rebuilds when missing", San.state(camp) ~= rerun and San.stats(camp).removed == 0)
    camp.sanitary = { removed = 3 }
    check("partial state gets defaults", San.stats(camp).removed == 3 and San.state(camp).bank == 0 and type(San.state(camp).points) == "table")
    camp.sanitary = rerun
    state = San.state(camp)
end

do
    HOURS = HOURS + 5
    state.points = {}
    for i = 1, 14 do state.points[i] = { key = "t" .. i, x = 110 + i, y = 120, z = 0, c = 1, b = 0, w = 0 } end
    state.tidy = 0
    San.refresh(camp, state)
    local scoreInside = state.score
    state.points = {}
    for i = 1, 14 do state.points[i] = { key = "r" .. i, x = 90, y = 100 + i, z = 0, c = 1, b = 0, w = 0 } end
    San.refresh(camp, state)
    local scoreRing = state.score
    check("corpses inside weigh more than in the ring", scoreInside < scoreRing, scoreInside .. " vs " .. scoreRing)
    state.points = {}
    for i = 1, 20 do state.points[i] = { key = "z" .. i, x = 110 + i, y = 121, z = 0, c = 2, b = 1, w = 0 } end
    San.refresh(camp, state)
    check("score floors at zero", state.score == 0, state.score)
    state.points = {}
    state.tidy = 0
    San.refresh(camp, state)
    check("score caps at one hundred", state.score >= 99 and state.score <= 100)
    local stamp = math.floor(Store.hours() * 60)
    state.score, state.stamp = 0, stamp
    local low = San.morale(camp)
    state.score = 100
    local high = San.morale(camp)
    check("morale hook range", math.abs(low - (-8)) < 1e-9 and math.abs(high - 4) < 1e-9, low .. " .. " .. high)
    state.score = 50
    check("morale is linear", math.abs(San.morale(camp) - (-2)) < 1e-9)
    state.score = 100
    local with = Stats.compute(camp).morale
    Options.set(camp, "sanitation", false)
    local without = Stats.compute(camp).morale
    Options.set(camp, "sanitation", true)
    check("morale hook feeds stats", with >= without)
    local cached = San.score(camp)
    state.points = { { key = "n1", x = 111, y = 111, z = 0, c = 3, b = 0, w = 0 } }
    check("score is cached within a minute", San.score(camp) == cached)
    HOURS = HOURS + 1 / 60 + 0.001
    check("score recomputes after a minute", San.score(camp) < cached)
    state.points = {}
    San.refresh(camp, state)
end

do
    local lines = Hooks.tabLines(lifeTab, camp)
    local joined = {}
    for _, line in ipairs(lines) do joined[#joined + 1] = line.text end
    local text = table.concat(joined, "\n")
    check("life tab shows the section", string.find(text, T("SanTitle"), 1, true) ~= nil)
    check("life tab shows the memorial", string.find(text, T("SanFallenTitle"), 1, true) ~= nil)
    local newest = state.fallen[#state.fallen]
    check("newest fallen listed", string.find(text, T(newest.mem and "SanFallenMemory" or "SanFallenRow", tostring(newest.day), newest.name), 1, true) ~= nil)
    local shown = 0
    for _, entry in ipairs(state.fallen) do
        if string.find(text, T(entry.mem and "SanFallenMemory" or "SanFallenRow", tostring(entry.day), entry.name), 1, true) ~= nil then shown = shown + 1 end
    end
    check("only the last five fallen are shown", shown == 5, shown)
    check("section lines are well formed", (function()
        for _, line in ipairs(San.lines(camp)) do
            if type(line.text) ~= "string" or type(line.r) ~= "number" or type(line.g) ~= "number" or type(line.b) ~= "number" then return false end
        end
        return true
    end)())
    local mine = San.overview(camp)
    check("overview has one short line when clean", #mine == 1 and #mine[1].text > 10, #mine)
    check("overview line is part of the shared overview", (function()
        for _, line in ipairs(Hooks.overview(camp)) do if line.text == mine[1].text then return true end end
        return false
    end)())
    state.points = {}
    for i = 1, 12 do state.points[i] = { key = "d" .. i, x = 110 + i, y = 122, z = 0, c = 1, b = 1, w = 0 } end
    San.refresh(camp, state)
    mine = San.overview(camp)
    check("overview adds a red line when dirty", #mine == 2 and mine[2].r == 1 and mine[2].g < 0.5 and mine[2].b < 0.5, #mine)
    check("overview mentions the dirt", string.find(mine[2].text, "12", 1, true) ~= nil)
    state.points = {}
    San.refresh(camp, state)

    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
    win:selectTab("life")
    local okLife = pcall(function() win:prerender() end)
    check("window renders the life tab", okLife and win.hitRows ~= nil)
    local okLines, uiLines = pcall(function() return win:lines(camp) end)
    local hasLine = false
    if okLines then
        local expect = San.overview(camp)[1].text
        for _, line in ipairs(uiLines) do if line.text == expect then hasLine = true end end
    end
    check("overview tab carries the sanitary line", okLines and hasLine, okLines and "" or tostring(uiLines))
    local okPeople, peopleLines = pcall(function() return win:settlerLines(camp) end)
    check("people tab renders", okPeople and #peopleLines >= 1)
    local rows = Options.lines(camp)
    local found = 0
    for _, line in ipairs(rows) do
        if line.text == T("OptRow", T("Opt_sanitation"), T("OptOn")) then found = found + 1 end
        if line.text == T("OptRow", T("Opt_sanitaryRing"), T("OptVal_sanitaryRing_25")) then found = found + 1 end
    end
    check("settings tab lists sanitary options", found == 2, found)
    check("ring values have labels", A.TN("OptVal_sanitaryRing_0") ~= nil and A.TN("OptVal_sanitaryRing_10") ~= nil and A.TN("OptVal_sanitaryRing_25") ~= nil and A.TN("OptVal_sanitaryRing_50") ~= nil)
    local stats = San.stats(camp)
    local numbers = true
    for _, key in ipairs({ "score", "corpses", "blood", "removed", "buried", "graves", "fallen" }) do
        if type(stats[key]) ~= "number" then numbers = false end
    end
    check("stats are all numbers", numbers)
    check("fallen stat counts everyone", stats.fallen == state.lost)
end

do
    Options.set(camp, "sanitation", false)
    local offCursor = state.cursor
    local offBody = body(145, 145, {})
    HOURS = HOURS + 1 / 60 + 0.001
    tick(camp, 3)
    check("option off stops the cursor", state.cursor == offCursor)
    check("option off leaves bodies", #offBody.sq.bodies == 1)
    check("option off score is neutral", San.score(camp) == 100)
    check("option off morale is neutral", Hooks.sum("morale", camp) == 0 and San.morale(camp) == 0)
    check("option off roles hook silent", #Hooks.collect("roles", camp) == 0)
    check("option off anchor silent", Hooks.first("anchor", camp, "u1", camp.settlers.u1, { x = 1, y = 1, z = 0 }) == nil)
    check("option off overview silent", San.overview(camp) == nil)
    check("option off section explains", #San.lines(camp) == 1 and San.lines(camp)[1].text == T("SanOff"))
    check("option off settler info silent", #Hooks.collect("settlerInfo", camp, "u1", camp.settlers.u1) == 0)
    check("option off reserve does nothing", San.reserve(camp, true) == 0)
    Options.set(camp, "sanitation", true)
    tick(camp, 2)
    check("option on resumes", state.cursor ~= offCursor or state.passes > 0)
    offBody.sq.bodies = {}
end

do
    local logBefore, notesBefore = #camp.log, #PLAYER.notes
    check("multiplier without surge", San.multiplier(camp, state) == 1)
    Hooks.each("raidend", camp, { at = HOURS, people = 6, site = { x = 135, y = 160, z = 0 } }, 1)
    check("raid end starts the surge", state.surge > HOURS and state.surge - HOURS <= 2.0001 and state.surge - HOURS >= 1.99)
    check("surge doubles the budget", San.multiplier(camp, state) == 2)
    local logged = false
    for i = logBefore + 1, #camp.log do if camp.log[i].k == "san_aftermath" then logged = true end end
    check("aftermath journal entry", logged)
    check("aftermath popup", #PLAYER.notes == notesBefore + 1 and PLAYER.notes[#PLAYER.notes] == T("SanNoteAftermath", camp.name), PLAYER.notes[#PLAYER.notes])
    local zone = San.zone(camp)
    check("cursor jumps to the raid site", state.cursor == (160 - San.focusRows - zone.y1) * zone.w, state.cursor)
    HOURS = HOURS + 2.5
    check("surge expires", San.multiplier(camp, state) == 1)

    A.Progress = { bonus = function(c, key) if key == "clean" then return 1.5 end return 1 end }
    check("progress bonus multiplies", San.multiplier(camp, state) == 1.5)
    A.Progress = { bonus = function() error("boom") end }
    check("failing progress is ignored", San.multiplier(camp, state) == 1)
    A.Progress = { bonus = function() return "x" end }
    check("odd progress value is ignored", San.multiplier(camp, state) == 1)
    A.Progress = nil
    check("missing progress is fine", San.multiplier(camp, state) == 1)

    local base = San.crew(camp).weight
    Skills.data(camp.settlers.u1).clean = Skills.xpFor(10)
    local master = San.crew(camp).weight
    check("skill speeds the sanitary", master > base and math.abs(master - (1 + Skills.perLevel * 10)) < 1e-9, master)
    Skills.data(camp.settlers.u1).clean = 0
end

do
    local few = Camp.create({ x1 = 60, y1 = 100, x2 = 89, y2 = 129, z = 0 }, "Few")
    few.phase = "plan"
    few.options.recruit = false
    local lone = San.crew(few)
    check("no people no crew", lone.weight == 0 and #lone.list == 0 and lone.virtual == false)
    join(few, "f1", "builder", 70, 110)
    check("one person cannot clean", San.crew(few).weight == 0)
    join(few, "f2", "guard", 71, 110)
    local virtual = San.crew(few)
    check("two people give a minimum crew", virtual.virtual == true and virtual.weight == 0.3 and #virtual.list == 0, virtual.weight)
    join(few, "f3", "scavenger", 72, 110)
    check("three people get no sanitary row", #Hooks.collect("roles", few) == 0)
    join(few, "f4", "worker", 73, 110)
    join(few, "f5", "worker", 74, 110)
    check("four people get a sanitary row", #Hooks.collect("roles", few) == 1)
    local helpers = San.crew(few)
    check("workers and scavengers help slowly", #helpers.list == 2 and math.abs(helpers.weight - 0.6) < 1e-9 and helpers.virtual == false, helpers.weight)
    local guardHelps = false
    for _, member in ipairs(helpers.list) do if member.settler.role == "guard" then guardHelps = true end end
    check("guards never help", not guardHelps)
    few.settlers.f1.role = "sanitary"
    local withSanitary = San.crew(few)
    few.settlers.f1.role = "builder"
    check("sanitary role replaces helpers", withSanitary.sanitary == 1 and #withSanitary.list == 1)
    local fewState = San.state(few)
    body(80, 115, {})
    San.note(few, fewState, 80, 115, 0, 1, false)
    tick(few, 1)
    local helperTarget = few.settlers.f3.san
    check("helper walks to dirt", type(helperTarget) == "table" and helperTarget.x == 80)
    check("only helpers are sent", few.settlers.f1.san == nil and few.settlers.f2.san == nil)
    tick(few, 40)
    check("helpers eventually clean", fewState.removed == 1 and #sq(80, 115).bodies == 0)
    check("helpers are released after the job", few.settlers.f3.san == nil)

    local lonely = Camp.create({ x1 = 60, y1 = 140, x2 = 89, y2 = 169, z = 0 }, "Virtual")
    lonely.phase = "plan"
    lonely.options.recruit = false
    join(lonely, "v1", "builder", 70, 150)
    join(lonely, "v2", "farmer", 71, 150)
    local lonelyState = San.state(lonely)
    body(75, 150, {})
    San.note(lonely, lonelyState, 75, 150, 0, 1, false)
    tick(lonely, 5)
    check("virtual crew does not hurry", #sq(75, 150).bodies == 1)
    tick(lonely, 20)
    check("virtual crew cleans on the timer", #sq(75, 150).bodies == 0 and lonelyState.removed == 1)
    check("virtual crew sends nobody", lonely.settlers.v1.san == nil and lonely.settlers.v2.san == nil)

    local bare = Camp.create({ x1 = 120, y1 = 180, x2 = 149, y2 = 209, z = 0 }, "Bare")
    bare.phase = "plan"
    bare.options.recruit = false
    bare.storage = {}
    local okBare = pcall(function()
        join(bare, "b1", "sanitary", 130, 190)
        join(bare, "b2", "guard", 131, 190)
        body(133, 190, {})
        San.note(bare, San.state(bare), 133, 190, 0, 1, false)
        tick(bare, 12)
    end)
    check("no storage no crash", okBare)
    check("storageless camp cleans", #sq(133, 190).bodies == 0 and San.state(bare).removed == 1)

    local empty = Camp.create({ x1 = 160, y1 = 180, x2 = 189, y2 = 209, z = 0 }, "Empty")
    empty.phase = "plan"
    empty.options.recruit = false
    body(170, 190, {})
    local emptyState = San.state(empty)
    tick(empty, 5)
    check("nobody home nothing happens", #emptyState.points == 0 and emptyState.cursor == 0 and #sq(170, 190).bodies == 1)
    check("nobody home stats are sane", San.stats(empty).removed == 0 and San.score(empty) == 100)
    check("nobody home roles hook silent", #Hooks.collect("roles", empty) == 0)
    check("fresh camp section is two lines", #San.lines(empty) == 2, #San.lines(empty))
    check("fresh camp life tab stays short", #Hooks.tabLines(Hooks.tab("life"), empty) <= 4 + 12, #Hooks.tabLines(Hooks.tab("life"), empty))
    emptyState.points = { { key = "e1", x = 170, y = 190, z = 0, c = 1, b = 1, w = 0 } }
    local grown = San.lines(empty)
    check("section grows when there is dirt", #grown >= 4 and string.find(grown[3].text, T("SanLineDirt", "1", "1"), 1, true) ~= nil, #grown)
    emptyState.points = {}

    local filth = Camp.create({ x1 = 200, y1 = 180, x2 = 229, y2 = 209, z = 0 }, "Filth")
    filth.phase = "plan"
    filth.options.recruit = false
    join(filth, "z1", "guard", 210, 190)
    local filthState = San.state(filth)
    filthState.points = {}
    for i = 1, 12 do
        body(205 + i, 190, {})
        body(205 + i, 190, {})
        San.note(filth, filthState, 205 + i, 190, 0, 2, false)
    end
    local notes = #PLAYER.notes
    tick(filth, 1)
    check("filth is announced once", filthState.filthy == true and #PLAYER.notes == notes + 1, tostring(filthState.filthy) .. "/" .. (#PLAYER.notes - notes))
    local filthLogged = false
    for _, entry in ipairs(filth.log) do if entry.k == "san_filth" then filthLogged = true end end
    check("filth is journaled", filthLogged)
    tick(filth, 3)
    check("filth is not announced again", #PLAYER.notes == notes + 1)
    for i = 1, 12 do sq(205 + i, 190).bodies = {} end
    tick(filth, 1)
    check("recovery clears the filth flag", filthState.filthy == false)
    local freshLogged = false
    for _, entry in ipairs(filth.log) do if entry.k == "san_fresh" then freshLogged = true end end
    check("recovery is journaled", freshLogged)
    filth.phase = "clear"
    for i = 1, 12 do
        body(205 + i, 190, {})
        body(205 + i, 190, {})
        San.note(filth, filthState, 205 + i, 190, 0, 2, false)
    end
    local clearNotes = #PLAYER.notes
    tick(filth, 2)
    check("no filth alarm while the land is being cleared", filthState.filthy == false and #PLAYER.notes == clearNotes)
    filth.phase = "plan"
    tick(filth, 1)
    check("filth alarm resumes after clearing", filthState.filthy == true and #PLAYER.notes == clearNotes + 1)
    for i = 1, 12 do sq(205 + i, 190).bodies = {} end
end

do
    HOURS = math.floor(HOURS) + 1.1
    local printsBefore = #PRINTS
    tick(camp, 1)
    local traced = false
    for i = printsBefore + 1, #PRINTS do
        if string.find(PRINTS[i], "[ALifeCamp:Sanitary]", 1, true) ~= nil and string.find(PRINTS[i], "score=", 1, true) ~= nil then traced = true end
    end
    check("hourly diagnostics line", traced)
    printsBefore = #PRINTS
    tick(camp, 3)
    local spam = 0
    for i = printsBefore + 1, #PRINTS do
        if string.find(PRINTS[i], "[ALifeCamp:Sanitary]", 1, true) ~= nil then spam = spam + 1 end
    end
    check("diagnostics are not spammy", spam == 0, spam)
end

do
    Cheats = A.Cheats
    check("cheats defined", Cheats.actions.san_spawn ~= nil and Cheats.actions.san_now ~= nil and Cheats.actions.san_graves ~= nil)
    local sections = {}
    for _, entry in ipairs(Cheats.order) do sections[entry.id] = entry.section end
    check("cheats live in the life section", sections.san_spawn == "life" and sections.san_now == "life" and sections.san_graves == "life")
    PLAYER.x, PLAYER.y = 120, 120
    check("cheat camp is ours", Cheats.camp(PLAYER) == camp)
    state.points = {}
    local bodiesBefore, bloodBefore = zoneCount(camp)
    local spawnText = Cheats.run("san_spawn", PLAYER)
    local bodiesNow, bloodNow = zoneCount(camp)
    check("spawn cheat answers", type(spawnText) == "string" and #spawnText > 0 and not string.find(spawnText, "UI_ALC_", 1, true), spawnText)
    check("spawn scatters bodies", bodiesNow - bodiesBefore >= 12, bodiesNow - bodiesBefore)
    check("spawn scatters blood", bloodNow - bloodBefore >= 8, bloodNow - bloodBefore)
    local zone = San.zone(camp)
    local marked, ringBodies, insideBodies, zombies, named = 0, 0, 0, 0, 0
    for x = zone.x1, zone.x2 do
        for y = zone.y1, zone.y2 do
            for _, b in ipairs(sq(x, y).bodies) do
                if b.md.ALCcomrade then
                    marked = marked + 1
                    if type(b.md.ALCname) == "string" and #b.md.ALCname > 3 then named = named + 1 end
                else
                    zombies = zombies + 1
                end
                if Geo.contains(camp, x, y) then insideBodies = insideBodies + 1 else ringBodies = ringBodies + 1 end
            end
        end
    end
    check("spawn marks two comrades", marked == 2 and named == 2, marked)
    check("spawn adds ordinary corpses", zombies >= 10, zombies)
    check("spawn covers the camp and the ring", insideBodies >= 5 and ringBodies >= 3, insideBodies .. "/" .. ringBodies)
    local removedMark, buriedMark, gravesMark, lostMark = state.removed, state.buried, state.graves, state.lost
    local nowText = Cheats.run("san_now", PLAYER)
    local bodiesLeft, bloodLeft = zoneCount(camp)
    check("now cheat answers", type(nowText) == "string" and #nowText > 0 and not string.find(nowText, "UI_ALC_", 1, true), nowText)
    check("now cheat clears the zone", bodiesLeft <= bodiesBefore and bloodLeft <= bloodBefore, bodiesLeft .. "/" .. bloodLeft)
    check("now cheat buries only the comrades", state.buried == buriedMark + 2 and state.lost == lostMark + 2, state.buried - buriedMark)
    check("now cheat removes the rest", state.removed - removedMark >= 10, state.removed - removedMark)
    check("comrade graves appear", state.graves >= gravesMark + 1)
    local lostMark2, buriedMark2 = state.lost, state.buried
    local graveText = Cheats.run("san_graves", PLAYER)
    check("graves cheat answers", type(graveText) == "string" and #graveText > 0 and not string.find(graveText, "UI_ALC_", 1, true), graveText)
    local honored = state.buried - buriedMark2
    check("graves cheat buries three to five", honored >= 3 and honored <= 5, honored)
    check("graves cheat records names", state.lost == lostMark2 + honored and #state.fallen >= 3)
    local last = state.fallen[#state.fallen]
    check("graves cheat keeps names from the list", type(last.name) == "string" and #last.name > 3)
    local cheatLogged = false
    for _, entry in ipairs(camp.log) do if entry.k == "cheat" and entry.a == "san_graves" then cheatLogged = true end end
    check("cheat logs", cheatLogged)
    check("grave cap respected overall", state.graves + state.markers <= San.graveCap)
    check("graves never exceed capacity", state.graves + state.markers <= #layout.slots)
end

do
    local count = 0
    for _, entry in ipairs(camp.log) do
        T("Log_" .. entry.k, tostring(entry.a or ""), tostring(entry.b or ""))
        count = count + 1
    end
    check("journal entries all have text", count > 0)
    for _, key in ipairs({ "Role_sanitary", "Skill_clean", "Kind_cemetery", "SanTitle", "SanOff", "SanNameless", "SanLineScore", "SanSayCarry", "SanSayBury",
        "SanSayBody1", "SanSayBody2", "SanSayBody3", "SanSayBlood1", "SanSayBlood2", "SanNoteBuried", "SanNoteMemory", "SanNoteAftermath", "SanNoteFilth",
        "SanDoingClean", "SanDoingCarry", "Log_san_buried", "Log_san_mass", "Log_san_memory", "Log_san_cemetery", "Log_san_aftermath", "Log_san_cleaned",
        "Log_san_filth", "Log_san_fresh", "SanGrade_0", "SanGrade_1", "SanGrade_2", "SanGrade_3", "SanGrade_4", "SanGrade_5", "SanLineZone", "SanLineZoneFlat",
        "SanLineDirt", "SanLineJobs", "SanLineCrew", "SanLineNobody", "SanLineRemoved", "SanLineBuried", "SanLineMass", "SanLinePlot", "SanLinePlotNone",
        "SanFallenTitle", "SanFallenRow", "SanFallenMemory", "SanOverview", "SanOverviewDirty", "Opt_sanitation", "OptHint_sanitation",
        "Opt_sanitaryRing", "OptHint_sanitaryRing" }) do
        T(key, "a", "b", "c")
    end
end

do
    local mine = {}
    for _, message in ipairs(SILENT) do
        if (string.find(message, "CampSanitary", 1, true) or string.find(message, "CheatsSanitary", 1, true)) and not string.find(message, "boom", 1, true) then
            mine[#mine + 1] = message
        end
    end
    check("no swallowed errors in the module", #mine == 0, mine[1])
end

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
