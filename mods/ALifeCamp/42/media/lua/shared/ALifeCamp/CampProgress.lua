require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Progress = {}
ALifeCamp.Progress = Progress

Progress.perPerson = 0.005
Progress.perLevel = 0.0002
Progress.skillShare = 1
Progress.crowd = 12
Progress.crowdShare = 0.5
Progress.dayBase = 4
Progress.dayPerson = 0.5
Progress.dayCap = 5
Progress.perBuilt = 10
Progress.perRecycled = 0.12
Progress.perHarvested = 0.08
Progress.perRepelled = 30
Progress.rebate = 0.1
Progress.autoHours = 6
Progress.checkEvery = 5
Progress.studyEvery = 15
Progress.studyDelay = 8
Progress.studyCap = 3
Progress.bookBase = 6
Progress.bookStep = 4
Progress.magazinePoints = 8
Progress.findBase = 0.12
Progress.findPerScout = 0.04
Progress.findScoutCap = 4
Progress.shelfLimit = 3
Progress.glowHours = 12
Progress.glowCap = 12
Progress.traceEvery = 60
Progress.recentCount = 3
Progress.paceDaysFrom = 72
Progress.logCap = 3
Progress.mark = "ALCpg"

Progress.branches = { "eco", "def", "life" }
Progress.branchColor = {
    eco = { 0.78, 0.9, 0.5 }, def = { 0.95, 0.68, 0.58 }, life = { 0.6, 0.85, 0.95 },
}
Progress.keys = { "build", "farm", "recycle", "heal", "clean", "trade", "mood", "morale", "defense" }
Progress.additive = { mood = true, morale = true, defense = true }
Progress.sources = { "Sanitary", "Health", "Life", "Council" }

Progress.techs = {
    { id = "rotation", branch = "eco", cost = 60, effects = { farm = 1.15 },
      reward = { { "Base.Nails", 20 }, { "Base.Rope", 2 } } },
    { id = "sorting", branch = "eco", cost = 80, effects = { recycle = 1.2 },
      reward = { { "Base.Nails", 30 }, { "Base.ScrapMetal", 4 } } },
    { id = "sawmill", branch = "eco", cost = 140, req = "sorting", effects = { build = 1.12 },
      reward = { { "Base.Plank", 12 }, { "Base.Nails", 20 } } },
    { id = "compost", branch = "eco", cost = 220, req = "rotation", effects = { farm = 1.25 },
      reward = { { "Base.Plank", 10 }, { "Base.Rope", 2 } } },
    { id = "forge", branch = "eco", cost = 320, req = "sorting", effects = { recycle = 1.3 },
      reward = { { "Base.Nails", 60 }, { "Base.ScrapMetal", 8 } } },
    { id = "logistics", branch = "eco", cost = 460, req = "sawmill", effects = { build = 1.2, trade = 1.1 },
      reward = { { "Base.Plank", 20 }, { "Base.Nails", 40 }, { "Base.Rope", 4 } } },
    { id = "watch", branch = "def", cost = 70, effects = { defense = 6 },
      reward = { { "Base.Bullets9mm", 12 } } },
    { id = "night", branch = "def", cost = 160, req = "watch", effects = { defense = 8, morale = 2 },
      reward = { { "Base.Bullets9mm", 16 } } },
    { id = "works", branch = "def", cost = 300, req = "watch", effects = { defense = 12 },
      reward = { { "Base.Plank", 16 }, { "Base.Nails", 40 } } },
    { id = "signal", branch = "def", cost = 440, req = "night", effects = { defense = 10, morale = 3 },
      reward = { { "Base.ScrapMetal", 6 }, { "Base.Rope", 3 } } },
    { id = "drill", branch = "def", cost = 700, req = "works", effects = { defense = 14 },
      reward = { { "Base.ShotgunShells", 12 }, { "Base.Bullets9mm", 24 } } },
    { id = "firstaid", branch = "life", cost = 70, effects = { heal = 1.2 },
      reward = { { "Base.Bandage", 5 } } },
    { id = "hygiene", branch = "life", cost = 90, effects = { clean = 1.25 },
      reward = { { "Base.Bandage", 3 }, { "Base.Disinfectant", 1 } } },
    { id = "infirmary", branch = "life", cost = 240, req = "firstaid", effects = { heal = 1.35 },
      reward = { { "Base.Bandage", 6 }, { "Base.Disinfectant", 2 } } },
    { id = "comfort", branch = "life", cost = 200, req = "hygiene", effects = { mood = 3, morale = 2 },
      reward = { { "Base.PeanutButter", 2 }, { "Base.Crackers", 4 } } },
    { id = "evenings", branch = "life", cost = 420, req = "comfort", effects = { mood = 5, morale = 3 },
      reward = { { "Base.CannedMilk", 3 }, { "Base.DehydratedMeatStick", 4 } } },
}

Progress.byId = {}
for index, tech in ipairs(Progress.techs) do
    tech.index = index
    Progress.byId[tech.id] = tech
    for order, name in ipairs(Progress.branches) do
        if name == tech.branch then tech.branchIndex = order end
    end
end

local function field(name)
    return function(c) return tonumber(c[name]) or 0 end
end

local function stat(name)
    return function(c) return tonumber(c.stats[name]) or 0 end
end

local function kind(name)
    return function(c) return c.kinds[name] or 0 end
end

local function outer(module, name)
    return function(c)
        local part = c.ext[module]
        if part == nil then return 0 end
        return tonumber(part[name]) or 0
    end
end

local function survived(c)
    local part = c.ext.Health
    if part == nil then return 0 end
    local count = tonumber(part.epidemics) or 0
    if part.epidemic == true then count = count - 1 end
    return math.max(0, count)
end

local function allBuilt(c)
    if c.total > 0 and c.finished == c.total then return c.finished end
    return math.min(c.finished, 5)
end

local function prize(points, glow, items)
    return { points = points, glow = glow, items = items }
end

Progress.achievements = {
    { id = "fence", goal = 1, read = kind("fence"), reward = prize(10, 2, { { "Base.Nails", 20 } }) },
    { id = "gate", goal = 1, read = field("gates"), reward = prize(10, 2, { { "Base.Plank", 6 } }) },
    { id = "post", goal = 1, read = kind("post"), reward = prize(25, 3, { { "Base.Nails", 40 }, { "Base.ScrapMetal", 4 } }) },
    { id = "vehicle", goal = 1, read = field("vehicles"), reward = prize(40, 4, { { "Base.ScrapMetal", 6 } }) },
    { id = "people5", goal = 5, read = field("people"), reward = prize(15, 2) },
    { id = "people10", goal = 10, read = field("people"), reward = prize(30, 3, { { "Base.Bandage", 4 } }) },
    { id = "people25", goal = 25, read = field("people"), reward = prize(60, 4, { { "Base.Plank", 20 } }) },
    { id = "people50", goal = 50, read = field("people"), reward = prize(120, 6) },
    { id = "days7", goal = 7, read = field("day"), reward = prize(15, 2) },
    { id = "days30", goal = 30, read = field("day"), reward = prize(50, 4) },
    { id = "days100", goal = 100, read = field("day"), reward = prize(150, 6) },
    { id = "recycle100", goal = 100, read = field("recycled"), reward = prize(15, 2, { { "Base.Nails", 30 } }) },
    { id = "recycle1000", goal = 1000, read = field("recycled"), reward = prize(60, 3, { { "Base.Nails", 100 }, { "Base.ScrapMetal", 10 } }) },
    { id = "cleared", goal = 1000, read = stat("cleared"), reward = prize(20, 2, { { "Base.Plank", 10 } }) },
    { id = "harvest", goal = 1, read = stat("harvested"), reward = prize(10, 2, { { "Base.Potato", 4 } }) },
    { id = "level2", goal = 2, read = field("level"), reward = prize(20, 3) },
    { id = "level3", goal = 3, read = field("level"), reward = prize(40, 4) },
    { id = "level4", goal = 4, read = field("level"), reward = prize(80, 5) },
    { id = "repel1", goal = 1, read = stat("repelled"), reward = prize(30, 4, { { "Base.Bullets9mm", 10 } }) },
    { id = "repel10", goal = 10, read = stat("repelled"), reward = prize(100, 6, { { "Base.ShotgunShells", 10 } }) },
    { id = "skill5", goal = 5, read = field("skill"), reward = prize(25, 3) },
    { id = "skill10", goal = 10, read = field("skill"), reward = prize(80, 5) },
    { id = "allbuilt", goal = 6, read = allBuilt, reward = prize(50, 4, { { "Base.Plank", 20 }, { "Base.Nails", 50 } }) },
    { id = "san_bury", src = "Sanitary", goal = 5, read = outer("Sanitary", "buried"), reward = prize(20, 2) },
    { id = "san_clean", src = "Sanitary", goal = 50, read = outer("Sanitary", "removed"), reward = prize(25, 2) },
    { id = "san_graves", src = "Sanitary", goal = 3, read = outer("Sanitary", "graves"), reward = prize(15, 2) },
    { id = "health_recover", src = "Health", goal = 5, read = outer("Health", "recovered"), reward = prize(25, 3, { { "Base.Bandage", 3 } }) },
    { id = "health_epidemic", src = "Health", goal = 1, read = survived, reward = prize(40, 4, { { "Base.Disinfectant", 1 } }) },
    { id = "life_feast", src = "Life", goal = 1, read = outer("Life", "feasts"), reward = prize(20, 4) },
    { id = "life_evenings", src = "Life", goal = 10, read = outer("Life", "evenings"), reward = prize(30, 4) },
    { id = "council_resolved", src = "Council", goal = 1, read = outer("Council", "resolved"), reward = prize(15, 2) },
    { id = "council_trades", src = "Council", goal = 3, read = outer("Council", "trades"), reward = prize(30, 3) },
    { id = "council_rep", src = "Council", goal = 20, read = outer("Council", "rep"), reward = prize(40, 4) },
    { id = "tech1", goal = 1, read = field("techs"), reward = prize(10, 2) },
    { id = "techall", goal = #Progress.techs, read = field("techs"), reward = prize(150, 6) },
}

Progress.achById = {}
for index, entry in ipairs(Progress.achievements) do
    entry.index = index
    Progress.achById[entry.id] = entry
end

Progress.library = {
    "Base.BookCarpentry1", "Base.BookCooking1", "Base.BookFarming1", "Base.BookFirstAid1", "Base.BookMechanic1",
    "Base.BookMetalWelding1", "Base.BookTailoring1", "Base.BookTrapping1", "Base.BookForaging1", "Base.BookFishing1",
    "Base.BookElectrician1", "Base.BookMaintenance1", "Base.BookCarpentry2", "Base.BookFarming2", "Base.BookFirstAid2",
    "Base.FarmingMag1", "Base.CookingMag1", "Base.MechanicMag1", "Base.ElectronicsMag1", "Base.TailoringMag1",
    "Base.HuntingMag1", "Base.MetalworkMag1", "Base.FishingMag1", "Base.EngineerMagazine1",
}

Progress.views = {}

local function whole(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function shown(value)
    return tostring(math.floor((tonumber(value) or 0) * 100 + 0.5) / 100)
end

local function plural(key, count)
    local n = math.floor(math.abs(tonumber(count) or 0))
    local last, tens = n % 10, math.floor(n / 10) % 10
    local form = "5"
    if tens ~= 1 then
        if last == 1 then
            form = "1"
        elseif last >= 2 and last <= 4 then
            form = "2"
        end
    end
    return T(key .. form, tostring(n))
end

local function techName(id)
    return T("PgT_" .. id)
end

local function achName(id)
    return T("PgA_" .. id)
end

local function notify(camp, key, a, b)
    local work = ALifeCamp.Work
    if work == nil or type(work.notify) ~= "function" then return end
    if b ~= nil then
        pcall(work.notify, camp, key, a, b)
    else
        pcall(work.notify, camp, key, a)
    end
end

local function validItem(fullType)
    local work = ALifeCamp.Work
    if work ~= nil and type(work.validItem) == "function" then
        local ok, valid = pcall(work.validItem, fullType)
        if ok then return valid == true end
    end
    return true
end

local function give(camp, fullType, count)
    if count <= 0 or not validItem(fullType) then return false end
    local ok, done = pcall(Stock.deposit, camp, fullType, count)
    return ok and done == true
end

local function payout(camp, items)
    local given = false
    for _, row in ipairs(items or {}) do
        if give(camp, row[1], row[2]) then given = true end
    end
    return given
end

local function itemName(fullType)
    local name
    pcall(function() name = getItemNameFromFullType(fullType) end)
    if name == nil or name == "" then return fullType end
    return name
end

function Progress.viewOf(camp)
    local view = Progress.views[camp.id]
    if view == nil then
        view = {}
        Progress.views[camp.id] = view
    end
    return view
end

function Progress.state(camp)
    local p = camp.progress
    if type(p) ~= "table" then
        p = {}
        camp.progress = p
    end
    if type(p.done) ~= "table" then p.done = {} end
    if type(p.ach) ~= "table" then p.ach = {} end
    if type(p.clock) ~= "table" then p.clock = {} end
    p.bank = math.max(0, tonumber(p.bank) or 0)
    p.spent = math.max(0, tonumber(p.spent) or 0)
    p.earned = math.max(0, tonumber(p.earned) or 0)
    p.books = math.max(0, tonumber(p.books) or 0)
    local tech = p.current ~= nil and Progress.byId[p.current] or nil
    if tech == nil or p.done[p.current] ~= nil or not Progress.unlocked(p, tech) then
        p.bank = p.bank + p.spent
        p.spent = 0
        p.current = nil
    elseif p.spent > tech.cost then
        p.bank = p.bank + p.spent - tech.cost
        p.spent = tech.cost
    end
    return p
end

function Progress.bonus(camp, key)
    local additive = Progress.additive[key] == true
    local value = additive and 0 or 1
    local p = type(camp) == "table" and camp.progress or nil
    if type(p) ~= "table" or type(p.done) ~= "table" then return value end
    for _, tech in ipairs(Progress.techs) do
        local effect = tech.effects[key]
        if effect ~= nil and p.done[tech.id] ~= nil then
            if additive then
                value = value + effect
            else
                value = value * effect
            end
        end
    end
    return value
end

function Progress.has(camp, id)
    local p = type(camp) == "table" and camp.progress or nil
    return type(p) == "table" and type(p.done) == "table" and p.done[id] ~= nil
end

function Progress.glow(camp)
    local p = type(camp) == "table" and camp.progress or nil
    if type(p) ~= "table" or type(p.glow) ~= "table" then return 0 end
    local left = 1 - (Store.hours() - (tonumber(p.glow.at) or 0)) / Progress.glowHours
    if left <= 0 then return 0 end
    return (tonumber(p.glow.value) or 0) * left
end

local function addGlow(p, amount, now)
    local current = 0
    if type(p.glow) == "table" then
        local left = 1 - (now - (tonumber(p.glow.at) or 0)) / Progress.glowHours
        if left > 0 then current = (tonumber(p.glow.value) or 0) * left end
    end
    p.glow = { value = math.min(Progress.glowCap, current + amount), at = now }
end

function Progress.unlocked(p, tech)
    return tech.req == nil or p.done[tech.req] ~= nil
end

function Progress.available(p)
    local list = {}
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] == nil and Progress.unlocked(p, tech) then list[#list + 1] = tech end
    end
    table.sort(list, function(a, b)
        if a.branchIndex ~= b.branchIndex then return a.branchIndex < b.branchIndex end
        if a.cost ~= b.cost then return a.cost < b.cost end
        return a.index < b.index
    end)
    return list
end

function Progress.cheapest(p)
    local best
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] == nil and Progress.unlocked(p, tech) then
            if best == nil or tech.cost < best.cost then best = tech end
        end
    end
    return best
end

function Progress.percent(p, tech)
    if tech == nil or tech.cost <= 0 then return 0 end
    return math.max(0, math.min(100, math.floor(p.spent * 100 / tech.cost)))
end

function Progress.rate(camp)
    local people = Store.settlerCount(camp)
    if people <= 0 then return 0 end
    local crowd = math.min(people, Progress.crowd) + math.max(0, people - Progress.crowd) * Progress.crowdShare
    local base = crowd * Progress.perPerson
    local levels = 0
    local skills = ALifeCamp.Skills
    if skills ~= nil then
        for _, settler in pairs(camp.settlers) do
            local ok, total = pcall(skills.totalLevel, settler)
            if ok and type(total) == "number" then levels = levels + total end
        end
    end
    return base + math.min(levels * Progress.perLevel, base * Progress.skillShare)
end

function Progress.perDay(camp, rate)
    local people = Store.settlerCount(camp)
    if people <= 0 then return 0 end
    return (rate or Progress.rate(camp)) * 1440 + Progress.dayBase + Progress.dayPerson * people
end

function Progress.finish(camp, p, tech, now, quiet)
    p.done[tech.id] = now
    if p.current == tech.id then
        p.bank = p.bank + math.max(0, p.spent - tech.cost)
        p.current = nil
        p.spent = 0
    end
    p.idleSince = now
    if quiet then return end
    local bonus = math.floor(tech.cost * Progress.rebate)
    p.bank = p.bank + bonus
    p.earned = p.earned + bonus
    payout(camp, tech.reward)
    local name = techName(tech.id)
    Store.log(camp, "pg_done", name, tostring(bonus))
    notify(camp, "PgDone", name)
end

function Progress.advance(camp, p, now)
    local tech = p.current ~= nil and Progress.byId[p.current] or nil
    if tech == nil then return end
    local move = math.min(p.bank, tech.cost - p.spent)
    if move > 0 then
        p.bank = p.bank - move
        p.spent = p.spent + move
    end
    if p.spent >= tech.cost - 0.000001 then Progress.finish(camp, p, tech, now, false) end
end

function Progress.credit(camp, p, amount, now)
    if amount <= 0 then return 0 end
    p.bank = p.bank + amount
    p.earned = p.earned + amount
    Progress.advance(camp, p, now)
    return amount
end

function Progress.add(camp, points)
    points = tonumber(points)
    if type(camp) ~= "table" or points == nil or points <= 0 then return 0 end
    return Progress.credit(camp, Progress.state(camp), points, Store.hours())
end

function Progress.select(camp, id)
    local p = Progress.state(camp)
    local tech = Progress.byId[id]
    if tech == nil then return false, "unknown" end
    if p.done[id] ~= nil then return false, "done" end
    if not Progress.unlocked(p, tech) then return false, "locked" end
    if p.current == id then return true end
    p.bank = p.bank + p.spent
    p.spent = 0
    p.current = id
    p.idleSince = nil
    Progress.advance(camp, p, Store.hours())
    return true
end

function Progress.auto(camp, p, now)
    if p.current ~= nil then
        p.idleSince = nil
        return
    end
    local pick = Progress.cheapest(p)
    if pick == nil then
        p.idleSince = nil
        return
    end
    if p.idleSince == nil then
        p.idleSince = now
        return
    end
    if Options.on(camp, "autoResearch") and now - p.idleSince >= Progress.autoHours then
        if Progress.select(camp, pick.id) then Store.log(camp, "pg_auto", techName(pick.id)) end
    end
end

function Progress.unlockAll(camp)
    local p = Progress.state(camp)
    local now = Store.hours()
    local count = 0
    p.bank = p.bank + p.spent
    p.spent = 0
    p.current = nil
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] == nil then
            Progress.finish(camp, p, tech, now, true)
            count = count + 1
        end
    end
    return count
end

local function counter(seen, name, current)
    current = tonumber(current) or 0
    local before = seen[name]
    seen[name] = current
    if before == nil or current <= before then return 0 end
    return current - before
end

function Progress.prime(camp, p)
    if type(p.seen) == "table" then return end
    local stats = type(camp.stats) == "table" and camp.stats or {}
    p.seen = {
        built = tonumber(stats.built) or 0,
        harvested = tonumber(stats.harvested) or 0,
        repelled = tonumber(stats.repelled) or 0,
        recycled = tonumber(camp.recycledTotal) or 0,
        day = Store.day(camp),
    }
end

function Progress.windfall(camp, p, now)
    local seen = p.seen
    local stats = type(camp.stats) == "table" and camp.stats or {}
    local gained = 0
    gained = gained + counter(seen, "built", stats.built) * Progress.perBuilt
    gained = gained + counter(seen, "harvested", stats.harvested) * Progress.perHarvested
    gained = gained + counter(seen, "repelled", stats.repelled) * Progress.perRepelled
    gained = gained + counter(seen, "recycled", camp.recycledTotal) * Progress.perRecycled
    local day = Store.day(camp)
    local before = tonumber(seen.day) or day
    seen.day = day
    if day > before then
        local people = Store.settlerCount(camp)
        if people > 0 then
            gained = gained + math.min(day - before, Progress.dayCap) * (Progress.dayBase + Progress.dayPerson * people)
            if Options.on(camp, "pgReadBooks") then pcall(Progress.discover, camp, p, now) end
        end
    end
    return gained
end

function Progress.bookValue(item)
    local category, full = "", ""
    pcall(function()
        category = tostring(item:getDisplayCategory() or "")
        full = tostring(item:getFullType() or "")
    end)
    local skillBook = category == "SkillBook" or (category == "" and string.find(full, "^Base%.Book%a+%d$") ~= nil)
    if skillBook then
        local level = tonumber(string.match(full, "(%d+)$")) or 1
        return Progress.bookBase + Progress.bookStep * level
    end
    if category == "RecipeResource" and (string.find(full, "Mag%d*$") ~= nil or string.find(full, "Magazine%d*$") ~= nil) then
        return Progress.magazinePoints
    end
    return nil
end

local function shelfAge(item, now)
    local stamp
    local ok = pcall(function()
        local data = item:getModData()
        stamp = data[Progress.mark]
        if stamp == nil then data[Progress.mark] = now end
    end)
    if not ok then return Progress.studyDelay end
    if type(stamp) ~= "number" then return 0 end
    return now - stamp
end

function Progress.study(camp, p, now)
    local view = Progress.viewOf(camp)
    view.shelf = 0
    if Store.settlerCount(camp) <= 0 then return 0 end
    local read, points, waiting = 0, 0, 0
    for _, entry in ipairs(camp.storage or {}) do
        local crate = Stock.crate(camp, entry)
        local container
        if crate ~= nil then pcall(function() container = crate:getContainer() end) end
        if container ~= nil then
            pcall(function()
                local items = container:getItems()
                for i = items:size() - 1, 0, -1 do
                    local item = items:get(i)
                    local value = Progress.bookValue(item)
                    if value ~= nil then
                        local age = shelfAge(item, now)
                        if read < Progress.studyCap and age >= Progress.studyDelay then
                            container:Remove(item)
                            read = read + 1
                            points = points + value
                        else
                            waiting = waiting + 1
                        end
                    end
                end
            end)
        end
    end
    view.shelf = waiting
    if read > 0 then
        p.books = p.books + read
        Progress.credit(camp, p, points, now)
        Store.log(camp, "pg_book", tostring(read), tostring(points))
    end
    return read
end

function Progress.discover(camp, p, now)
    local view = Progress.viewOf(camp)
    if (view.shelf or 0) >= Progress.shelfLimit then return false end
    local scouts = 0
    for _, settler in pairs(camp.settlers) do
        if settler.role == "scavenger" then scouts = scouts + 1 end
    end
    local chance = Progress.findBase + Progress.findPerScout * math.min(scouts, Progress.findScoutCap)
    if Hooks.rand(100) > whole(chance * 100) then return false end
    local fullType = Progress.library[Hooks.rand(#Progress.library)]
    if fullType == nil or not give(camp, fullType, 1) then return false end
    view.shelf = (view.shelf or 0) + 1
    local name = itemName(fullType)
    Store.log(camp, "pg_found", name)
    notify(camp, "PgFound", name)
    return true
end

local function gatesOf(project)
    local gates = ALifeCamp.Gates
    if gates ~= nil and type(gates.of) == "function" then
        local ok, list = pcall(gates.of, project)
        if ok and type(list) == "table" then return #list end
    end
    return 1
end

function Progress.gather(camp, p)
    local ctx = { camp = camp, kinds = {}, ext = {}, total = 0, finished = 0, gates = 0, vehicles = 0, skill = 0, techs = 0 }
    ctx.stats = type(camp.stats) == "table" and camp.stats or {}
    ctx.people = Store.settlerCount(camp)
    ctx.day = Store.day(camp)
    ctx.level = tonumber(camp.level) or 1
    ctx.recycled = tonumber(camp.recycledTotal) or 0
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] ~= nil then ctx.techs = ctx.techs + 1 end
    end
    local build = ALifeCamp.Build
    if build ~= nil then
        local ok, plan = pcall(build.plan, camp)
        if ok and type(plan) == "table" and type(plan.items) == "table" then
            for _, project in pairs(plan.items) do
                ctx.total = ctx.total + 1
                if project.status == "done" then
                    ctx.finished = ctx.finished + 1
                    ctx.kinds[project.kind] = (ctx.kinds[project.kind] or 0) + 1
                    if project.kind == "fence" then ctx.gates = ctx.gates + gatesOf(project) end
                end
            end
        end
    end
    local motor = camp.motor
    if type(motor) == "table" and type(motor.parked) == "table" then
        for _ in pairs(motor.parked) do ctx.vehicles = ctx.vehicles + 1 end
    end
    local skills = ALifeCamp.Skills
    if skills ~= nil then
        for _, settler in pairs(camp.settlers) do
            local ok, _, level = pcall(skills.best, settler)
            if ok and type(level) == "number" and level > ctx.skill then ctx.skill = level end
        end
    end
    for _, name in ipairs(Progress.sources) do
        local module = ALifeCamp[name]
        if type(module) == "table" and type(module.stats) == "function" then
            local ok, part = pcall(module.stats, camp)
            if ok and type(part) == "table" then ctx.ext[name] = part end
        end
    end
    return ctx
end

function Progress.sourceReady(entry)
    if entry.src == nil then return true end
    local module = ALifeCamp[entry.src]
    return type(module) == "table" and type(module.stats) == "function"
end

function Progress.rewardText(entry)
    local reward = entry.reward
    if reward == nil then return "" end
    if reward.items ~= nil then return T("PgRewardItems", tostring(reward.points or 0)) end
    return T("PgRewardPts", tostring(reward.points or 0))
end

function Progress.grant(camp, id, quiet)
    local entry = Progress.achById[id]
    if entry == nil then return false end
    local p = Progress.state(camp)
    if p.ach[id] ~= nil then return false end
    local now = Store.hours()
    p.ach[id] = now
    if quiet then return true end
    local reward = entry.reward
    if reward ~= nil then
        if (reward.points or 0) > 0 then Progress.credit(camp, p, reward.points, now) end
        payout(camp, reward.items)
        if (reward.glow or 0) > 0 then addGlow(p, reward.glow, now) end
    end
    return true
end

function Progress.grantAll(camp)
    local count = 0
    for _, entry in ipairs(Progress.achievements) do
        if Progress.grant(camp, entry.id, true) then count = count + 1 end
    end
    return count
end

function Progress.announce(camp, opened)
    for i, entry in ipairs(opened) do
        if i <= Progress.logCap then Store.log(camp, "pg_ach", achName(entry.id), Progress.rewardText(entry)) end
    end
    if #opened > Progress.logCap then Store.log(camp, "pg_achmore", tostring(#opened - Progress.logCap)) end
    if #opened == 1 then
        notify(camp, "PgAchieved", achName(opened[1].id))
    elseif #opened > 1 then
        notify(camp, "PgAchievedMany", achName(opened[1].id), tostring(#opened - 1))
    end
end

function Progress.check(camp, p)
    local ctx = Progress.gather(camp, p)
    local view = Progress.viewOf(camp)
    local values, opened = {}, {}
    local near, nearRatio
    for _, entry in ipairs(Progress.achievements) do
        if p.ach[entry.id] == nil and Progress.sourceReady(entry) then
            local ok, value = pcall(entry.read, ctx)
            if not ok or type(value) ~= "number" then value = 0 end
            values[entry.id] = value
            if value >= entry.goal then
                opened[#opened + 1] = entry
            else
                local ratio = value / entry.goal
                if near == nil or ratio > nearRatio then near, nearRatio = entry, ratio end
            end
        end
    end
    view.values = values
    view.near = near ~= nil and { id = near.id, value = values[near.id], goal = near.goal } or nil
    for _, entry in ipairs(opened) do Progress.grant(camp, entry.id, false) end
    if #opened > 0 then Progress.announce(camp, opened) end
    return #opened
end

function Progress.achievementCounts(p)
    local open, total = 0, 0
    for _, entry in ipairs(Progress.achievements) do
        local has = p.ach[entry.id] ~= nil
        if has then open = open + 1 end
        if has or Progress.sourceReady(entry) then total = total + 1 end
    end
    return open, total
end

function Progress.recent(p, count)
    local list = {}
    for index, entry in ipairs(Progress.achievements) do
        local stamp = p.ach[entry.id]
        if stamp ~= nil then list[#list + 1] = { entry = entry, at = tonumber(stamp) or 0, index = index } end
    end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.index < b.index
    end)
    local out = {}
    for i = 1, math.min(count, #list) do out[i] = list[i].entry end
    return out
end

function Progress.stats(camp)
    local p = Progress.state(camp)
    local done = 0
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] ~= nil then done = done + 1 end
    end
    local open, total = Progress.achievementCounts(p)
    local tech = p.current ~= nil and Progress.byId[p.current] or nil
    return {
        done = done,
        total = #Progress.techs,
        current = p.current or "",
        points = math.floor(p.bank + p.spent),
        achievements = open,
        achievementsTotal = total,
        percent = Progress.percent(p, tech),
        bank = math.floor(p.bank),
        earned = math.floor(p.earned),
        books = p.books,
    }
end

function Progress.trace(camp, p)
    local s = Progress.stats(camp)
    local view = Progress.viewOf(camp)
    print("[ALifeCamp:Progress] camp=" .. tostring(camp.id) .. " tech=" .. s.done .. "/" .. s.total
        .. " cur=" .. (s.current ~= "" and s.current or "-") .. " pct=" .. s.percent .. " pts=" .. s.points
        .. " earned=" .. s.earned .. " ach=" .. s.achievements .. "/" .. s.achievementsTotal
        .. " perday=" .. whole(Progress.perDay(camp, view.rate)) .. " books=" .. s.books .. " shelf=" .. (view.shelf or 0))
end

function Progress.step(camp, minutes)
    minutes = tonumber(minutes) or 1
    if minutes <= 0 then return end
    local p = Progress.state(camp)
    local now = Store.hours()
    Progress.prime(camp, p)
    local view = Progress.viewOf(camp)
    local rate = Progress.rate(camp)
    view.rate = rate
    local ok, extra = pcall(Progress.windfall, camp, p, now)
    local gained = rate * minutes + ((ok and type(extra) == "number") and extra or 0)
    if gained > 0 then Progress.credit(camp, p, gained, now) end
    Progress.advance(camp, p, now)
    local clock = p.clock
    clock.check = (tonumber(clock.check) or Progress.checkEvery) + minutes
    if clock.check >= Progress.checkEvery then
        clock.check = 0
        pcall(Progress.check, camp, p)
    end
    clock.study = (tonumber(clock.study) or Progress.studyEvery) + minutes
    if clock.study >= Progress.studyEvery then
        clock.study = 0
        if Options.on(camp, "pgReadBooks") then
            pcall(Progress.study, camp, p, now)
        else
            view.shelf = 0
        end
    end
    pcall(Progress.auto, camp, p, now)
    clock.trace = (tonumber(clock.trace) or 0) + minutes
    if clock.trace >= Progress.traceEvery then
        clock.trace = 0
        pcall(Progress.trace, camp, p)
    end
end

function Progress.effectText(tech)
    local parts = {}
    for _, key in ipairs(Progress.keys) do
        local value = tech.effects[key]
        if value ~= nil then parts[#parts + 1] = T("PgEff_" .. key, shown(value)) end
    end
    return table.concat(parts, ", ")
end

function Progress.overview(camp)
    local s = Progress.stats(camp)
    local text
    if s.current ~= "" then
        text = T("PgOverview", tostring(s.done), tostring(s.total), techName(s.current), plural("PgPct", s.percent))
    elseif s.done >= s.total then
        text = T("PgOverviewDone", tostring(s.done), tostring(s.total))
    else
        text = T("PgOverviewIdle", tostring(s.done), tostring(s.total))
    end
    return { Hooks.line(text, 0.7, 0.9, 0.8) }
end

function Progress.researchLines(camp)
    local p = Progress.state(camp)
    local view = Progress.viewOf(camp)
    local now = Store.hours()
    local lines = {}
    local function add(line, indent)
        if indent ~= nil then line.indent = indent end
        lines[#lines + 1] = line
    end
    local perDay = Progress.perDay(camp, view.rate)
    local available = Progress.available(p)
    local current = p.current ~= nil and Progress.byId[p.current] or nil
    if current ~= nil then
        add(Hooks.line(T("PgCurrent", techName(current.id), tostring(math.floor(p.spent)), tostring(current.cost),
            plural("PgPct", Progress.percent(p, current))), 1, 0.85, 0.35))
        add(Hooks.line(T("PgD_" .. current.id), 0.75, 0.75, 0.8), 18)
        if perDay > 0 then
            local hours = math.max(1, math.ceil((current.cost - p.spent) / (perDay / 24)))
            if hours >= Progress.paceDaysFrom then
                add(Hooks.line(T("PgPaceDays", tostring(whole(perDay)), tostring(math.ceil(hours / 24))), 0.7, 0.85, 0.7), 18)
            else
                add(Hooks.line(T("PgPace", tostring(whole(perDay)), tostring(hours)), 0.7, 0.85, 0.7), 18)
            end
        else
            add(Hooks.line(T("PgPaceNone"), 0.95, 0.6, 0.5), 18)
        end
    elseif #available > 0 then
        add(Hooks.line(T("PgChoose", tostring(math.floor(p.bank))), 1, 0.85, 0.35))
        if Options.on(camp, "autoResearch") then
            local left = Progress.autoHours - (p.idleSince ~= nil and (now - p.idleSince) or 0)
            add(Hooks.line(T("PgAutoIn", tostring(math.max(0, math.ceil(left)))), 0.7, 0.7, 0.75), 18)
        else
            add(Hooks.line(T("PgAutoOff"), 0.7, 0.7, 0.75), 18)
        end
    else
        add(Hooks.line(T("PgAllDone", tostring(math.floor(p.bank))), 0.6, 0.95, 0.65))
    end
    if #available > 0 then
        add(Hooks.line(""))
        add(Hooks.line(T("PgHdrAvail"), 0.6, 0.85, 1))
        for _, tech in ipairs(available) do
            local color = Progress.branchColor[tech.branch]
            local branch = T("PgBranch_" .. tech.branch)
            if tech.id == p.current then
                add(Hooks.line(T("PgRowNow", techName(tech.id), branch), 1, 0.85, 0.35), 10)
            else
                local id = tech.id
                add(Hooks.line(T("PgRow", techName(id), branch, tostring(tech.cost), Progress.effectText(tech)),
                    color[1], color[2], color[3], function(c) Progress.select(c, id) end), 10)
            end
        end
    end
    local locked = {}
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] == nil and not Progress.unlocked(p, tech) then locked[#locked + 1] = tech end
    end
    if #locked > 0 then
        add(Hooks.line(""))
        add(Hooks.line(T("PgHdrLocked"), 0.6, 0.85, 1))
        for _, tech in ipairs(locked) do
            add(Hooks.line(T("PgLockedRow", techName(tech.id), tostring(tech.cost), techName(tech.req)), 0.6, 0.6, 0.66), 10)
        end
    end
    local finished = {}
    for _, tech in ipairs(Progress.techs) do
        if p.done[tech.id] ~= nil then finished[#finished + 1] = tech end
    end
    if #finished > 0 then
        add(Hooks.line(""))
        add(Hooks.line(T("PgHdrDone"), 0.6, 0.85, 1))
        for _, tech in ipairs(finished) do
            add(Hooks.line(T("PgDoneRow", techName(tech.id), Progress.effectText(tech)), 0.6, 0.9, 0.7), 10)
        end
    end
    if Options.on(camp, "pgReadBooks") then
        add(Hooks.line(""))
        if p.books > 0 or (view.shelf or 0) > 0 then
            add(Hooks.line(T("PgLibrary", tostring(p.books), tostring(view.shelf or 0)), 0.8, 0.75, 0.95))
        end
        add(Hooks.line(T("PgLibraryHint", tostring(Progress.studyDelay)), 0.62, 0.62, 0.68))
    end
    return lines
end

function Progress.achieveLines(camp)
    local p = Progress.state(camp)
    local view = Progress.viewOf(camp)
    local lines = {}
    local open, total = Progress.achievementCounts(p)
    lines[#lines + 1] = Hooks.line(T("PgAchCount", tostring(open), tostring(total)), 1, 0.85, 0.35)
    local recent = Progress.recent(p, Progress.recentCount)
    if #recent == 0 then
        lines[#lines + 1] = Hooks.line(T("PgAchNone"), 0.7, 0.7, 0.75)
    else
        lines[#lines + 1] = Hooks.line(T("PgAchRecentHdr"), 0.6, 0.85, 1)
    end
    for _, entry in ipairs(recent) do
        local line = Hooks.line(T("PgAchRecent", achName(entry.id), T("PgAD_" .. entry.id)), 0.6, 0.9, 0.7)
        line.indent = 10
        lines[#lines + 1] = line
    end
    local near = view.near
    if near ~= nil and Progress.achById[near.id] ~= nil and p.ach[near.id] == nil then
        lines[#lines + 1] = Hooks.line(T("PgAchNear", achName(near.id), T("PgAD_" .. near.id),
            tostring(math.floor(near.value)), tostring(near.goal)), 0.85, 0.85, 0.95)
    elseif open >= total then
        lines[#lines + 1] = Hooks.line(T("PgAchAll"), 0.6, 0.95, 0.65)
    end
    local glow = Progress.glow(camp)
    if glow >= 0.5 then
        lines[#lines + 1] = Hooks.line(T("PgGlow", tostring(whole(glow))), 0.95, 0.8, 0.5)
    end
    return lines
end

Options.define({ key = "autoResearch", group = "life", kind = "toggle", default = true, priority = 40 })
Options.define({ key = "pgReadBooks", group = "life", kind = "toggle", default = true, priority = 41 })

Hooks.add("minute", function(camp, minutes) Progress.step(camp, minutes) end)
Hooks.add("labor", function(camp) return Progress.bonus(camp, "build") end)
Hooks.add("farm", function(camp) return Progress.bonus(camp, "farm") end)
Hooks.add("recycle", function(camp) return Progress.bonus(camp, "recycle") end)
Hooks.add("morale", function(camp) return Progress.bonus(camp, "morale") + Progress.glow(camp) end)
Hooks.add("defense", function(camp) return Progress.bonus(camp, "defense") end)
Hooks.add("overview", function(camp) return Progress.overview(camp) end)
Hooks.section("progress", "PgSecResearch", function(camp) return Progress.researchLines(camp) end, 10)
Hooks.section("progress", "PgSecAchieve", function(camp) return Progress.achieveLines(camp) end, 20)

return Progress
