dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Hooks, Options, Store, Settlers, Stock, Camp = A.Hooks, A.Options, A.Store, A.Settlers, A.Stock, A.Camp
local Life, Cheats, Stats, Build = A.Life, A.Cheats, A.Stats, A.Build

HOUR = 12
TEMP = 15
function getGameTime() return { getWorldAgeHours = function() return HOURS end, getHour = function() return HOUR end } end
function getClimateManager() return { getTemperature = function() return TEMP end } end

for x = 80, 160 do for y = 80, 160 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
local reg, orders = MOCKALIFE()

local seed = 7
RANDOM = "zero"
local function rng(n)
    if RANDOM == "zero" then return 0 end
    seed = (seed * 16807) % 2147483647
    return seed % n
end
local function addActor(uid, x, y)
    local shell = ADDACTOR(reg, uid, "friendly", x, y, A.World.square(x, y, 0))
    ZombRand = rng
    return shell
end

check("module loaded", Life ~= nil and Life.mood ~= nil and Life.stats ~= nil and Life.phase ~= nil)
check("options defined in life group", Options.byKey.rhythm ~= nil and Options.byKey.traditions ~= nil and Options.byKey.desertion ~= nil
    and Options.byKey.rhythm.group == "life" and Options.byKey.traditions.group == "life" and Options.byKey.desertion.group == "life")

local function fixCrates(c)
    for _, entry in ipairs(c.storage) do
        local crate = Stock.crate(c, entry)
        local container = crate ~= nil and crate:getContainer() or nil
        if container ~= nil then function container:getCapacity() return 1000000 end end
    end
end

local camp = Camp.create({ x1 = 100, y1 = 100, x2 = 125, y2 = 120, z = 0 }, "Life")
fixCrates(camp)
camp.phase = "build"
for _, key in ipairs({ "autoPlan", "expand", "raids", "recruit", "vehicles" }) do camp.options[key] = false end
check("options default on", Options.on(camp, "rhythm") and Options.on(camp, "traditions") and Options.on(camp, "desertion"))

local function project(kind, id, x, y, w, h, status)
    local items = Build.plan(camp).items
    items[tostring(id)] = { id = id, camp = camp.id, kind = kind, x = x, y = y, w = w, h = h, status = status or "done", stage = 1, work = 0, paid = false, done = {} }
    return items[tostring(id)]
end
local fireProject = project("campfire", 1, 106, 104, 3, 3)
local bigHouse = project("house_m", 2, 114, 102, 6, 5)
local smallHouse = project("house_s", 3, 102, 112, 4, 4)
local FIRE = { x = 107, y = 105 }
local CENTER = { x = 112, y = 110 }

local roster = {
    { "g1", "guard" }, { "g2", "guard" }, { "g3", "guard" }, { "b1", "builder" }, { "b2", "builder" },
    { "s1", "scavenger" }, { "s2", "scavenger" }, { "f1", "farmer" },
}
local shells = {}
for index, row in ipairs(roster) do
    local shell = addActor(row[1], 110 + index, 108)
    shells[row[1]] = shell
    Settlers.settle(camp, row[1], "Name " .. row[1])
    camp.settlers[row[1]].role = row[2]
end
check("eight settlers", Store.settlerCount(camp) == 8)

local function sortedUids()
    local list = {}
    for uid in pairs(camp.settlers) do list[#list + 1] = uid end
    table.sort(list)
    return list
end

local function clearLines()
    for _, shell in pairs(shells) do shell.lines = {} end
end

local function allLines()
    local out = {}
    for _, shell in pairs(shells) do
        for _, line in ipairs(shell.lines) do out[#out + 1] = line end
    end
    return out
end

local function tick(minutes, hour)
    for _ = 1, minutes do
        HOURS = HOURS + 1 / 60
        if hour ~= nil then HOUR = hour end
        Hooks.each("minute", camp, 1)
    end
end

local function place(uid, x, y)
    shells[uid].px, shells[uid].py = x, y
end

local function gatherAt(point, uids)
    for index, uid in ipairs(uids) do place(uid, point.x - 2 + (index % 3), point.y + 1 + math.floor(index / 3)) end
end

local function logCount(key)
    local n = 0
    for _, entry in ipairs(camp.log) do
        if entry.k == key then n = n + 1 end
    end
    return n
end

local function lastLog(key)
    for i = #camp.log, 1, -1 do
        if camp.log[i].k == key then return camp.log[i] end
    end
    return nil
end

local function moods()
    local out = {}
    for uid, settler in pairs(camp.settlers) do out[uid] = settler.mood end
    return out
end

local traitsOk, moodsOk, hashOk = true, true, true
for uid, settler in pairs(camp.settlers) do
    local expected = Life.traits[A.Work.hash(uid) % #Life.traits + 1]
    if settler.trait ~= expected then hashOk = false end
    if Life.react[settler.trait] == nil then traitsOk = false end
    if settler.mood ~= 60 then moodsOk = false end
end
check("traits come from uid hash", hashOk)
check("traits are known", traitsOk)
check("start mood is 60", moodsOk)
check("trait stable", Life.traitOf("g1") == Life.traitOf("g1") and Life.traitOf("g1") == camp.settlers.g1.trait)
local seen = {}
for i = 1, 200 do seen[Life.traitOf("person" .. i)] = true end
local kinds = 0
for _ in pairs(seen) do kinds = kinds + 1 end
check("all five characters occur", kinds == 5, kinds)

camp.settlers.g1.trait = "loner"
camp.settlers.g2.trait = "grumbler"
camp.settlers.g3.trait = "optimist"
camp.settlers.b1.trait = "social"
camp.settlers.b2.trait = "workaholic"
camp.settlers.s1.trait = "optimist"
camp.settlers.s2.trait = "loner"
camp.settlers.f1.trait = "grumbler"

check("phase night 3", Life.phaseAt(3) == "night" and Life.phaseAt(0) == "night" and Life.phaseAt(5) == "night" and Life.phaseAt(22) == "night" and Life.phaseAt(23) == "night")
check("phase morning", Life.phaseAt(6) == "morning" and Life.phaseAt(7) == "morning")
check("phase work", Life.phaseAt(8) == "work" and Life.phaseAt(12) == "work" and Life.phaseAt(14) == "work" and Life.phaseAt(18) == "work")
check("phase lunch", Life.phaseAt(13) == "lunch")
check("phase evening", Life.phaseAt(19) == "evening" and Life.phaseAt(21) == "evening")
HOUR = 20
check("phase() follows clock", Life.phase() == "evening" and Life.phase(camp) == "evening")
HOUR = 12
check("phase() work at noon", Life.phase() == "work")
check("stats shape", (function()
    local s = Life.stats(camp)
    return type(s.mood) == "number" and type(s.feasts) == "number" and type(s.deserted) == "number"
        and type(s.evenings) == "number" and type(s.phase) == "string"
end)())
check("average mood is 60", Life.mood(camp) == 60)

local function anchorAt(uid, hour)
    HOUR = hour
    Life.drop(camp)
    return Hooks.first("anchor", camp, uid, camp.settlers[uid], { x = 1, y = 1, z = 0 })
end

local function cheb(point, center)
    return math.max(math.abs(point.x - center.x), math.abs(point.y - center.y))
end

local function guardIndex(uid)
    local list = {}
    for id, settler in pairs(camp.settlers) do
        if settler.role == "guard" then list[#list + 1] = id end
    end
    table.sort(list)
    for index, id in ipairs(list) do
        if id == uid then return index, #list end
    end
    return nil, #list
end

check("anchor hook registered at 40", (function()
    for _, entry in ipairs(Hooks.lists.anchor or {}) do
        if entry.priority == 40 then return true end
    end
    return false
end)())

local plain = { "b1", "b2", "s1", "s2", "f1" }
local function allRing(hour, center, low, high)
    local ok = true
    for _, uid in ipairs(plain) do
        local point = anchorAt(uid, hour)
        if point == nil or point.exact ~= true or cheb(point, center) < low or cheb(point, center) > high then ok = false end
    end
    return ok
end
check("work hours leave anchors alone", (function()
    for _, hour in ipairs({ 8, 10, 12, 14, 16, 18 }) do
        for _, uid in ipairs(sortedUids()) do
            if anchorAt(uid, hour) ~= nil then return false end
        end
    end
    return true
end)())
check("muster at camp centre on ring", allRing(6, CENTER, 1, 3))
check("breakfast at the fire when no mess", allRing(7, FIRE, 1, 3))
check("lunch at the fire", allRing(13, FIRE, 1, 3))
check("dinner at the fire", allRing(19, FIRE, 1, 3))
check("evening gathering at the fire", allRing(20, FIRE, 1, 3) and allRing(21, FIRE, 1, 3))
check("anchors carry their kinds", (function()
    local expected = { [6] = "muster", [7] = "mess", [13] = "mess", [19] = "mess", [20] = "camp", [21] = "camp", [23] = "rest", [2] = "rest" }
    for hour, kind in pairs(expected) do
        local point = anchorAt("b1", hour)
        if point == nil or point.kind ~= kind then return false end
    end
    return true
end)())

local cells = {}
local distinct = 0
for _, uid in ipairs(plain) do
    local point = anchorAt(uid, 20)
    local key = point.x .. ":" .. point.y
    if cells[key] == nil then distinct = distinct + 1 end
    cells[key] = true
end
check("people spread over different cells", distinct >= 4, distinct)

local function guardsFree(hour)
    local free, held = 0, 0
    for _, uid in ipairs({ "g1", "g2", "g3" }) do
        local point = anchorAt(uid, hour)
        if point ~= nil then free = free + 1 else held = held + 1 end
    end
    return free, held
end
for _, hour in ipairs({ 6, 7, 13, 19, 20, 21 }) do
    local free, held = guardsFree(hour)
    check("guards released by turns at " .. hour, free >= 1 and held >= 1, free .. "/" .. held)
end
check("guard turns swap each hour", (anchorAt("g2", 20) ~= nil) ~= (anchorAt("g2", 21) ~= nil))
check("guard parity matches index", (function()
    for _, hour in ipairs({ 6, 7, 20, 21 }) do
        for _, uid in ipairs({ "g1", "g2", "g3" }) do
            local index = guardIndex(uid)
            local expected = (index + hour) % 2 == 0
            if (anchorAt(uid, hour) ~= nil) ~= expected then return false end
        end
    end
    return true
end)())

local function nightWatch()
    local shift = camp.life.nights
    local guards, scavs = {}, {}
    for id, settler in pairs(camp.settlers) do
        if settler.role == "guard" then guards[#guards + 1] = id end
        if settler.role == "scavenger" then scavs[#scavs + 1] = id end
    end
    table.sort(guards)
    table.sort(scavs)
    local watch = {}
    for i = 0, math.ceil(#guards / 3) - 1 do watch[guards[(shift + i) % #guards + 1]] = true end
    for i = 0, math.floor(#scavs / 2) - 1 do watch[scavs[(shift + i) % #scavs + 1]] = true end
    return watch
end
local watch = nightWatch()
local nightOk, watchCount = true, 0
for _, uid in ipairs(sortedUids()) do
    local point = anchorAt(uid, 23)
    if watch[uid] then
        watchCount = watchCount + 1
        if point ~= nil then nightOk = false end
    else
        if point == nil or point.exact ~= true then nightOk = false end
    end
end
check("night: third of guards and half of scavengers stay on duty", nightOk and watchCount == 2, watchCount)
check("night: sleepers without houses go to the fire", (function()
    for _, uid in ipairs(sortedUids()) do
        local point = anchorAt(uid, 2)
        if not watch[uid] and (point == nil or cheb(point, FIRE) > 3) then return false end
    end
    return true
end)())
check("night: at least one guard keeps the post", (function()
    local held = 0
    for _, uid in ipairs({ "g1", "g2", "g3" }) do
        if anchorAt(uid, 0) == nil then held = held + 1 end
    end
    return held >= 1
end)())

camp.settlers.g2.role, camp.settlers.g3.role = "builder", "builder"
check("night: a lone guard always stays", anchorAt("g1", 23) == nil and anchorAt("g1", 3) == nil)
check("day: a lone guard never leaves the post", anchorAt("g1", 20) == nil and anchorAt("g1", 21) == nil and anchorAt("g1", 7) == nil)
camp.settlers.g2.role, camp.settlers.g3.role = "guard", "guard"

camp.raid = { at = HOURS, people = 8, site = { x = 112, y = 100, z = 0 } }
local raidClean = true
for _, hour in ipairs({ 6, 7, 13, 19, 20, 23 }) do
    for _, uid in ipairs(sortedUids()) do
        if anchorAt(uid, hour) ~= nil then raidClean = false end
    end
end
check("raid: no anchors at all", raidClean)
camp.raid = nil

camp.phase = "clear"
local clearClean = true
for _, hour in ipairs({ 6, 13, 20, 23 }) do
    for _, uid in ipairs(sortedUids()) do
        if anchorAt(uid, hour) ~= nil then clearClean = false end
    end
end
check("clearing phase: no anchors", clearClean)
camp.phase = "build"

camp.settlers.b1.ill = { kind = "flu", level = 1 }
check("ill settler is left alone", anchorAt("b1", 20) == nil and anchorAt("b1", 23) == nil and anchorAt("b2", 20) ~= nil)
camp.settlers.b1.ill = nil
check("recovered settler is called again", anchorAt("b1", 20) ~= nil)

Options.set(camp, "rhythm", false)
local rhythmOff = true
for _, hour in ipairs({ 6, 7, 13, 20, 23 }) do
    for _, uid in ipairs(sortedUids()) do
        if anchorAt(uid, hour) ~= nil then rhythmOff = false end
    end
end
check("rhythm off: no anchors", rhythmOff)
Options.set(camp, "rhythm", true)
check("rhythm on again", anchorAt("b2", 20) ~= nil)

local realCrew = A.Motor ~= nil and A.Motor.crewAnchor or nil
if A.Motor == nil then A.Motor = {} end
A.Motor.crewAnchor = function(c, uid) if uid == "b2" then return { x = 1, y = 1, z = 0 } end return nil end
check("vehicle crew is not recalled", anchorAt("b2", 20) == nil and anchorAt("b1", 20) ~= nil)
local ringA = Life.ring(camp, { x = 500, y = 500, z = 0 }, "stable", "mess")
local ringB = Life.ring(camp, { x = 500, y = 500, z = 0 }, "stable", "mess")
check("fallback ring is stable for a settler", ringA.x == ringB.x and ringA.y == ringB.y and ringA.exact == true)
check("fallback ring works over unloaded ground", cheb(ringA, { x = 500, y = 500 }) >= 1 and cheb(ringA, { x = 500, y = 500 }) <= 3 and ringA.kind == "mess")
local ringC = Life.ring(camp, { x = 500, y = 500, z = 0 }, "another", "mess")
check("fallback ring differs between settlers", ringA.x ~= ringC.x or ringA.y ~= ringC.y)
A.Motor.crewAnchor = realCrew

local function near(a, b)
    return math.abs(a - b) < 0.000001
end

local function targetOf(uid)
    Life.drop(camp)
    local life = Life.state(camp)
    local env = Life.environment(camp, 0)
    return Life.target(camp, life, env, uid, camp.settlers[uid], Store.hours())
end

local function delta(uid, change, revert)
    local before = targetOf(uid)
    change()
    local after = targetOf(uid)
    revert()
    return after - before
end

local function startsWith(text, key)
    local template = UIJSON["UI_ALC_" .. key]
    local cut = string.find(template, "%", 1, true)
    local prefix = cut and string.sub(template, 1, cut - 1) or template
    return string.sub(text, 1, #prefix) == prefix
end

local function hasLine(lines, key)
    for _, line in ipairs(lines) do
        if line.text ~= nil and startsWith(line.text, key) then return line end
    end
    return nil
end

local function hookValue(name, expected)
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, value = pcall(entry.fn, camp)
        if ok and type(value) == "number" and near(value, expected) then return true end
    end
    return false
end

local function noted(fragment)
    for _, text in ipairs(PLAYER.notes) do
        if string.find(text, fragment, 1, true) ~= nil then return true end
    end
    return false
end

local function afterName(key)
    local template = UIJSON["UI_ALC_" .. key]
    local cut = string.find(template, "%1", 1, true)
    local rest = string.sub(template, cut + 2)
    local stop = string.find(rest, "%", 1, true)
    if stop ~= nil then rest = string.sub(rest, 1, stop - 1) end
    return rest
end

local function ownOverview(c)
    local rows = {}
    for _, line in ipairs(Hooks.overview(c)) do
        if startsWith(line.text, "LfOverview") then rows[#rows + 1] = line end
    end
    return rows
end

local function countLog(c, key)
    local n = 0
    for _, entry in ipairs(c.log) do
        if entry.k == key then n = n + 1 end
    end
    return n
end

local function spawnCamp(name, rect, uids)
    local c = Camp.create(rect, name)
    fixCrates(c)
    for _, key in ipairs({ "autoPlan", "expand", "raids", "recruit", "vehicles" }) do c.options[key] = false end
    c.phase = "plan"
    for index, uid in ipairs(uids) do
        shells[uid] = addActor(uid, rect.x1 + index, rect.y1 + 2)
        Settlers.settle(c, uid, "Name " .. uid)
        c.settlers[uid].role = "worker"
    end
    return c
end

local function runHours(c, hours, step)
    for _ = 1, math.floor(hours / step) do
        HOURS = HOURS + step
        Hooks.each("minute", c, step * 60)
    end
end

do
    local calls, stationCalled = {}, false
    local function install(overrides)
        local duty = {
            ring = function(c, center, uid, inner, outer, indoor)
                calls[#calls + 1] = { "ring", center.x, center.y, uid, inner, outer, indoor }
                return { x = center.x + 2, y = center.y - 1, z = 0, exact = true }
            end,
            mess = function(c)
                calls[#calls + 1] = { "mess" }
                return { x = 120, y = 114, z = 0, indoor = true, kind = "canteen" }
            end,
            campfire = function(c)
                calls[#calls + 1] = { "campfire" }
                return { x = 108, y = 106, z = 0 }
            end,
            home = function(c, uid)
                calls[#calls + 1] = { "home", uid }
                return { x = 117, y = 104, z = 0, exact = true }
            end,
            station = function()
                stationCalled = true
                return nil
            end,
        }
        for key, value in pairs(overrides or {}) do duty[key] = value end
        A.Duty = duty
    end
    local function lastRing()
        for i = #calls, 1, -1 do
            if calls[i][1] == "ring" then return calls[i] end
        end
        return nil
    end

    install()
    local dinner = anchorAt("b1", 19)
    check("dinner is eaten at Duty.mess", dinner ~= nil and dinner.x == 122 and dinner.y == 113 and dinner.exact == true)
    local ring = lastRing()
    check("ring asked around the mess with inner 1 outer 3", ring ~= nil and ring[2] == 120 and ring[3] == 114 and ring[4] == "b1" and ring[5] == 1 and ring[6] == 3)
    check("indoor mess is passed on to the ring", ring[7] == true)
    check("meal anchor carries its kind", dinner.kind == "mess")
    local supper = anchorAt("b1", 20)
    check("evening gathering at Duty.campfire", supper ~= nil and supper.x == 110 and supper.y == 105)
    check("gathering anchor is at the camp fire", supper.kind == "camp" and lastRing()[7] == false)
    local muster = anchorAt("b1", 6)
    check("muster around the centre via Duty.ring", muster ~= nil and muster.x == 114 and muster.y == 109 and muster.kind == "muster")
    local breakfast = anchorAt("b1", 7)
    check("breakfast at the mess", breakfast ~= nil and breakfast.x == 122 and breakfast.y == 113)
    local lunch = anchorAt("b2", 13)
    check("lunch at the mess", lunch ~= nil and lunch.x == 122 and lunch.y == 113)
    local home = anchorAt("b2", 23)
    check("night goes to Duty.home", home ~= nil and home.x == 117 and home.y == 104 and home.exact == true and home.kind == "home")
    local asked = false
    for _, entry in ipairs(calls) do
        if entry[1] == "home" and entry[2] == "b2" then asked = true end
    end
    check("Duty.home asked for that settler", asked)
    local watching = nightWatch()
    local stays = true
    for uid in pairs(watching) do
        if anchorAt(uid, 23) ~= nil then stays = false end
    end
    check("night watch stays on duty with Duty installed", stays)

    install({ home = function() return nil end })
    local homeless = anchorAt("b2", 23)
    check("no home means the campfire", homeless ~= nil and homeless.x == 110 and homeless.y == 105 and homeless.kind == "rest")

    install({ ring = function() error("boom") end })
    local broken = anchorAt("b1", 20)
    check("broken Duty.ring falls back to a local cell", broken ~= nil and broken.exact == true and cheb(broken, { x = 108, y = 106 }) >= 1 and cheb(broken, { x = 108, y = 106 }) <= 3)
    install({ ring = function() return nil end })
    check("empty Duty.ring falls back", anchorAt("b1", 20) ~= nil)
    install({ ring = function() return "nonsense" end })
    check("garbage from Duty.ring falls back", anchorAt("b1", 20) ~= nil)
    install({ campfire = function() return nil end })
    local ownFire = anchorAt("b1", 20)
    check("no ready campfire from Duty uses the project", ownFire ~= nil and ownFire.x == FIRE.x + 2 and ownFire.y == FIRE.y - 1)
    install({ mess = function() return nil end })
    local ownMess = anchorAt("b1", 19)
    check("no mess from Duty uses the campfire", ownMess ~= nil and ownMess.x == 110 and ownMess.y == 105)
    install({ campfire = function() error("boom") end, mess = function() error("boom") end, home = function() error("boom") end })
    check("failing Duty is harmless", anchorAt("b1", 19) ~= nil and anchorAt("b1", 23) ~= nil)
    A.Duty = {}
    check("Duty without functions is harmless", anchorAt("b1", 20) ~= nil and anchorAt("b1", 23) ~= nil)
    check("Duty.station is never called by the routine", stationCalled == false)
    A.Duty = nil
    check("work hours stay free with Duty installed", (function()
        install()
        for _, hour in ipairs({ 8, 10, 15, 18 }) do
            if anchorAt("b1", hour) ~= nil then return false end
        end
        A.Duty = nil
        return true
    end)())
end

do
    project("plaza", 10, 105, 101, 7, 3)
    local p = anchorAt("b1", 6)
    check("muster at the plaza when it is built", p ~= nil and cheb(p, { x = 108, y = 102 }) >= 1 and cheb(p, { x = 108, y = 102 }) <= 3)
    Build.plan(camp).items["10"] = nil
    fireProject.status = "planned"
    local q = anchorAt("b1", 20)
    check("without a campfire the camp centre hosts the evening", q ~= nil and cheb(q, CENTER) >= 1 and cheb(q, CENTER) <= 3)
    project("plaza", 11, 105, 101, 7, 3)
    local r = anchorAt("b1", 20)
    check("plaza is the next best place for the evening", r ~= nil and cheb(r, { x = 108, y = 102 }) <= 3)
    Build.plan(camp).items["11"] = nil
    fireProject.status = "done"
end

do
    Options.set(camp, "traditions", true)
    local cont = Stock.crate(camp, camp.storage[1]):getContainer()
    for _ = 1, 80 do
        local item = NEWITEM("Base.Canned", 400)
        function item:getModData() self.mod = self.mod or {} return self.mod end
        item.container = cont
        table.insert(cont.items, item)
    end
    Stock.refresh(camp)
    for _, uid in ipairs(sortedUids()) do place(uid, 112, 108) end
    HOURS = HOURS + 1 / 60
    HOUR = 20
    camp.orderClock = 3
    fire("EveryOneMinute")
    local expected = Hooks.first("anchor", camp, "b1", camp.settlers.b1, { x = 1, y = 1, z = 0 })
    local order = orders.b1
    check("director issues a patrol order from the routine", order ~= nil and order.kind == "patrol" and expected ~= nil
        and order.anchor.x == expected.x and order.anchor.y == expected.y, order and (order.anchor.x .. "," .. order.anchor.y))
    check("order is exactly the ring cell, no jitter", cheb(order.anchor, FIRE) >= 1 and cheb(order.anchor, FIRE) <= 3)
    local free = nil
    for _, uid in ipairs({ "g1", "g2", "g3" }) do
        local anchor = Hooks.first("anchor", camp, uid, camp.settlers[uid], { x = 1, y = 1, z = 0 })
        if anchor ~= nil then
            free = uid
            check("released guard walks to the fire", orders[uid] ~= nil and orders[uid].anchor.x == anchor.x and orders[uid].anchor.y == anchor.y)
        else
            check("guard on post keeps the core anchor", orders[uid] ~= nil and (orders[uid].anchor.x ~= nil))
        end
    end
    check("one guard was released", free ~= nil)
    camp.phase = "build"
    camp.hunger = 0
end

do
    A.Duty = nil
    camp.hunger = 0
    camp.raid = nil
    camp.phase = "build"
    local SAN, SICK, PROG, EXTRA = 50, {}, 0, 0
    Hooks.add("defense", function() return EXTRA end)
    camp.stock.food = 2 * 2000 * Store.settlerCount(camp)
    local life = Life.state(camp)
    for _, settler in pairs(camp.settlers) do settler.lf.buffs = {} end
    life.buffs = {}

    local function hungry(h) return function() camp.hunger = h end end
    local function calm() camp.hunger = 0 end
    local dLoner = delta("g1", hungry(2), calm)
    local dGrumbler = delta("g2", hungry(2), calm)
    local dOptimist = delta("g3", hungry(2), calm)
    check("hunger lowers the target", dLoner < 0, dLoner)
    check("loner feels hunger one to one", near(dLoner, -10), dLoner)
    check("grumbler reacts twice as hard to bad things", near(dGrumbler, 2 * dLoner), dGrumbler)
    check("optimist shrugs off a part of the bad", near(dOptimist, 0.8 * dLoner), dOptimist)
    camp.hunger = 100
    check("starvation floors the target at zero", targetOf("g2") == 0)
    camp.hunger = 0

    local function sanitary(score) return function() A.Sanitary = { score = function() return score end } end end
    local function noSanitary() A.Sanitary = nil end
    local cLoner = delta("g1", sanitary(100), noSanitary)
    local cGrumbler = delta("g2", sanitary(100), noSanitary)
    local cOptimist = delta("g3", sanitary(100), noSanitary)
    check("clean camp lifts the mood", near(cLoner, 8), cLoner)
    check("optimist enjoys the good more, grumbler less", near(cOptimist, 12) and near(cGrumbler, 6.4), cOptimist .. "/" .. cGrumbler)
    check("dirty camp lowers the mood", near(delta("g1", sanitary(0), noSanitary), -8))
    check("neutral cleanliness changes nothing", near(delta("g1", sanitary(50), noSanitary), 0))
    check("broken Sanitary is ignored", near(delta("g1", function() A.Sanitary = { score = function() error("boom") end } end, noSanitary), 0))
    check("non numeric Sanitary is ignored", near(delta("g1", function() A.Sanitary = { score = function() return "x" end } end, noSanitary), 0))

    local function sickness(levels) return function() A.Health = { sickLevel = function(c, uid) return levels[uid] or 0 end } end end
    local function noHealth() A.Health = nil end
    check("sickness lowers the mood", near(delta("g1", sickness({ g1 = 2 }), noHealth), -18))
    check("others do not catch the mood", near(delta("g3", sickness({ g1 = 2 }), noHealth), 0))
    check("percent style sickness is understood", near(delta("g1", sickness({ g1 = 100 }), noHealth), -27.027027027027), delta("g1", sickness({ g1 = 100 }), noHealth))
    check("ill flag alone counts as light illness", near(delta("g1", function() camp.settlers.g1.ill = { kind = "flu", level = 1 } end, function() camp.settlers.g1.ill = nil end), -9))
    check("broken Health is ignored", near(delta("g1", function() A.Health = { sickLevel = function() error("boom") end } end, noHealth), 0))

    local function progress(value) return function() A.Progress = { bonus = function(c, key) if key == "mood" then return value end return 0 end } end end
    local function noProgress() A.Progress = nil end
    check("progress bonus lifts the mood", near(delta("g1", progress(8), noProgress), 8))
    check("progress bonus is capped", near(delta("g1", progress(100), noProgress), 15))
    check("negative progress is capped too", near(delta("g1", progress(-100), noProgress), -15))
    check("broken Progress is ignored", near(delta("g1", function() A.Progress = { bonus = function() error("boom") end } end, noProgress), 0))

    local function crowd() bigHouse.status = "planned" end
    local function roof() bigHouse.status = "done" end
    check("shortage of beds lowers the mood", near(delta("g1", crowd, roof), -10))
    check("grumbler loses comfort at 0.8 and suffers the shortage twice", near(delta("g2", crowd, roof), -12 - 3.2), delta("g2", crowd, roof))

    check("weak defence lowers the mood", near(delta("g1", function() EXTRA = -100 end, function() EXTRA = 0 end), -6))
    check("strong defence lifts the mood", near(delta("g1", function() EXTRA = 200 end, function() EXTRA = 0 end), 4))
    check("raid in progress frightens", near(delta("g1", function() camp.raid = { at = HOURS, people = 8 } end, function() camp.raid = nil end), -8))
    check("a recent raid still weighs", near(delta("g1", function() life.raidAt = Store.hours() - 12 life.raidSafe = nil end, function() life.raidAt = nil end), -4))
    check("a repelled raid weighs half as much", near(delta("g1", function() life.raidAt = Store.hours() - 12 life.raidSafe = true end, function() life.raidAt = nil life.raidSafe = nil end), -2))
    check("old raid is forgotten", near(delta("g1", function() life.raidAt = Store.hours() - 30 end, function() life.raidAt = nil end), 0))

    local function socialAge(uid, age) camp.settlers[uid].lf.social = Store.hours() - age end
    socialAge("b1", 0)
    local _, f0 = targetOf("b1")
    check("fresh evening gives the sociable full bonus", near(f0.social, 9), f0.social)
    socialAge("b1", 20)
    local _, f1 = targetOf("b1")
    check("bonus fades with time", near(f1.social, 9 * (36 - 20) / 24), f1.social)
    socialAge("b1", 60)
    local _, f2 = targetOf("b1")
    check("sociable settler longs for company", near(f2.social, -5), f2.social)
    socialAge("b1", 100)
    local _, f3 = targetOf("b1")
    check("longing is capped", near(f3.social, -10), f3.social)
    socialAge("g1", 100)
    local _, fLoner = targetOf("g1")
    check("loner does not need evenings", near(fLoner.social, 0))
    socialAge("b2", 100)
    local _, fPlain = targetOf("b2")
    check("ordinary settler misses evenings a little", near(fPlain.social, -2), fPlain.social)
    Options.set(camp, "traditions", false)
    local _, fOff = targetOf("b1")
    check("no social need when traditions are off", near(fOff.social, 0))
    Options.set(camp, "traditions", true)

    local function plan() camp.phase = "plan" end
    local function building() camp.phase = "build" end
    check("workaholic is bored without work", near(delta("b2", plan, building), -12))
    check("others do not mind idleness", near(delta("g1", plan, building), 0))

    local function holiday(value) return function() life.buffs.test = { v = value, e = Store.hours() + 5, f = "holiday" } end end
    local function noHoliday() life.buffs.test = nil end
    check("holiday lifts the mood", near(delta("g1", holiday(10), noHoliday), 10))
    check("optimist enjoys holidays more", near(delta("g3", holiday(10), noHoliday), 15))
    check("grumbler enjoys holidays less", near(delta("g2", holiday(10), noHoliday), 8))
    check("expired buffs do not count", near(delta("g1", function() life.buffs.test = { v = 10, e = Store.hours() - 1, f = "holiday" } end, noHoliday), 0))
    check("personal buffs count", near(delta("g1", function() camp.settlers.g1.lf.buffs.mine = { v = 5, e = Store.hours() + 5, f = "holiday" } end, function() camp.settlers.g1.lf.buffs.mine = nil end), 5))

    for _, uid in ipairs(sortedUids()) do socialAge(uid, 0) end
    life.deaths = {}
    camp.settlers.b2.lf.social = Store.hours() - 100
    Hooks.each("died", camp, { name = "Dead One" }, "dead1")
    local _, lossG1 = targetOf("g1")
    local _, lossB1 = targetOf("b1")
    local _, lossB2 = targetOf("b2")
    check("a death weighs on the camp", near(lossG1.loss, -5 - 8 * 0.6), lossG1.loss)
    check("sociable settlers mourn less", near(lossB1.loss, -5 - 8 * 0.3), lossB1.loss)
    check("lonely settlers mourn the most", near(lossB2.loss, -13), lossB2.loss)
    check("cohesion softens the blow", lossB1.loss > lossG1.loss and lossG1.loss > lossB2.loss)
    life.queue = {}
    life.buffs.memorial = nil
    life.deaths = { Store.hours() - 36 }
    local _, fading = targetOf("g1")
    check("grief fades", near(fading.loss, -2.5), fading.loss)
    life.deaths = { Store.hours() - 80 }
    local _, gone = targetOf("g1")
    check("old grief is gone", near(gone.loss, 0))
    life.deaths = { Store.hours(), Store.hours(), Store.hours(), Store.hours(), Store.hours() }
    local _, capped = targetOf("g1")
    check("grief is capped", near(capped.loss, -15), capped.loss)
    life.deaths = {}
    for _, uid in ipairs(sortedUids()) do socialAge(uid, 0) end

    for _, uid in ipairs(sortedUids()) do
        local value = targetOf(uid)
        check("target in range for " .. uid, value >= 0 and value <= 100)
    end
end

do
    camp.hunger = 3
    local life = Life.state(camp)
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 60 end
    Life.drop(camp)
    local previous = moods()
    local maxStep, moved = 0, false
    for _ = 1, 40 do
        tick(1, 12)
        local now = moods()
        for uid, value in pairs(now) do
            local step = math.abs(value - previous[uid])
            if step > maxStep then maxStep = step end
            if step > 0 then moved = true end
        end
        previous = now
    end
    check("mood moves", moved)
    check("mood moves at most a point per minute", maxStep <= 1.000001, maxStep)
    check("mood moves a full point per minute when far from the target", maxStep >= 0.999, maxStep)

    Life.setMood(camp, 100)
    local snapshot = moods()
    Hooks.each("minute", camp, 30)
    local bigStep = 0
    for uid, value in pairs(moods()) do bigStep = math.max(bigStep, math.abs(value - snapshot[uid])) end
    check("long gaps move the mood proportionally", bigStep > 1 and bigStep <= 30.000001, bigStep)

    camp.hunger = 40
    for _ = 1, 120 do tick(1, 12) end
    local low = 100
    for _, value in pairs(moods()) do low = math.min(low, value) end
    check("mood never drops below zero", low >= 0, low)
    check("grumbler bottoms out at zero in a famine", camp.settlers.g2.mood == 0)

    camp.hunger = 0
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 10 end
    for _ = 1, 20 do tick(1, 12) end
    local risen = true
    for _, uid in ipairs(sortedUids()) do
        if not near(camp.settlers[uid].mood, 30) then risen = false end
    end
    check("recovery is also a point per minute", risen, camp.settlers.g1.mood)

    check("setMood reports the count", Life.setMood(camp, 100, true) == 8)
    for _ = 1, 60 do tick(1, 12) end
    local high = 0
    for _, value in pairs(moods()) do high = math.max(high, value) end
    check("mood never exceeds 100", high <= 100, high)
    check("held cheat mood stays at 100", Life.mood(camp) == 100)
    runHours(camp, 7, 0.25)
    check("cheat mood wears off", camp.settlers.g1.mood < 100 and camp.settlers.g2.mood < 100, camp.settlers.g1.mood)
    Life.setMood(camp, 60)
    check("plain setMood sets every mood", Life.mood(camp) == 60 and camp.settlers.g2.lf.buffs.cheat == nil)
    Life.setMood(camp, 250)
    check("setMood clamps", Life.mood(camp) == 100)
    Life.setMood(camp, -5)
    check("setMood clamps below", Life.mood(camp) == 0)
    Life.setMood(camp, 60)
    life.lastLeft = nil
end

do
    Options.set(camp, "traditions", true)
    camp.hunger = 0
    camp.phase = "build"
    Life.setMood(camp, 60)
    clearLines()
    local life = Life.state(camp)
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].lf.social = Store.hours() - 100 end
    local circle = { "b1", "b2", "s1", "s2", "f1" }
    gatherAt(FIRE, circle)
    for _, uid in ipairs({ "g1", "g2", "g3" }) do place(uid, 121, 118) end
    tick(2, 12)
    local base = life.evenings
    tick(6, 19)
    check("no session at dinner time", life.evenings == base)
    local sessionAt
    for minute = 1, 12 do
        tick(1, 20)
        if life.evenings > base and sessionAt == nil then sessionAt = { minute = minute, hours = HOURS } end
    end
    check("session happens once the circle has formed", sessionAt ~= nil and sessionAt.minute == 8, sessionAt and sessionAt.minute)
    check("only one session per evening", life.evenings == base + 1)
    local at = sessionAt.hours
    check("attendees remember the evening", camp.settlers.b1.lf.social >= at - 0.000001 and camp.settlers.s2.lf.social >= at - 0.000001)
    check("absent settlers do not", camp.settlers.g1.lf.social < at - 50)
    check("sociable attendee gets the evening buff", camp.settlers.b1.lf.buffs.evening ~= nil and camp.settlers.b1.lf.buffs.evening.v == 4)
    check("loner gets no evening buff", camp.settlers.s2.lf.buffs.evening == nil)
    check("absent settlers get no buff", camp.settlers.g1.lf.buffs.evening == nil)
    check("two voices over the fire", #allLines() == 2, #allLines())
    check("journal notes the first evening", countLog(camp, "lf_evening") == 1 and lastLog("lf_evening").a == 5, lastLog("lf_evening") and lastLog("lf_evening").a)
    check("listeners train a side skill", camp.settlers.b1.skills ~= nil and camp.settlers.b1.skills.farm == Life.lessonXp, camp.settlers.b1.skills and camp.settlers.b1.skills.farm)
    local _, fed = targetOf("b1")
    check("evening feeds the social factor", near(fed.social, 9 + 4), fed.social)

    clearLines()
    tick(60, 21)
    check("no second session the same evening", life.evenings == base + 1)
    tick(3, 12)
    tick(20, 20)
    check("next evening, next session", life.evenings == base + 2)
    check("journal does not repeat every evening", countLog(camp, "lf_evening") == 1)
    for _ = 1, 2 do
        tick(3, 12)
        tick(12, 20)
    end
    check("journal repeats every third evening", life.evenings == base + 4 and countLog(camp, "lf_evening") == 2, countLog(camp, "lf_evening"))

    place("b1", 121, 118)
    place("b2", 121, 118)
    place("s1", 121, 118)
    local count = life.evenings
    tick(3, 12)
    tick(30, 20)
    check("two people are not a circle", life.evenings == count)

    reg.records.ghost = { uid = "ghost", revision = 1, generation = 1, lifecycle = "active", worldPosition = { x = 110, y = 110, z = 0 }, memory = {} }
    Settlers.settle(camp, "ghost", "Ghost")
    camp.settlers.ghost.role = "worker"
    tick(3, 12)
    tick(12, 20)
    check("an off-screen settler inside the camp counts", life.evenings == count + 1)
    camp.settlers.ghost = nil
    reg.records.ghost = nil

    gatherAt(FIRE, circle)
    Options.set(camp, "traditions", false)
    count = life.evenings
    tick(3, 12)
    tick(30, 20)
    check("no sessions when traditions are off", life.evenings == count)
    Options.set(camp, "traditions", true)
end

do
    local life = Life.state(camp)
    Options.set(camp, "traditions", true)
    camp.hunger = 0
    Life.setMood(camp, 60)
    life.feastDue = nil
    life.gather = nil
    life.queue = {}
    local cont = Stock.crate(camp, camp.storage[1]):getContainer()
    cont.items = {}
    local function addFood(count)
        for _ = 1, count do
            local item = NEWITEM("Base.Canned", 100)
            function item:getModData() self.mod = self.mod or {} return self.mod end
            item.container = cont
            table.insert(cont.items, item)
        end
        Stock.refresh(camp)
    end
    addFood(300)
    check("stock holds plenty of food", camp.stock.food == 30000, camp.stock.food)
    local people = Store.settlerCount(camp)
    Hooks.each("daily", camp, 29, {})
    check("no anniversary at day 29", life.feastDue ~= true)
    Hooks.each("daily", camp, 30, {})
    check("anniversary comes at day 30", life.feastDue == true and life.annivDone == 1)
    Hooks.each("daily", camp, 31, {})
    check("day 31 does not repeat it", life.annivDone == 1 and life.feastDue == true)

    local feasts = life.feasts
    for _, uid in ipairs(sortedUids()) do place(uid, 121, 118) end
    tick(3, 12)
    tick(20, 20)
    check("feast waits until people gather", life.feastDue == true and life.feasts == feasts)

    gatherAt(FIRE, sortedUids())
    local notes = #PLAYER.notes
    local before = camp.stock.food
    tick(3, 12)
    tick(9, 20)
    Stock.refresh(camp)
    check("feast is held", life.feasts == feasts + 1 and life.feastDue == nil)
    check("feast eats 600 per person", before - camp.stock.food == people * 600, before - camp.stock.food)
    check("feast buff is 15 for two days", life.buffs.feast ~= nil and life.buffs.feast.v == 15 and math.abs(life.buffs.feast.e - (HOURS + 48)) < 0.2)
    check("feast starts a gathering", life.gather ~= nil and life.gather.kind == "feast")
    check("feast is logged", countLog(camp, "lf_feast") == 1 and lastLog("lf_feast").a == people and lastLog("lf_feast").b == people * 600)
    check("player is told about the feast", #PLAYER.notes > notes and noted(afterName("LfFeast")))
    local _, fed = targetOf("g1")
    check("feast shows in the mood target", near(fed.holiday, 15), fed.holiday)

    Hooks.each("daily", camp, 60, {})
    check("second anniversary comes at day 60", life.feastDue == true and life.annivDone == 2)
    cont.items = {}
    addFood(200)
    feasts = life.feasts
    life.gather = nil
    before = camp.stock.food
    tick(3, 12)
    tick(9, 20)
    Stock.refresh(camp)
    check("short of food the feast is modest", life.feasts == feasts + 1 and countLog(camp, "lf_anniv") == 1 and camp.stock.food == before, camp.stock.food)
    check("modest feast gives a smaller bonus", life.buffs.feast.v == 6 and math.abs(life.buffs.feast.e - (HOURS + 24)) < 0.2)
    check("modest feast is announced", noted(afterName("LfAnnivPoor")))

    Hooks.each("daily", camp, 90, {})
    cont.items = {}
    addFood(241)
    feasts = life.feasts
    life.gather = nil
    before = camp.stock.food
    tick(3, 12)
    tick(9, 20)
    Stock.refresh(camp)
    check("just over a day and a half still allows the feast", life.feasts == feasts + 1 and before - camp.stock.food == people * 600 and countLog(camp, "lf_feast") == 2, before - camp.stock.food)

    Hooks.each("daily", camp, 120, {})
    cont.items = {}
    Stock.refresh(camp)
    feasts = life.feasts
    life.gather = nil
    tick(3, 12)
    tick(9, 20)
    check("empty larder means no feast but still a holiday", life.feasts == feasts + 1 and countLog(camp, "lf_anniv") == 2 and camp.stock.food == 0)

    Options.set(camp, "traditions", false)
    Hooks.each("daily", camp, 150, {})
    check("no anniversary when traditions are off", life.feastDue ~= true and life.annivDone == 4)
    Options.set(camp, "traditions", true)
    Hooks.each("daily", camp, 150, {})
    check("anniversary catches up when traditions return", life.feastDue == true and life.annivDone == 5)
    life.feastDue = nil

    local old = { id = 99, founded = HOURS - 24 * 75, settlers = {}, options = {}, stats = { built = 0 }, log = {} }
    check("an old camp does not feast at once", Life.state(old).annivDone == 2 and old.life.feastDue == nil)
    life.gather = nil
end

do
    local life = Life.state(camp)
    Options.set(camp, "traditions", true)
    life.gather = nil
    life.queue = {}
    life.buffs = {}
    camp.raid = nil
    clearLines()
    HOUR = 15
    local feasts = life.feasts
    Hooks.each("raidstart", camp, {})
    check("raid start is remembered", type(life.raidAt) == "number")
    camp.raid = { at = HOURS, people = 8 }
    Hooks.each("raidend", camp, camp.raid, 0)
    check("flawless defence queues a victory", #life.queue == 1 and life.queue[1].k == "victory" and life.raidSafe == true)
    tick(2, 15)
    check("victory waits while the raid is still marked", life.gather == nil)
    camp.raid = nil
    tick(1, 15)
    check("victory starts when the raid is cleaned up", life.gather ~= nil and life.gather.kind == "victory" and #life.queue == 0)
    check("victory buff is 10 for a day", life.buffs.victory ~= nil and life.buffs.victory.v == 10 and math.abs(life.buffs.victory.e - (HOURS + 24)) < 0.2)
    check("victory counts as a feast", life.feasts == feasts + 1)
    check("victory is logged", countLog(camp, "lf_victory") == 1)
    check("victory is announced", noted(afterName("LfVictory")))
    check("victory is cheered", #allLines() == 2)
    local _, won = targetOf("g1")
    check("victory shows in the target", near(won.holiday, 10), won.holiday)

    life.gather = nil
    Hooks.each("raidend", camp, {}, 0)
    tick(3, 23)
    check("no victory party at night", life.gather == nil and #life.queue == 1)
    tick(1, 9)
    check("victory party waits for the morning", life.gather ~= nil and life.gather.kind == "victory")

    life.gather = nil
    life.queue = {}
    Hooks.each("raidend", camp, {}, 2)
    check("losses cancel the victory", #life.queue == 0 and life.raidSafe == false)
    Options.set(camp, "traditions", false)
    Hooks.each("raidend", camp, {}, 0)
    check("no victory when traditions are off", #life.queue == 0)
    Options.set(camp, "traditions", true)

    life.gather = { kind = "victory", e = Store.hours() + 0.4 }
    check("gathering pulls people to the fire in working hours", (function()
        local p = anchorAt("b1", 10)
        return p ~= nil and cheb(p, FIRE) >= 1 and cheb(p, FIRE) <= 3
    end)())
    local free, held = guardsFree(10)
    check("gathering lets guards rotate", free >= 1 and held >= 1, free .. "/" .. held)
    Options.set(camp, "rhythm", false)
    check("gathering works with the rhythm off", anchorAt("b1", 10) ~= nil)
    Options.set(camp, "traditions", false)
    check("gathering is a tradition", anchorAt("b1", 10) == nil)
    life.gather.kind = "party"
    check("party ignores the traditions switch", anchorAt("b1", 10) ~= nil)
    Options.set(camp, "traditions", true)
    Options.set(camp, "rhythm", true)
    camp.settlers.b1.ill = { kind = "flu", level = 1 }
    check("gathering leaves the ill alone", anchorAt("b1", 10) == nil)
    camp.settlers.b1.ill = nil
    camp.raid = { at = HOURS, people = 8 }
    check("gathering stops for a raid", anchorAt("b2", 10) == nil)
    camp.raid = nil
    HOURS = HOURS + 1
    check("gathering ends on time", anchorAt("b1", 10) == nil)
    life.gather = nil

    clearLines()
    life.deaths = {}
    life.queue = {}
    Hooks.each("died", camp, { name = "Fallen Ann" }, "ann")
    check("death is recorded", #life.deaths == 1 and life.buffs.memorial ~= nil and life.buffs.memorial.v == -8 and #life.queue == 1 and life.queue[1].k == "memorial")
    tick(1, 10)
    check("memorial is held", life.gather ~= nil and life.gather.kind == "memorial" and countLog(camp, "lf_memorial") == 1 and lastLog("lf_memorial").a == "Fallen Ann")
    local named = false
    for _, line in ipairs(allLines()) do
        if string.find(line, "Fallen Ann", 1, true) then named = true end
    end
    check("someone says the name aloud", named)
    check("memorial has a note for the player", noted(afterName("LfMemorial")) and noted("Fallen Ann"))
    life.gather = nil
    for i = 1, 7 do Hooks.each("died", camp, { name = "N" .. i }, "n" .. i) end
    check("only the last five deaths are kept", #life.deaths == 5)
    check("the queue stays short", #life.queue <= Life.queueLimit)
    life.deaths = {}
    life.queue = {}
    life.buffs.memorial = nil

    clearLines()
    shells.newbie = addActor("newbie", 112, 108)
    Settlers.settle(camp, "newbie", "Newbie Nick")
    local fresh = camp.settlers.newbie
    check("newcomer starts at 60 with a trait", fresh.mood == 60 and Life.react[fresh.trait] ~= nil)
    check("newcomer gets a welcome buff", fresh.lf.buffs.hello ~= nil and fresh.lf.buffs.hello.v == 8)
    check("newcomer greets everyone", #shells.newbie.lines == 1)
    local welcomed = false
    for uid, shell in pairs(shells) do
        if uid ~= "newbie" then
            for _, line in ipairs(shell.lines) do
                if string.find(line, "Newbie Nick", 1, true) then welcomed = true end
            end
        end
    end
    check("a veteran welcomes the newcomer", welcomed)
    local _, glow = targetOf("newbie")
    local _, plainGlow = targetOf("g1")
    check("welcome shows in the target", near(glow.holiday - plainGlow.holiday, 8), glow.holiday - plainGlow.holiday)
    camp.settlers.newbie = nil
    Options.set(camp, "traditions", false)
    clearLines()
    shells.newbie2 = addActor("newbie2", 112, 108)
    Settlers.settle(camp, "newbie2", "Quiet Quinn")
    check("no welcome when traditions are off", camp.settlers.newbie2.lf.buffs.hello == nil and #shells.newbie2.lines == 0)
    camp.settlers.newbie2 = nil
    Options.set(camp, "traditions", true)
    life.gather = nil
end

do
    local camp2 = spawnCamp("Bad", { x1 = 130, y1 = 130, x2 = 150, y2 = 145, z = 0 }, { "u1", "u2", "u3", "u4" })
    camp2.hunger = 20
    camp2.settlers.u1.trait = "grumbler"
    camp2.settlers.u2.trait = "loner"
    camp2.settlers.u3.trait = "optimist"
    camp2.settlers.u4.trait = "social"
    HOUR = 12
    runHours(camp2, 45, 0.5)
    check("everyone has grumbled once", countLog(camp2, "lf_grumble") == 4, countLog(camp2, "lf_grumble"))
    check("grumbling is logged by name", (function()
        for _, entry in ipairs(camp2.log) do
            if entry.k == "lf_grumble" and string.find(entry.a, "Name u1", 1, true) then return true end
        end
        return false
    end)())
    check("unhappy settlers have low moods", camp2.settlers.u1.mood < 10 and camp2.settlers.u2.mood < 10)
    check("optimist stays above the line", camp2.settlers.u3.mood >= 10 and camp2.settlers.u3.mood < 25, camp2.settlers.u3.mood)
    check("nobody leaves before 48 hours of misery", Store.settlerCount(camp2) == 4 and camp2.life.deserted == 0)
    runHours(camp2, 7, 0.5)
    check("one settler leaves after two days", Store.settlerCount(camp2) == 3 and camp2.life.deserted == 1 and camp2.settlers.u1 == nil, Store.settlerCount(camp2))
    check("leaving is logged", countLog(camp2, "lf_left") == 1)
    check("leaver is released by A-Life", reg.records.u1.memory.camp == nil)
    check("left counter in stats", camp2.stats.left == 1)
    check("leaving is announced to the player", noted(afterName("LfLeft")) and noted("Name u1"))
    runHours(camp2, 2, 0.5)
    check("departures keep a pause", Store.settlerCount(camp2) == 3)
    runHours(camp2, 10, 0.5)
    check("a second one leaves later", Store.settlerCount(camp2) == 2 and camp2.life.deserted == 2, Store.settlerCount(camp2))
    runHours(camp2, 150, 0.5)
    check("with two people left nobody goes", Store.settlerCount(camp2) == 2 and camp2.life.deserted == 2)
    check("grumble is logged only once per spell", countLog(camp2, "lf_grumble") == 4)

    local camp3 = spawnCamp("Patient", { x1 = 130, y1 = 100, x2 = 150, y2 = 115, z = 0 }, { "p1", "p2", "p3", "p4" })
    Options.set(camp3, "desertion", false)
    camp3.hunger = 20
    camp3.settlers.p1.trait = "grumbler"
    runHours(camp3, 100, 0.5)
    check("desertion off: nobody leaves", Store.settlerCount(camp3) == 4 and camp3.life.deserted == 0)
    check("desertion off: no grumbling in the journal", countLog(camp3, "lf_grumble") == 0)
    check("moods still fall with desertion off", camp3.settlers.p1.mood < 10)
    Options.set(camp3, "desertion", true)
    runHours(camp3, 2, 0.5)
    check("switching it back on starts the clock", camp3.life.deserted == 0 and camp3.settlers.p1.lf.low ~= nil)

    local camp4 = spawnCamp("Small", { x1 = 60, y1 = 100, x2 = 76, y2 = 115, z = 0 }, { "q1", "q2" })
    camp4.hunger = 20
    camp4.settlers.q1.trait = "grumbler"
    runHours(camp4, 120, 0.5)
    check("two people never desert", Store.settlerCount(camp4) == 2 and camp4.life.deserted == 0)
    check("two unhappy people still grumble", countLog(camp4, "lf_grumble") >= 1)

    local camp5 = spawnCamp("Recover", { x1 = 60, y1 = 120, x2 = 76, y2 = 135, z = 0 }, { "r1", "r2", "r3" })
    camp5.hunger = 20
    camp5.settlers.r1.trait = "grumbler"
    runHours(camp5, 30, 0.5)
    check("low timer is running", camp5.settlers.r1.lf.low ~= nil)
    camp5.hunger = 0
    camp5.stock.food = 100000
    runHours(camp5, 3, 0.5)
    check("recovery stops the timer", camp5.settlers.r1.lf.low == nil and camp5.settlers.r1.mood > 10)
    camp5.hunger = 20
    camp5.stock.food = 0
    runHours(camp5, 30, 0.5)
    check("the clock starts over", Store.settlerCount(camp5) == 3 and camp5.life.deserted == 0)
    runHours(camp5, 40, 0.5)
    check("and eventually one leaves", camp5.life.deserted == 1 and Store.settlerCount(camp5) == 2)

    Camp.abandon(camp2)
    Camp.abandon(camp3)
    Camp.abandon(camp4)
    Camp.abandon(camp5)
end

do
    local life = Life.state(camp)
    camp.hunger = 0
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 20 end
    check("labor 0.85 at low mood", hookValue("labor", 0.85) and near(Life.laborFactor(camp), 0.85), Life.laborFactor(camp))
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 5 end
    check("labor stays at 0.85 below 20", hookValue("labor", 0.85) and near(Life.laborFactor(camp), 0.85))
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 90 end
    check("labor 1.12 at high mood", hookValue("labor", 1.12) and near(Life.laborFactor(camp), 1.12))
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 100 end
    check("labor stays at 1.12 above 90", hookValue("labor", 1.12) and near(Life.laborFactor(camp), 1.12))
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 55 end
    check("labor in between", hookValue("labor", 0.85 + 35 / 70 * 0.27) and near(Life.laborFactor(camp), 0.985), Life.laborFactor(camp))
    check("empty camp does not change labor", Life.laborFactor({ settlers = {} }) == 1 and Life.moraleShift({ settlers = {} }) == 0)

    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 60 end
    check("morale shift is zero at 60", hookValue("morale", 0) and near(Life.moraleShift(camp), 0))
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 90 end
    check("morale shift +5 at 90", hookValue("morale", 5) and near(Life.moraleShift(camp), 5))
    local high = Stats.compute(camp).morale
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 30 end
    check("morale shift -5 at 30", hookValue("morale", -5) and near(Life.moraleShift(camp), -5))
    local lowMorale = Stats.compute(camp).morale
    check("camp morale follows the settlers", high - lowMorale >= 9 and high - lowMorale <= 11, high .. "/" .. lowMorale)

    local built = camp.stats.built
    Hooks.each("daily", camp, 3, {})
    camp.stats.built = built + 3
    Hooks.each("daily", camp, 4, {})
    local digest = lastLog("lf_digest")
    check("digest counts people", digest ~= nil and digest.a == Store.settlerCount(camp))
    check("digest holds mood and the day's building", type(digest.b) == "string" and string.find(digest.b, "3", 1, true) ~= nil and string.find(digest.b, tostring(Life.mood(camp)), 1, true) ~= nil, digest.b)
    Hooks.each("daily", camp, 5, {})
    check("digest shows nothing built on a quiet day", string.find(lastLog("lf_digest").b, " 0", 1, true) ~= nil, lastLog("lf_digest").b)
    camp.stats.built = built

    local ids = {}
    for _, uid in ipairs(sortedUids()) do ids[#ids + 1] = uid end
    local infoOk = true
    for _, uid in ipairs(ids) do
        local parts = Hooks.collect("settlerInfo", camp, uid, camp.settlers[uid])
        local trait = UIJSON["UI_ALC_LfTrait_" .. camp.settlers[uid].trait]
        local own = {}
        for _, part in ipairs(parts) do
            if startsWith(part, "LfInfo") then own[#own + 1] = part end
        end
        if #own ~= 1 or string.find(own[1], "30", 1, true) == nil or string.find(own[1], trait, 1, true) == nil then infoOk = false end
    end
    check("people list shows mood and character", infoOk)
    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    local rows = win:settlerLines(camp)
    local prefix = string.sub(UIJSON.UI_ALC_LfInfo, 1, string.find(UIJSON.UI_ALC_LfInfo, "%", 1, true) - 1)
    local shown = 0
    for _, row in ipairs(rows) do
        if string.find(row.text, prefix, 1, true) ~= nil then shown = shown + 1 end
    end
    check("window row carries the note", shown == 8, shown)
    check("info works for a settler without fields", #Life.info(camp, "stranger", {}) == 1)
end

do
    local life = Life.state(camp)
    camp.hunger = 0
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 70 end
    camp.settlers.g1.mood = 50
    check("camp mood is the average", Life.mood(camp) == 68, Life.mood(camp))
    local stats = Life.stats(camp)
    check("stats agree with the module", stats.mood == Life.mood(camp) and stats.feasts == life.feasts and stats.deserted == life.deserted
        and stats.evenings == life.evenings and stats.phase == Life.phase(camp))
    check("stats are plain values", type(stats.phase) == "string" and type(stats.mood) == "number")
    check("empty camp reports neutral mood", Life.mood({ settlers = {} }) == 60)
    HOUR = 3
    check("stats phase follows the clock", Life.stats(camp).phase == "night")
    HOUR = 12
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 60 end
    tick(1, 12)
end

do
    local life = Life.state(camp)
    local tab = Hooks.tab("life")
    camp.hunger = 3
    camp.stock.food = 100000
    Life.drop(camp)
    for _ = 1, 3 do tick(1, 12) end
    local lines = Hooks.tabLines(tab, camp)
    check("life tab is filled", #lines >= 7, #lines)
    local titled = false
    for _, row in ipairs(lines) do
        if row.text == UIJSON.UI_ALC_LfSecLife then titled = true end
    end
    check("section title is shown", titled)
    check("mood line", hasLine(lines, "LfLineMood") ~= nil)
    check("phase line", hasLine(lines, "LfLinePhase") ~= nil)
    check("next tradition line", hasLine(lines, "LfLineAnniv") ~= nil)
    check("counters line", hasLine(lines, "LfLineStats") ~= nil)
    check("worst factor is named", hasLine(lines, "LfLineWorst") ~= nil and string.find(hasLine(lines, "LfLineWorst").text, UIJSON.UI_ALC_LfFactor_food, 1, true) ~= nil)
    check("best factor is named", hasLine(lines, "LfLineBest") ~= nil)
    camp.hunger = 0
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 70 end
    check("no unhappy people", hasLine(Hooks.tabLines(tab, camp), "LfLineUnhappyNone") ~= nil)
    for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = 20 end
    local unhappy = hasLine(Hooks.tabLines(tab, camp), "LfLineUnhappy")
    local _, brackets = string.gsub(unhappy.text, "%(", "")
    check("unhappy list shows five names at most", brackets == 5, brackets)
    check("unhappy list starts with the unhappiest", string.find(unhappy.text, "(20)", 1, true) ~= nil)
    life.feastDue = true
    check("feast tonight is announced", hasLine(Hooks.tabLines(tab, camp), "LfLineAnnivTonight") ~= nil)
    life.feastDue = nil
    check("days to the anniversary are counted", Life.daysToAnniversary(camp) >= 1 and Life.daysToAnniversary(camp) <= 30)
    local good = hasLine(Hooks.tabLines(tab, camp), "LfLineAnniv")
    check("anniversary line carries the number", string.find(good.text, tostring(Life.daysToAnniversary(camp)), 1, true) ~= nil)
    Options.set(camp, "rhythm", false)
    check("rhythm off is mentioned", hasLine(Hooks.tabLines(tab, camp), "LfLineRhythmOff") ~= nil)
    Options.set(camp, "rhythm", true)
    Options.set(camp, "traditions", false)
    check("traditions off is mentioned", hasLine(Hooks.tabLines(tab, camp), "LfLineTraditionsOff") ~= nil)
    Options.set(camp, "traditions", true)
    life.gather = { kind = "feast", e = Store.hours() + 1 }
    check("running gathering is shown", hasLine(Hooks.tabLines(tab, camp), "LfLineGather") ~= nil)
    life.gather = nil
    for _, key in ipairs({ "good", "fair", "poor", "low", "top" }) do
        local mood = ({ good = 70, fair = 50, poor = 30, low = 10, top = 95 })[key]
        for _, uid in ipairs(sortedUids()) do camp.settlers[uid].mood = mood end
        local overview = ownOverview(camp)
        check("overview line at mood " .. mood, #overview == 1 and string.find(overview[1].text, tostring(mood), 1, true) ~= nil)
    end
    local empty = { settlers = {}, options = {}, stats = { built = 0 }, founded = 0, id = 77, log = {} }
    check("empty camp has a single polite line", #Life.lines(empty) == 1 and #Life.overview(empty) == 0)
    Life.setMood(camp, 60)
end

do
    local life = Life.state(camp)
    check("cheats are defined", Cheats.actions.lf_party ~= nil and Cheats.actions.lf_mood ~= nil and Cheats.actions.lf_evening ~= nil)
    local listed = {}
    for _, row in ipairs(Cheats.order) do
        if row.id == "lf_party" or row.id == "lf_mood" or row.id == "lf_evening" then listed[row.id] = row.section end
    end
    check("cheats sit in the life section", listed.lf_party == "life" and listed.lf_mood == "life" and listed.lf_evening == "life")
    for _, id in ipairs({ "lf_party", "lf_mood", "lf_evening" }) do
        for _, prefix in ipairs({ "ChT_", "ChD_", "ChR_" }) do
            check("cheat text " .. prefix .. id, UIJSON["UI_ALC_" .. prefix .. id] ~= nil)
        end
    end

    life.gather = nil
    life.queue = {}
    camp.hunger = 0
    local feasts = life.feasts
    local text = Cheats.run("lf_party", PLAYER)
    check("party cheat answers", type(text) == "string" and text ~= "" and string.find(text, "UI_ALC_", 1, true) == nil and string.find(text, "8", 1, true) ~= nil, text)
    check("party starts a gathering", life.gather ~= nil and life.gather.kind == "party" and life.feasts == feasts + 1 and life.buffs.feast ~= nil)
    check("party is journaled", countLog(camp, "lf_party") == 1)
    local anchor = anchorAt("b1", 10)
    check("party calls everybody to the fire", anchor ~= nil and cheb(anchor, FIRE) <= 3)
    life.gather = nil

    Life.setMood(camp, 20)
    text = Cheats.run("lf_mood", PLAYER)
    check("mood cheat answers", type(text) == "string" and string.find(text, "UI_ALC_", 1, true) == nil, text)
    check("mood cheat gives everyone 100", Life.mood(camp) == 100)
    for _ = 1, 30 do tick(1, 12) end
    check("the cheat mood holds", Life.mood(camp) == 100)

    Life.setMood(camp, 60)
    HOUR = 12
    gatherAt(FIRE, { "b1", "b2", "s1", "s2", "f1" })
    for _, uid in ipairs({ "g1", "g2", "g3" }) do place(uid, 121, 118) end
    tick(2, 12)
    check("it is noon", Life.phase(camp) == "work")
    local evenings = life.evenings
    text = Cheats.run("lf_evening", PLAYER)
    check("evening cheat answers", type(text) == "string" and string.find(text, "30", 1, true) ~= nil, text)
    check("evening cheat forces the phase for the camp only", Life.phase(camp) == "evening" and Life.phase() == "work")
    check("evening cheat shows in stats", Life.stats(camp).phase == "evening")
    local p = anchorAt("b1", 12)
    check("evening cheat sends people to the fire", p ~= nil and cheb(p, FIRE) <= 3)
    for _ = 1, 10 do tick(1, 12) end
    check("evening cheat holds a session", life.evenings == evenings + 1)
    for _ = 1, 25 do tick(1, 12) end
    check("forced evening expires after half an hour", Life.phase(camp) == "work" and anchorAt("b1", 12) == nil)
    text = Cheats.run("lf_evening", PLAYER)
    tick(10, 12)
    check("evening cheat can be repeated", life.evenings == evenings + 2)
    life.forcedUntil = nil
    Life.drop(camp)
end

do
    local hourly = 0
    local mark = #PRINTS
    for _ = 1, 180 do tick(1, 12) end
    for index = mark + 1, #PRINTS do
        if string.find(PRINTS[index], "[ALifeCamp:Life] camp=" .. camp.id, 1, true) ~= nil then hourly = hourly + 1 end
    end
    check("one diagnostic line per game hour", hourly >= 3 and hourly <= 4, hourly)
    local sample
    for index = #PRINTS, 1, -1 do
        if string.find(PRINTS[index], "[ALifeCamp:Life]", 1, true) ~= nil then sample = PRINTS[index] break end
    end
    check("diagnostic line carries the key values", sample ~= nil and string.find(sample, "mood=", 1, true) ~= nil and string.find(sample, "people=", 1, true) ~= nil
        and string.find(sample, "phase=", 1, true) ~= nil and string.find(sample, "feasts=", 1, true) ~= nil, sample)
end

do
    local dutyPath = ROOT .. "/shared/ALifeCamp/CampDuty.lua"
    local handle = io.open(dutyPath, "r")
    local chunk, err
    if handle ~= nil then
        handle:close()
        chunk, err = loadfile(dutyPath)
        check("real Duty file compiles", chunk ~= nil, err)
    end
    if chunk ~= nil then
        chunk()
        local Duty = A.Duty
        check("real Duty is available", Duty ~= nil and Duty.ring ~= nil and Duty.mess ~= nil and Duty.campfire ~= nil and Duty.home ~= nil)
        check("stations option exists", Options.byKey.stations ~= nil and Options.on(camp, "stations"))
        project("canteen", 20, 114, 108, 6, 4)
        local canteen = { x1 = 114, y1 = 108, x2 = 119, y2 = 111 }
        local houses = { { x1 = 114, y1 = 102, x2 = 119, y2 = 106 }, { x1 = 102, y1 = 112, x2 = 105, y2 = 115 } }
        local function inside(rect, x, y) return x >= rect.x1 and x <= rect.x2 and y >= rect.y1 and y <= rect.y2 end
        local function pass(hour)
            HOUR = hour
            HOURS = HOURS + 1 / 60
            Life.drop(camp)
            camp.orderClock = 3
            fire("EveryOneMinute")
        end
        local function stationsOfKind(kind)
            local out = {}
            for _, uid in ipairs(sortedUids()) do
                local station = camp.settlers[uid].station
                if station ~= nil and station.kind == kind then out[#out + 1] = station end
            end
            return out
        end
        local function distinct(list)
            local seen = {}
            for _, station in ipairs(list) do
                local key = station.x .. ":" .. station.y
                if seen[key] then return false end
                seen[key] = true
            end
            return true
        end

        pass(19)
        local diners = stationsOfKind("mess")
        local seated = true
        for _, station in ipairs(diners) do
            if not inside(canteen, station.x, station.y) then seated = false end
        end
        check("dinner: seven diners, the rest on guard", #diners == 7, #diners)
        check("dinner: everybody sits inside the canteen", seated)
        check("dinner: on distinct tiles", distinct(diners))
        check("dinner: orders are hold orders", orders.b1.kind == "hold" and inside(canteen, orders.b1.anchor.x, orders.b1.anchor.y))
        check("dinner: guard on duty keeps the post", camp.settlers.g2.station ~= nil and camp.settlers.g2.station.kind == "post")
        local parts = Hooks.collect("settlerInfo", camp, "b1", camp.settlers.b1)
        local joined = table.concat(parts, "|")
        check("people list says where the settler is", string.find(joined, UIJSON.UI_ALC_DutyAt_mess, 1, true) ~= nil, joined)

        pass(20)
        local circle = stationsOfKind("camp")
        local ringed = true
        for _, station in ipairs(circle) do
            if cheb(station, FIRE) < 1 or cheb(station, FIRE) > 3 then ringed = false end
        end
        check("evening: people sit around the fire", #circle >= 5 and ringed, #circle)
        check("evening: on distinct tiles", distinct(circle))

        pass(6)
        local lineup = stationsOfKind("muster")
        local lined = true
        for _, station in ipairs(lineup) do
            if cheb(station, CENTER) < 1 or cheb(station, CENTER) > 3 then lined = false end
        end
        check("morning: line-up around the centre", #lineup >= 5 and lined and distinct(lineup), #lineup)

        pass(7)
        check("breakfast in the canteen", #stationsOfKind("mess") >= 5)

        pass(23)
        local sleepers = stationsOfKind("home")
        local housed = true
        for _, station in ipairs(sleepers) do
            if not inside(houses[1], station.x, station.y) and not inside(houses[2], station.x, station.y) then housed = false end
        end
        check("night: six sleepers go home", #sleepers == 6, #sleepers)
        check("night: they are inside the houses", housed)
        check("night: on distinct tiles", distinct(sleepers))
        local before = {}
        for _, uid in ipairs(sortedUids()) do
            local station = camp.settlers[uid].station
            before[uid] = station and (station.x .. ":" .. station.y) or ""
        end
        pass(23)
        local stable = true
        for _, uid in ipairs(sortedUids()) do
            local station = camp.settlers[uid].station
            if (station and (station.x .. ":" .. station.y) or "") ~= before[uid] then stable = false end
        end
        check("night: beds stay the same", stable)
        local watch = nightWatch()
        local posted = true
        for uid in pairs(watch) do
            local station = camp.settlers[uid].station
            if station == nil or station.kind == "home" then posted = false end
        end
        check("night: the watch is not sent to bed", posted)

        pass(10)
        local leftover = #stationsOfKind("mess") + #stationsOfKind("muster") + #stationsOfKind("home") + #stationsOfKind("rest")
        local anchored = 0
        for _, uid in ipairs(sortedUids()) do
            if Hooks.first("anchor", camp, uid, camp.settlers[uid], { x = 1, y = 1, z = 0 }) ~= nil then anchored = anchored + 1 end
        end
        check("work hours belong to the stations", anchored == 0 and leftover <= 1 and #stationsOfKind("camp") <= 1, anchored .. "/" .. leftover)

        Options.set(camp, "stations", false)
        pass(20)
        check("stations off: the core falls back to patrol orders", orders.b1.kind == "patrol")
        Options.set(camp, "stations", true)

        fireProject.status = "planned"
        pass(20)
        local campfires = stationsOfKind("camp")
        local fallback = true
        for _, station in ipairs(campfires) do
            if cheb(station, CENTER) > 3 then fallback = false end
        end
        check("no campfire: the evening goes on at the camp centre", #campfires >= 5 and fallback, #campfires)
        fireProject.status = "done"
        Build.plan(camp).items["20"] = nil
        camp.phase = "build"
    end
end

do
    local problems = {}
    local function plain(value, path, stack)
        local kind = type(value)
        if kind == "function" or kind == "userdata" or kind == "thread" then
            problems[#problems + 1] = path .. ":" .. kind
            return
        end
        if kind == "number" and value ~= value then problems[#problems + 1] = path .. ":nan" end
        if kind ~= "table" then return end
        if stack[value] then
            problems[#problems + 1] = path .. ":cycle"
            return
        end
        stack[value] = true
        local numeric, maxIndex = 0, 0
        for key, inner in pairs(value) do
            if type(key) == "number" then
                numeric = numeric + 1
                maxIndex = math.max(maxIndex, key)
            elseif type(key) ~= "string" then
                problems[#problems + 1] = path .. ":key"
            end
            plain(inner, path .. "." .. tostring(key), stack)
        end
        if numeric > 0 and (numeric ~= maxIndex or #value ~= numeric) then problems[#problems + 1] = path .. ":holes" end
        stack[value] = nil
    end
    local life = Life.state(camp)
    life.gather = { kind = "feast", e = Store.hours() + 1 }
    life.queue = { { k = "memorial", name = "A" }, { k = "victory" } }
    life.deaths = { Store.hours() }
    plain(camp.life, "life", {})
    for uid, settler in pairs(camp.settlers) do plain(settler, "settler " .. uid, {}) end
    check("state is plain data", #problems == 0, table.concat(problems, ";"))
    local keys = 0
    for _ in pairs(camp.life) do keys = keys + 1 end
    check("camp state stays small", keys <= 30, keys)
    local small = true
    for _, settler in pairs(camp.settlers) do
        local n = 0
        for _ in pairs(settler.lf) do n = n + 1 end
        if n > 6 then small = false end
    end
    check("settler state stays small", small)
    check("state survives a copy", (function()
        local function copy(value)
            if type(value) ~= "table" then return value end
            local out = {}
            for key, inner in pairs(value) do out[key] = copy(inner) end
            return out
        end
        local clone = copy(camp.life)
        camp.life = clone
        Life.drop(camp)
        tick(2, 12)
        local anchorOk = anchorAt("b1", 20) ~= nil
        return anchorOk and Life.stats(camp).evenings == clone.evenings
    end)())
    life = Life.state(camp)
    life.gather = nil
    life.queue = {}
end

do
    local keys = {}
    for _, key in ipairs(Life.barkKeys) do keys[#keys + 1] = key end
    for _, trait in ipairs(Life.traits) do keys[#keys + 1] = "LfTrait_" .. trait end
    for index = 1, 5 do keys[#keys + 1] = "LfMood_" .. index end
    for _, phase in ipairs({ "morning", "work", "lunch", "evening", "night" }) do keys[#keys + 1] = "LfPhase_" .. phase end
    for _, kind in ipairs({ "feast", "party", "victory", "memorial" }) do keys[#keys + 1] = "LfGather_" .. kind end
    for _, factor in ipairs(Life.factorOrder) do keys[#keys + 1] = "LfFactor_" .. factor end
    for _, key in ipairs({ "rhythm", "traditions", "desertion" }) do
        keys[#keys + 1] = "Opt_" .. key
        keys[#keys + 1] = "OptHint_" .. key
    end
    for _, key in ipairs({ "evening", "left", "digest", "grumble", "feast", "anniv", "victory", "memorial", "party" }) do keys[#keys + 1] = "Log_lf_" .. key end
    for _, key in ipairs({ "LfFeast", "LfAnnivPoor", "LfVictory", "LfMemorial", "LfLeft", "LfSecLife", "LfOverview", "LfInfo", "LfDigestTail" }) do keys[#keys + 1] = key end
    local missing = {}
    for _, key in ipairs(keys) do
        local text = A.T(key, "Aa", "Bb", "Cc")
        if string.sub(text, 1, 7) == "UI_ALC_" or string.find(text, "%%%d") then missing[#missing + 1] = key end
    end
    check("all texts exist and take their arguments", #missing == 0, table.concat(missing, ","))
    local barkLong = {}
    for _, key in ipairs(Life.barkKeys) do
        local letters = 0
        local text = UIJSON["UI_ALC_" .. key]
        for i = 1, #text do
            local byte = string.byte(text, i)
            if byte < 128 or byte >= 192 then letters = letters + 1 end
        end
        if letters > 70 then barkLong[#barkLong + 1] = key end
    end
    check("barks are short enough for a speech bubble", #barkLong == 0, table.concat(barkLong, ","))
    check("at least twenty barks", #Life.barkKeys >= 20, #Life.barkKeys)
    local rows = {}
    for _, key in ipairs({ "lf_evening", "lf_left", "lf_digest", "lf_grumble", "lf_feast", "lf_anniv", "lf_victory", "lf_memorial", "lf_party" }) do
        rows[#rows + 1] = { h = HOURS, k = key, a = "X", b = "Y" }
    end
    local saved = camp.log
    camp.log = rows
    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    local lines = win:logLines(camp)
    camp.log = saved
    local bad = 0
    for _, row in ipairs(lines) do
        if string.find(row.text, "UI_ALC_", 1, true) ~= nil then bad = bad + 1 end
    end
    check("every journal entry has a text", #lines == #rows and bad == 0, bad)

    local source = io.open(ROOT .. "/shared/ALifeCamp/CampLife.lua", "r")
    if source ~= nil then
        local body = source:read("*a")
        source:close()
        local absent = {}
        for key in string.gmatch(body, '"(Lf[%w_]+)"') do
            if string.sub(key, -1) ~= "_" and UIJSON["UI_ALC_" .. key] == nil then absent[#absent + 1] = key end
        end
        for key in string.gmatch(body, 'Store%.log%(camp, "(lf_[%w_]+)"') do
            if UIJSON["UI_ALC_Log_" .. key] == nil then absent[#absent + 1] = key end
        end
        check("every text key written in the module exists", #absent == 0, table.concat(absent, ","))
        local seen = 0
        for _ in string.gmatch(body, '"(Lf[%w_]+)"') do seen = seen + 1 end
        check("the key scan really saw the module", seen > 80, seen)
    end
end

local missing = {}
for key in pairs(MISSING) do missing[#missing + 1] = key end
table.sort(missing)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missing }
