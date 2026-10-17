require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampLand"
require "ALifeCamp/CampClear"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampSite"
require "ALifeCamp/CampStats"
require "ALifeCamp/CampExpand"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampAdopt"
require "ALifeCamp/Camp"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampDirector"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock
local World = ALifeCamp.World
local Land = ALifeCamp.Land
local Clear = ALifeCamp.Clear
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan
local Bp = ALifeCamp.Blueprints
local Site = ALifeCamp.Site
local Stats = ALifeCamp.Stats
local Expand = ALifeCamp.Expand
local Settlers = ALifeCamp.Settlers
local Camp = ALifeCamp.Camp
local Director = ALifeCamp.Director

local Work = {}
ALifeCamp.Work = Work

Work.clearRate = 12
Work.kcalPerDay = 2000
Work.starveHours = 24
Work.orderEvery = 3
Work.inviteHours = 6

function Work.notify(camp, key, ...)
    local player = getPlayer()
    if player == nil then return end
    local text = ALifeCamp.T(key, camp.name, ...)
    pcall(function() player:setHaloNote(text) end)
end

function Work.hash(text)
    local h = 0
    for i = 1, #text do h = (h * 31 + string.byte(text, i)) % 1000003 end
    return h
end

function Work.pickRole(camp)
    local counts = Settlers.counts(camp)
    local total = math.max(1, counts.total)
    local want = {
        { "builder", 0.34 }, { "farmer", 0.2 }, { "guard", 0.2 }, { "scavenger", 0.16 }, { "medic", 0.1 },
    }
    if ALifeCamp.Posts ~= nil and ALifeCamp.Posts.garageDone(camp) ~= nil then want[#want + 1] = { "mechanic", 0.08 } end
    for _, row in ipairs(Hooks.collect("roles", camp)) do want[#want + 1] = row end
    local best, bestGap
    for _, row in ipairs(want) do
        local gap = row[2] - (counts[row[1]] or 0) / total
        if bestGap == nil or gap > bestGap then best, bestGap = row[1], gap end
    end
    return best or "worker"
end

function Work.center(camp)
    local x, y = Geo.center(camp)
    return { x = x, y = y, z = camp.z }
end

function Work.arrivals(camp, minutes)
    if camp.pending == nil then return end
    local hours = Store.hours()
    for uid, info in pairs(camp.pending) do
        if not Settlers.alive(uid) then
            Settlers.cancelInvite(camp, uid)
            Store.log(camp, "invitelost", info.name)
        else
            local role = Work.pickRole(camp)
            local settler = Settlers.settle(camp, uid, info.name)
            settler.role = role
            Settlers.order(uid, "patrol", Work.center(camp), false)
            Settlers.say(Settlers.shell(uid), "Settled", camp.name)
            Work.notify(camp, "Arrived", settler.name)
        end
    end
end

function Work.upkeep(camp)
    for uid, settler in pairs(camp.settlers) do
        if not Settlers.alive(uid) then
            camp.settlers[uid] = nil
            camp.stats.left = camp.stats.left + 1
            Store.log(camp, "died", settler.name)
            Hooks.each("died", camp, settler, uid)
        elseif settler.role == nil or settler.role == "worker" then
            settler.role = Work.pickRole(camp)
        end
    end
end

function Work.food(camp, minutes)
    local people = Store.settlerCount(camp)
    if people == 0 then
        camp.hunger = 0
        return
    end
    camp.foodDebt = (camp.foodDebt or 0) + people * (Work.kcalPerDay / 1440) * minutes
    if camp.foodDebt >= 300 then
        local taken = Stock.consume(camp, "food", camp.foodDebt)
        camp.foodDebt = math.max(-4000, camp.foodDebt - taken)
        if taken <= 0 then
            camp.hunger = (camp.hunger or 0) + minutes / 60
        else
            camp.hunger = math.max(0, (camp.hunger or 0) - minutes / 30)
        end
    end
    if (camp.hunger or 0) >= Work.starveHours then
        camp.hunger = Work.starveHours / 2
        local leaver
        for uid in pairs(camp.settlers) do leaver = uid break end
        if leaver ~= nil then
            local name = camp.settlers[leaver].name
            Settlers.dismiss(camp, leaver)
            Store.log(camp, "starved", name)
            Work.notify(camp, "Starved", name)
        end
    end
end

function Work.labor(camp)
    local total = 0
    for uid in pairs(camp.settlers) do
        local x, y, z, loaded = Settlers.where(uid)
        if x == nil then
            total = total + 0.25
        elseif loaded then
            if Geo.distanceTo(camp, x, y) < 25 then total = total + 1 else total = total + 0.3 end
        else
            total = total + 0.5
        end
    end
    return total * Hooks.product("labor", camp)
end

function Work.clearStep(camp, minutes)
    if camp.phase ~= "clear" then return end
    local labor = Work.labor(camp)
    camp.labor = labor
    if labor <= 0 then return end
    local budget = labor * Work.clearRate * minutes
    local limit = camp.expand ~= nil and camp.expand.strip or nil
    local spent, removed = Clear.step(camp, budget, limit)
    camp.clearTotal = (camp.clearTotal or 0) + removed
    if removed > 0 and camp.clearTotal - (camp.clearLogged or 0) >= 40 then
        camp.clearLogged = camp.clearTotal
        Store.log(camp, "cleared", camp.clearTotal)
    end
    camp.clearMinutes = (camp.clearMinutes or 0) + minutes
    local state = Clear.state(camp)
    local area = Geo.area(limit or camp)
    local cap = math.min(Work.clearCapMax, Work.clearEarlyMinutes + area / 15)
    local settled = (state.passes or 0) >= Work.clearPasses and (state.lastRemoved or 0) <= Work.clearResidue
    local early = camp.clearMinutes >= cap or settled
    if early or Clear.finished(camp, limit) then
        camp.clearMinutes = nil
        if camp.expand ~= nil then
            Expand.finish(camp)
            Work.notify(camp, "Expanded", tostring(Geo.width(camp)), tostring(Geo.height(camp)))
        else
            camp.phase = "plan"
            Store.log(camp, "cleardone")
            Work.notify(camp, "ClearDone")
        end
    end
end

Work.adoptShare = { clear = 0.4, build = 0.5 }

function Work.adoptStep(camp, minutes)
    local adopt = ALifeCamp.Adopt
    if adopt == nil or not adopt.enabled(camp) then return end
    local counts = Settlers.counts(camp)
    local labor = Work.labor(camp) + counts.builder * 0.5
    labor = labor * (Work.adoptShare[camp.phase] or 1)
    adopt.step(camp, labor, minutes)
end

Work.sawRatio = 3
Work.scavengeEvery = 60
Work.loot = {
    { "Base.Nails", 6, 18, 5 }, { "Base.Plank", 1, 4, 4 }, { "Base.Log", 1, 3, 3 }, { "Base.ScrapMetal", 1, 3, 2 }, { "Base.Rope", 1, 2, 2 },
    { "Base.WaterRationCan", 1, 3, 4 }, { "Base.Crackers", 1, 3, 3 }, { "Base.DehydratedMeatStick", 1, 2, 3 },
    { "Base.PeanutButter", 1, 2, 2 }, { "Base.DriedBlackBeans", 1, 2, 2 }, { "Base.CannedMilk", 1, 2, 1 },
}

local function rand(n)
    if ZombRand ~= nil then return ZombRand(n) + 1 end
    return math.random(n)
end

function Work.validItem(fullType)
    local ok, found = pcall(function() return getScriptManager():FindItem(fullType) end)
    if not ok then return true end
    return found ~= nil
end

function Work.logReserve(camp)
    local total = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status ~= "done" and not project.paid then
            local stage = Build.currentStage(project)
            if stage ~= nil then total = total + (Bp.cost(Build.openOps(project, stage)).logs or 0) end
        end
    end
    return math.min(total, 12)
end

Work.lootEvery = 2
Work.lootRange = 30
Work.lootTries = 8
Work.lootItems = 6

local function lootContainer(camp, container, budget)
    local moved = 0
    pcall(function()
        local items = container:getItems()
        for i = items:size() - 1, 0, -1 do
            if moved >= budget then break end
            local item = items:get(i)
            local junk = ALifeCamp.Recycle ~= nil and ALifeCamp.Recycle.ruleOf(item) ~= nil
            if Stock.classify(item) ~= nil or junk then
                for _, entry in ipairs(camp.storage) do
                    local crate = Stock.crate(camp, entry)
                    if crate ~= nil then
                        local done = false
                        pcall(function()
                            container:Remove(item)
                            if junk then ALifeCamp.Recycle.flag(item) end
                            crate:getContainer():AddItem(item)
                            done = true
                        end)
                        if done then moved = moved + 1 end
                        break
                    end
                end
            end
        end
    end)
    return moved
end

local function lootGround(camp, square, budget)
    local moved = 0
    pcall(function()
        local list = square:getWorldObjects()
        for i = list:size() - 1, 0, -1 do
            if moved >= budget then break end
            local wobject = list:get(i)
            local item = wobject:getItem()
            local junk = ALifeCamp.Recycle ~= nil and ALifeCamp.Recycle.ruleOf(item) ~= nil
            if Stock.classify(item) ~= nil or junk then
                for _, entry in ipairs(camp.storage) do
                    local crate = Stock.crate(camp, entry)
                    if crate ~= nil then
                        local done = false
                        pcall(function()
                            square:transmitRemoveItemFromSquare(wobject)
                            pcall(function() wobject:removeFromWorld() end)
                            pcall(function() wobject:removeFromSquare() end)
                            if junk then ALifeCamp.Recycle.flag(item) end
                            crate:getContainer():AddItem(item)
                            done = true
                        end)
                        if done then moved = moved + 1 end
                        break
                    end
                end
            end
        end
    end)
    return moved
end

Work.lootLevels = { 0, 0, -1, -2 }

function Work.looting(camp, minutes)
    camp.lootClock = (camp.lootClock or 0) + minutes
    if camp.lootClock < Work.lootEvery then return end
    camp.lootClock = 0
    local counts = Settlers.counts(camp)
    local people = math.max(counts.scavenger or 0, math.ceil((counts.total or 0) / 3))
    if people <= 0 then return end
    local x1, y1 = camp.x1 - Work.lootRange, camp.y1 - Work.lootRange
    local w, h = Geo.width(camp) + Work.lootRange * 2, Geo.height(camp) + Work.lootRange * 2
    local total = 0
    for _ = 1, people * Work.lootTries do
        local level = camp.z + Work.lootLevels[rand(#Work.lootLevels)]
        local square = World.square(x1 + rand(w) - 1, y1 + rand(h) - 1, level)
        if square ~= nil and total < people * Work.lootItems then
            local before = total
            total = total + lootGround(camp, square, Work.lootItems)
            pcall(function()
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    local container = object:getContainer()
                    if container ~= nil and World.tag(object) == nil then
                        total = total + lootContainer(camp, container, Work.lootItems)
                    end
                end
            end)
            if total > before then
                camp.loot = { x = square:getX(), y = square:getY(), z = square:getZ(), at = Store.hours() }
            end
        end
    end
    if total > 0 then
        camp.stats.hauled = camp.stats.hauled + total
        Stock.refresh(camp)
        camp.lootedTotal = (camp.lootedTotal or 0) + total
        if camp.lootedTotal >= 40 then
            Store.log(camp, "looted", camp.lootedTotal)
            camp.lootedTotal = 0
        end
    end
end

function Work.supply(camp, minutes)
    local counts = Settlers.counts(camp)
    local spare = math.floor((camp.stock.logs or 0) - Work.logReserve(camp))
    if spare >= 1 and (counts.builder > 0 or counts.total > 0) then
        local rate = math.max(0.5, counts.builder) * 0.5 * minutes
        local logs = math.min(spare, math.max(1, math.floor(rate + (camp.sawCarry or 0))))
        camp.sawCarry = (rate + (camp.sawCarry or 0)) - math.floor(rate + (camp.sawCarry or 0))
        if logs > 0 then
            local taken = Stock.consume(camp, "logs", logs)
            if taken > 0 then
                Stock.deposit(camp, "Base.Plank", math.floor(taken * Work.sawRatio))
                camp.stats.hauled = camp.stats.hauled + math.floor(taken)
            end
        end
    end
    camp.woodClock = (camp.woodClock or 0) + minutes
    if camp.woodClock >= 60 then
        camp.woodClock = camp.woodClock - 60
        local short = Work.logReserve(camp) - (camp.stock.logs or 0)
        local cutters = math.min(3, counts.builder)
        if short > 0 and cutters > 0 then
            local cut = math.min(short, cutters)
            Stock.deposit(camp, "Base.Log", cut)
            camp.stats.hauled = camp.stats.hauled + cut
            Store.log(camp, "woodcut", cut)
        end
    end
    camp.scavengeClock = (camp.scavengeClock or 0) + minutes
    if camp.scavengeClock >= Work.scavengeEvery then
        camp.scavengeClock = 0
        local count = counts.scavenger
        local got = {}
        for _ = 1, count do
            if rand(100) <= 70 then
                local total = 0
                for _, row in ipairs(Work.loot) do total = total + row[4] end
                local ticket = rand(total)
                for _, row in ipairs(Work.loot) do
                    ticket = ticket - row[4]
                    if ticket <= 0 then
                        local amount = row[2] + rand(row[3] - row[2] + 1) - 1
                        if Work.validItem(row[1]) then
                            Stock.deposit(camp, row[1], amount)
                            got[#got + 1] = row[1]
                        end
                        break
                    end
                end
            end
        end
        if #got > 0 then Store.log(camp, "scavenged", #got) end
    end
end

Work.planEvery = 3
Work.planIdleEvery = 30
Work.clearEarlyMinutes = 90
Work.clearCapMax = 480
Work.clearPasses = 3
Work.clearResidue = 8

function Work.autoPlan(camp, minutes)
    if camp.options.autoPlan == false or (camp.phase ~= "plan" and camp.phase ~= "build") then return end
    camp.planClock = (camp.planClock or 0) + minutes
    if camp.planClock < (camp.planIdle and Work.planIdleEvery or Work.planEvery) then return end
    camp.planClock = 0
    local added = Plan.generate(camp)
    camp.planIdle = added == 0
    if added > 0 then Store.log(camp, "planned", added) end
end

function Work.buildStep(camp, minutes)
    if camp.phase == "clear" then return end
    pcall(Work.autoPlan, camp, minutes)
    local plan = Build.plan(camp)
    local any = false
    for _, project in pairs(plan.items) do
        if project.status ~= "done" then any = true break end
    end
    if camp.phase == "plan" and any then
        camp.phase = "build"
        Store.log(camp, "building")
    end
    if camp.phase ~= "build" then return end
    local counts = Settlers.counts(camp)
    local labor = Work.labor(camp) + counts.builder * 0.5
    if ALifeCamp.Skills ~= nil then labor = labor * ALifeCamp.Skills.factor(camp, "build") end
    camp.labor = labor
    local slots = math.max(1, math.floor(labor / 2))
    local ready, tries = 0, 0
    for _, project in ipairs(Build.list(camp)) do
        if project.status ~= "done" then
            if project.kind == "fence" then
                project.prepared = true
            elseif ready < slots then
                if project.prepared ~= true and tries < 6 then
                    tries = tries + 1
                    project.prepared = Clear.prepare(camp, Bp.footprint(project), 40 * minutes)
                end
                if project.prepared == true then
                    ready = ready + 1
                    if Site.class(project) ~= nil then Site.place(camp, project) end
                end
            end
        end
    end
    local advanced, active = Build.step(camp, labor, minutes)
    Site.sweep(camp)
    camp.active = {}
    if active ~= nil then
        for _, project in ipairs(active) do camp.active[#camp.active + 1] = project.id end
    end
    if not any then
        camp.phase = "plan"
    end
    local allDone = true
    local total = 0
    for _, project in pairs(plan.items) do
        total = total + 1
        if project.status ~= "done" then allDone = false end
    end
    if total > 0 and allDone then
        camp.phase = "plan"
        if not camp.allBuiltNoted then
            camp.allBuiltNoted = true
            Store.log(camp, "allbuilt")
            Work.notify(camp, "AllBuilt")
        end
    else
        camp.allBuiltNoted = nil
    end
end

Work.harvestHours = 24
Work.crops = {
    "Base.Carrots", "Base.Potato", "Base.Cabbage", "Base.Tomato", "Base.Corn", "Base.Lettuce", "Base.Onion",
    "Base.Broccoli", "Base.Peas", "Base.Turnip", "Base.Pumpkin",
}

function Work.farm(camp, minutes)
    local counts = Stats.counts(camp)
    if counts.farm <= 0 then
        camp.farmClock = 0
        return
    end
    camp.farmClock = (camp.farmClock or 0) + minutes / 60
    if camp.farmClock < Work.harvestHours then return end
    camp.farmClock = camp.farmClock - Work.harvestHours
    local farmers = Settlers.counts(camp).farmer or 0
    local perFarm = 14 + 8 * math.min(2, farmers / counts.farm)
    local skills = ALifeCamp.Skills
    if skills ~= nil then perFarm = perFarm * skills.factor(camp, "farm") end
    perFarm = perFarm * Hooks.product("farm", camp)
    local total = math.floor(counts.farm * perFarm)
    local valid = {}
    for _, name in ipairs(Work.crops) do
        if Work.validItem(name) then valid[#valid + 1] = name end
    end
    if #valid == 0 then return end
    local tally = {}
    for _ = 1, total do
        local pick = valid[rand(#valid)]
        tally[pick] = (tally[pick] or 0) + 1
    end
    for name, count in pairs(tally) do Stock.deposit(camp, name, count) end
    camp.stats.harvested = camp.stats.harvested + total
    Store.log(camp, "harvest", total)
end

function Work.gate(camp)
    local gates = ALifeCamp.Gates.list(camp)
    if gates[1] ~= nil then
        local x, y = ALifeCamp.Gates.at(gates[1], 0, 3)
        return { x = x, y = y, z = camp.z }
    end
    local x, y = Geo.center(camp)
    return { x = x, y = y, z = camp.z }
end

function Work.raidSite(camp)
    local sites = ALifeCamp.Posts ~= nil and ALifeCamp.Posts.gateSites(camp) or {}
    if #sites == 0 then return Work.gate(camp) end
    local pick = sites[rand(#sites)]
    return { x = pick.x, y = pick.y, z = camp.z }
end

function Work.posts(camp)
    local posts = {}
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "tower" and project.status == "done" then
            posts[#posts + 1] = { x = project.x + 1, y = project.y + 1, z = camp.z }
        end
    end
    table.sort(posts, function(a, b) return a.x * 10000 + a.y < b.x * 10000 + b.y end)
    if ALifeCamp.Adopt ~= nil then
        for _, post in ipairs(ALifeCamp.Adopt.posts(camp)) do posts[#posts + 1] = post end
    end
    if ALifeCamp.Posts ~= nil then
        for _, point in ipairs(ALifeCamp.Posts.guardPoints(camp)) do posts[#posts + 1] = point end
    end
    posts[#posts + 1] = Work.gate(camp)
    return posts
end

function Work.growth(camp, minutes)
    camp.growthClock = (camp.growthClock or 0) + minutes
    if camp.growthClock < 20 then return end
    camp.growthClock = 0
    local stats = Stats.compute(camp)
    camp.defense, camp.morale = stats.defense, stats.morale
    local was = camp.level or 1
    if stats.level ~= was then
        camp.level = stats.level
        if stats.level > was then
            Store.log(camp, "levelup", stats.level)
            Work.notify(camp, "LevelUp", tostring(stats.level))
        else
            Store.log(camp, "leveldown", stats.level)
        end
    end
    if ALifeCamp.Tiers ~= nil and type(ALifeCamp.Tiers.update) == "function" then
        local ok, _, up = pcall(ALifeCamp.Tiers.update, camp)
        if ok and up then
            Store.log(camp, "tierup", camp.tier)
            Work.notify(camp, "TierUp", ALifeCamp.Tiers.name(camp))
        end
    end
    Expand.cleanupFence(camp)
    local ready = Expand.ready(camp, stats)
    if ready then
        local side = Expand.best(camp)
        if side ~= nil and Expand.apply(camp, side) then
            Work.notify(camp, "Expanding", ALifeCamp.T("Side_" .. side))
        end
    end
end

Work.raidDelay = { 48, 48 }
Work.raidRepeat = { 96, 96 }
Work.raidWindow = 3

function Work.raidEvents()
    local events = ALifeRU ~= nil and ALifeRU.Events or nil
    if events == nil or type(events.start) ~= "function" then return nil end
    if type(events.isEnabled) == "function" and not events.isEnabled("raid_town") then return nil end
    return events
end

function Work.raidEnd(camp, raid)
    local lost = math.max(0, raid.people - Store.settlerCount(camp))
    Hooks.each("raidend", camp, raid, lost)
    if lost <= 0 then
        camp.stats.repelled = (camp.stats.repelled or 0) + 1
        Store.log(camp, "repelled")
        Work.notify(camp, "Repelled")
    else
        Store.log(camp, "raidlost", lost)
        Work.notify(camp, "RaidLost", tostring(lost))
    end
end

function Work.threat(camp)
    if camp.options.raids == false or (camp.level or 1) < 2 then return end
    local now = Store.hours()
    local raid = camp.raid
    if raid ~= nil then
        if now - raid.at >= Work.raidWindow then
            Work.raidEnd(camp, raid)
            camp.raid = nil
        end
        return
    end
    camp.nextRaid = camp.nextRaid or (now + Work.raidDelay[1] + rand(Work.raidDelay[2]))
    if now < camp.nextRaid then return end
    local events = Work.raidEvents()
    if events == nil or Store.settlerCount(camp) < 2 then
        camp.nextRaid = now + 12
        return
    end
    local site = Work.raidSite(camp)
    local ok, ctx = pcall(events.start, "raid_town", { site = site, force = true })
    if ok and ctx ~= nil then
        camp.raid = { at = now, people = Store.settlerCount(camp), site = site }
        camp.stats.raids = camp.stats.raids + 1
        camp.nextRaid = now + Work.raidRepeat[1] + rand(Work.raidRepeat[2])
        Store.log(camp, "raid")
        Work.notify(camp, "Raid")
        Hooks.each("raidstart", camp, camp.raid)
    else
        camp.nextRaid = now + 6
    end
end

function Work.report(camp)
    local day = Store.day(camp)
    if (camp.reportDay or 0) >= day then return end
    camp.reportDay = day
    camp.stats.days = day
    local stats = Stats.compute(camp)
    local food = math.floor(stats.foodDays * 10) / 10
    Store.log(camp, "daily", stats.people, food)
    if stats.people > 0 and stats.foodDays < 1 then Work.notify(camp, "LowFood", tostring(food)) end
    Hooks.each("daily", camp, day, stats)
end

Work.drillHours = { 9, 11 }

function Work.drillSite(camp)
    local hour = -1
    pcall(function() hour = getGameTime():getHour() end)
    if hour < Work.drillHours[1] or hour >= Work.drillHours[2] then return nil end
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "range" and project.status == "done" and not project.retired then
            return { x = project.x + math.floor(project.w / 2), y = project.y + project.h - 2, z = camp.z, exact = false }
        end
    end
    return nil
end

function Work.orders(camp, minutes)
    camp.orderClock = (camp.orderClock or 0) + minutes
    if camp.orderClock < Work.orderEvery then return end
    camp.orderClock = 0
    local base = Work.center(camp)
    local clearing = camp.phase == "clear" and camp.clear ~= nil and camp.clear.last ~= nil
    if clearing then base = { x = camp.clear.last.x, y = camp.clear.last.y, z = camp.z } end
    local site
    if camp.phase == "build" and camp.active ~= nil and camp.active[1] ~= nil then
        local project = Build.get(camp, camp.active[1])
        if project ~= nil then
            site = { x = project.x + math.floor(project.w / 2), y = project.y + math.floor(project.h / 2), z = camp.z }
            if project.kind == "fence" then site = nil end
        end
    end
    if site == nil and camp.adoptActive ~= nil and camp.adoptActive[1] ~= nil and ALifeCamp.Adopt ~= nil then
        local rec = ALifeCamp.Adopt.get(camp, camp.adoptActive[1])
        if rec ~= nil then site = ALifeCamp.Adopt.center(rec) end
    end
    local posts = Work.posts(camp)
    local gate = camp.raid ~= nil and camp.raid.site or nil
    local drill = Work.drillSite(camp)
    local Duty = ALifeCamp.Duty
    local stations = Duty ~= nil and Duty.enabled(camp)
    local ctx
    if stations then
        Duty.begin(camp)
        ctx = Duty.context(camp)
        ctx.posts = posts
    end
    local uids = {}
    for uid in pairs(camp.settlers) do uids[#uids + 1] = uid end
    table.sort(uids)
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if Settlers.shell(uid) ~= nil then
            local h = Work.hash(uid)
            local anchor = base
            if site ~= nil and (settler.role == "builder" or settler.role == "worker") then anchor = site end
            if settler.role == "guard" then
                anchor = gate or posts[h % #posts + 1]
            elseif gate ~= nil then
                anchor = Work.center(camp)
            end
            local special = gate ~= nil
            if drill ~= nil and gate == nil and settler.role ~= "guard" and settler.role ~= "builder" then
                anchor = drill
                special = true
            end
            if stations and not special then
                local station = Duty.station(camp, uid, settler, ctx)
                if station ~= nil then anchor = station end
            end
            if stations and anchor.exact ~= true then
                local pinned
                if gate ~= nil and settler.role == "guard" then
                    pinned = Duty.ring(camp, anchor, uid, 0, 2)
                    if pinned ~= nil then pinned.kind = "raid" end
                elseif gate ~= nil then
                    pinned = Duty.ring(camp, anchor, uid, 2, 6)
                    if pinned ~= nil then pinned.kind = "camp" end
                elseif drill ~= nil and anchor == drill then
                    pinned = Duty.ring(camp, anchor, uid, 0, 3)
                    if pinned ~= nil then pinned.kind = "range" end
                else
                    pinned = Duty.ring(camp, anchor, uid, 0, 3)
                end
                if pinned ~= nil then anchor = pinned end
            end
            local hauling = ALifeCamp.Motor ~= nil and ALifeCamp.Motor.crewAnchor(camp, uid) or nil
            if hauling ~= nil then anchor = hauling end
            local custom = Hooks.first("anchor", camp, uid, settler, anchor)
            if custom ~= nil then anchor = custom end
            if stations and anchor.exact == true then
                Duty.hold(camp, uid, anchor)
            else
                local jx, jy = (h % 5) - 2, math.floor(h / 5) % 5 - 2
                if anchor.exact == true then jx, jy = 0, 0 end
                anchor = { x = anchor.x + jx, y = anchor.y + jy, z = anchor.z }
                Settlers.order(uid, "patrol", anchor, true)
                if settler.station ~= nil then settler.station = nil end
            end
        end
    end
end

Work.recruitEvery = 5
Work.recruitRange = 150

function Work.recruit(camp, minutes)
    if camp.options.recruit == false then return end
    camp.recruitClock = (camp.recruitClock or 0) + minutes
    if camp.recruitClock < Work.recruitEvery then return end
    camp.recruitClock = 0
    if camp.phase == "clear" then return end
    local player = getPlayer()
    if player == nil then return end
    local ok, bindings = pcall(function() return ProjectALife.Watchdog.bindings end)
    if not ok or type(bindings) ~= "table" then return end
    local cx, cy = Geo.center(camp)
    local taken = {}
    for _, other in ipairs(Store.list()) do
        for uid in pairs(other.settlers or {}) do taken[uid] = true end
    end
    local invited = 0
    for uid, binding in pairs(bindings) do
        local shell = type(binding) == "table" and binding.shell or nil
        if invited < 2 and shell ~= nil and not taken[uid] then
            local near = false
            pcall(function()
                near = math.abs(shell:getX() - cx) <= Work.recruitRange and math.abs(shell:getY() - cy) <= Work.recruitRange
            end)
            if near then
                local record = Settlers.record(uid)
                if record ~= nil and record.lifecycle ~= "dead" and Settlers.stance(record, player) == "friendly" then
                    if Settlers.invite(player, shell, camp) then invited = invited + 1 end
                end
            end
        end
    end
end

Work.storageWanted = 1
Work.storageRadius = 8

function Work.storageAnchors(camp)
    local anchors = {}
    for uid in pairs(camp.settlers) do
        local x, y, _, loaded = Settlers.where(uid)
        if x ~= nil and loaded and Geo.contains(camp, math.floor(x), math.floor(y)) then
            anchors[#anchors + 1] = { x = math.floor(x), y = math.floor(y) }
        end
    end
    local cx, cy = Geo.center(camp)
    anchors[#anchors + 1] = { x = math.floor(cx), y = math.floor(cy) }
    local player = getPlayer()
    if player ~= nil and Geo.contains(camp, math.floor(player:getX()), math.floor(player:getY())) then
        anchors[#anchors + 1] = { x = math.floor(player:getX()), y = math.floor(player:getY()) }
    end
    return anchors
end

function Work.ensureStorage(camp, minutes)
    local carry
    for i = #camp.storage, 1, -1 do
        local entry = camp.storage[i]
        local loaded = World.square(entry.x, entry.y, entry.z or camp.z) ~= nil
        if loaded and Stock.crate(camp, entry) == nil then
            if type(entry.add) == "table" then
                carry = carry or {}
                for fullType, count in pairs(entry.add) do carry[fullType] = (carry[fullType] or 0) + count end
            end
            table.remove(camp.storage, i)
        end
    end
    if #camp.storage > 0 then
        if carry ~= nil then
            local first = camp.storage[1]
            first.add = first.add or {}
            for fullType, count in pairs(carry) do first.add[fullType] = (first.add[fullType] or 0) + count end
        end
        return
    end
    camp.storageClock = (camp.storageClock or 0) + minutes
    if camp.storageClock < 2 then return end
    camp.storageClock = 0
    local placed = 0
    for _, anchor in ipairs(Work.storageAnchors(camp)) do
        local px, py = anchor.x, anchor.y
        while placed < Work.storageWanted do
            local fx, fy = World.freeAround(px, py, camp.z, Work.storageRadius)
            if fx == nil or not ALifeCamp.Camp.addStorage(camp, fx, fy, camp.z) then break end
            placed = placed + 1
            px, py = fx + 1, fy
        end
        if placed > 0 then break end
    end
    if placed > 0 then
        if carry ~= nil then camp.storage[1].add = carry end
        Stock.refresh(camp)
        Store.log(camp, "storage", placed)
    end
end

function Work.recycleStep(camp, minutes)
    local recycle = ALifeCamp.Recycle
    if recycle == nil then return end
    recycle.starterKit(camp)
    local counts = Settlers.counts(camp)
    local workers = (counts.scavenger or 0) + (counts.worker or 0) + math.floor((counts.builder or 0) / 2)
    if workers <= 0 and counts.total > 0 then workers = 1 end
    local skills = ALifeCamp.Skills
    if skills ~= nil then workers = workers * skills.factor(camp, "scavenge") end
    workers = workers * Hooks.product("recycle", camp)
    recycle.step(camp, workers, minutes)
end

function Work.trace(camp, minutes)
    camp.traceClock = (camp.traceClock or 0) + minutes
    if camp.traceClock < 30 then return end
    camp.traceClock = 0
    local open, done, waiting = 0, 0, 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status == "done" then
            done = done + 1
        else
            open = open + 1
            if project.waiting then waiting = waiting + 1 end
        end
    end
    local stock = camp.stock or {}
    print("[ALifeCamp] " .. tostring(camp.name) .. " phase=" .. tostring(camp.phase) .. " people=" .. tostring(Store.settlerCount(camp))
        .. " labor=" .. tostring(camp.labor) .. " plan=" .. done .. "/" .. (done + open) .. " waiting=" .. waiting
        .. " planks=" .. tostring(stock.planks or 0) .. " nails=" .. tostring(stock.nails or 0) .. " metal=" .. tostring(stock.metal or 0)
        .. " cleared=" .. tostring(camp.stats.cleared or 0) .. " recycled=" .. tostring(camp.recycledTotal or 0))
end

function Work.run(camp, elapsed)
    local minutes = math.min(30, math.max(0, (elapsed or 0) * 60))
    if minutes <= 0 then minutes = 1 end
    pcall(Work.ensureStorage, camp, minutes)
    Work.arrivals(camp, minutes)
    pcall(Work.recruit, camp, minutes)
    Work.upkeep(camp)
    Work.food(camp, minutes)
    Work.supply(camp, minutes)
    pcall(Work.looting, camp, minutes)
    pcall(Work.recycleStep, camp, minutes)
    pcall(Work.trace, camp, minutes)
    if ALifeCamp.Skills ~= nil then pcall(ALifeCamp.Skills.step, camp, minutes) end
    if ALifeCamp.Motor ~= nil then pcall(ALifeCamp.Motor.step, camp, minutes) end
    Work.clearStep(camp, minutes)
    Work.adoptStep(camp, minutes)
    Work.buildStep(camp, minutes)
    Work.farm(camp, minutes)
    Work.growth(camp, minutes)
    Work.threat(camp)
    Work.report(camp)
    Hooks.each("minute", camp, minutes)
    Work.orders(camp, minutes)
end

Director.steps[#Director.steps + 1] = Work.run

return Work
