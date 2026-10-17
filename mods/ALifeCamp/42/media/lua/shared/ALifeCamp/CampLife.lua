require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampStats"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Settlers = ALifeCamp.Settlers
local Build = ALifeCamp.Build
local Stats = ALifeCamp.Stats
local T = ALifeCamp.T

local Life = {}
ALifeCamp.Life = Life

Life.startMood = 60
Life.base = 58
Life.rate = 1
Life.envEvery = 5
Life.fireRadius = 8
Life.circleMin = 3
Life.gatherDelay = 8
Life.speakers = 2
Life.queueLimit = 3
Life.eveningLogEvery = 3
Life.eveningBonus = 4
Life.eveningHours = 6
Life.lessonChance = 30
Life.lessonXp = 5
Life.anniversary = 30
Life.feastCost = 600
Life.feastDays = 1.5
Life.feastBonus = 15
Life.feastHours = 48
Life.poorBonus = 6
Life.poorHours = 24
Life.victoryBonus = 10
Life.victoryHours = 24
Life.memorialPenalty = -8
Life.memorialHours = 24
Life.helloBonus = 8
Life.helloHours = 12
Life.cheatBonus = 60
Life.cheatHours = 6
Life.grumbleBelow = 25
Life.calmAbove = 35
Life.leaveBelow = 10
Life.leaveAfter = 48
Life.leaveCooldown = 6
Life.minCrew = 3
Life.unhappyBelow = 35
Life.unhappyShown = 5
Life.laborLow = 0.85
Life.laborHigh = 1.12
Life.ringInner = 1
Life.ringOuter = 3
Life.gatherMinutes = { feast = 40, party = 30, victory = 25, memorial = 20 }

Life.traits = { "optimist", "grumbler", "loner", "social", "workaholic" }
Life.react = {
    optimist = { good = 1.5, bad = 0.8, base = 4 },
    grumbler = { good = 0.8, bad = 2, base = -3 },
    loner = { good = 1, bad = 1, base = 0 },
    social = { good = 1, bad = 1, base = 0 },
    workaholic = { good = 1, bad = 1, base = 0 },
}
Life.factorOrder = { "food", "housing", "safety", "clean", "health", "social", "loss", "work", "holiday", "progress" }
Life.componentOrder = { "hunger", "larder", "housing", "safety", "fear", "clean", "health", "social", "loss", "work", "holiday", "progress" }
Life.groups = {
    hunger = "food", larder = "food", housing = "housing", safety = "safety", fear = "safety", clean = "clean",
    health = "health", social = "social", loss = "loss", work = "work", holiday = "holiday", progress = "progress",
}

Life.traitBarks = {
    optimist = "LfBarkOptimist", grumbler = "LfBarkGrumbler", loner = "LfBarkLoner",
    social = "LfBarkSocial", workaholic = "LfBarkWorkaholic",
}
Life.jokes = { "LfBarkJoke1", "LfBarkJoke2", "LfBarkJoke3", "LfBarkJoke4" }
Life.phaseBarks = { morning = "LfBarkMuster", lunch = "LfBarkLunch", night = "LfBarkSleep" }
Life.barkKeys = {
    "LfBarkCold", "LfBarkHungry", "LfBarkGood", "LfBarkScared", "LfBarkWalls", "LfBarkHome", "LfBarkBored", "LfBarkSad",
    "LfBarkJoke1", "LfBarkJoke2", "LfBarkJoke3", "LfBarkJoke4",
    "LfBarkOptimist", "LfBarkGrumbler", "LfBarkLoner", "LfBarkSocial", "LfBarkWorkaholic",
    "LfBarkFeast", "LfBarkVictory", "LfBarkMemorial", "LfBarkWelcome",
    "LfBarkMuster", "LfBarkLunch", "LfBarkSleep", "LfBarkGrumble", "LfBarkQuit",
}

Life.contexts = {}
Life.envs = {}
Life.views = {}

Life.ringCells = {}
for dx = -3, 3 do
    for dy = -3, 3 do
        local distance = math.max(math.abs(dx), math.abs(dy))
        if distance >= 1 then Life.ringCells[#Life.ringCells + 1] = { dx, dy, distance } end
    end
end

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function num(value, default)
    if type(value) == "number" and value == value then return value end
    return default or 0
end

local function round(value)
    return math.floor(value + 0.5)
end

local function valid(point)
    return type(point) == "table" and type(point.x) == "number" and type(point.y) == "number"
end

local function hash(text)
    local work = ALifeCamp.Work
    if work ~= nil and type(work.hash) == "function" then
        local ok, value = pcall(work.hash, text)
        if ok and type(value) == "number" then return value end
    end
    local h = 0
    for i = 1, #text do h = (h * 31 + string.byte(text, i)) % 1000003 end
    return h
end

local function optional(name, method, a, b)
    local module = ALifeCamp[name]
    if module == nil or type(module[method]) ~= "function" then return nil end
    local ok, value = pcall(module[method], a, b)
    if ok then return value end
    return nil
end

local function dailyFood()
    local work = ALifeCamp.Work
    if work ~= nil then return num(work.kcalPerDay, 2000) end
    return 2000
end

local function say(uid, key, name)
    local shell = Settlers.shell(uid)
    if shell == nil then return end
    if name ~= nil then
        pcall(Settlers.say, shell, key, name)
    else
        pcall(Settlers.say, shell, key)
    end
end

local function notify(camp, key, name)
    local work = ALifeCamp.Work
    if work == nil or type(work.notify) ~= "function" then return end
    if name ~= nil then
        pcall(work.notify, camp, key, name)
    else
        pcall(work.notify, camp, key)
    end
end

local function addBuff(buffs, name, value, expires, factor)
    buffs[name] = { v = value, e = expires, f = factor }
end

local function sumBuffs(buffs, now, into)
    for _, buff in pairs(buffs) do
        if type(buff) == "table" and num(buff.e) > now and type(buff.f) == "string" then
            into[buff.f] = (into[buff.f] or 0) + num(buff.v)
        end
    end
end

local function pruneBuffs(buffs, now)
    local expired = {}
    for name, buff in pairs(buffs) do
        if type(buff) ~= "table" or num(buff.e) <= now then expired[#expired + 1] = name end
    end
    for _, name in ipairs(expired) do buffs[name] = nil end
end

local function mine(settler)
    local data = settler.lf
    if type(data) ~= "table" then
        data = {}
        settler.lf = data
    end
    if type(data.buffs) ~= "table" then data.buffs = {} end
    return data
end

function Life.state(camp)
    local life = camp.life
    if type(life) ~= "table" then
        life = {}
        camp.life = life
        life.annivDone = math.floor(Store.day(camp) / Life.anniversary)
    end
    life.feasts = num(life.feasts)
    life.deserted = num(life.deserted)
    life.evenings = num(life.evenings)
    life.nights = num(life.nights)
    life.eveningMinutes = num(life.eveningMinutes)
    life.annivDone = num(life.annivDone)
    if type(life.buffs) ~= "table" then life.buffs = {} end
    if type(life.deaths) ~= "table" then life.deaths = {} end
    if type(life.queue) ~= "table" then life.queue = {} end
    return life
end

function Life.drop(camp)
    if camp == nil then
        Life.contexts, Life.envs, Life.views = {}, {}, {}
        return
    end
    Life.contexts[camp.id] = nil
    Life.envs[camp.id] = nil
    Life.views[camp.id] = nil
end

function Life.stale(camp)
    Life.contexts[camp.id] = nil
end

function Life.traitOf(uid)
    return Life.traits[hash(tostring(uid)) % #Life.traits + 1]
end

function Life.ensure(camp, uid, settler)
    if Life.react[settler.trait] == nil then settler.trait = Life.traitOf(uid) end
    settler.mood = clamp(num(settler.mood, Life.startMood), 0, 100)
    local data = mine(settler)
    if type(data.social) ~= "number" then data.social = Store.hours() end
    return settler
end

function Life.hour()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return num(hour, 12)
end

function Life.phaseAt(hour)
    if hour >= 22 or hour < 6 then return "night" end
    if hour >= 19 then return "evening" end
    if hour >= 13 and hour < 14 then return "lunch" end
    if hour >= 6 and hour < 8 then return "morning" end
    return "work"
end

function Life.forced(camp)
    local life = camp ~= nil and camp.life or nil
    return type(life) == "table" and num(life.forcedUntil) > Store.hours()
end

function Life.phase(camp)
    if Life.forced(camp) then return "evening" end
    return Life.phaseAt(Life.hour())
end

function Life.spotAt(camp, phase, hour)
    if phase == "morning" then
        if hour < 7 then return "muster" end
        return "mess"
    end
    if phase == "lunch" then return "mess" end
    if phase == "evening" then
        if Life.forced(camp) or hour >= 20 then return "fire" end
        return "mess"
    end
    if phase == "night" then return "bed" end
    return nil
end

function Life.projects(camp)
    local list = {}
    for _, project in pairs(Build.plan(camp).items) do list[#list + 1] = project end
    table.sort(list, function(a, b) return num(a.id) < num(b.id) end)
    return list
end

function Life.ownFire(camp)
    local fire, x1, y1, x2, y2
    for _, project in ipairs(Life.projects(camp)) do
        if project.status == "done" and not project.retired then
            if project.kind == "campfire" and fire == nil then
                fire = {
                    x = project.x + math.floor(num(project.w) / 2),
                    y = project.y + math.floor(num(project.h) / 2),
                    z = camp.z,
                }
            elseif project.kind == "plaza" then
                local right, bottom = project.x + num(project.w) - 1, project.y + num(project.h) - 1
                x1 = x1 == nil and project.x or math.min(x1, project.x)
                y1 = y1 == nil and project.y or math.min(y1, project.y)
                x2 = x2 == nil and right or math.max(x2, right)
                y2 = y2 == nil and bottom or math.max(y2, bottom)
            end
        end
    end
    local plaza
    if x1 ~= nil then plaza = { x = math.floor((x1 + x2) / 2), y = math.floor((y1 + y2) / 2), z = camp.z } end
    return fire, plaza
end

function Life.locate(camp, ctx)
    local cx, cy = Geo.center(camp)
    local center = { x = cx, y = cy, z = camp.z }
    local fire, plaza = Life.ownFire(camp)
    local ready = optional("Duty", "campfire", camp)
    if valid(ready) then fire = { x = ready.x, y = ready.y, z = ready.z or camp.z } end
    ctx.center = center
    ctx.fire = fire or plaza or center
    ctx.muster = plaza or center
    local mess = optional("Duty", "mess", camp)
    if valid(mess) then
        ctx.mess = mess
    else
        ctx.mess = ctx.fire
    end
end

function Life.pickWatch(into, list, count, shift)
    local total = #list
    for i = 0, count - 1 do
        into[list[(shift + i) % total + 1]] = true
    end
end

function Life.roster(camp, life, ctx)
    local guards, scavengers = {}, {}
    for uid, settler in pairs(camp.settlers) do
        if settler.role == "guard" then
            guards[#guards + 1] = uid
        elseif settler.role == "scavenger" then
            scavengers[#scavengers + 1] = uid
        end
    end
    table.sort(guards)
    table.sort(scavengers)
    ctx.guards = {}
    for index, uid in ipairs(guards) do ctx.guards[uid] = index end
    ctx.guardCount = #guards
    ctx.watch = {}
    Life.pickWatch(ctx.watch, guards, math.ceil(#guards / 3), life.nights)
    Life.pickWatch(ctx.watch, scavengers, math.floor(#scavengers / 2), life.nights)
end

function Life.context(camp)
    local life = Life.state(camp)
    local now = Store.hours()
    local hour = Life.hour()
    local phase = Life.phase(camp)
    local stamp = round(now * 60)
    local cached = Life.contexts[camp.id]
    if cached ~= nil and cached.stamp == stamp and cached.hour == hour and cached.phase == phase and cached.nights == life.nights then
        return cached
    end
    local ctx = { stamp = stamp, hour = hour, phase = phase, nights = life.nights }
    ctx.spot = Life.spotAt(camp, phase, hour)
    Life.locate(camp, ctx)
    Life.roster(camp, life, ctx)
    Life.contexts[camp.id] = ctx
    return ctx
end

function Life.localRing(camp, center, uid)
    local count = #Life.ringCells
    local start = hash(tostring(uid)) % count
    local z = center.z or camp.z
    for step = 0, count - 1 do
        local cell = Life.ringCells[(start + step) % count + 1]
        if cell[3] >= Life.ringInner and cell[3] <= Life.ringOuter then
            local x, y = center.x + cell[1], center.y + cell[2]
            if World.free(x, y, z) then return { x = x, y = y, z = z, exact = true } end
        end
    end
    local cell = Life.ringCells[start + 1]
    return { x = center.x + cell[1], y = center.y + cell[2], z = z, exact = true }
end

function Life.ring(camp, center, uid, kind)
    local duty = ALifeCamp.Duty
    local spot
    if duty ~= nil and type(duty.ring) == "function" then
        local ok, found = pcall(duty.ring, camp, center, uid, Life.ringInner, Life.ringOuter, center.indoor == true)
        if ok and valid(found) then spot = found end
    end
    if spot == nil then spot = Life.localRing(camp, center, uid) end
    return { x = spot.x, y = spot.y, z = spot.z or camp.z, exact = true, kind = kind }
end

function Life.home(camp, uid)
    local home = optional("Duty", "home", camp, uid)
    if valid(home) then return { x = home.x, y = home.y, z = home.z or camp.z, exact = true, kind = home.kind or "home" } end
    return nil
end

Life.spotKinds = { muster = "muster", mess = "mess", fire = "camp" }

function Life.place(camp, ctx, kind, uid)
    if kind == "bed" then
        local home = Life.home(camp, uid)
        if home ~= nil then return home end
        return Life.ring(camp, ctx.fire, uid, "rest")
    end
    return Life.ring(camp, ctx[kind], uid, Life.spotKinds[kind])
end

function Life.guardFree(ctx, uid)
    local index = ctx.guards[uid]
    if index == nil then return true end
    if ctx.guardCount <= 1 then return false end
    return (index + ctx.hour) % 2 == 0
end

function Life.gathering(camp, life)
    local gather = life.gather
    if type(gather) ~= "table" or num(gather.e) <= Store.hours() then return nil end
    if gather.kind ~= "party" and not Options.on(camp, "traditions") then return nil end
    return gather
end

function Life.anchor(camp, uid, settler, current)
    if camp.raid ~= nil or camp.phase == "clear" or settler.ill ~= nil then return nil end
    local life = Life.state(camp)
    local gather = Life.gathering(camp, life)
    if gather == nil and not Options.on(camp, "rhythm") then return nil end
    if optional("Motor", "crewAnchor", camp, uid) ~= nil then return nil end
    local ctx = Life.context(camp)
    if ctx.phase == "night" and ctx.watch[uid] then return nil end
    local kind = ctx.spot
    if gather ~= nil then kind = "fire" end
    if kind == nil then return nil end
    if ctx.phase ~= "night" and not Life.guardFree(ctx, uid) then return nil end
    return Life.place(camp, ctx, kind, uid)
end

function Life.average(camp)
    local total, count = 0, 0
    for _, settler in pairs(camp.settlers) do
        total = total + num(settler.mood, Life.startMood)
        count = count + 1
    end
    if count == 0 then return Life.startMood end
    return total / count
end

function Life.mood(camp)
    return round(Life.average(camp))
end

function Life.laborFactor(camp)
    if ALifeCamp.isEmpty(camp.settlers) then return 1 end
    local mood = clamp(Life.average(camp), 20, 90)
    return Life.laborLow + (mood - 20) / 70 * (Life.laborHigh - Life.laborLow)
end

function Life.moraleShift(camp)
    if ALifeCamp.isEmpty(camp.settlers) then return 0 end
    return (Life.average(camp) - 60) / 6
end

function Life.environment(camp, minutes)
    local env = Life.envs[camp.id]
    if env ~= nil and env.age < Life.envEvery then
        env.age = env.age + minutes
        return env
    end
    env = { age = 0, people = Store.settlerCount(camp), beds = 0, defense = 0 }
    local ok, stats = pcall(Stats.compute, camp)
    if ok and type(stats) == "table" then
        env.people = num(stats.people, env.people)
        env.beds = num(stats.capacity)
        env.defense = num(stats.defense)
    end
    local clean = optional("Sanitary", "score", camp)
    if type(clean) == "number" and clean == clean then env.clean = clamp(clean, 0, 100) end
    env.progress = clamp(num(optional("Progress", "bonus", camp, "mood")), -15, 15)
    env.busy = camp.phase == "clear" or camp.phase == "build"
        or (type(camp.adoptActive) == "table" and camp.adoptActive[1] ~= nil)
    Life.envs[camp.id] = env
    return env
end

function Life.fear(camp, life, now)
    if camp.raid ~= nil then return 1 end
    if type(life.raidAt) ~= "number" then return 0 end
    local fear = 1 - (now - life.raidAt) / 24
    if life.raidSafe == true then fear = fear / 2 end
    return clamp(fear, 0, 1)
end

function Life.safetyLevel(ratio)
    if ratio >= 15 then return 5 end
    if ratio >= 8 then return 3 end
    if ratio >= 4 then return 1 end
    if ratio >= 2 then return -2 end
    return -5
end

function Life.sickness(camp, uid, settler)
    local level = num(optional("Health", "sickLevel", camp, uid))
    if level <= 0 and settler.ill ~= nil then level = 1 end
    if level > 3 then level = level / 33.3 end
    return level
end

function Life.socialFactor(settler, now)
    local trait = settler.trait
    if trait == "loner" then return 0 end
    local peak, floor = 4, -2
    if trait == "social" then peak, floor = 9, -10 end
    local age = now - num(mine(settler).social, now)
    if age <= 12 then return peak end
    if age <= 36 then return peak * (36 - age) / 24 end
    if age <= 84 then return floor * (age - 36) / 48 end
    return floor
end

function Life.mournShare(settler, now)
    local share = 1
    if settler.trait == "social" then share = share * 0.5 end
    if now - num(mine(settler).social, now - 1000) <= 48 then share = share * 0.6 end
    return share
end

function Life.grief(life, now)
    local loss = 0
    for _, at in ipairs(life.deaths) do
        local age = now - num(at)
        if age >= 0 and age < 72 then loss = loss - 5 * (1 - age / 72) end
    end
    return math.max(-15, loss)
end

function Life.factors(camp, life, env, uid, settler, now)
    local f = {}
    local people = math.max(1, env.people)
    local stock = type(camp.stock) == "table" and camp.stock or {}
    local days = num(stock.food) / (people * dailyFood())
    f.hunger = -math.min(40, num(camp.hunger) * 5)
    f.larder = 0
    if days >= 3 then
        f.larder = 3
    elseif days >= 1.5 then
        f.larder = 1
    elseif days < 0.5 then
        f.larder = -4
    end
    local short = math.max(0, env.people - env.beds)
    if short == 0 then
        f.housing = 4
    else
        f.housing = -12 * short / people
    end
    f.safety = Life.safetyLevel(env.defense / people)
    f.fear = -8 * Life.fear(camp, life, now)
    if env.clean ~= nil then
        f.clean = clamp((env.clean - 50) / 50, -1, 1) * 8
    else
        f.clean = 0
    end
    f.health = -math.min(30, Life.sickness(camp, uid, settler) * 9)
    if Options.on(camp, "traditions") then
        f.social = Life.socialFactor(settler, now)
    else
        f.social = 0
    end
    f.loss = Life.grief(life, now)
    f.work = 0
    if settler.trait == "workaholic" then
        if env.busy then f.work = 4 else f.work = -8 end
    end
    f.holiday = 0
    f.progress = env.progress or 0
    sumBuffs(life.buffs, now, f)
    sumBuffs(mine(settler).buffs, now, f)
    local mourn = life.buffs.memorial
    if type(mourn) == "table" and num(mourn.e) > now then
        f.loss = f.loss - num(mourn.v) * (1 - Life.mournShare(settler, now))
    end
    return f
end

function Life.target(camp, life, env, uid, settler, now)
    local factors = Life.factors(camp, life, env, uid, settler, now)
    local react = Life.react[settler.trait] or Life.react.loner
    local total = Life.base + react.base
    for _, key in ipairs(Life.componentOrder) do
        local value = factors[key] or 0
        if value > 0 then
            total = total + value * react.good
        else
            total = total + value * react.bad
        end
    end
    return clamp(total, 0, 100), factors
end

function Life.drift(camp, life, env, minutes, now)
    local totals, count = {}, 0
    local limit = minutes * Life.rate
    for uid, settler in pairs(camp.settlers) do
        Life.ensure(camp, uid, settler)
        pruneBuffs(mine(settler).buffs, now)
        local target, factors = Life.target(camp, life, env, uid, settler, now)
        settler.mood = clamp(settler.mood + clamp(target - settler.mood, -limit, limit), 0, 100)
        for key, value in pairs(factors) do
            local group = Life.groups[key] or key
            totals[group] = (totals[group] or 0) + value
        end
        count = count + 1
    end
    if count > 0 then
        for key, value in pairs(totals) do totals[key] = value / count end
    end
    Life.views[camp.id] = totals
end

function Life.shelled(camp)
    local list = {}
    for uid in pairs(camp.settlers) do
        if Settlers.shell(uid) ~= nil then list[#list + 1] = uid end
    end
    table.sort(list)
    return list
end

function Life.cheer(camp, key, count, name)
    local pool = Life.shelled(camp)
    for _ = 1, count do
        if #pool == 0 then return end
        say(table.remove(pool, Hooks.rand(#pool)), key, name)
    end
end

function Life.cold()
    local cold = false
    pcall(function() cold = getClimateManager():getTemperature() < 10 end)
    return cold
end

function Life.pickBark(camp, life, env, settler, now)
    local pool = {}
    local function add(key, weight)
        for _ = 1, weight do pool[#pool + 1] = key end
    end
    local people = math.max(1, env.people)
    local stock = type(camp.stock) == "table" and camp.stock or {}
    local mood = num(settler.mood, Life.startMood)
    if num(camp.hunger) > 0.3 or num(stock.food) / (people * dailyFood()) < 1 then add("LfBarkHungry", 3) end
    if Life.fear(camp, life, now) > 0.3 then add("LfBarkScared", 3) end
    if env.defense / people < 2 then add("LfBarkWalls", 2) end
    if Life.cold() then add("LfBarkCold", 2) end
    if mood >= 70 then add("LfBarkGood", 3) end
    if mood < 35 then add("LfBarkSad", 3) end
    if mood < 55 then add("LfBarkHome", 1) end
    if not env.busy then add("LfBarkBored", 2) end
    add(Life.traitBarks[settler.trait] or Life.traitBarks.loner, 2)
    for _, key in ipairs(Life.jokes) do add(key, 1) end
    return pool[Hooks.rand(#pool)]
end

function Life.chatter(camp, life, env, present, now)
    local pool = {}
    for _, uid in ipairs(present) do
        if Settlers.shell(uid) ~= nil then pool[#pool + 1] = uid end
    end
    for _ = 1, Life.speakers do
        if #pool == 0 then return end
        local uid = table.remove(pool, Hooks.rand(#pool))
        say(uid, Life.pickBark(camp, life, env, camp.settlers[uid], now))
    end
end

function Life.teach(camp, uid, settler)
    local skills = ALifeCamp.Skills
    local main = skills.primary[settler.role or "worker"] or "scavenge"
    local pool = {}
    for _, skill in ipairs(skills.list) do
        if skill ~= main then pool[#pool + 1] = skill end
    end
    if #pool == 0 then return end
    skills.gain(camp, uid, pool[Hooks.rand(#pool)], Life.lessonXp)
end

function Life.lesson(camp, uid, settler)
    if ALifeCamp.Skills == nil or Hooks.rand(100) > Life.lessonChance then return end
    pcall(Life.teach, camp, uid, settler)
end

function Life.present(camp, point, radius)
    local list = {}
    for uid in pairs(camp.settlers) do
        local x, y, _, loaded = Settlers.where(uid)
        if x ~= nil then
            if loaded then
                local dx, dy = x - point.x, y - point.y
                if dx * dx + dy * dy <= radius * radius then list[#list + 1] = uid end
            elseif Geo.distanceTo(camp, x, y) <= 12 then
                list[#list + 1] = uid
            end
        end
    end
    table.sort(list)
    return list
end

function Life.session(camp, life, env, present, now)
    life.eveningDone = true
    life.evenings = life.evenings + 1
    for _, uid in ipairs(present) do
        local settler = camp.settlers[uid]
        local data = mine(settler)
        data.social = now
        if settler.trait ~= "loner" then
            addBuff(data.buffs, "evening", Life.eveningBonus, now + Life.eveningHours, "social")
        end
        Life.lesson(camp, uid, settler)
    end
    Life.chatter(camp, life, env, present, now)
    if life.evenings % Life.eveningLogEvery == 1 then
        Store.log(camp, "lf_evening", #present, Life.mood(camp))
    end
end

function Life.feast(camp, life, now)
    local people = Store.settlerCount(camp)
    local stock = type(camp.stock) == "table" and camp.stock or {}
    life.feastDue = nil
    life.feasts = life.feasts + 1
    if num(stock.food) > people * dailyFood() * Life.feastDays then
        local ok, used = pcall(Stock.consume, camp, "food", people * Life.feastCost)
        addBuff(life.buffs, "feast", Life.feastBonus, now + Life.feastHours, "holiday")
        Store.log(camp, "lf_feast", people, round(ok and num(used) or 0))
        notify(camp, "LfFeast")
    else
        addBuff(life.buffs, "feast", Life.poorBonus, now + Life.poorHours, "holiday")
        Store.log(camp, "lf_anniv", people)
        notify(camp, "LfAnnivPoor")
    end
    life.gather = { kind = "feast", e = now + Life.gatherMinutes.feast / 60 }
    Life.stale(camp)
    Life.cheer(camp, "LfBarkFeast", Life.speakers)
end

function Life.evening(camp, life, env, ctx, minutes, now)
    if ctx.phase ~= "evening" or ctx.spot ~= "fire" then return end
    if not Options.on(camp, "traditions") then return end
    life.eveningMinutes = life.eveningMinutes + minutes
    if life.eveningMinutes < Life.gatherDelay then return end
    local wantSession = life.eveningDone ~= true
    local wantFeast = life.feastDue == true
    if not wantSession and not wantFeast then return end
    local present = Life.present(camp, ctx.fire, Life.fireRadius)
    local people = Store.settlerCount(camp)
    if wantSession and #present >= Life.circleMin then Life.session(camp, life, env, present, now) end
    if wantFeast and people >= 2 and #present >= math.min(Life.circleMin, people) then Life.feast(camp, life, now) end
end

function Life.enqueue(life, item)
    while #life.queue >= Life.queueLimit do table.remove(life.queue, 1) end
    life.queue[#life.queue + 1] = item
end

function Life.begin(camp, life, item, now)
    life.gather = { kind = item.k, e = now + (Life.gatherMinutes[item.k] or 20) / 60 }
    Life.stale(camp)
    if item.k == "memorial" then
        Store.log(camp, "lf_memorial", item.name)
        notify(camp, "LfMemorial", item.name)
        Life.cheer(camp, "LfBarkMemorial", 1, item.name)
        return
    end
    life.feasts = life.feasts + 1
    addBuff(life.buffs, "victory", Life.victoryBonus, now + Life.victoryHours, "holiday")
    Store.log(camp, "lf_victory")
    notify(camp, "LfVictory")
    Life.cheer(camp, "LfBarkVictory", Life.speakers)
end

function Life.queueStep(camp, life, now)
    if type(life.gather) == "table" and now >= num(life.gather.e) then
        life.gather = nil
        Life.stale(camp)
    end
    if #life.queue == 0 then return end
    if not Options.on(camp, "traditions") then
        life.queue = {}
        return
    end
    if life.gather ~= nil or camp.raid ~= nil or camp.phase == "clear" then return end
    local hour = Life.hour()
    if hour < 7 or hour >= 22 then return end
    Life.begin(camp, life, table.remove(life.queue, 1), now)
end

function Life.transition(camp, life, phase)
    if life.last == phase then return end
    local known = life.last ~= nil
    life.last = phase
    if phase == "evening" then
        life.eveningDone = false
        life.eveningMinutes = 0
    elseif phase == "night" then
        life.nights = life.nights + 1
    end
    Life.stale(camp)
    local key = Life.phaseBarks[phase]
    if known and key ~= nil and Options.on(camp, "rhythm") then
        local pool = Life.shelled(camp)
        if #pool > 0 then say(pool[Hooks.rand(#pool)], key) end
    end
end

function Life.desert(camp, life, uid, now)
    local settler = camp.settlers[uid]
    if settler == nil then return end
    local name = tostring(settler.name or uid)
    say(uid, "LfBarkQuit")
    if Settlers.dismiss(camp, uid) then
        life.deserted = life.deserted + 1
        life.lastLeft = now
        Life.stale(camp)
        Store.log(camp, "lf_left", name)
        notify(camp, "LfLeft", name)
    end
end

function Life.discontent(camp, life, now)
    local enabled = Options.on(camp, "desertion")
    local leavers = {}
    for uid, settler in pairs(camp.settlers) do
        local data = mine(settler)
        local mood = num(settler.mood, Life.startMood)
        if not enabled then
            data.low = nil
            data.grumbled = nil
        else
            if mood < Life.grumbleBelow and data.grumbled ~= true then
                data.grumbled = true
                Store.log(camp, "lf_grumble", tostring(settler.name or uid))
                say(uid, "LfBarkGrumble")
            elseif mood >= Life.calmAbove then
                data.grumbled = nil
            end
            if mood < Life.leaveBelow then
                data.low = data.low or now
                if now - data.low >= Life.leaveAfter then leavers[#leavers + 1] = uid end
            else
                data.low = nil
            end
        end
    end
    if #leavers == 0 or Store.settlerCount(camp) < Life.minCrew then return end
    if now - num(life.lastLeft, -1000000) < Life.leaveCooldown then return end
    table.sort(leavers, function(a, b)
        local ma, mb = camp.settlers[a].mood, camp.settlers[b].mood
        if ma ~= mb then return ma < mb end
        return tostring(a) < tostring(b)
    end)
    Life.desert(camp, life, leavers[1], now)
end

function Life.trace(camp, life, phase, now)
    local key = math.floor(now)
    if life.traceKey == key then return end
    life.traceKey = key
    local people, low = 0, 0
    for _, settler in pairs(camp.settlers) do
        people = people + 1
        if num(settler.mood, Life.startMood) < Life.grumbleBelow then low = low + 1 end
    end
    if people == 0 then return end
    print("[ALifeCamp:Life] camp=" .. tostring(camp.id) .. " people=" .. tostring(people) .. " mood=" .. tostring(Life.mood(camp))
        .. " low=" .. tostring(low) .. " phase=" .. phase .. " feasts=" .. tostring(life.feasts)
        .. " evenings=" .. tostring(life.evenings) .. " deserted=" .. tostring(life.deserted))
end

function Life.step(camp, minutes)
    minutes = clamp(num(minutes, 1), 0, 30)
    local life = Life.state(camp)
    local now = Store.hours()
    local env = Life.environment(camp, minutes)
    pruneBuffs(life.buffs, now)
    Life.transition(camp, life, Life.phase(camp))
    local ctx = Life.context(camp)
    Life.drift(camp, life, env, minutes, now)
    Life.queueStep(camp, life, now)
    Life.evening(camp, life, env, ctx, minutes, now)
    Life.discontent(camp, life, now)
    Life.trace(camp, life, ctx.phase, now)
end

function Life.onArrived(camp, settler, uid)
    local now = Store.hours()
    Life.ensure(camp, uid, settler)
    settler.mood = Life.startMood
    mine(settler).social = now
    Life.stale(camp)
    if not Options.on(camp, "traditions") then return end
    addBuff(mine(settler).buffs, "hello", Life.helloBonus, now + Life.helloHours, "holiday")
    local veterans = {}
    for _, other in ipairs(Life.shelled(camp)) do
        if other ~= uid then veterans[#veterans + 1] = other end
    end
    if #veterans > 0 then say(veterans[Hooks.rand(#veterans)], "LfBarkWelcome", tostring(settler.name or uid)) end
end

function Life.onDied(camp, settler, uid)
    local life = Life.state(camp)
    local now = Store.hours()
    life.deaths[#life.deaths + 1] = now
    while #life.deaths > 5 do table.remove(life.deaths, 1) end
    Life.stale(camp)
    if not Options.on(camp, "traditions") then return end
    addBuff(life.buffs, "memorial", Life.memorialPenalty, now + Life.memorialHours, "loss")
    Life.enqueue(life, { k = "memorial", name = tostring(settler.name or uid) })
end

function Life.onRaidStart(camp, raid)
    local life = Life.state(camp)
    life.raidAt = Store.hours()
    life.raidSafe = nil
end

function Life.onRaidEnd(camp, raid, lost)
    local life = Life.state(camp)
    life.raidSafe = num(lost) == 0
    if life.raidSafe and Options.on(camp, "traditions") then Life.enqueue(life, { k = "victory" }) end
end

function Life.onDaily(camp, day, stats)
    local life = Life.state(camp)
    local built = num(camp.stats and camp.stats.built)
    local fresh = built - num(life.builtMark, built)
    life.builtMark = built
    local people = Store.settlerCount(camp)
    if people > 0 then
        Store.log(camp, "lf_digest", people, T("LfDigestTail", tostring(Life.mood(camp)), tostring(math.max(0, fresh))))
    end
    if Options.on(camp, "traditions") and day > 0 then
        local due = math.floor(day / Life.anniversary)
        if due > life.annivDone then
            life.annivDone = due
            life.feastDue = true
        end
    end
end

function Life.party(camp)
    local life = Life.state(camp)
    local now = Store.hours()
    local people = Store.settlerCount(camp)
    addBuff(life.buffs, "feast", Life.feastBonus, now + Life.feastHours, "holiday")
    life.gather = { kind = "party", e = now + Life.gatherMinutes.party / 60 }
    life.feasts = life.feasts + 1
    Store.log(camp, "lf_party", people)
    Life.stale(camp)
    Life.cheer(camp, "LfBarkFeast", Life.speakers)
    return people
end

function Life.setMood(camp, value, hold)
    local life = Life.state(camp)
    local now = Store.hours()
    local count = 0
    for uid, settler in pairs(camp.settlers) do
        Life.ensure(camp, uid, settler)
        local data = mine(settler)
        settler.mood = clamp(value, 0, 100)
        data.low = nil
        data.grumbled = nil
        if hold then addBuff(data.buffs, "cheat", Life.cheatBonus, now + Life.cheatHours, "holiday") end
        count = count + 1
    end
    life.lastLeft = nil
    return count
end

function Life.forceEvening(camp, minutes)
    local life = Life.state(camp)
    life.forcedUntil = Store.hours() + minutes / 60
    life.eveningDone = false
    life.eveningMinutes = 0
    Life.stale(camp)
    return minutes
end

function Life.stats(camp)
    local life = Life.state(camp)
    return {
        mood = Life.mood(camp), feasts = life.feasts, deserted = life.deserted,
        evenings = life.evenings, phase = Life.phase(camp),
    }
end

function Life.info(camp, uid, settler)
    local trait = settler.trait
    if Life.react[trait] == nil then trait = Life.traitOf(uid) end
    return { T("LfInfo", tostring(round(num(settler.mood, Life.startMood))), T("LfTrait_" .. trait)) }
end

function Life.word(mood)
    local index = 5
    if mood < 20 then
        index = 1
    elseif mood < 40 then
        index = 2
    elseif mood < 60 then
        index = 3
    elseif mood < 80 then
        index = 4
    end
    return T("LfMood_" .. index)
end

function Life.tint(mood)
    if mood < 25 then return 1, 0.45, 0.4 end
    if mood < 45 then return 0.95, 0.72, 0.4 end
    if mood < 65 then return 0.88, 0.88, 0.9 end
    if mood < 80 then return 0.6, 0.95, 0.65 end
    return 0.45, 1, 0.75
end

function Life.unhappy(camp)
    local list = {}
    for uid, settler in pairs(camp.settlers) do
        local mood = num(settler.mood, Life.startMood)
        if mood < Life.unhappyBelow then
            list[#list + 1] = { name = tostring(settler.name or uid), mood = round(mood), uid = tostring(uid) }
        end
    end
    table.sort(list, function(a, b)
        if a.mood ~= b.mood then return a.mood < b.mood end
        return a.uid < b.uid
    end)
    return list
end

function Life.daysToAnniversary(camp)
    return Life.anniversary - Store.day(camp) % Life.anniversary
end

function Life.extremes(camp)
    local view = Life.views[camp.id]
    if view == nil then return nil end
    local worstKey, worst, bestKey, best
    for _, key in ipairs(Life.factorOrder) do
        local value = view[key]
        if value ~= nil then
            if worst == nil or value < worst then worstKey, worst = key, value end
            if best == nil or value > best then bestKey, best = key, value end
        end
    end
    return worstKey, worst, bestKey, best
end

function Life.lines(camp)
    local life = Life.state(camp)
    if Store.settlerCount(camp) == 0 then return { Hooks.line(T("LfLineEmpty"), 0.7, 0.7, 0.75) } end
    local lines = {}
    local mood = Life.average(camp)
    local r, g, b = Life.tint(mood)
    lines[#lines + 1] = Hooks.line(T("LfLineMood", Life.word(mood), tostring(round(mood))), r, g, b)
    lines[#lines + 1] = Hooks.line(T("LfLinePhase", T("LfPhase_" .. Life.phase(camp))), 0.85, 0.85, 0.9)
    if not Options.on(camp, "rhythm") then lines[#lines + 1] = Hooks.line(T("LfLineRhythmOff"), 0.7, 0.7, 0.75) end
    local gather = Life.gathering(camp, life)
    if gather ~= nil then lines[#lines + 1] = Hooks.line(T("LfLineGather", T("LfGather_" .. gather.kind)), 1, 0.85, 0.4) end
    if not Options.on(camp, "traditions") then
        lines[#lines + 1] = Hooks.line(T("LfLineTraditionsOff"), 0.7, 0.7, 0.75)
    elseif life.feastDue == true then
        lines[#lines + 1] = Hooks.line(T("LfLineAnnivTonight"), 1, 0.85, 0.4)
    else
        lines[#lines + 1] = Hooks.line(T("LfLineAnniv", tostring(Life.daysToAnniversary(camp))), 0.9, 0.85, 0.6)
    end
    local unhappy = Life.unhappy(camp)
    if #unhappy == 0 then
        lines[#lines + 1] = Hooks.line(T("LfLineUnhappyNone"), 0.6, 0.9, 0.7)
    else
        local names = {}
        for index, row in ipairs(unhappy) do
            if index <= Life.unhappyShown then names[#names + 1] = T("LfUnhappyItem", row.name, tostring(row.mood)) end
        end
        lines[#lines + 1] = Hooks.line(T("LfLineUnhappy", table.concat(names, ", ")), 1, 0.55, 0.45)
    end
    local worstKey, worst, bestKey, best = Life.extremes(camp)
    if worstKey ~= nil and worst <= -3 then
        lines[#lines + 1] = Hooks.line(T("LfLineWorst", T("LfFactor_" .. worstKey), tostring(round(-worst))), 0.95, 0.7, 0.5)
    end
    if bestKey ~= nil and best >= 3 then
        lines[#lines + 1] = Hooks.line(T("LfLineBest", T("LfFactor_" .. bestKey), tostring(round(best))), 0.6, 0.9, 0.7)
    end
    lines[#lines + 1] = Hooks.line(T("LfLineStats", tostring(life.feasts), tostring(life.evenings), tostring(life.deserted)), 0.75, 0.75, 0.8)
    return lines
end

function Life.overview(camp)
    if Store.settlerCount(camp) == 0 then return {} end
    local mood = Life.average(camp)
    local r, g, b = Life.tint(mood)
    return { Hooks.line(T("LfOverview", Life.word(mood), tostring(round(mood)), T("LfPhase_" .. Life.phase(camp))), r, g, b) }
end

Options.define({ key = "rhythm", group = "life", kind = "toggle", default = true, priority = 30 })
Options.define({ key = "traditions", group = "life", kind = "toggle", default = true, priority = 31 })
Options.define({ key = "desertion", group = "life", kind = "toggle", default = true, priority = 32 })

Hooks.add("minute", function(camp, minutes) Life.step(camp, minutes) end)
Hooks.add("labor", function(camp) return Life.laborFactor(camp) end)
Hooks.add("morale", function(camp) return Life.moraleShift(camp) end)
Hooks.add("anchor", function(camp, uid, settler, current) return Life.anchor(camp, uid, settler, current) end, 40)
Hooks.add("settlerInfo", function(camp, uid, settler) return Life.info(camp, uid, settler) end)
Hooks.add("arrived", function(camp, settler, uid) Life.onArrived(camp, settler, uid) end)
Hooks.add("died", function(camp, settler, uid) Life.onDied(camp, settler, uid) end)
Hooks.add("raidstart", function(camp, raid) Life.onRaidStart(camp, raid) end)
Hooks.add("raidend", function(camp, raid, lost) Life.onRaidEnd(camp, raid, lost) end)
Hooks.add("daily", function(camp, day, stats) Life.onDaily(camp, day, stats) end)
Hooks.add("overview", function(camp) return Life.overview(camp) end)
Hooks.section("life", "LfSecLife", function(camp) return Life.lines(camp) end, 10)

return Life
