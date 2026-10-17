dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = nil
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = nil
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Hooks, Options, Stock, Stats, Work, Skills, Recycle, Cheats, Progress =
    A.Store, A.Camp, A.Hooks, A.Options, A.Stock, A.Stats, A.Work, A.Skills, A.Recycle, A.Cheats, A.Progress
local T = A.T

for x = 90, 170 do for y = 90, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
MOCKALIFE()
function getItemNameFromFullType(fullType) return "Item " .. fullType end
local INVALID = {}
function getScriptManager()
    return { FindItem = function(_, fullType) if INVALID[fullType] then return nil end return { fullType = fullType } end }
end

local silentAtStart = #SILENT
local neverFind = function(n) return n end
local realRand = neverFind
Hooks.rand = neverFind

local function newCamp(x1, name)
    local camp = Camp.create({ x1 = x1, y1 = 100, x2 = x1 + 15, y2 = 112, z = 0 }, name, { demolish = false })
    camp.settlers = {}
    camp.options.autoResearch = false
    return camp
end

local function people(camp, count, role)
    camp.settlers = {}
    for i = 1, count do camp.settlers["u" .. i] = { name = "S" .. i, role = role or "builder", since = 0 } end
end

local function advance(target, minutes, step)
    step = step or 5
    local left = minutes
    while left > 0 do
        local dt = math.min(step, left)
        HOURS = HOURS + dt / 60
        Hooks.each("minute", target, dt)
        left = left - dt
    end
end

local function plain(value, path, seen)
    local kind = type(value)
    if kind == "function" or kind == "userdata" or kind == "thread" then return false, path end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return false, path .. " (nan/inf)" end
        return true
    end
    if kind ~= "table" then return true end
    if seen[value] then return false, path .. " (cycle)" end
    seen[value] = true
    local count, max = 0, 0
    for k, v in pairs(value) do
        if type(k) ~= "string" and type(k) ~= "number" then return false, path .. " (key type)" end
        if type(k) == "number" then
            count = count + 1
            if k > max then max = k end
        end
        local ok, where = plain(v, path .. "." .. tostring(k), seen)
        if not ok then return false, where end
    end
    seen[value] = nil
    if count > 0 and max ~= count then return false, path .. " (holes)" end
    return true
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

local function size(value)
    if type(value) ~= "table" then return 1 end
    local n = 1
    for _, v in pairs(value) do n = n + size(v) end
    return n
end

local function crateOf(camp)
    return Stock.crate(camp, camp.storage[1])
end

local function contents(camp)
    local out = {}
    for _, entry in ipairs(camp.storage) do
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then
            local items = crate:getContainer():getItems()
            for i = 0, items:size() - 1 do
                local full = items:get(i):getFullType()
                out[full] = (out[full] or 0) + 1
            end
        end
    end
    return out
end

local function emptyCrates(camp)
    for _, entry in ipairs(camp.storage) do
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then crate:getContainer().items = {} end
    end
end

local function logKinds(camp)
    local out = {}
    for _, entry in ipairs(camp.log) do out[entry.k] = (out[entry.k] or 0) + 1 end
    return out
end

local function hasLine(lines, text)
    for _, line in ipairs(lines) do
        if line.text == text then return true end
    end
    return false
end

local function noteCount(from, text)
    local count = 0
    for i = from + 1, #PLAYER.notes do
        if PLAYER.notes[i] == text then count = count + 1 end
    end
    return count
end

local function charCount(text)
    local _, count = string.gsub(text, "[^\128-\191]", "")
    return count
end

local function sourceOf(path)
    local handle = io.open(path, "r")
    if handle == nil then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function book(full, category, marked)
    local item = NEWITEM(full)
    item.cat = category
    if not marked then
        function item:getModData() error("no mod data on this item") end
    end
    return item
end

local function research(camp, id)
    local ok = Progress.select(camp, id)
    Progress.add(camp, Progress.byId[id].cost + 1)
    return ok and camp.progress.done[id] ~= nil
end

do
    check("module exported", Progress ~= nil and type(Progress.bonus) == "function" and type(Progress.add) == "function" and type(Progress.stats) == "function")
    check("tree size", #Progress.techs == 16, #Progress.techs)
    check("achievements about thirty", #Progress.achievements >= 30 and #Progress.achievements <= 40, #Progress.achievements)

    local good, why = true, nil
    local branchCount = { eco = 0, def = 0, life = 0 }
    local seenIds = {}
    for _, tech in ipairs(Progress.techs) do
        local ok = seenIds[tech.id] == nil and tech.cost > 0 and branchCount[tech.branch] ~= nil and type(tech.effects) == "table" and not ALifeCamp.isEmpty(tech.effects)
        seenIds[tech.id] = true
        if ok then branchCount[tech.branch] = branchCount[tech.branch] + 1 end
        if tech.req ~= nil and Progress.byId[tech.req] == nil then ok = false end
        for key in pairs(tech.effects) do
            local known = false
            for _, name in ipairs(Progress.keys) do if name == key then known = true end end
            if not known then ok = false end
        end
        if not ok and good then good, why = false, tech.id end
    end
    check("tech catalog consistent", good, why)
    check("three branches", branchCount.eco >= 4 and branchCount.def >= 4 and branchCount.life >= 4, branchCount.eco .. "/" .. branchCount.def .. "/" .. branchCount.life)

    local maxDepth, acyclic = 0, true
    for _, tech in ipairs(Progress.techs) do
        local depth, guard, walker = 0, 0, tech
        while walker.req ~= nil and guard < 40 do
            walker = Progress.byId[walker.req]
            depth, guard = depth + 1, guard + 1
        end
        if guard >= 40 then acyclic = false end
        if depth > maxDepth then maxDepth = depth end
    end
    check("requirements acyclic and chained", acyclic and maxDepth >= 2, maxDepth)

    local keySeen = {}
    for _, tech in ipairs(Progress.techs) do for key in pairs(tech.effects) do keySeen[key] = true end end
    local allKeys = true
    for _, key in ipairs(Progress.keys) do if not keySeen[key] then allKeys = false end end
    check("every bonus key has a tech", allKeys)

    local achGood, achWhy = true, nil
    for _, entry in ipairs(Progress.achievements) do
        local ok = entry.goal > 0 and type(entry.read) == "function" and entry.reward ~= nil and entry.reward.points > 0
        if not ok and achGood then achGood, achWhy = false, entry.id end
    end
    check("achievement catalog consistent", achGood, achWhy)

    local totalCost = 0
    for _, tech in ipairs(Progress.techs) do totalCost = totalCost + tech.cost end
    check("tree cost is a long goal", totalCost >= 3000, totalCost)
end

do
    local camp = newCamp(100, "Options")
    local spec = Options.byKey.autoResearch
    check("option defined", spec ~= nil and spec.group == "life" and spec.kind == "toggle" and spec.default == true)
    camp.options.autoResearch = nil
    check("option default on", Options.on(camp, "autoResearch") == true)
    check("option has texts", A.TN("Opt_autoResearch") ~= nil and A.TN("OptHint_autoResearch") ~= nil)
    local books = Options.byKey.pgReadBooks
    check("books option defined", books ~= nil and books.group == "life" and books.kind == "toggle" and books.default == true)
    check("books option on by default", Options.on(camp, "pgReadBooks") == true and A.TN("Opt_pgReadBooks") ~= nil and A.TN("OptHint_pgReadBooks") ~= nil)
    check("books option listed in settings", (function()
        for _, line in ipairs(Options.lines(camp)) do
            if line.text == T("OptRow", T("Opt_pgReadBooks"), T("OptOn")) then return true end
        end
        return false
    end)())
    check("option listed in settings", (function()
        for _, line in ipairs(Options.lines(camp)) do
            if line.text == T("OptRow", T("Opt_autoResearch"), T("OptOn")) then return true end
        end
        return false
    end)())
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Empty")
    local s0 = Progress.stats(camp)
    check("stats shape", s0.done == 0 and s0.total == 16 and s0.current == "" and s0.points == 0 and s0.achievements == 0 and type(s0.achievementsTotal) == "number")
    check("stats total counts only ready sources", s0.achievementsTotal == #Progress.achievements - 10, s0.achievementsTotal)
    check("bonus defaults multiply", Progress.bonus(camp, "farm") == 1 and Progress.bonus(camp, "build") == 1 and Progress.bonus(camp, "heal") == 1
        and Progress.bonus(camp, "clean") == 1 and Progress.bonus(camp, "trade") == 1 and Progress.bonus(camp, "recycle") == 1)
    check("bonus defaults add", Progress.bonus(camp, "defense") == 0 and Progress.bonus(camp, "mood") == 0 and Progress.bonus(camp, "morale") == 0)
    check("bonus unknown key neutral", Progress.bonus(camp, "nothing") == 1)
    check("bonus nil camp", Progress.bonus(nil, "farm") == 1 and Progress.bonus(nil, "defense") == 0)
    check("hooks neutral without techs", Hooks.product("labor", camp) == 1 and Hooks.product("farm", camp) == 1 and Hooks.product("recycle", camp) == 1
        and Hooks.sum("defense", camp) == 0 and Hooks.sum("morale", camp) == 0)

    people(camp, 0)
    check("no people no rate", Progress.rate(camp) == 0 and Progress.perDay(camp) == 0)
    advance(camp, 180, 1)
    check("no people no points", Progress.stats(camp).points == 0 and Progress.stats(camp).earned == 0)
    check("no people overview line", #Progress.overview(camp) == 1 and hasLine(Hooks.overview(camp), Progress.overview(camp)[1].text))
    Progress.select(camp, "rotation")
    local pace = false
    for _, line in ipairs(Progress.researchLines(camp)) do
        if line.text == T("PgPaceNone") then pace = true end
    end
    check("no people pace line", pace)
    check("selection works without people", camp.progress.current == "rotation")
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Income")
    people(camp, 5)
    Progress.grantAll(camp)
    advance(camp, 1, 1)
    local before = Progress.stats(camp).points
    advance(camp, 60, 1)
    local hourGain = Progress.stats(camp).points - before
    check("points accrue per minute", hourGain >= 1 and hourGain <= 3, hourGain)
    check("rate with five settlers", math.abs(Progress.rate(camp) - 5 * Progress.perPerson) < 1e-9, Progress.rate(camp))

    before = Progress.stats(camp).points
    advance(camp, 1440, 5)
    local dayGain = Progress.stats(camp).points - before
    check("day income at five settlers", dayGain >= 40 and dayGain <= 48, dayGain)
    local stats = Progress.stats(camp)
    check("bank grows without selection", stats.current == "" and stats.bank == stats.points and camp.progress.current == nil)

    for _, settler in pairs(camp.settlers) do settler.skills = { build = Skills.xpFor(4), farm = Skills.xpFor(2) } end
    local withSkills = Progress.rate(camp)
    check("skills raise the rate", withSkills > 5 * Progress.perPerson and withSkills <= 10 * Progress.perPerson + 1e-9, withSkills)
    for _, settler in pairs(camp.settlers) do settler.skills = { build = Skills.xpFor(10), farm = Skills.xpFor(10), guard = Skills.xpFor(10) } end
    check("skill share is capped", Progress.rate(camp) <= 5 * Progress.perPerson * (1 + Progress.skillShare) + 1e-9)
    for _, settler in pairs(camp.settlers) do settler.skills = nil end
    people(camp, 40)
    local crowdRate = Progress.rate(camp)
    check("crowd rate is damped", crowdRate < 40 * Progress.perPerson and crowdRate > 12 * Progress.perPerson, crowdRate)
    people(camp, 5)

    local bank = camp.progress.bank
    check("bank flows into research on select", Progress.select(camp, "rotation") == true and camp.progress.current == "rotation" and camp.progress.bank == 0 and math.abs(camp.progress.spent - bank) < 1e-9)
    check("select same is noop", Progress.select(camp, "rotation") == true and math.abs(camp.progress.spent - bank) < 1e-9)
    check("select unknown", select(2, Progress.select(camp, "nope")) == "unknown")
    check("select locked refused", Progress.select(camp, "compost") == false and select(2, Progress.select(camp, "compost")) == "locked")
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Auto")
    camp.options.autoResearch = nil
    people(camp, 5)
    local firstDoneAt
    local startHours = HOURS
    for _ = 1, 96 do
        advance(camp, 30, 5)
        if firstDoneAt == nil and Progress.stats(camp).done >= 1 then firstDoneAt = (HOURS - startHours) / 24 end
    end
    check("auto picked the cheapest first", camp.progress.done.rotation ~= nil, tostring(camp.progress.current))
    check("first cheap tech within one to two days", firstDoneAt ~= nil and firstDoneAt >= 0.9 and firstDoneAt <= 2, firstDoneAt)
    check("auto select logged", (logKinds(camp).pg_auto or 0) >= 1)
    check("auto picks next cheapest available", camp.progress.current == "watch" or camp.progress.done.watch ~= nil, tostring(camp.progress.current))
    Camp.abandon(camp)

    camp = newCamp(100, "AutoWait")
    camp.options.autoResearch = nil
    people(camp, 5)
    advance(camp, 5 * 60, 5)
    check("auto waits for six hours", camp.progress.current == nil)
    advance(camp, 70, 5)
    check("auto picks after six hours", camp.progress.current == "rotation", camp.progress.current)
    camp.progress.current, camp.progress.spent, camp.progress.bank = nil, 0, 0
    camp.progress.done.rotation = 1
    camp.progress.idleSince = HOURS - 7
    advance(camp, 5, 5)
    check("auto prefers the cheapest after dependencies", camp.progress.current == "watch", tostring(camp.progress.current))
    Camp.abandon(camp)

    camp = newCamp(100, "AutoOff")
    people(camp, 5)
    Progress.grantAll(camp)
    camp.options.autoResearch = false
    advance(camp, 24 * 60, 10)
    check("auto off never selects", camp.progress.current == nil and Progress.stats(camp).bank > 20)
    Options.set(camp, "autoResearch", true)
    advance(camp, 5, 5)
    check("turning auto on selects at once when idle is long", camp.progress.current == "rotation", tostring(camp.progress.current))
    Camp.abandon(camp)

    camp = newCamp(100, "Switch")
    people(camp, 3)
    Progress.select(camp, "rotation")
    camp.progress.spent = 40
    check("switch refunds progress", Progress.select(camp, "watch") == true and camp.progress.current == "watch" and camp.progress.spent == 40 and camp.progress.bank == 0)
    check("switch back keeps points", Progress.select(camp, "rotation") == true and camp.progress.current == "rotation" and camp.progress.spent == 40)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Complete")
    people(camp, 5)
    Progress.select(camp, "rotation")
    local notesBefore = #PLAYER.notes
    check("add returns amount", Progress.add(camp, 60) == 60)
    check("tech completed", camp.progress.done.rotation ~= nil and camp.progress.current == nil and camp.progress.spent == 0)
    check("rebate goes to bank", camp.progress.bank == 6, camp.progress.bank)
    check("completion notified once", noteCount(notesBefore, T("PgDone", camp.name, T("PgT_rotation"))) == 1)
    check("completion logged", (logKinds(camp).pg_done or 0) == 1)
    check("completion rewards items", (contents(camp)["Base.Nails"] or 0) == 20 and (contents(camp)["Base.Rope"] or 0) == 2, tostring(contents(camp)["Base.Nails"]))
    check("select done refused", select(2, Progress.select(camp, "rotation")) == "done")
    check("compost unlocked by rotation", Progress.select(camp, "compost") == true)
    check("add ignores bad input", Progress.add(camp, -5) == 0 and Progress.add(camp, "x") == 0 and Progress.add(nil, 5) == 0 and Progress.add(camp, 0) == 0)
    Progress.select(camp, "firstaid")
    local held = camp.progress.bank + camp.progress.spent
    Progress.add(camp, 100)
    check("overflow carries to bank", camp.progress.done.firstaid ~= nil and camp.progress.bank == held + 100 - 70 + 7, camp.progress.bank)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Invalid")
    people(camp, 3)
    INVALID["Base.Nails"] = true
    Progress.select(camp, "rotation")
    Progress.add(camp, 60)
    INVALID["Base.Nails"] = nil
    check("invalid reward items are skipped", camp.progress.done.rotation ~= nil and (contents(camp)["Base.Nails"] or 0) == 0 and (contents(camp)["Base.Rope"] or 0) == 2)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Effects")
    people(camp, 5)
    camp.plan = { items = {}, serial = 0 }
    local laborBase = Work.labor(camp)
    local defenseBase = Stats.compute(camp).defense
    local moraleBase = Stats.compute(camp).morale

    local function junkCrate(count)
        local container = crateOf(camp):getContainer()
        for i = 1, count do
            local item = NEWITEM("Base.Junk" .. i)
            item.cat = "Junk"
            item.mod = {}
            function item:getModData() return self.mod end
            function item:getActualWeight() return 0.5 end
            Recycle.flag(item)
            container:AddItem(item)
        end
    end
    local function processed()
        local before = camp.recycledTotal or 0
        junkCrate(60)
        camp.kitGiven = true
        Work.recycleStep(camp, 1)
        emptyCrates(camp)
        return (camp.recycledTotal or 0) - before
    end
    local function harvestOnce()
        camp.plan = { items = { ["1"] = { id = 1, kind = "farm", status = "done", x = 105, y = 105, w = 5, h = 4 } }, serial = 1 }
        camp.farmClock = 24
        local before = camp.stats.harvested
        Work.farm(camp, 1)
        return camp.stats.harvested - before
    end

    local recycleBase = processed()
    local farmBase = harvestOnce()
    check("baseline recycle budget", recycleBase >= 5, recycleBase)
    check("baseline harvest", farmBase == 14, farmBase)

    check("rotation researched", research(camp, "rotation"))
    check("farm hook after rotation", math.abs(Hooks.product("farm", camp) - 1.15) < 1e-9)
    check("harvest grows with rotation", harvestOnce() == 16)
    check("compost researched", research(camp, "compost"))
    check("farm hook stacks", math.abs(Progress.bonus(camp, "farm") - 1.15 * 1.25) < 1e-9)
    check("harvest grows with compost", harvestOnce() == 20)

    check("sorting researched", research(camp, "sorting"))
    check("recycle hook after sorting", math.abs(Hooks.product("recycle", camp) - 1.2) < 1e-9)
    local recycle1 = processed()
    check("recycling speeds up with sorting", recycle1 > recycleBase, recycle1 .. " vs " .. recycleBase)
    check("forge researched", research(camp, "forge"))
    local recycle2 = processed()
    check("recycling speeds up with forge", recycle2 > recycle1 and math.abs(Progress.bonus(camp, "recycle") - 1.2 * 1.3) < 1e-9, recycle2 .. " vs " .. recycle1)

    check("sawmill needs sorting", research(camp, "sawmill"))
    check("labor hook after sawmill", math.abs(Hooks.product("labor", camp) - 1.12) < 1e-9)
    check("work labor grows", math.abs(Work.labor(camp) / laborBase - 1.12) < 1e-6, Work.labor(camp) .. " vs " .. laborBase)
    check("logistics researched", research(camp, "logistics"))
    check("build bonus stacks and trade exposed", math.abs(Progress.bonus(camp, "build") - 1.12 * 1.2) < 1e-9 and math.abs(Progress.bonus(camp, "trade") - 1.1) < 1e-9)

    check("watch researched", research(camp, "watch"))
    check("defense hook", Hooks.sum("defense", camp) == 6 and Progress.bonus(camp, "defense") == 6)
    check("stats defense includes tech", Stats.compute(camp).defense == defenseBase + 6, Stats.compute(camp).defense .. " vs " .. defenseBase)
    check("night researched", research(camp, "night"))
    check("morale bonus from tech", Progress.bonus(camp, "morale") == 2 and Stats.compute(camp).morale == moraleBase + 2, Stats.compute(camp).morale .. " vs " .. moraleBase)
    check("defense stacks", Progress.bonus(camp, "defense") == 14)
    check("infirmary needs first aid", research(camp, "firstaid") and research(camp, "infirmary"))
    check("heal bonus exposed", math.abs(Progress.bonus(camp, "heal") - 1.2 * 1.35) < 1e-9)
    check("hygiene researched", research(camp, "hygiene"))
    check("clean bonus exposed", math.abs(Progress.bonus(camp, "clean") - 1.25) < 1e-9)
    check("comfort and evenings researched", research(camp, "comfort") and research(camp, "evenings"))
    check("mood bonus is additive", Progress.bonus(camp, "mood") == 8 and Progress.bonus(camp, "morale") == 2 + 2 + 3)
    check("has helper", Progress.has(camp, "evenings") == true and Progress.has(camp, "drill") == false and Progress.has(nil, "x") == false)
    check("rest of the defense branch", research(camp, "works") and research(camp, "signal") and research(camp, "drill"))
    check("tree complete", Progress.stats(camp).done == 16 and Progress.stats(camp).current == "")
    check("defense total", Progress.bonus(camp, "defense") == 6 + 8 + 12 + 10 + 14)
    check("morale total", Progress.bonus(camp, "morale") == 2 + 3 + 2 + 3)
    check("tree complete overview", Progress.overview(camp)[1].text == T("PgOverviewDone", "16", "16") and hasLine(Hooks.overview(camp), T("PgOverviewDone", "16", "16")), Progress.overview(camp)[1].text)
    check("tree complete research lines", Progress.researchLines(camp)[1].text == T("PgAllDone", tostring(math.floor(camp.progress.bank))))
    check("select after complete refused", Progress.select(camp, "drill") == false)
    check("tree complete achievement", (function()
        camp.progress.clock.check = 99
        advance(camp, 5, 5)
        return camp.progress.ach.techall ~= nil and camp.progress.ach.tech1 ~= nil
    end)())
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Achievements")
    people(camp, 6)
    camp.plan = { items = {}, serial = 0 }
    camp.stats.harvested, camp.stats.repelled, camp.recycledTotal, camp.level = 5, 1, 120, 2
    local earnedBefore = Progress.stats(camp).earned
    local notesBefore = #PLAYER.notes
    advance(camp, 5, 5)
    local p = camp.progress
    check("harvest achievement", p.ach.harvest ~= nil)
    check("repel achievement", p.ach.repel1 ~= nil)
    check("recycle achievement", p.ach.recycle100 ~= nil and p.ach.recycle1000 == nil)
    check("level achievement", p.ach.level2 ~= nil and p.ach.level3 == nil)
    check("people achievement", p.ach.people5 ~= nil and p.ach.people10 == nil)
    check("no unearned achievements", p.ach.fence == nil and p.ach.post == nil and p.ach.vehicle == nil and p.ach.days7 == nil and p.ach.skill5 == nil and p.ach.allbuilt == nil and p.ach.tech1 == nil)
    check("achievement rewards points", Progress.stats(camp).earned >= earnedBefore + 90, Progress.stats(camp).earned)
    check("achievement rewards items", (contents(camp)["Base.Potato"] or 0) == 4 and (contents(camp)["Base.Bullets9mm"] or 0) == 10 and (contents(camp)["Base.Nails"] or 0) == 30, tostring(contents(camp)["Base.Potato"]))
    check("achievement glow active", Progress.glow(camp) > 5, Progress.glow(camp))
    check("glow feeds morale hook", Hooks.sum("morale", camp) > Progress.bonus(camp, "morale") + 5)
    check("achievements logged and capped", (logKinds(camp).pg_ach or 0) == 3 and (logKinds(camp).pg_achmore or 0) == 1, tostring(logKinds(camp).pg_ach) .. "/" .. tostring(logKinds(camp).pg_achmore))
    local expectedNote = T("PgAchievedMany", camp.name, T("PgA_people5"), "4")
    check("many achievements produce one popup naming the first and the rest", noteCount(notesBefore, expectedNote) == 1)
    local open = Progress.stats(camp).achievements
    advance(camp, 5, 5)
    check("achievements not granted twice", Progress.stats(camp).achievements == open)

    local glowNow = Progress.glow(camp)
    HOURS = HOURS + 6
    local glowHalf = Progress.glow(camp)
    check("glow decays", glowHalf < glowNow and glowHalf > 0, glowNow .. " -> " .. glowHalf)
    HOURS = HOURS + 7
    check("glow gone after twelve hours", Progress.glow(camp) == 0 and Hooks.sum("morale", camp) == Progress.bonus(camp, "morale"))
    Progress.grant(camp, "people50", false)
    Progress.grant(camp, "days100", false)
    Progress.grant(camp, "skill10", false)
    check("glow cap respected", Progress.glow(camp) <= Progress.glowCap + 1e-9 and Progress.glow(camp) > Progress.glowCap - 0.1, Progress.glow(camp))
    check("grant unknown", Progress.grant(camp, "bogus", false) == false)
    check("grant twice refused", Progress.grant(camp, "people50", false) == false)
    local plainOk, plainWhy = plain(camp.progress, "progress", {})
    check("state plain after play", plainOk, plainWhy)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Buildings")
    people(camp, 5)
    camp.settlers.u1.skills = { build = Skills.xpFor(5) }
    camp.settlers.u2.skills = { farm = Skills.xpFor(10) }
    camp.motor = { parked = { a = { military = true } } }
    local items = {}
    for i = 1, 6 do items[tostring(i)] = { id = i, kind = i == 1 and "fence" or (i == 2 and "post" or "shed"), status = "done", x = 100 + i, y = 100, w = 4, h = 3 } end
    camp.plan = { items = items, serial = 6 }
    advance(camp, 5, 5)
    local p = camp.progress
    check("fence and gate achievements", p.ach.fence ~= nil and p.ach.gate ~= nil)
    check("post achievement", p.ach.post ~= nil)
    check("vehicle achievement", p.ach.vehicle ~= nil)
    check("skill achievements", p.ach.skill5 ~= nil and p.ach.skill10 ~= nil)
    check("all built achievement", p.ach.allbuilt ~= nil)
    camp.plan.items["7"] = { id = 7, kind = "shed", status = "active", x = 130, y = 100, w = 4, h = 3 }
    p.ach.allbuilt = nil
    p.clock.check = 99
    advance(camp, 5, 5)
    check("all built needs all projects", p.ach.allbuilt == nil)
    local near = Progress.viewOf(camp).near
    check("near achievement tracked", near ~= nil and Progress.achById[near.id] ~= nil and near.value < near.goal)
    camp.stats.cleared = 1000
    p.clock.check = 99
    advance(camp, 5, 5)
    check("cleared achievement", p.ach.cleared ~= nil)
    HOURS = HOURS + 24 * 8
    p.clock.check = 99
    advance(camp, 5, 5)
    check("days achievement", p.ach.days7 ~= nil and p.ach.days30 == nil)

    local savedModules = { Sanitary = A.Sanitary, Health = A.Health, Life = A.Life, Council = A.Council }
    A.Sanitary = { stats = function() return { buried = 6, removed = 10, graves = 3 } end }
    A.Health = { stats = function() error("health exploded") end }
    A.Life = { stats = function() return { feasts = 1, evenings = 4 } end }
    A.Council = { stats = function() return { resolved = 2, trades = 1, rep = 7 } end }
    p.clock.check = 99
    local silentBefore = #SILENT
    advance(camp, 5, 5)
    check("external sanitary achievements", p.ach.san_bury ~= nil and p.ach.san_graves ~= nil and p.ach.san_clean == nil)
    check("external life achievements", p.ach.life_feast ~= nil and p.ach.life_evenings == nil)
    check("external council achievements", p.ach.council_resolved ~= nil and p.ach.council_rep == nil and p.ach.council_trades == nil)
    check("failing external module ignored", p.ach.health_recover == nil and p.ach.health_epidemic == nil)
    check("external failure was swallowed", #SILENT > silentBefore)
    check("total counts external modules", Progress.stats(camp).achievementsTotal == #Progress.achievements, Progress.stats(camp).achievementsTotal)
    A.Health = { stats = function() return { recovered = 9, epidemics = 1, epidemic = true } end }
    A.Council = { stats = function() return { resolved = 2, trades = 1, rep = 25 } end }
    p.clock.check = 99
    advance(camp, 5, 5)
    check("running epidemic is not survived yet", p.ach.health_recover ~= nil and p.ach.health_epidemic == nil)
    check("good reputation achievement", p.ach.council_rep ~= nil)
    A.Health = { stats = function() return { recovered = 9, epidemics = 1, epidemic = false } end }
    p.clock.check = 99
    advance(camp, 5, 5)
    check("finished epidemic is survived", p.ach.health_epidemic ~= nil)
    A.Sanitary, A.Health, A.Life, A.Council = nil, nil, nil, nil
    local opened = Progress.stats(camp).achievements
    local totalWithout = Progress.stats(camp).achievementsTotal
    check("total shrinks without modules but keeps opened", totalWithout == #Progress.achievements - 10 + 7, totalWithout)
    check("open never exceeds total", opened <= totalWithout, opened)
    p.clock.check = 99
    advance(camp, 5, 5)
    check("camp keeps working without external modules", Progress.stats(camp).achievements == opened)
    A.Sanitary, A.Health, A.Life, A.Council = savedModules.Sanitary, savedModules.Health, savedModules.Life, savedModules.Council
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Bulk")
    people(camp, 3)
    Progress.select(camp, "sorting")
    Progress.add(camp, 30)
    check("unlock all counts", Progress.unlockAll(camp) == 16 and Progress.stats(camp).done == 16 and Progress.stats(camp).current == "")
    check("unlock all keeps points", camp.progress.bank == 30 and camp.progress.spent == 0, camp.progress.bank)
    check("unlock all is quiet", (logKinds(camp).pg_done or 0) == 0 and ALifeCamp.isEmpty(contents(camp)))
    check("unlock all idempotent", Progress.unlockAll(camp) == 0)
    local granted = Progress.grantAll(camp)
    check("grant all", granted == #Progress.achievements and Progress.stats(camp).achievements == #Progress.achievements, granted)
    check("grant all is quiet", (logKinds(camp).pg_ach or 0) == 0 and Progress.glow(camp) == 0)
    check("grant all idempotent", Progress.grantAll(camp) == 0)
    local lines = Progress.achieveLines(camp)
    check("achieve lines when all open", lines[1].text == T("PgAchCount", tostring(#Progress.achievements), tostring(#Progress.achievements)) and lines[#lines].text == T("PgAchAll"))
    check("research lines when tree done", Progress.researchLines(camp)[1].text == T("PgAllDone", "30"))
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Library")
    people(camp, 4)
    advance(camp, 5, 5)
    HOURS = HOURS + 1
    emptyCrates(camp)
    local container = crateOf(camp):getContainer()
    container:AddItem(book("Base.BookCarpentry3", "SkillBook", true))
    container:AddItem(book("Base.FarmingMag1", "RecipeResource", true))
    container:AddItem(book("Base.CarrotBagSeed2_Empty", "RecipeResource", true))
    container:AddItem(book("Base.Book", "Literature", true))
    container:AddItem(book("Base.Plank", "", true))
    local view = Progress.viewOf(camp)
    check("book value skill", Progress.bookValue(book("Base.BookCarpentry3", "SkillBook")) == Progress.bookBase + Progress.bookStep * 3)
    check("book value level scales", Progress.bookValue(book("Base.BookCooking5", "SkillBook")) > Progress.bookValue(book("Base.BookCooking1", "SkillBook")))
    check("book value magazine", Progress.bookValue(book("Base.FarmingMag1", "RecipeResource")) == Progress.magazinePoints)
    check("book value herbalist magazine", Progress.bookValue(book("Base.HerbalistMag", "RecipeResource")) == Progress.magazinePoints)
    check("book value engineer magazine", Progress.bookValue(book("Base.EngineerMagazine2", "RecipeResource")) == Progress.magazinePoints)
    check("book value by name when category is unknown", Progress.bookValue(book("Base.BookFirstAid2", "")) == Progress.bookBase + Progress.bookStep * 2)
    check("seed bag is not a book", Progress.bookValue(book("Base.CarrotBagSeed2_Empty", "RecipeResource")) == nil)
    check("plain literature is not read", Progress.bookValue(book("Base.Book", "Literature")) == nil and Progress.bookValue(book("Base.Plank", "")) == nil)
    check("book value survives broken item", Progress.bookValue({}) == nil)

    local earnedBefore = Progress.stats(camp).earned
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("fresh books wait", camp.progress.books == 0 and view.shelf == 2, tostring(view.shelf))
    check("fresh books stay in the crate", (contents(camp)["Base.BookCarpentry3"] or 0) == 1 and (contents(camp)["Base.FarmingMag1"] or 0) == 1)
    HOURS = HOURS + Progress.studyDelay + 0.5
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("books are read after the delay", camp.progress.books == 2, camp.progress.books)
    check("read books are consumed", (contents(camp)["Base.BookCarpentry3"] or 0) == 0 and (contents(camp)["Base.FarmingMag1"] or 0) == 0)
    check("other items untouched", (contents(camp)["Base.CarrotBagSeed2_Empty"] or 0) == 1 and (contents(camp)["Base.Book"] or 0) == 1 and (contents(camp)["Base.Plank"] or 0) == 1)
    check("books give points", Progress.stats(camp).earned - earnedBefore >= Progress.bookBase + Progress.bookStep * 3 + Progress.magazinePoints, Progress.stats(camp).earned - earnedBefore)
    check("books logged", (logKinds(camp).pg_book or 0) == 1)
    check("shelf empty after reading", view.shelf == 0)

    emptyCrates(camp)
    container = crateOf(camp):getContainer()
    for i = 1, 5 do container:AddItem(book("Base.BookFarming" .. i, "SkillBook", true)) end
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    HOURS = HOURS + Progress.studyDelay + 0.5
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("reading is capped per scan", camp.progress.books == 2 + Progress.studyCap, camp.progress.books)
    check("rest waits for the next scan", view.shelf == 2, tostring(view.shelf))
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("next scan finishes the shelf", camp.progress.books == 2 + 5 and view.shelf == 0, camp.progress.books)

    emptyCrates(camp)
    crateOf(camp):getContainer():AddItem(book("Base.BookMechanic2", "SkillBook", false))
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("items without mod data are read at once", camp.progress.books == 8 and (contents(camp)["Base.BookMechanic2"] or 0) == 0)

    emptyCrates(camp)
    container = crateOf(camp):getContainer()
    container:AddItem(book("Base.BookTailoring1", "SkillBook", true))
    container:AddItem(book("Base.BookTailoring2", "SkillBook", true))
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    local kept = camp.settlers
    camp.settlers = {}
    HOURS = HOURS + 10
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("nobody reads without people", (contents(camp)["Base.BookTailoring1"] or 0) == 1)
    camp.settlers = kept
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("people read again", (contents(camp)["Base.BookTailoring1"] or 0) == 0)

    camp.options.pgReadBooks = false
    emptyCrates(camp)
    crateOf(camp):getContainer():AddItem(book("Base.BookCooking2", "SkillBook", true))
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    HOURS = HOURS + Progress.studyDelay + 1
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("reading off leaves books alone", (contents(camp)["Base.BookCooking2"] or 0) == 1 and view.shelf == 0)
    local hintShown = false
    for _, line in ipairs(Progress.researchLines(camp)) do
        if line.text == T("PgLibraryHint", tostring(Progress.studyDelay)) then hintShown = true end
    end
    check("reading off hides the library hint", not hintShown)
    camp.options.pgReadBooks = true
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("reading on starts the delay for a waiting book", (contents(camp)["Base.BookCooking2"] or 0) == 1 and view.shelf == 1)
    HOURS = HOURS + Progress.studyDelay + 1
    camp.progress.clock.study = 99
    advance(camp, 1, 1)
    check("reading on picks the book up", (contents(camp)["Base.BookCooking2"] or 0) == 0)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Finds")
    people(camp, 3)
    advance(camp, 5, 5)
    emptyCrates(camp)
    Hooks.rand = function(n) return 1 end
    Progress.viewOf(camp).shelf = 0
    check("discover adds a book", Progress.discover(camp, camp.progress, HOURS) == true and (contents(camp)[Progress.library[1]] or 0) == 1)
    check("discover logged", (logKinds(camp).pg_found or 0) == 1)
    check("discover notified", noteCount(0, T("PgFound", camp.name, getItemNameFromFullType(Progress.library[1]))) >= 1)
    check("discover raises shelf", Progress.viewOf(camp).shelf == 1)
    Progress.viewOf(camp).shelf = Progress.shelfLimit
    check("discover respects shelf limit", Progress.discover(camp, camp.progress, HOURS) == false)
    Progress.viewOf(camp).shelf = 0
    Hooks.rand = function(n) if n == 100 then return 100 end return 1 end
    check("discover can miss", Progress.discover(camp, camp.progress, HOURS) == false)
    Hooks.rand = function(n) return 1 end
    local kept = camp.storage
    camp.storage = {}
    check("discover without storage is harmless", Progress.discover(camp, camp.progress, HOURS) == false)
    camp.storage = { { x = 999, y = 999, z = 0 } }
    check("pending storage accepts books", Progress.discover(camp, camp.progress, HOURS) == true and camp.storage[1].add ~= nil)
    advance(camp, 20, 5)
    camp.storage = kept
    Hooks.rand = realRand
    Camp.abandon(camp)

    camp = newCamp(100, "Daily")
    people(camp, 3, "scavenger")
    Hooks.rand = function(n) return 1 end
    advance(camp, 5, 5)
    HOURS = HOURS + 24
    advance(camp, 5, 5)
    Hooks.rand = realRand
    check("daily discovery through the minute hook", (logKinds(camp).pg_found or 0) == 1, tostring(logKinds(camp).pg_found))
    check("daily points granted", camp.progress.earned >= Progress.dayBase + Progress.dayPerson * 3, camp.progress.earned)
    Camp.abandon(camp)

    camp = newCamp(100, "NoBooks")
    people(camp, 3, "scavenger")
    camp.options.pgReadBooks = false
    Hooks.rand = function(n) return 1 end
    advance(camp, 5, 5)
    HOURS = HOURS + 24
    advance(camp, 5, 5)
    Hooks.rand = realRand
    check("no discoveries with reading off", (logKinds(camp).pg_found or 0) == 0 and Progress.stats(camp).earned > 0)
    Camp.abandon(camp)

    camp = newCamp(100, "Chance")
    people(camp, 5, "scavenger")
    local rolls = {}
    Hooks.rand = function(n) rolls[#rolls + 1] = n return n end
    Progress.discover(camp, Progress.state(camp), HOURS)
    Hooks.rand = realRand
    check("discover rolls a percent die", rolls[1] == 100)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Counters")
    people(camp, 2)
    camp.stats.built, camp.recycledTotal, camp.stats.harvested, camp.stats.repelled = 3, 500, 100, 2
    Progress.grantAll(camp)
    advance(camp, 1, 1)
    local primed = Progress.stats(camp).earned
    check("existing counters are not paid retroactively", primed < 1, primed)
    camp.stats.built = camp.stats.built + 2
    advance(camp, 1, 1)
    local builtGain = Progress.stats(camp).earned - primed
    check("projects pay points", builtGain >= 2 * Progress.perBuilt and builtGain < 2 * Progress.perBuilt + 1, builtGain)
    local mark = Progress.stats(camp).earned
    camp.recycledTotal = camp.recycledTotal + 100
    advance(camp, 1, 1)
    check("recycling pays points", math.abs(Progress.stats(camp).earned - mark - 100 * Progress.perRecycled) < 1, Progress.stats(camp).earned - mark)
    mark = Progress.stats(camp).earned
    camp.stats.harvested = camp.stats.harvested + 50
    advance(camp, 1, 1)
    check("harvest pays points", math.abs(Progress.stats(camp).earned - mark - 50 * Progress.perHarvested) < 1, Progress.stats(camp).earned - mark)
    mark = Progress.stats(camp).earned
    camp.stats.repelled = camp.stats.repelled + 1
    advance(camp, 1, 1)
    check("repelled raids pay points", math.abs(Progress.stats(camp).earned - mark - Progress.perRepelled) < 1, Progress.stats(camp).earned - mark)
    mark = Progress.stats(camp).earned
    camp.stats.built = 0
    advance(camp, 1, 1)
    check("counter reset does not pay", Progress.stats(camp).earned - mark < 1)
    camp.stats.built = 4
    advance(camp, 1, 1)
    check("counter growth after reset pays again", Progress.stats(camp).earned - mark >= 4 * Progress.perBuilt)
    mark = Progress.stats(camp).earned
    HOURS = HOURS + 24 * 30
    advance(camp, 5, 5)
    check("day jump is capped", Progress.stats(camp).earned - mark <= Progress.dayCap * (Progress.dayBase + Progress.dayPerson * 2) + 1, Progress.stats(camp).earned - mark)
    check("day jump pays", Progress.stats(camp).earned - mark >= Progress.dayCap * (Progress.dayBase + Progress.dayPerson * 2) - 1)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Edge")
    people(camp, 3)
    local keptStats, keptStorage = camp.stats, camp.storage
    camp.stats = nil
    camp.storage = nil
    local ok = pcall(function()
        advance(camp, 30, 5)
        Progress.stats(camp)
        Progress.researchLines(camp)
        Progress.achieveLines(camp)
        Progress.overview(camp)
    end)
    camp.stats, camp.storage = keptStats, keptStorage
    check("camp without stats and storage survives", ok)
    Camp.abandon(camp)

    camp = newCamp(100, "Lonely")
    people(camp, 4)
    local savedSkills, savedBuild, savedWork, savedGates = A.Skills, A.Build, A.Work, A.Gates
    A.Skills, A.Build, A.Work, A.Gates = nil, nil, nil, nil
    local lonelyOk = pcall(function()
        advance(camp, 60, 5)
        Progress.select(camp, "rotation")
        Progress.add(camp, 100)
        Progress.researchLines(camp)
        Progress.achieveLines(camp)
        Progress.stats(camp)
    end)
    A.Skills, A.Build, A.Work, A.Gates = savedSkills, savedBuild, savedWork, savedGates
    check("works without neighbor modules", lonelyOk and camp.progress.done.rotation ~= nil)
    check("no neighbor modules still pays rewards", (contents(camp)["Base.Nails"] or 0) == 20)
    Camp.abandon(camp)

    camp = newCamp(100, "Unloaded")
    people(camp, 3)
    camp.storage = { { x = 9999, y = 9999, z = 0 }, { x = 9998, y = 9999, z = 0 } }
    local unloadedOk = pcall(function()
        advance(camp, 40, 5)
        Progress.select(camp, "rotation")
        Progress.add(camp, 70)
    end)
    check("unloaded storage does not break", unloadedOk and camp.progress.done.rotation ~= nil)
    local pending = 0
    for _, entry in ipairs(camp.storage) do for _, count in pairs(entry.add or {}) do pending = pending + count end end
    check("rewards wait for unloaded storage", pending >= 22, pending)
    Camp.abandon(camp)

    camp = newCamp(100, "Bare")
    people(camp, 3)
    camp.storage = {}
    Progress.select(camp, "rotation")
    local bareOk = pcall(function() Progress.add(camp, 60) end)
    check("no storage keeps points", bareOk and camp.progress.done.rotation ~= nil and camp.progress.bank == 6, camp.progress.bank)
    Camp.abandon(camp)

    camp = newCamp(100, "Sealed")
    people(camp, 3)
    local broken = Progress.state(camp)
    broken.current = "bogus"
    broken.spent = 10
    check("corrupted current is repaired", Progress.state(camp).current == nil and Progress.state(camp).bank == 10)
    camp.progress = { done = "oops", ach = 5, clock = "x", bank = "12", spent = nil, current = "compost" }
    local repaired = Progress.state(camp)
    check("corrupted tables are rebuilt", type(repaired.done) == "table" and type(repaired.ach) == "table" and type(repaired.clock) == "table" and repaired.bank == 12 and repaired.current == nil)
    check("zero and negative minutes ignored", pcall(Progress.step, camp, 0) and pcall(Progress.step, camp, -3) and pcall(Progress.step, camp, nil))
    camp.progress = { done = {}, ach = {}, clock = {}, bank = -5, spent = 30 }
    local fixed = Progress.state(camp)
    check("negative and orphan numbers are repaired", fixed.bank == 30 and fixed.spent == 0 and fixed.current == nil)
    camp.progress = { done = {}, ach = {}, clock = {}, bank = 0, spent = 90, current = "rotation" }
    fixed = Progress.state(camp)
    check("overshoot goes back to the bank", fixed.bank == 30 and fixed.spent == 60 and fixed.current == "rotation")
    Progress.step(camp, 1)
    check("overshoot completes on the next step", camp.progress.done.rotation ~= nil and camp.progress.current == nil and camp.progress.bank >= 30)
    Camp.abandon(camp)
end

do
    local one = newCamp(100, "One")
    local two = newCamp(120, "Two")
    people(one, 2)
    people(two, 6)
    advance(one, 120, 5)
    Progress.select(one, "watch")
    check("selection is per camp", one.progress.current == "watch" and two.progress == nil)
    Progress.add(two, 500)
    check("points are per camp", Progress.stats(two).earned >= 500 and Progress.stats(one).earned < 100)
    check("views are per camp", Progress.viewOf(one) ~= Progress.viewOf(two))
    check("stats are per camp", Progress.stats(one).current == "watch" and Progress.stats(two).current == "")
    Camp.abandon(one)
    Camp.abandon(two)
end

do
    local camp = newCamp(100, "Interface")
    people(camp, 5)
    advance(camp, 10, 5)
    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
    local tab = win:hookTab("progress")
    check("progress tab has two sections", tab ~= nil and #tab.sections == 2 and tab.sections[1].title == "PgSecResearch" and tab.sections[2].title == "PgSecAchieve")
    check("section priorities", tab.sections[1].priority == 10 and tab.sections[2].priority == 20)
    win:selectTab("progress")
    win:prerender()
    local available = Progress.available(Progress.state(camp))
    check("five technologies available at the start", #available == 5, #available)
    local clickable = 0
    for _, line in ipairs(Hooks.tabLines(tab, camp)) do if line.click ~= nil then clickable = clickable + 1 end end
    check("every available tech is a clickable row", clickable == 5, clickable)
    check("window registers clickable rows", #win.hitRows >= 1, #win.hitRows)

    local lines = Hooks.tabLines(tab, camp)
    local text = {}
    for _, line in ipairs(lines) do text[#text + 1] = line.text end
    local joined = table.concat(text, "\n")
    check("tab shows both titles", joined:find(T("PgSecResearch"), 1, true) ~= nil and joined:find(T("PgSecAchieve"), 1, true) ~= nil)
    check("tab shows choose hint", joined:find(T("PgChoose", tostring(math.floor(camp.progress.bank))), 1, true) ~= nil)
    check("tab shows auto-off hint", joined:find(T("PgAutoOff"), 1, true) ~= nil)
    check("tab shows a full tech row", joined:find(T("PgRow", T("PgT_rotation"), T("PgBranch_eco"), "60", Progress.effectText(Progress.byId.rotation)), 1, true) ~= nil)
    check("tab shows locked requirement", joined:find(T("PgLockedRow", T("PgT_compost"), "220", T("PgT_rotation")), 1, true) ~= nil)
    local counted = Progress.stats(camp)
    check("tab shows achievements count", joined:find(T("PgAchCount", tostring(counted.achievements), tostring(counted.achievementsTotal)), 1, true) ~= nil and counted.achievementsTotal == #Progress.achievements - 10)
    check("tab shows library hint", joined:find(T("PgLibraryHint", tostring(Progress.studyDelay)), 1, true) ~= nil)
    check("effect texts", Progress.effectText(Progress.byId.logistics) == T("PgEff_build", "1.2") .. ", " .. T("PgEff_trade", "1.1"), Progress.effectText(Progress.byId.logistics))

    local clickY
    for _, row in ipairs(win.hitRows) do
        clickY = row.y1 + 1
        break
    end
    win:onContentClick(clickY)
    check("click starts research", camp.progress.current ~= nil, tostring(camp.progress.current))
    local firstPick = camp.progress.current
    win:prerender()
    camp.progress.spent = 30
    local lines2 = Hooks.tabLines(tab, camp)
    check("current research line", lines2[2].text:find(T("PgT_" .. firstPick), 1, true) ~= nil, lines2[2].text)
    check("current research percent word", lines2[2].text:find(T("PgPct5", tostring(Progress.stats(camp).percent)), 1, true) ~= nil and Progress.stats(camp).percent == math.floor(30 * 100 / Progress.byId[firstPick].cost), lines2[2].text)
    check("current research description", lines2[3].text == T("PgD_" .. firstPick))
    local prefix = T("PgPace", "@", "@"):match("^(.-)@")
    check("current research pace", lines2[4].text:sub(1, #prefix) == prefix, lines2[4].text)
    local clickables = 0
    for _, line in ipairs(lines2) do if line.click ~= nil then clickables = clickables + 1 end end
    check("current row is not clickable", clickables == 4, clickables)
    local row2 = win.hitRows[1]
    win:onMouseDown(20, row2.y1 + 1)
    win:onMouseUp(20, row2.y1 + 1)
    check("mouse click switches research", camp.progress.current ~= nil and camp.progress.current ~= firstPick, tostring(camp.progress.current))

    camp.progress.done = { watch = 1, works = 1 }
    camp.progress.current, camp.progress.spent, camp.progress.bank = nil, 0, 0
    Progress.select(camp, "drill")
    local perDay = Progress.perDay(camp, Progress.viewOf(camp).rate)
    local days = math.ceil(math.max(1, math.ceil(Progress.byId.drill.cost / (perDay / 24))) / 24)
    local paceDays = false
    for _, line in ipairs(Progress.researchLines(camp)) do
        if line.text == T("PgPaceDays", tostring(math.floor(perDay + 0.5)), tostring(days)) then paceDays = true end
    end
    check("long research pace is shown in days", paceDays and days >= 3, days)
    camp.progress.done = {}
    camp.progress.current, camp.progress.spent = nil, 0

    local all = {}
    local function gather(list) for _, line in ipairs(list) do all[#all + 1] = line end end
    gather(Progress.researchLines(camp))
    for _, tech in ipairs(Progress.techs) do
        camp.progress.done = { [tech.id] = 1 }
        camp.progress.current = nil
        gather(Progress.researchLines(camp))
    end
    camp.progress.done = {}
    Progress.unlockAll(camp)
    gather(Progress.researchLines(camp))
    gather(Progress.achieveLines(camp))
    Progress.grantAll(camp)
    gather(Progress.achieveLines(camp))
    local widest, widestText = 0, ""
    for _, line in ipairs(all) do
        local width = charCount(line.text) + (line.indent or 0) / 7
        if width > widest then widest, widestText = width, line.text end
    end
    check("research and achievement lines fit the window", widest <= 88, widest .. " " .. widestText)
    local descriptions = 0
    for _, tech in ipairs(Progress.techs) do descriptions = math.max(descriptions, charCount(T("PgD_" .. tech.id)) + 3) end
    for _, entry in ipairs(Progress.achievements) do
        descriptions = math.max(descriptions, charCount(T("PgAchRecent", T("PgA_" .. entry.id), T("PgAD_" .. entry.id))))
    end
    check("descriptions are short", descriptions <= 82, descriptions)
    check("tab lines survive a full window pass", (function()
        for _, t in ipairs(win.tabs) do
            win:selectTab(t.id)
            win:prerender()
        end
        return true
    end)())
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Overview")
    people(camp, 3)
    local idle = Progress.overview(camp)
    check("overview adds one line", #idle == 1 and hasLine(Hooks.overview(camp), idle[1].text))
    check("overview idle line", idle[1].text == T("PgOverviewIdle", "0", "16"), idle[1].text)
    Progress.select(camp, "sorting")
    local p = camp.progress
    local function overviewFor(spent)
        p.spent, p.bank = spent, 0
        local text = Progress.overview(camp)[1].text
        if not hasLine(Hooks.overview(camp), text) then return "" end
        return text
    end
    check("overview current line", overviewFor(40) == T("PgOverview", "0", "16", T("PgT_sorting"), T("PgPct5", "50")), overviewFor(40))
    check("percent form one", overviewFor(17):find(T("PgPct1", "21"), 1, true) ~= nil, overviewFor(17))
    check("percent form few", overviewFor(18):find(T("PgPct2", "22"), 1, true) ~= nil, overviewFor(18))
    check("percent form many", overviewFor(20):find(T("PgPct5", "25"), 1, true) ~= nil and overviewFor(9):find(T("PgPct5", "11"), 1, true) ~= nil and overviewFor(0):find(T("PgPct5", "0"), 1, true) ~= nil)
    check("overview has no bare percent sign", overviewFor(40):find("%%") == nil)
    local stats = Progress.stats(camp)
    p.spent = 40
    stats = Progress.stats(camp)
    check("stats current is a string id", stats.current == "sorting" and type(stats.current) == "string" and stats.percent == 50)
    check("stats points are bank plus progress", stats.points == 40)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Cheater")
    people(camp, 3)
    local actions = Cheats.actions
    check("cheats registered", actions.pg_points ~= nil and actions.pg_unlock ~= nil and actions.pg_achieve ~= nil)
    local sections = {}
    for _, entry in ipairs(Cheats.order) do sections[entry.id] = entry.section end
    check("cheats in life section", sections.pg_points == "life" and sections.pg_unlock == "life" and sections.pg_achieve == "life")
    check("cheat points", actions.pg_points(camp, PLAYER) == 200 and Progress.stats(camp).earned == 200)
    check("cheat unlock", actions.pg_unlock(camp, PLAYER) == 16 and Progress.stats(camp).done == 16)
    check("cheat unlock repeat", actions.pg_unlock(camp, PLAYER) == 0)
    check("cheat achieve", actions.pg_achieve(camp, PLAYER) == #Progress.achievements and Progress.stats(camp).achievements == #Progress.achievements)
    local runText = Cheats.run("pg_points", PLAYER)
    check("cheat run text", runText == T("ChR_pg_points", "200"), runText)
    check("cheat run unlock text", Cheats.run("pg_unlock", PLAYER) == T("ChR_pg_unlock", "0"))
    check("cheat texts exist", A.TN("ChT_pg_points") ~= nil and A.TN("ChD_pg_unlock") ~= nil and A.TN("ChR_pg_achieve") ~= nil)
    local kept = A.Progress
    A.Progress = nil
    check("cheats without module", actions.pg_points(camp, PLAYER) == 0 and actions.pg_unlock(camp, PLAYER) == 0 and actions.pg_achieve(camp, PLAYER) == 0)
    A.Progress = kept
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Saved")
    people(camp, 6)
    camp.options.autoResearch = true
    for _ = 1, 3 do advance(camp, 1440, 10) end
    camp.stats.harvested = 50
    advance(camp, 10, 5)
    local ok, why = plain(camp.progress, "progress", {})
    check("saved state is plain data", ok, why)
    local clone = copy(camp)
    check("state survives a save round trip", Progress.stats(clone).done == Progress.stats(camp).done and Progress.stats(clone).earned == Progress.stats(camp).earned
        and Progress.bonus(clone, "farm") == Progress.bonus(camp, "farm"))
    check("state stays small", size(camp.progress) < 220, size(camp.progress))
    advance(clone, 30, 5)
    check("restored state keeps running", Progress.stats(clone).earned > Progress.stats(camp).earned)
    Camp.abandon(camp)
end

do
    local camp = newCamp(100, "Pace")
    people(camp, 5)
    camp.options.autoResearch = true
    local fullDay
    local population = 5
    for day = 1, 120 do
        if day % 3 == 0 and population < 14 then
            population = population + 1
            camp.settlers["x" .. population] = { name = "X" .. population, role = "builder", since = 0 }
        end
        camp.stats.built = camp.stats.built + (day <= 12 and 2 or 1)
        camp.recycledTotal = (camp.recycledTotal or 0) + 30
        camp.stats.harvested = camp.stats.harvested + 30
        for _, settler in pairs(camp.settlers) do
            settler.skills = settler.skills or {}
            settler.skills.build = (settler.skills.build or 0) + 12
        end
        advance(camp, 1440, 15)
        if fullDay == nil and Progress.stats(camp).done >= 16 then fullDay = day end
    end
    check("whole tree takes weeks for a growing camp", fullDay ~= nil and fullDay >= 14 and fullDay <= 70, tostring(fullDay))
    check("tree eventually done", Progress.stats(camp).done == 16)
    Camp.abandon(camp)

    camp = newCamp(100, "Small")
    people(camp, 3)
    camp.options.autoResearch = true
    local firstSmall
    local startHours = HOURS
    for _ = 1, 96 do
        advance(camp, 60, 10)
        if firstSmall == nil and Progress.stats(camp).done >= 1 then firstSmall = (HOURS - startHours) / 24 end
    end
    check("three settlers get the first tech within a few days", firstSmall ~= nil and firstSmall <= 3, tostring(firstSmall))
    Camp.abandon(camp)
end

do
    local seed = 24680
    local function roll(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return math.floor(seed / 65536) % n + 1
    end
    Hooks.rand = roll
    local camps = { newCamp(100, "Fuzz1"), newCamp(120, "Fuzz2") }
    local ids = {}
    for _, tech in ipairs(Progress.techs) do ids[#ids + 1] = tech.id end
    local bad
    local swallowed = #SILENT
    for step = 1, 1500 do
        local camp = camps[roll(2)]
        local op = roll(10)
        if op == 1 then
            Progress.select(camp, ids[roll(#ids)])
        elseif op == 2 then
            Progress.add(camp, roll(300) - 40)
        elseif op == 3 then
            HOURS = HOURS + roll(120) / 60
            Hooks.each("minute", camp, roll(30))
        elseif op == 4 then
            Options.set(camp, "autoResearch", roll(2) == 1)
            Options.set(camp, "pgReadBooks", roll(2) == 1)
        elseif op == 5 then
            people(camp, roll(30) - 3, ({ "builder", "scavenger", "guard", "farmer" })[roll(4)])
        elseif op == 6 then
            camp.stats.built = camp.stats.built + roll(5) - 2
            camp.stats.harvested = camp.stats.harvested + roll(50) - 10
            camp.recycledTotal = (camp.recycledTotal or 0) + roll(200) - 50
            camp.level = roll(5)
        elseif op == 7 then
            HOURS = HOURS + roll(24 * 5)
            Hooks.each("minute", camp, 30)
        elseif op == 8 then
            local p = Progress.state(camp)
            p.current = ({ "bogus", "compost", "rotation", false })[roll(4)] or nil
            p.spent = roll(100) - 20
            p.bank = roll(100) - 20
            Progress.stats(camp)
        elseif op == 9 then
            Progress.researchLines(camp)
            Progress.achieveLines(camp)
            Progress.overview(camp)
        else
            local items = {}
            for i = 1, roll(9) do items[tostring(i)] = { id = i, kind = ({ "fence", "post", "shed", "farm" })[roll(4)], status = ({ "done", "active" })[roll(2)], x = 100, y = 100, w = 4, h = 3 } end
            camp.plan = { items = items, serial = 9 }
            camp.motor = (roll(2) == 1) and { parked = { a = {} } } or nil
        end
        local p = camp.progress
        if p ~= nil and bad == nil then
            if p.bank < 0 or p.spent < 0 then bad = "negative points at " .. step end
            local tech = p.current ~= nil and Progress.byId[p.current] or nil
            if p.current ~= nil and (tech == nil or p.done[p.current] or p.spent > tech.cost + 1e-6 or (tech.req ~= nil and not p.done[tech.req])) then bad = "bad current at " .. step end
            if p.current == nil and p.spent ~= 0 then bad = "orphan progress at " .. step end
            local stats = Progress.stats(camp)
            if stats.done > stats.total or stats.achievements > stats.achievementsTotal or stats.percent < 0 or stats.percent > 100 then bad = "bad stats at " .. step end
            local plainOk = plain(p, "progress", {})
            if not plainOk then bad = "state not plain at " .. step end
        end
    end
    check("random operations keep the state valid", bad == nil, bad)
    local mine = 0
    for i = swallowed + 1, #SILENT do
        if SILENT[i]:find("CampProgress.lua", 1, true) then mine = mine + 1 end
    end
    check("random operations raise no internal errors", mine == 0, mine)
    Hooks.rand = realRand
    Camp.abandon(camps[1])
    Camp.abandon(camps[2])
end

do
    local camp = newCamp(100, "Hourly")
    people(camp, 3)
    local function countPrints()
        local n, last = 0, nil
        for _, line in ipairs(PRINTS) do
            if line:find("[ALifeCamp:Progress]", 1, true) then
                n = n + 1
                last = line
            end
        end
        return n, last
    end
    local before = countPrints()
    advance(camp, 180, 1)
    local after, last = countPrints()
    check("one diagnostic line per game hour", after - before == 3, after - before)
    check("diagnostic line format", last ~= nil and last:find("tech=0/16", 1, true) ~= nil and last:find("ach=", 1, true) ~= nil and last:find("perday=", 1, true) ~= nil and last:find("books=", 1, true) ~= nil, last)
    Camp.abandon(camp)
end

do
    local keys = {}
    local function want(key) keys[#keys + 1] = key end
    for _, key in ipairs({ "PgSecResearch", "PgSecAchieve", "PgPct1", "PgPct2", "PgPct5", "PgPaceNone", "PgAutoOff", "PgHdrAvail", "PgHdrLocked", "PgHdrDone",
        "Opt_pgReadBooks", "OptHint_pgReadBooks",
        "PgAchNone", "PgAchRecentHdr", "PgPaceDays", "PgFound", "PgAchAll", "Opt_autoResearch", "OptHint_autoResearch" }) do want(key) end
    for _, branch in ipairs(Progress.branches) do want("PgBranch_" .. branch) end
    for _, key in ipairs(Progress.keys) do want("PgEff_" .. key) end
    for _, tech in ipairs(Progress.techs) do
        want("PgT_" .. tech.id)
        want("PgD_" .. tech.id)
    end
    for _, entry in ipairs(Progress.achievements) do
        want("PgA_" .. entry.id)
        want("PgAD_" .. entry.id)
    end
    for _, key in ipairs(keys) do
        check("text key " .. key, A.TN(key) ~= nil)
    end
    T("PgCurrent", "a", "1", "2", "3")
    T("PgPace", "1", "2")
    T("PgChoose", "1")
    T("PgAutoIn", "1")
    T("PgAllDone", "1")
    T("PgRow", "a", "b", "1", "c")
    T("PgRowNow", "a", "b")
    T("PgLockedRow", "a", "1", "b")
    T("PgDoneRow", "a", "b")
    T("PgLibrary", "1", "2")
    T("PgLibraryHint", "8")
    T("PgFound", "a", "b")
    T("PgAchCount", "1", "2")
    T("PgAchRecent", "a", "b")
    T("PgAchNear", "a", "b", "1", "2")
    T("PgGlow", "1")
    T("PgDone", "a", "b")
    T("PgAchieved", "a", "b")
    T("PgAchievedMany", "a", "b", "1")
    T("PgOverview", "1", "2", "a", "b")
    T("PgOverviewIdle", "1", "2")
    T("PgOverviewDone", "1", "2")
    T("PgRewardPts", "1")
    T("PgRewardItems", "1")
    for _, kindKey in ipairs({ "pg_done", "pg_auto", "pg_ach", "pg_achmore", "pg_book", "pg_found" }) do T("Log_" .. kindKey, "a", "b") end
    for _, id in ipairs({ "pg_points", "pg_unlock", "pg_achieve" }) do
        T("ChT_" .. id)
        T("ChD_" .. id)
        T("ChR_" .. id, "1")
    end
    local glowOk = true
    for _, tech in ipairs(Progress.techs) do
        if Progress.effectText(tech) == "" then glowOk = false end
    end
    check("every tech has an effect text", glowOk)
end

do
    local source = sourceOf(ROOT .. "/shared/ALifeCamp/CampProgress.lua")
    local cheatSource = sourceOf(ADDON .. "/shared/ALifeCampCheats/CheatsProgress.lua")
    check("sources readable", source ~= nil and cheatSource ~= nil)
    local function ascii(text) return text:find("[\128-\255]") == nil end
    local function commentFree(text)
        for line in text:gmatch("[^\n]+") do
            local stripped = line:gsub('"[^"]*"', "")
            if stripped:find("%-%-") then return false end
        end
        return true
    end
    check("module source is ascii only", source ~= nil and ascii(source))
    check("cheat source is ascii only", cheatSource ~= nil and ascii(cheatSource))
    check("module source has no comments", source ~= nil and commentFree(source))
    check("cheat source has no comments", cheatSource ~= nil and commentFree(cheatSource))
    local banned = {
        "string%.format", "string%.rep", "math%.random", "math%.randomseed", "goto", "[^%w_]os%.", "[^%w_]io%.",
        "[^%w_%.:]next%(", "[^%w_%.:]unpack%(", "loadstring", "require%(",
    }
    local offender
    for _, pattern in ipairs(banned) do
        for _, text in ipairs({ source or "", cheatSource or "" }) do
            if text:find(pattern) ~= nil and offender == nil then offender = pattern end
        end
    end
    check("modules avoid calls missing in Kahlua", offender == nil, offender)
end

do
    local unexpected = {}
    for i = silentAtStart + 1, #SILENT do
        local message = SILENT[i]
        local mine = message:find("CampProgress.lua", 1, true) or message:find("CheatsProgress.lua", 1, true) or message:find("<python>", 1, true)
        local intended = message:find("health exploded", 1, true) or message:find("no mod data", 1, true) or message:find("getDisplayCategory", 1, true)
        if mine and not intended then unexpected[#unexpected + 1] = message end
    end
    check("no unexpected swallowed errors in the module or the test", #unexpected == 0, unexpected[1])
end

MISSING.UI_ALC_Opt_uiRing = nil
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
