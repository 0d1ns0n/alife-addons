require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampLand"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampGates"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampDistricts"
require "ALifeCamp/CampSkills"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Settlers = ALifeCamp.Settlers
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local Land = ALifeCamp.Land
local Place = ALifeCamp.Place
local Gates = ALifeCamp.Gates
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local T = ALifeCamp.T

local Sanitary = {}
ALifeCamp.Sanitary = Sanitary

local CEM = "location_community_cemetary_01"

Sanitary.ringValues = { 0, 10, 25, 50 }
Sanitary.pointLimit = 20
Sanitary.scanBudget = 160
Sanitary.levels = 3
Sanitary.nearRange = 4
Sanitary.waitMinutes = 8
Sanitary.rate = 1.2
Sanitary.bankCap = 8
Sanitary.actionsPerMinute = 6
Sanitary.helperWeight = 0.3
Sanitary.helperCount = 2
Sanitary.surgeHours = 2
Sanitary.unseenMinutes = 45
Sanitary.failLimit = 3
Sanitary.muteHours = 12
Sanitary.muteKeep = 40
Sanitary.cost = { body = 3, comrade = 4, blood = 1, grave = 3 }
Sanitary.weights = { bodyIn = 7, bodyOut = 2.5, bloodIn = 1.5, bloodOut = 0.5 }
Sanitary.tidyCap = 10
Sanitary.tidyDecay = 1.5
Sanitary.graveCap = 40
Sanitary.fallenKeep = 40
Sanitary.deadKeep = 30
Sanitary.graceMinutes = 3
Sanitary.bodyMinutes = 60
Sanitary.unloadedMinutes = 120
Sanitary.deadHours = 72
Sanitary.jobHours = 12
Sanitary.jobLimit = 6
Sanitary.shareBase = 0.12
Sanitary.shareHeavy = 0.25
Sanitary.heavyCorpses = 15
Sanitary.minPeople = 4
Sanitary.margin = 5
Sanitary.towerZone = 4
Sanitary.gateZone = { -6, -1, 6, 11 }
Sanitary.searchRadius = 8
Sanitary.searchLimit = 300
Sanitary.retryHours = 1
Sanitary.forceHours = 1 / 12
Sanitary.filthBelow = 25
Sanitary.freshAbove = 60
Sanitary.dirtyBelow = 40
Sanitary.skillXp = 1.5
Sanitary.logEvery = 10
Sanitary.speech = 25
Sanitary.focusRows = 8
Sanitary.politeRange = 2.5

Sanitary.sprites = {
    pitWest = CEM .. "_40",
    pitEast = CEM .. "_41",
    cross = { CEM .. "_22", CEM .. "_23" },
    stone = { CEM .. "_1", CEM .. "_3", CEM .. "_5", CEM .. "_9" },
    cairn = CEM .. "_30",
    angel = CEM .. "_11",
    lane = { "blends_natural_01_96", "blends_natural_01_101" },
    flowers = {
        "vegetation_ornamental_01_16", "vegetation_ornamental_01_17", "vegetation_ornamental_01_18",
        "vegetation_ornamental_01_19", "vegetation_ornamental_01_20", "vegetation_ornamental_01_21",
    },
}

Sanitary.defaults = {
    cursor = 0, passes = 0, sig = "", serial = 0, slot = 1, laneDone = 0,
    removed = 0, washed = 0, buried = 0, graves = 0, markers = 0, mass = 0, lost = 0, memorials = 0,
    bank = 0, tidy = 0, score = 100, stamp = -1, surge = 0, power = 0, tryAt = -100, plotScan = -1,
    traceHour = -1, monument = false, flowers = false, filthy = false,
}

Sanitary.lists = { "points", "jobs", "fallen", "dead", "mute" }

Bp.kinds.cemetery = {
    w = 7, h = 5, priority = 10.5,
    build = function(project) return { { id = "pave", ops = {} } } end,
}

local Districts = ALifeCamp.Districts
if Districts ~= nil and type(Districts.colors) == "table" then
    Districts.colors.cemetery = { r = 0.66, g = 0.7, b = 0.82, 0.66, 0.7, 0.82 }
end

local knownSprites = {}
local faults = {}

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function planar(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

local function enabled(camp)
    return camp ~= nil and Options.on(camp, "sanitation")
end

local function hash(x, y, salt)
    return (math.abs(x) * 73856093 + math.abs(y) * 19349663 + (salt or 0) * 83492791) % 2147483647
end

local function pick(list, x, y, salt)
    return list[hash(x, y, salt) % #list + 1]
end

local function spriteKnown(name)
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local function inspect(square)
    local count, blood = 0, false
    pcall(function()
        local bodies = square:getDeadBodys()
        if bodies ~= nil then count = bodies:size() end
        blood = square:haveBlood() == true
    end)
    return count, blood
end

local function bodiesOf(square)
    local list = {}
    pcall(function()
        local bodies = square:getDeadBodys()
        if bodies == nil then return end
        for i = 0, bodies:size() - 1 do list[#list + 1] = bodies:get(i) end
    end)
    return list
end

local function bloodOn(square)
    local blood = false
    pcall(function() blood = square:haveBlood() == true end)
    return blood
end

local function removeBody(square, body)
    return pcall(function() square:removeCorpse(body, false) end)
end

local function washBlood(square)
    local ok = pcall(function() square:removeBlood(false, false) end)
    if not ok then return false end
    return not bloodOn(square)
end

local function dataOf(body)
    local data
    pcall(function() data = body:getModData() end)
    if type(data) ~= "table" then return nil end
    return data
end

local function uidOf(data)
    local uid = data.ProjectALifeCorpseOf
    if type(uid) ~= "string" then uid = data.ProjectALifeUID end
    if type(uid) ~= "string" or uid == "" then return nil end
    return uid
end

local function descriptorName(body)
    local name
    pcall(function()
        local descriptor = body:getDescriptor()
        if descriptor == nil then return end
        local forename, surname = descriptor:getForename(), descriptor:getSurname()
        if forename ~= nil and forename ~= "" then name = forename end
        if name ~= nil and surname ~= nil and surname ~= "" then name = name .. " " .. surname end
    end)
    return name
end

local function profileName(uid)
    local record = Settlers.record(uid)
    if record == nil then return nil end
    local name
    pcall(function()
        local profile = ProjectALife.Catalog.npc(record.profileId)
        name = profile and profile.general and profile.general.name
    end)
    if name == nil then return nil end
    return tostring(name)
end

local function notify(camp, key, a)
    local work = ALifeCamp.Work
    if work == nil or type(work.notify) ~= "function" then return end
    pcall(work.notify, camp, key, a)
end

local function fenceOf(camp)
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "fence" and not project.retired then return project end
    end
    return nil
end

local function byUid(a, b)
    return a.uid < b.uid
end

function Sanitary.state(camp)
    local state = camp.sanitary
    if type(state) == "table" and state.ready == true then return state end
    if type(state) ~= "table" then
        state = {}
        camp.sanitary = state
    end
    for key, value in pairs(Sanitary.defaults) do
        if state[key] == nil then state[key] = value end
    end
    for _, key in ipairs(Sanitary.lists) do
        if type(state[key]) ~= "table" then state[key] = {} end
    end
    state.ready = true
    return state
end

function Sanitary.surging(state)
    return Store.hours() < (state.surge or 0)
end

function Sanitary.ring(camp)
    return math.max(0, math.floor(Options.number(camp, "sanitaryRing")))
end

function Sanitary.zone(camp)
    local ring = Sanitary.ring(camp)
    local x1, y1, x2, y2 = camp.x1 - ring, camp.y1 - ring, camp.x2 + ring, camp.y2 + ring
    return {
        x1 = x1, y1 = y1, x2 = x2, y2 = y2, w = x2 - x1 + 1, h = y2 - y1 + 1, ring = ring,
        sig = x1 .. "," .. y1 .. "," .. x2 .. "," .. y2,
    }
end

function Sanitary.where(uid)
    local x, y, _, loaded = Settlers.where(uid)
    return x, y, loaded
end

function Sanitary.tidy(state, amount)
    state.tidy = math.min(Sanitary.tidyCap, (state.tidy or 0) + amount)
end

function Sanitary.muted(state, key)
    local untilAt = state.mute[key]
    return untilAt ~= nil and Store.hours() < untilAt
end

function Sanitary.silence(state, key)
    local now = Store.hours()
    state.mute[key] = now + Sanitary.muteHours
    local count = 0
    for _ in pairs(state.mute) do count = count + 1 end
    if count <= Sanitary.muteKeep then return end
    local stale = {}
    for name, untilAt in pairs(state.mute) do
        if untilAt <= now then stale[#stale + 1] = name end
    end
    for _, name in ipairs(stale) do state.mute[name] = nil end
end

function Sanitary.note(camp, state, x, y, z, count, blood)
    local key = x .. ":" .. y .. ":" .. z
    if Sanitary.muted(state, key) then return false end
    for _, point in ipairs(state.points) do
        if point.key == key then
            point.c, point.b = count, blood and 1 or 0
            return true
        end
    end
    if #state.points >= Sanitary.pointLimit then return false end
    state.points[#state.points + 1] = {
        key = key, x = x, y = y, z = z, c = count, b = blood and 1 or 0,
        at = Store.hours(), w = 0, f = 0, m = 0,
    }
    return true
end

function Sanitary.rezone(camp, state, zone)
    state.sig = zone.sig
    state.cursor = 0
    local keep = {}
    for _, point in ipairs(state.points) do
        if point.x >= zone.x1 and point.x <= zone.x2 and point.y >= zone.y1 and point.y <= zone.y2 then
            keep[#keep + 1] = point
        end
    end
    state.points = keep
end

function Sanitary.probe(camp, state, x, y)
    local top = 0
    if Geo.contains(camp, x, y) then top = Sanitary.levels - 1 end
    local spent = 0
    for dz = 0, top do
        local z = camp.z + dz
        local square = World.square(x, y, z)
        if square == nil then
            spent = spent + 0.5
        else
            spent = spent + 1
            local count, blood = inspect(square)
            if count > 0 or blood then Sanitary.note(camp, state, x, y, z, count, blood) end
        end
    end
    return spent
end

function Sanitary.scan(camp, state, minutes)
    if Store.settlerCount(camp) <= 0 then return 0 end
    local zone = Sanitary.zone(camp)
    if state.sig ~= zone.sig then Sanitary.rezone(camp, state, zone) end
    local total = zone.w * zone.h
    local budget = Sanitary.scanBudget * clamp(minutes, 1, 4)
    local spent = 0
    while spent < budget and #state.points < Sanitary.pointLimit do
        local index = state.cursor
        if index >= total then index = 0 end
        local x = zone.x1 + index % zone.w
        local y = zone.y1 + math.floor(index / zone.w)
        spent = spent + Sanitary.probe(camp, state, x, y)
        index = index + 1
        if index >= total then
            state.cursor = 0
            state.passes = state.passes + 1
            break
        end
        state.cursor = index
    end
    return spent
end

function Sanitary.verify(camp, state, minutes)
    local keep = {}
    for _, point in ipairs(state.points) do
        local square = World.square(point.x, point.y, point.z)
        if square == nil then
            point.m = (point.m or 0) + minutes
            if point.m < Sanitary.unseenMinutes then keep[#keep + 1] = point end
        else
            point.m = 0
            local count, blood = inspect(square)
            if (count > 0 or blood) and not Sanitary.muted(state, point.key) then
                point.c, point.b = count, blood and 1 or 0
                keep[#keep + 1] = point
            end
        end
    end
    state.points = keep
end

function Sanitary.known(camp, state)
    local inside = { c = 0, b = 0 }
    local outside = { c = 0, b = 0 }
    for _, point in ipairs(state.points) do
        local part = Geo.contains(camp, point.x, point.y) and inside or outside
        part.c = part.c + (point.c or 0)
        part.b = part.b + (point.b or 0)
    end
    return inside, outside
end

function Sanitary.corpseCount(camp, state)
    local inside, outside = Sanitary.known(camp, state)
    return inside.c + outside.c
end

function Sanitary.friendly(uid)
    local record = Settlers.record(uid)
    if record == nil then return false end
    local player
    pcall(function() player = getPlayer() end)
    return Settlers.stance(record, player) == "friendly"
end

function Sanitary.recorded(state, uid)
    if uid == nil then return false end
    for _, entry in ipairs(state.fallen) do
        if entry.uid == uid then return true end
    end
    return false
end

function Sanitary.queued(state, uid)
    if uid == nil then return false end
    for _, job in ipairs(state.jobs) do
        if job.uid == uid then return true end
    end
    return false
end

function Sanitary.identify(camp, body)
    local data = dataOf(body)
    if data == nil then return nil end
    local uid = uidOf(data)
    if uid ~= nil then
        local member = camp.settlers[uid]
        if member ~= nil then return { uid = uid, name = tostring(member.name or uid), member = true } end
        local dead = Sanitary.state(camp).dead[uid]
        if dead ~= nil then return { uid = uid, name = tostring(dead.name or uid), member = true, day = dead.day } end
    end
    if data.ALCcomrade == true then
        local name = type(data.ALCname) == "string" and data.ALCname or descriptorName(body) or T("SanNameless")
        return { uid = uid, name = name, member = data.ALCally ~= true }
    end
    if uid ~= nil and Sanitary.friendly(uid) then
        return { uid = uid, name = descriptorName(body) or profileName(uid) or T("SanNameless"), member = false }
    end
    return nil
end

function Sanitary.skillFactor(member)
    local skills = ALifeCamp.Skills
    if skills == nil then return 1 end
    local level = 0
    pcall(function() level = skills.level(member.settler, "clean") end)
    return 1 + (skills.perLevel or 0.06) * level
end

function Sanitary.crew(camp)
    local sanitary, helpers, people = {}, {}, 0
    for uid, settler in pairs(camp.settlers) do
        people = people + 1
        local role = settler.role or "worker"
        if role == "sanitary" then
            sanitary[#sanitary + 1] = { uid = uid, settler = settler, base = 1 }
        elseif role == "worker" or role == "scavenger" then
            helpers[#helpers + 1] = { uid = uid, settler = settler, base = Sanitary.helperWeight }
        end
    end
    table.sort(sanitary, byUid)
    table.sort(helpers, byUid)
    local crew = { list = {}, weight = 0, virtual = false, people = people, sanitary = #sanitary }
    if #sanitary > 0 then
        crew.list = sanitary
    elseif people >= 2 then
        for index = 1, math.min(Sanitary.helperCount, #helpers) do crew.list[#crew.list + 1] = helpers[index] end
        if #crew.list == 0 then
            crew.virtual = true
            crew.weight = Sanitary.helperWeight
        end
    end
    for _, member in ipairs(crew.list) do
        member.w = member.base * Sanitary.skillFactor(member)
        crew.weight = crew.weight + member.w
    end
    return crew
end

function Sanitary.multiplier(camp, state)
    local value = 1
    local progress = ALifeCamp.Progress
    if progress ~= nil and type(progress.bonus) == "function" then
        local ok, bonus = pcall(progress.bonus, camp, "clean")
        if ok and type(bonus) == "number" and bonus > 0 then value = value * bonus end
    end
    if Sanitary.surging(state) then value = value * 2 end
    return value
end

function Sanitary.tasks(state)
    local list = {}
    for _, job in ipairs(state.jobs) do
        if job.x ~= nil then
            list[#list + 1] = { key = "j" .. tostring(job.id), job = true, ref = job, x = job.x, y = job.y, z = job.z }
        end
    end
    for _, point in ipairs(state.points) do
        list[#list + 1] = { key = "p" .. point.key, ref = point, x = point.x, y = point.y, z = point.z }
    end
    return list
end

function Sanitary.assign(camp, crew, tasks)
    local taken, order = {}, {}
    local cx, cy = Geo.center(camp)
    for _, member in ipairs(crew.list) do
        local settler = member.settler
        local previous = type(settler.san) == "table" and settler.san.k or nil
        local chosen
        if previous ~= nil then
            for _, task in ipairs(tasks) do
                if task.key == previous and taken[task.key] == nil then
                    chosen = task
                    break
                end
            end
        end
        if chosen == nil then
            local px, py = Sanitary.where(member.uid)
            if px == nil then px, py = cx, cy end
            local best
            for _, task in ipairs(tasks) do
                if taken[task.key] == nil then
                    local score = planar(px, py, task.x + 0.5, task.y + 0.5)
                    if task.job then
                        score = score - 1000000000
                        if task.ref.by == member.uid then score = score - 1000000000 end
                    end
                    if best == nil or score < best then chosen, best = task, score end
                end
            end
        end
        if chosen ~= nil then
            taken[chosen.key] = member
            settler.san = { k = chosen.key, x = chosen.x, y = chosen.y }
            order[#order + 1] = { task = chosen, member = member }
        else
            settler.san = nil
        end
    end
    if #crew.list == 0 and crew.virtual and tasks[1] ~= nil then
        order[#order + 1] = { task = tasks[1], member = nil }
    end
    return order
end

function Sanitary.release(camp, crew)
    local active = {}
    for _, member in ipairs(crew.list) do active[member.uid] = true end
    for uid, settler in pairs(camp.settlers) do
        if settler.san ~= nil and not active[uid] then settler.san = nil end
    end
end

function Sanitary.say(member, key)
    if member == nil then return end
    pcall(function() Settlers.say(Settlers.shell(member.uid), key) end)
end

function Sanitary.train(camp, member, cost)
    if member == nil then return end
    local skills = ALifeCamp.Skills
    if skills == nil then return end
    pcall(skills.gain, camp, member.uid, "clean", cost * Sanitary.skillXp)
end

function Sanitary.countBody(camp, state, member)
    state.removed = state.removed + 1
    Sanitary.tidy(state, 1.5)
    if state.removed % Sanitary.logEvery == 0 then Store.log(camp, "san_cleaned", state.removed) end
    if member ~= nil and Hooks.rand(100) <= Sanitary.speech then
        Sanitary.say(member, "SanSayBody" .. Hooks.rand(3))
    end
end

function Sanitary.cleanSquare(camp, state, square, opts)
    local result = { bodies = 0, comrades = 0, washed = 0, spent = 0, left = 0, failed = 0 }
    local bank = opts.bank
    local member = opts.member
    local function affordable(cost)
        return bank == nil or bank - result.spent >= cost
    end
    for _, body in ipairs(bodiesOf(square)) do
        local info = Sanitary.identify(camp, body)
        local cost = info ~= nil and Sanitary.cost.comrade or Sanitary.cost.body
        if not affordable(cost) then
            result.left = result.left + 1
        elseif not removeBody(square, body) then
            result.failed = result.failed + 1
            result.left = result.left + 1
        else
            result.spent = result.spent + cost
            Sanitary.train(camp, member, cost)
            if info ~= nil then
                result.comrades = result.comrades + 1
                Sanitary.arrange(camp, info, opts)
            else
                result.bodies = result.bodies + 1
                Sanitary.countBody(camp, state, member)
            end
        end
    end
    if bloodOn(square) then
        if not affordable(Sanitary.cost.blood) then
            result.left = result.left + 1
        elseif not washBlood(square) then
            result.failed = result.failed + 1
            result.left = result.left + 1
        else
            result.spent = result.spent + Sanitary.cost.blood
            result.washed = result.washed + 1
            state.washed = state.washed + 1
            Sanitary.tidy(state, 0.4)
            Sanitary.train(camp, member, Sanitary.cost.blood)
            if member ~= nil and Hooks.rand(100) <= Sanitary.speech / 2 then Sanitary.say(member, "SanSayBlood" .. Hooks.rand(2)) end
        end
    end
    return result
end

function Sanitary.clean(camp, state, point, member)
    local square = World.square(point.x, point.y, point.z)
    if square == nil then return false end
    local result = Sanitary.cleanSquare(camp, state, square, { bank = state.bank, member = member })
    state.bank = math.max(0, state.bank - result.spent)
    if result.failed > 0 then point.f = (point.f or 0) + 1 end
    if result.left == 0 then
        point.done = true
    elseif (point.f or 0) >= Sanitary.failLimit then
        point.done = true
        Sanitary.silence(state, point.key)
    end
    point.w = 0
    return result.spent > 0
end

function Sanitary.deliver(camp, state, job, member)
    local expired = Store.hours() - (job.at or 0) >= Sanitary.jobHours
    if state.bank < Sanitary.cost.grave and not expired then return false end
    local kind = Sanitary.finishJob(camp, state, job, member, expired)
    if kind == nil then return false end
    state.bank = math.max(0, state.bank - Sanitary.cost.grave)
    job.done = true
    return true
end

function Sanitary.playerNear(task)
    local near = false
    pcall(function()
        local player = getPlayer()
        if player == nil then return end
        local range = Sanitary.politeRange
        near = planar(player:getX(), player:getY(), task.x + 0.5, task.y + 0.5) < range * range
    end)
    return near
end

function Sanitary.attend(camp, state, task, member, minutes)
    local ref = task.ref
    if not task.job and Sanitary.playerNear(task) then return false end
    local near = false
    if member ~= nil then
        local px, py = Sanitary.where(member.uid)
        if px ~= nil then
            near = planar(px, py, task.x + 0.5, task.y + 0.5) <= Sanitary.nearRange * Sanitary.nearRange
        end
    end
    if not near then
        ref.w = (ref.w or 0) + minutes
        if ref.w < Sanitary.waitMinutes then return false end
    end
    if task.job then return Sanitary.deliver(camp, state, ref, member) end
    return Sanitary.clean(camp, state, ref, member)
end

local function pruneDone(list)
    local keep = {}
    for _, item in ipairs(list) do
        if item.done ~= true then keep[#keep + 1] = item end
    end
    return keep
end

function Sanitary.work(camp, state, minutes)
    if camp.raid ~= nil then return 0 end
    local crew = Sanitary.crew(camp)
    state.power = crew.weight
    Sanitary.release(camp, crew)
    local tasks = Sanitary.tasks(state)
    if #tasks == 0 or crew.weight <= 0 then
        for _, member in ipairs(crew.list) do member.settler.san = nil end
        return 0
    end
    local budget = Sanitary.rate * crew.weight * Sanitary.multiplier(camp, state) * minutes
    state.bank = math.min(Sanitary.bankCap, state.bank + budget)
    local done = 0
    for _, entry in ipairs(Sanitary.assign(camp, crew, tasks)) do
        if done < Sanitary.actionsPerMinute and Sanitary.attend(camp, state, entry.task, entry.member, minutes) then
            done = done + 1
        end
    end
    state.points = pruneDone(state.points)
    state.jobs = pruneDone(state.jobs)
    return done
end

function Sanitary.layout(w, h)
    local cx = math.floor(w / 2)
    local slots = {}
    local dy = 2
    while dy <= h - 1 do
        local k = 0
        while true do
            local left = cx - 2 - 2 * k
            local right = cx + 1 + 2 * k
            local leftOk = left >= 0
            local rightOk = right + 1 <= w - 1
            if not leftOk and not rightOk then break end
            if leftOk then slots[#slots + 1] = { dx = left, dy = dy } end
            if rightOk then slots[#slots + 1] = { dx = right, dy = dy } end
            k = k + 1
        end
        dy = dy + 2
    end
    return { cx = cx, slots = slots }
end

function Sanitary.plot(camp)
    local state = Sanitary.state(camp)
    local items = Build.plan(camp).items
    if state.plotId ~= nil then
        local project = items[tostring(state.plotId)]
        if project ~= nil and project.kind == "cemetery" and not project.retired then return project end
        state.plotId = nil
    end
    local stamp = math.floor(Store.hours() * 60)
    if state.plotScan == stamp then return nil end
    state.plotScan = stamp
    for _, project in pairs(items) do
        if project.kind == "cemetery" and not project.retired then
            state.plotId = project.id
            return project
        end
    end
    return nil
end

function Sanitary.capacity(camp)
    local plot = Sanitary.plot(camp)
    if plot == nil then return 0, 0 end
    local total = #Sanitary.layout(plot.w, plot.h).slots
    local state = Sanitary.state(camp)
    return total, math.max(0, total - (state.slot - 1))
end

function Sanitary.sizes(camp)
    local area = Geo.area(camp)
    if area >= 10000 then return { { 17, 11 }, { 13, 9 }, { 9, 9 }, { 9, 7 }, { 7, 5 } } end
    if area >= 4000 then return { { 13, 9 }, { 9, 9 }, { 9, 7 }, { 7, 5 } } end
    if area >= 1500 then return { { 9, 9 }, { 9, 7 }, { 7, 5 }, { 5, 4 } } end
    if area >= 600 then return { { 9, 7 }, { 7, 5 }, { 5, 4 } } end
    return { { 7, 5 }, { 5, 4 }, { 5, 3 } }
end

function Sanitary.keepOut(camp, gates)
    local out = {}
    local zone = Sanitary.gateZone
    for _, geo in ipairs(gates) do
        local x, y, w, h = Gates.rect(geo, zone[1], zone[2], zone[3], zone[4])
        out[#out + 1] = { x1 = x, y1 = y, x2 = x + w - 1, y2 = y + h - 1 }
    end
    local t = Sanitary.towerZone
    out[#out + 1] = { x1 = camp.x1, y1 = camp.y1, x2 = camp.x1 + t, y2 = camp.y1 + t }
    out[#out + 1] = { x1 = camp.x2 - t, y1 = camp.y1, x2 = camp.x2, y2 = camp.y1 + t }
    out[#out + 1] = { x1 = camp.x1, y1 = camp.y2 - t, x2 = camp.x1 + t, y2 = camp.y2 }
    out[#out + 1] = { x1 = camp.x2 - t, y1 = camp.y2 - t, x2 = camp.x2, y2 = camp.y2 }
    return out
end

function Sanitary.rectOk(camp, x, y, w, h, zones)
    local x2, y2 = x + w - 1, y + h - 1
    if x < camp.x1 or y < camp.y1 or x2 > camp.x2 or y2 > camp.y2 then return false end
    for _, zone in ipairs(zones) do
        if x <= zone.x2 and x2 >= zone.x1 and y <= zone.y2 and y2 >= zone.y1 then return false end
    end
    return Build.fits(camp, "cemetery", x, y, w, h) == true
end

function Sanitary.anchors(camp, w, h, gates)
    local m = Sanitary.margin
    local cx, cy = Geo.center(camp)
    local gx, gy = cx, camp.y2
    if gates[1] ~= nil then gx, gy = gates[1].x, gates[1].y end
    local list = {
        { x = camp.x1 + m, y = camp.y1 + m },
        { x = camp.x2 - m - w + 1, y = camp.y1 + m },
        { x = camp.x1 + m, y = camp.y2 - m - h + 1 },
        { x = camp.x2 - m - w + 1, y = camp.y2 - m - h + 1 },
        { x = cx - math.floor(w / 2), y = camp.y1 + 3 },
        { x = cx - math.floor(w / 2), y = camp.y2 - 3 - h + 1 },
        { x = camp.x1 + 3, y = cy - math.floor(h / 2) },
        { x = camp.x2 - 3 - w + 1, y = cy - math.floor(h / 2) },
    }
    for index, anchor in ipairs(list) do
        anchor.rank = index
        anchor.far = planar(anchor.x + w / 2, anchor.y + h / 2, gx, gy)
    end
    table.sort(list, function(a, b)
        if a.far ~= b.far then return a.far > b.far end
        return a.rank < b.rank
    end)
    return list
end

function Sanitary.locate(camp, w, h, budget)
    local gates = {}
    pcall(function() gates = Gates.list(camp) end)
    local zones = Sanitary.keepOut(camp, gates)
    for _, anchor in ipairs(Sanitary.anchors(camp, w, h, gates)) do
        for r = 0, Sanitary.searchRadius do
            for dx = -r, r do
                for dy = -r, r do
                    if r == 0 or math.abs(dx) == r or math.abs(dy) == r then
                        if budget.left <= 0 then return nil end
                        budget.left = budget.left - 1
                        local x, y = anchor.x + dx, anchor.y + dy
                        if Sanitary.rectOk(camp, x, y, w, h, zones) then return x, y end
                    end
                end
            end
        end
    end
    return nil
end

function Sanitary.place(camp, state)
    local rect = state.rect
    if type(rect) == "table" then
        local project = Build.add(camp, "cemetery", rect.x, rect.y, { w = rect.w, h = rect.h })
        if project ~= nil then return project end
    end
    local budget = { left = Sanitary.searchLimit }
    for _, size in ipairs(Sanitary.sizes(camp)) do
        local x, y = Sanitary.locate(camp, size[1], size[2], budget)
        if x ~= nil then
            local project = Build.add(camp, "cemetery", x, y, { w = size[1], h = size[2] })
            if project ~= nil then return project end
        end
        if budget.left <= 0 then break end
    end
    return nil
end

function Sanitary.claim(camp, state, project)
    project.status = "done"
    project.stage = 2
    project.prepared = true
    project.finished = Store.hours()
    state.plotId = project.id
    state.rect = { x = project.x, y = project.y, w = project.w, h = project.h }
    return project
end

function Sanitary.reserve(camp, force)
    if camp == nil or not enabled(camp) then return 0 end
    local state = Sanitary.state(camp)
    if Sanitary.plot(camp) ~= nil then return 0 end
    if fenceOf(camp) == nil then return 0 end
    local now = Store.hours()
    local gap = force and Sanitary.forceHours or Sanitary.retryHours
    if now - state.tryAt < gap then return 0 end
    state.tryAt = now
    local project = Sanitary.place(camp, state)
    if project == nil then return 0 end
    Sanitary.claim(camp, state, project)
    return 1
end

function Sanitary.maybeReserve(camp, state)
    if camp.phase == "clear" then return end
    if camp.options.autoPlan == false and state.lost == 0 and #state.jobs == 0 then return end
    Sanitary.reserve(camp, false)
end

function Sanitary.ensurePlot(camp, state, force)
    local plot = Sanitary.plot(camp)
    if plot == nil and force then
        Sanitary.reserve(camp, true)
        plot = Sanitary.plot(camp)
    end
    return plot
end

local function tend(square)
    local doomed = {}
    pcall(function()
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            if type(World.tag(object)) ~= "table" then
                local kind = Land ~= nil and Land.classify(object) or nil
                if kind == "plant" or kind == "junk" then doomed[#doomed + 1] = object end
            end
        end
    end)
    for _, object in ipairs(doomed) do
        ALifeCamp.World.removeHard(square, object)
    end
    if #doomed > 0 then pcall(function() square:RecalcProperties() end) end
    pcall(function() square:disableErosion() end)
    return #doomed
end

function Sanitary.open(square, x, y, z)
    tend(square)
    local free = false
    pcall(function() free = square:isFree(false) == true and square:isOutside() == true end)
    if not free then return false end
    if Place.blocked(x, y, z) then return false end
    return World.find(square, "grave", nil) == nil
end

local function graveInfo()
    return {
        name = "EmptyGraves", north = false, canBarricade = false, canPassThrough = false,
        blockAllTheSquare = false, isThumpable = false, isWallLike = false, hoppable = false,
        dismantable = false, canBePlastered = false, isContainer = false, isDoor = false,
        isDoorFrame = false, isStairs = false, isCorner = false, isFloor = false,
        thumpDmg = 8, crossSpeed = 1.0, modData = {},
    }
end

local function newPit(square, sprite, spriteType, tag)
    local object
    pcall(function()
        object = IsoThumpable.new(getCell(), square, sprite, false, graveInfo())
        pcall(function() object:setName("EmptyGraves") end)
        pcall(function() object:setCanBarricade(false) end)
        pcall(function() object:setIsThumpable(false) end)
        local data = object:getModData()
        data.spriteType = spriteType
        data.corpses = 1
        data.filled = true
        data.ALC = tag
        pcall(function() square:disableErosion() end)
        square:AddSpecialObject(object)
    end)
    if object ~= nil then Place.finish(square, object) end
    return object
end

local function putProp(sprite, x, y, z, tag)
    if not spriteKnown(sprite) then return nil end
    local object = Place.prop(sprite, x, y, z, tag)
    return object
end

function Sanitary.consecrate(camp, state, plot)
    local layout = Sanitary.layout(plot.w, plot.h)
    local sprites = Sanitary.sprites
    local z = camp.z
    local mx, my = plot.x + layout.cx, plot.y
    local fresh = not state.monument
    if not state.monument then
        local square = World.square(mx, my, z)
        if square ~= nil then
            if Sanitary.open(square, mx, my, z) then putProp(sprites.angel, mx, my, z, Place.tag(plot, "M", "grave")) end
            state.monument = true
        end
    end
    if not state.flowers then
        local left, right = World.square(mx - 1, my, z), World.square(mx + 1, my, z)
        if left ~= nil and right ~= nil then
            if Sanitary.open(left, mx - 1, my, z) then
                putProp(pick(sprites.flowers, mx - 1, my, 11), mx - 1, my, z, Place.tag(plot, "F1", "grave"))
            end
            if Sanitary.open(right, mx + 1, my, z) then
                putProp(pick(sprites.flowers, mx + 1, my, 12), mx + 1, my, z, Place.tag(plot, "F2", "grave"))
            end
            state.flowers = true
        end
    end
    while state.laneDone < plot.h - 1 do
        local dy = state.laneDone + 1
        local lx, ly = mx, plot.y + dy
        local square = World.square(lx, ly, z)
        if square == nil then break end
        tend(square)
        pcall(Place.floor, lx, ly, z, pick(sprites.lane, lx, ly, 21), Place.tag(plot, "L" .. dy, "grave"))
        state.laneDone = dy
    end
    if fresh and state.monument then Store.log(camp, "san_cemetery", plot.w, plot.h) end
    return state.monument
end

function Sanitary.raise(camp, plot, job, west, east, ax, ay, index)
    local z = camp.z
    local sprites = Sanitary.sprites
    local sign = job.ally and pick(sprites.cross, ax, ay, 3) or pick(sprites.stone, ax, ay, 5)
    if job.mem then
        local mark = putProp(sign, ax, ay, z, Place.tag(plot, "H" .. index, "grave"))
        if mark == nil then return nil end
        if Sanitary.open(east, ax + 1, ay, z) then putProp(sprites.cairn, ax + 1, ay, z, Place.tag(plot, "C" .. index, "grave")) end
        return "marker"
    end
    if not spriteKnown(sprites.pitWest) or not spriteKnown(sprites.pitEast) then return nil end
    local a = newPit(west, sprites.pitWest, "sprite2", Place.tag(plot, "G" .. index .. "w", "grave"))
    local b = newPit(east, sprites.pitEast, "sprite1", Place.tag(plot, "G" .. index .. "e", "grave"))
    if a == nil or b == nil then
        if a ~= nil then World.remove(a) end
        if b ~= nil then World.remove(b) end
        return nil
    end
    putProp(sign, ax, ay, z, Place.tag(plot, "H" .. index, "grave"))
    return "grave"
end

function Sanitary.entomb(camp, state, plot, job)
    local layout = Sanitary.layout(plot.w, plot.h)
    if state.graves + state.markers >= Sanitary.graveCap then return nil, "cap" end
    local z = camp.z
    local index = state.slot
    while index <= #layout.slots do
        local def = layout.slots[index]
        local ax, ay = plot.x + def.dx, plot.y + def.dy
        local west, east = World.square(ax, ay, z), World.square(ax + 1, ay, z)
        if west == nil or east == nil then return nil, "unloaded" end
        local usable = Sanitary.open(west, ax, ay, z) and (job.mem or Sanitary.open(east, ax + 1, ay, z))
        if usable then
            Sanitary.consecrate(camp, state, plot)
            local kind = Sanitary.raise(camp, plot, job, west, east, ax, ay, index)
            if kind ~= nil then
                state.slot = index + 1
                return kind
            end
        end
        index = index + 1
        state.slot = index
    end
    return nil, "full"
end

function Sanitary.record(camp, state, job, kind, member)
    local entry = { name = job.name, day = job.day or Store.day(camp) }
    if job.uid ~= nil then entry.uid = job.uid end
    if job.mem then entry.mem = true end
    state.fallen[#state.fallen + 1] = entry
    while #state.fallen > Sanitary.fallenKeep do table.remove(state.fallen, 1) end
    state.lost = state.lost + 1
    if job.mem then
        state.memorials = state.memorials + 1
        if kind == "marker" then state.markers = state.markers + 1 end
        Store.log(camp, "san_memory", job.name)
        if not job.ally then notify(camp, "SanNoteMemory", job.name) end
    else
        state.buried = state.buried + 1
        if kind == "grave" then state.graves = state.graves + 1 else state.mass = state.mass + 1 end
        Store.log(camp, kind == "grave" and "san_buried" or "san_mass", job.name)
        if not job.ally then notify(camp, "SanNoteBuried", job.name) end
    end
    Sanitary.tidy(state, 2)
    Sanitary.say(member, "SanSayBury")
    Sanitary.train(camp, member, Sanitary.cost.grave)
end

function Sanitary.finishJob(camp, state, job, member, force)
    local plot = Sanitary.ensurePlot(camp, state, force)
    local kind
    if plot ~= nil then
        local made, why = Sanitary.entomb(camp, state, plot, job)
        if made == nil and why == "unloaded" and not force then return nil end
        kind = made
    end
    Sanitary.record(camp, state, job, kind, member)
    return kind or "mass"
end

function Sanitary.target(camp, state, plot)
    local layout = Sanitary.layout(plot.w, plot.h)
    local index = state.slot + #state.jobs
    if index > #layout.slots then return nil end
    if state.graves + state.markers + #state.jobs >= Sanitary.graveCap then return nil end
    local def = layout.slots[index]
    return { x = plot.x + def.dx, y = plot.y + def.dy }
end

function Sanitary.arrange(camp, info, opts)
    local state = Sanitary.state(camp)
    opts = opts or {}
    if Sanitary.recorded(state, info.uid) or Sanitary.queued(state, info.uid) then
        if not info.memorial then Sanitary.countBody(camp, state, opts.member) end
        return "dup"
    end
    state.serial = state.serial + 1
    local job = {
        id = state.serial, name = tostring(info.name or T("SanNameless")), day = info.day or Store.day(camp),
        mem = info.memorial == true, ally = info.member == false, at = Store.hours(), w = 0,
    }
    if info.uid ~= nil then job.uid = info.uid end
    if opts.member ~= nil then job.by = opts.member.uid end
    local target
    if not opts.instant then
        local plot = Sanitary.ensurePlot(camp, state, true)
        if plot ~= nil and #state.jobs < Sanitary.jobLimit then target = Sanitary.target(camp, state, plot) end
    end
    if target == nil then
        Sanitary.finishJob(camp, state, job, opts.member, true)
        return "done"
    end
    job.x, job.y, job.z = target.x, target.y, camp.z
    state.jobs[#state.jobs + 1] = job
    Sanitary.say(opts.member, "SanSayCarry")
    return "queued"
end

function Sanitary.honor(camp, name, opts)
    if camp == nil then return "none" end
    opts = opts or {}
    local info = {
        name = tostring(name or T("SanNameless")), member = opts.ally ~= true, memorial = opts.memorial == true,
        day = opts.day, uid = opts.uid,
    }
    return Sanitary.arrange(camp, info, { instant = true })
end

function Sanitary.cleanAll(camp)
    if camp == nil then return 0 end
    local state = Sanitary.state(camp)
    local zone = Sanitary.zone(camp)
    local total = 0
    for y = zone.y1, zone.y2 do
        for x = zone.x1, zone.x2 do
            local top = 0
            if Geo.contains(camp, x, y) then top = Sanitary.levels - 1 end
            for dz = 0, top do
                local square = World.square(x, y, camp.z + dz)
                if square ~= nil then
                    local count, blood = inspect(square)
                    if count > 0 or blood then
                        local result = Sanitary.cleanSquare(camp, state, square, { instant = true })
                        total = total + result.bodies + result.comrades + result.washed
                    end
                end
            end
        end
    end
    state.points = {}
    local jobs = state.jobs
    state.jobs = {}
    for _, job in ipairs(jobs) do
        Sanitary.finishJob(camp, state, job, nil, true)
        total = total + 1
    end
    Sanitary.refresh(camp, state)
    return total
end

function Sanitary.findBody(dead, uid)
    for dx = -2, 2 do
        for dy = -2, 2 do
            local x, y = dead.x + dx, dead.y + dy
            local square = World.square(x, y, dead.z)
            if square ~= nil then
                for _, body in ipairs(bodiesOf(square)) do
                    local data = dataOf(body)
                    if data ~= nil and (data.ProjectALifeCorpseOf == uid or data.ProjectALifeUID == uid) then
                        return x, y, dead.z
                    end
                end
            end
        end
    end
    return nil
end

function Sanitary.trimDead(state)
    local count = 0
    for _ in pairs(state.dead) do count = count + 1 end
    while count > Sanitary.deadKeep do
        local oldest, oldestAt
        for uid, dead in pairs(state.dead) do
            if oldestAt == nil or dead.at < oldestAt then oldest, oldestAt = uid, dead.at end
        end
        if oldest == nil then return end
        state.dead[oldest] = nil
        count = count - 1
    end
end

function Sanitary.onDied(camp, settler, uid)
    if not enabled(camp) or type(uid) ~= "string" then return end
    local state = Sanitary.state(camp)
    if Sanitary.recorded(state, uid) or Sanitary.queued(state, uid) then return end
    local x, y, z = Settlers.where(uid)
    if x == nil then
        local cx, cy = Geo.center(camp)
        x, y, z = cx, cy, camp.z
    end
    state.dead[uid] = {
        name = tostring(settler ~= nil and settler.name or uid), day = Store.day(camp), at = Store.hours(),
        x = math.floor(x), y = math.floor(y), z = math.floor(z or camp.z), st = "wait",
    }
    Sanitary.trimDead(state)
end

function Sanitary.resolveDead(camp, state, minutes)
    local now = Store.hours()
    local expired = {}
    for uid, dead in pairs(state.dead) do
        local age = (now - dead.at) * 60
        if dead.st == "wait" then
            local x, y, z = Sanitary.findBody(dead, uid)
            if x ~= nil then
                local square = World.square(x, y, z)
                if square ~= nil then
                    local count, blood = inspect(square)
                    Sanitary.note(camp, state, x, y, z, count, blood)
                end
                dead.st = "body"
            else
                local loaded = World.square(dead.x, dead.y, dead.z) ~= nil
                if (loaded and age >= Sanitary.graceMinutes) or age >= Sanitary.unloadedMinutes then
                    dead.st = "gone"
                    Sanitary.arrange(camp, { uid = uid, name = dead.name, day = dead.day, member = true, memorial = true }, {})
                end
            end
        elseif dead.st == "body" and age >= Sanitary.bodyMinutes then
            dead.st = "gone"
            if not Sanitary.recorded(state, uid) and not Sanitary.queued(state, uid) then
                Sanitary.arrange(camp, { uid = uid, name = dead.name, day = dead.day, member = true, memorial = true }, {})
            end
        end
        if age > Sanitary.deadHours * 60 then expired[#expired + 1] = uid end
    end
    for _, uid in ipairs(expired) do state.dead[uid] = nil end
end

function Sanitary.compute(camp, state)
    local inside, outside = Sanitary.known(camp, state)
    local w = Sanitary.weights
    local penalty = inside.c * w.bodyIn + outside.c * w.bodyOut + inside.b * w.bloodIn + outside.b * w.bloodOut
    local bonus = math.min(Sanitary.tidyCap, state.tidy or 0)
    if Sanitary.plot(camp) ~= nil then bonus = bonus + 1 + math.min(4, state.graves * 0.5) end
    return clamp(math.floor(100 - penalty + bonus + 0.5), 0, 100)
end

function Sanitary.refresh(camp, state, stamp)
    state = state or Sanitary.state(camp)
    state.score = Sanitary.compute(camp, state)
    state.stamp = stamp or math.floor(Store.hours() * 60)
    return state.score
end

function Sanitary.score(camp)
    if camp == nil or not enabled(camp) then return 100 end
    local state = Sanitary.state(camp)
    local stamp = math.floor(Store.hours() * 60)
    if state.stamp ~= stamp then Sanitary.refresh(camp, state, stamp) end
    return state.score
end

function Sanitary.stats(camp)
    local state = Sanitary.state(camp)
    local inside, outside = Sanitary.known(camp, state)
    local capacity, free = Sanitary.capacity(camp)
    return {
        score = Sanitary.score(camp), corpses = inside.c + outside.c, blood = inside.b + outside.b,
        removed = state.removed, buried = state.buried, graves = state.graves, fallen = state.lost,
        washed = state.washed, mass = state.mass, markers = state.markers, memorials = state.memorials,
        jobs = #state.jobs, points = #state.points, capacity = capacity, free = free,
    }
end

function Sanitary.mood(camp, state)
    if camp.phase == "clear" then return end
    local score = state.score
    if score < Sanitary.filthBelow and not state.filthy then
        state.filthy = true
        Store.log(camp, "san_filth")
        notify(camp, "SanNoteFilth")
    elseif score >= Sanitary.freshAbove and state.filthy then
        state.filthy = false
        Store.log(camp, "san_fresh")
    end
end

function Sanitary.upkeep(camp, state, minutes)
    state.tidy = math.max(0, (state.tidy or 0) - Sanitary.tidyDecay * minutes / 60)
end

function Sanitary.settle(camp, state, minutes)
    Sanitary.refresh(camp, state)
    Sanitary.mood(camp, state)
end

function Sanitary.trace(camp, state, minutes)
    local hour = math.floor(Store.hours())
    if state.traceHour == hour then return end
    state.traceHour = hour
    local stats = Sanitary.stats(camp)
    print("[ALifeCamp:Sanitary] camp=" .. tostring(camp.id) .. " score=" .. stats.score .. " corpses=" .. stats.corpses
        .. " blood=" .. stats.blood .. " points=" .. stats.points .. " jobs=" .. stats.jobs .. " removed=" .. stats.removed
        .. " washed=" .. stats.washed .. " buried=" .. stats.buried .. " graves=" .. stats.graves
        .. " fallen=" .. stats.fallen .. " power=" .. (math.floor((state.power or 0) * 10) / 10)
        .. " cursor=" .. state.cursor .. " passes=" .. state.passes .. " plot=" .. (stats.capacity > 0 and "yes" or "no"))
end

local function guarded(name, fn, camp, state, minutes)
    local ok, err = pcall(fn, camp, state, minutes)
    if not ok and not faults[name] then
        faults[name] = true
        print("[ALifeCamp:Sanitary] " .. name .. " failed: " .. tostring(err))
    end
    return ok
end

function Sanitary.step(camp, minutes)
    if not enabled(camp) then return end
    minutes = tonumber(minutes) or 1
    if minutes <= 0 then minutes = 1 end
    if minutes > 30 then minutes = 30 end
    local state = Sanitary.state(camp)
    guarded("upkeep", Sanitary.upkeep, camp, state, minutes)
    guarded("dead", Sanitary.resolveDead, camp, state, minutes)
    guarded("verify", Sanitary.verify, camp, state, minutes)
    guarded("scan", Sanitary.scan, camp, state, minutes)
    guarded("work", Sanitary.work, camp, state, minutes)
    guarded("reserve", Sanitary.maybeReserve, camp, state, minutes)
    guarded("settle", Sanitary.settle, camp, state, minutes)
    guarded("trace", Sanitary.trace, camp, state, minutes)
end

function Sanitary.roles(camp)
    if not enabled(camp) then return nil end
    if Store.settlerCount(camp) < Sanitary.minPeople then return nil end
    local share = Sanitary.shareBase
    if Sanitary.corpseCount(camp, Sanitary.state(camp)) > Sanitary.heavyCorpses then share = Sanitary.shareHeavy end
    return { { "sanitary", share } }
end

function Sanitary.morale(camp)
    if not enabled(camp) then return 0 end
    return -8 + 12 * Sanitary.score(camp) / 100
end

function Sanitary.anchor(camp, uid, settler, current)
    if camp.raid ~= nil or not enabled(camp) or settler == nil then return nil end
    if settler.role == "guard" then return nil end
    local target = settler.san
    if type(target) ~= "table" or type(target.x) ~= "number" then return nil end
    return { x = target.x, y = target.y, z = camp.z, exact = true }
end

function Sanitary.onRaidEnd(camp, raid, lost)
    if not enabled(camp) then return end
    local state = Sanitary.state(camp)
    state.surge = Store.hours() + Sanitary.surgeHours
    local site = type(raid) == "table" and raid.site or nil
    if type(site) == "table" and type(site.y) == "number" then
        local zone = Sanitary.zone(camp)
        local row = clamp(math.floor(site.y) - Sanitary.focusRows, zone.y1, zone.y2)
        state.sig = zone.sig
        state.cursor = (row - zone.y1) * zone.w
    end
    Store.log(camp, "san_aftermath", lost or 0)
    notify(camp, "SanNoteAftermath")
end

function Sanitary.info(camp, uid, settler)
    if not enabled(camp) or type(settler.san) ~= "table" or camp.raid ~= nil then return nil end
    local carrying = string.sub(tostring(settler.san.k), 1, 1) == "j"
    return { T(carrying and "SanDoingCarry" or "SanDoingClean") }
end

function Sanitary.grade(score)
    if score < 20 then return 0 end
    if score < 40 then return 1 end
    if score < 60 then return 2 end
    if score < 80 then return 3 end
    if score < 95 then return 4 end
    return 5
end

function Sanitary.color(score)
    if score >= 80 then return 0.6, 0.95, 0.65 end
    if score >= 60 then return 0.85, 0.9, 0.5 end
    if score >= 40 then return 0.95, 0.75, 0.4 end
    return 1, 0.45, 0.4
end

function Sanitary.overview(camp)
    if not enabled(camp) then return nil end
    local stats = Sanitary.stats(camp)
    local r, g, b = Sanitary.color(stats.score)
    local rows = {
        Hooks.line(T("SanOverview", tostring(stats.score), T("SanGrade_" .. Sanitary.grade(stats.score)),
            tostring(stats.removed), tostring(stats.buried)), r, g, b),
    }
    if stats.score < Sanitary.dirtyBelow then
        rows[#rows + 1] = Hooks.line(T("SanOverviewDirty", tostring(stats.corpses), tostring(stats.blood)), 1, 0.45, 0.4)
    end
    return rows
end

function Sanitary.lines(camp)
    if not enabled(camp) then return { Hooks.line(T("SanOff"), 0.7, 0.7, 0.75) } end
    local state = Sanitary.state(camp)
    local stats = Sanitary.stats(camp)
    local zone = Sanitary.zone(camp)
    local lines = {}
    local function add(text, r, g, b)
        lines[#lines + 1] = Hooks.line(text, r, g, b)
    end
    local dirt = stats.corpses + stats.blood
    local r, g, b = Sanitary.color(stats.score)
    add(T("SanLineScore", tostring(stats.score), T("SanGrade_" .. Sanitary.grade(stats.score))), r, g, b)
    if zone.ring > 0 then
        add(T("SanLineZone", tostring(zone.w), tostring(zone.h), tostring(zone.ring)), 0.8, 0.82, 0.88)
    else
        add(T("SanLineZoneFlat", tostring(zone.w), tostring(zone.h)), 0.8, 0.82, 0.88)
    end
    if dirt > 0 then add(T("SanLineDirt", tostring(stats.corpses), tostring(stats.blood)), 0.95, 0.75, 0.4) end
    if stats.jobs > 0 then add(T("SanLineJobs", tostring(stats.jobs)), 0.85, 0.85, 0.7) end
    if dirt > 0 or stats.jobs > 0 then
        local power = math.floor((state.power or 0) * 10) / 10
        if power > 0 then
            add(T("SanLineCrew", tostring(power)), 0.8, 0.82, 0.88)
        else
            add(T("SanLineNobody"), 0.7, 0.7, 0.75)
        end
    end
    if stats.removed + stats.washed > 0 then add(T("SanLineRemoved", tostring(stats.removed), tostring(stats.washed)), 0.8, 0.82, 0.88) end
    if stats.buried > 0 then add(T("SanLineBuried", tostring(stats.buried), tostring(stats.graves)), 0.8, 0.82, 0.88) end
    if stats.mass > 0 then add(T("SanLineMass", tostring(stats.mass)), 0.75, 0.75, 0.8) end
    if stats.fallen > 0 then
        if stats.capacity > 0 then
            local plot = Sanitary.plot(camp)
            add(T("SanLinePlot", tostring(plot.w), tostring(plot.h), tostring(stats.free)), 0.75, 0.82, 0.9)
        else
            add(T("SanLinePlotNone"), 0.7, 0.7, 0.75)
        end
        add(T("SanFallenTitle"), 0.85, 0.8, 1)
        local shown = 0
        for index = #state.fallen, 1, -1 do
            if shown >= 5 then break end
            local entry = state.fallen[index]
            local key = entry.mem and "SanFallenMemory" or "SanFallenRow"
            add(T(key, tostring(entry.day or 0), tostring(entry.name or "")), 0.82, 0.8, 0.92)
            shown = shown + 1
        end
    end
    return lines
end

Options.define({ key = "sanitation", group = "life", kind = "toggle", default = true, priority = 30 })
Options.define({
    key = "sanitaryRing", group = "life", kind = "cycle", values = Sanitary.ringValues, default = 25, priority = 31,
    after = function(camp)
        if type(camp.sanitary) == "table" then camp.sanitary.sig = "" end
    end,
})

Hooks.add("minute", Sanitary.step, 45)
Hooks.add("roles", Sanitary.roles)
Hooks.add("anchor", Sanitary.anchor, 30)
Hooks.add("morale", Sanitary.morale)
Hooks.add("died", Sanitary.onDied)
Hooks.add("raidend", Sanitary.onRaidEnd)
Hooks.add("overview", Sanitary.overview)
Hooks.add("settlerInfo", Sanitary.info, 60)
Hooks.section("life", "SanTitle", Sanitary.lines, 30)

return Sanitary
