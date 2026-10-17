require "ALifeCamp/CampText"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock
local Build = ALifeCamp.Build
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Council = {}
ALifeCamp.Council = Council

Council.maxOpen = 3
Council.lifetime = 24
Council.autoDelay = 3
Council.firstDelay = { 3, 8 }
Council.interval = { 12, 30 }
Council.levelStep = 3
Council.retry = 2
Council.historyLimit = 6
Council.historyShown = 3
Council.buffLimit = 10
Council.repLimit = 100
Council.noteHours = 1
Council.clickGap = 350
Council.list = {}
Council.byId = {}
Council.cache = {}
Council.reported = {}

Council.tones = {
    gold = { 1, 0.85, 0.35 },
    help = { 0.55, 0.95, 0.65 },
    danger = { 1, 0.55, 0.45 },
    calm = { 0.7, 0.85, 1 },
}

Council.items = {
    planks = { "Base.Plank" },
    nails = { "Base.Nails" },
    logs = { "Base.Log" },
    metal = { "Base.ScrapMetal" },
    rope = { "Base.Rope" },
    medicine = { "Base.Bandage", "Base.Pills", "Base.Disinfectant" },
    ammo = { "Base.Bullets9mm" },
    seeds = { "Base.CarrotBagSeed2", "Base.BroccoliBagSeed2", "Base.RedRadishBagSeed2" },
}

Council.foods = {
    { "Base.DriedBlackBeans", 3084 }, { "Base.PeanutButter", 2660 }, { "Base.CannedMilk", 472 },
    { "Base.CannedCorn", 315 }, { "Base.TinnedBeans", 170 }, { "Base.DehydratedMeatStick", 100 }, { "Base.Crackers", 70 },
}

Council.loot = {
    { "planks", 30 }, { "nails", 50 }, { "metal", 8 }, { "rope", 5 }, { "medicine", 4 }, { "food", 4000 }, { "ammo", 10 },
}

Council.value = {
    food = 0.05, water = 4, planks = 4, nails = 2, logs = 12, metal = 12, rope = 6, medicine = 30, ammo = 6, seeds = 8,
}

Council.tradeKinds = { "food", "planks", "nails", "logs", "metal", "rope", "medicine", "ammo", "seeds" }

Council.importance = { food = 1, medicine = 2, nails = 3, planks = 4, ammo = 5, metal = 6, rope = 7, logs = 8, seeds = 9 }

Council.goals = {
    food = { 0, 8000 }, planks = { 60, 6 }, nails = { 120, 10 }, logs = { 10, 2 }, metal = { 15, 2 },
    rope = { 8, 1 }, medicine = { 4, 1 }, ammo = { 10, 3 }, seeds = { 6, 1 },
}

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function nice(value)
    if value >= 1000 then return math.floor(value / 100 + 0.5) * 100 end
    if value >= 100 then return math.floor(value / 10 + 0.5) * 10 end
    if value >= 20 then return math.floor(value / 5 + 0.5) * 5 end
    return math.max(1, math.floor(value + 0.5))
end

local function niceFood(kcal)
    return math.max(300, math.floor(kcal / 100 + 0.5) * 100)
end

local function dayKcal()
    local work = ALifeCamp.Work
    if work ~= nil and type(work.kcalPerDay) == "number" then return work.kcalPerDay end
    return 2000
end

local function say(key, a, b, c)
    if c ~= nil then return T(key, tostring(a), tostring(b), tostring(c)) end
    if b ~= nil then return T(key, tostring(a), tostring(b)) end
    if a ~= nil then return T(key, tostring(a)) end
    return T(key)
end

local function sayWith(key, fn, p)
    if fn == nil then return say(key) end
    return say(key, fn(p))
end

Council.say = say

function Council.rand(n)
    return Hooks.rand(math.max(1, math.floor(n)))
end

local function roll(percent)
    return Council.rand(100) <= percent
end

function Council.state(camp)
    local st = camp.council
    if type(st) ~= "table" then
        st = {}
        camp.council = st
    end
    st.rep = clamp(tonumber(st.rep) or 0, -Council.repLimit, Council.repLimit)
    st.resolved = tonumber(st.resolved) or 0
    st.trades = tonumber(st.trades) or 0
    st.serial = tonumber(st.serial) or 0
    st.rev = tonumber(st.rev) or 0
    for _, name in ipairs({ "open", "history", "buffs", "last", "flags" }) do
        if type(st[name]) ~= "table" then st[name] = {} end
    end
    return st
end

local state = Council.state

local function luck(camp)
    return math.floor(state(camp).rep / 5)
end

function Council.addRep(camp, delta)
    local st = state(camp)
    st.rep = clamp(st.rep + delta, -Council.repLimit, Council.repLimit)
    st.rev = st.rev + 1
    return st.rep
end

local function addBuff(camp, kind, value, hours)
    local st = state(camp)
    local now = Store.hours()
    st.buffs[#st.buffs + 1] = { k = kind, v = value, t0 = now, t1 = now + hours }
    while #st.buffs > Council.buffLimit do table.remove(st.buffs, 1) end
    st.rev = st.rev + 1
end

function Council.mood(camp)
    local st = state(camp)
    local now = Store.hours()
    local total = st.rep / 30
    for _, buff in ipairs(st.buffs) do
        if buff.k == "m" and now < buff.t1 then
            total = total + buff.v * clamp(1 - (now - buff.t0) / math.max(0.01, buff.t1 - buff.t0), 0, 1)
        end
    end
    return clamp(total, -25, 25)
end

function Council.factor(camp, kind)
    local st = state(camp)
    local now = Store.hours()
    local value = 1
    for _, buff in ipairs(st.buffs) do
        if buff.k == kind and now < buff.t1 then value = value * buff.v end
    end
    return clamp(value, 0.4, 1.8)
end

function Council.flat(camp, kind)
    local st = state(camp)
    local now = Store.hours()
    local total = 0
    for _, buff in ipairs(st.buffs) do
        if buff.k == kind and now < buff.t1 then total = total + buff.v end
    end
    return total
end

local function progressAdd(camp, points)
    local progress = ALifeCamp.Progress
    if progress ~= nil and type(progress.add) == "function" then pcall(progress.add, camp, points) end
end

local function progressBonus(camp, key)
    local progress = ALifeCamp.Progress
    if progress == nil or type(progress.bonus) ~= "function" then return 0 end
    local ok, value = pcall(progress.bonus, camp, key)
    if not ok or type(value) ~= "number" then return 0 end
    if value >= 0.5 then value = value - 1 end
    return clamp(value, 0, 0.3)
end

local function validItem(fullType)
    local work = ALifeCamp.Work
    if work ~= nil and type(work.validItem) == "function" then
        local ok, valid = pcall(work.validItem, fullType)
        return not ok or valid == true
    end
    return true
end

local function giveFood(camp, kcal)
    local left, given = kcal, 0
    for _, row in ipairs(Council.foods) do
        if left >= row[2] * 0.9 and validItem(row[1]) then
            local count = math.floor(left / row[2] + 0.1)
            if count > 0 then
                Stock.deposit(camp, row[1], count)
                left = left - count * row[2]
                given = given + count * row[2]
            end
        end
    end
    return given
end

local function giveStock(camp, kind, amount)
    amount = math.floor(amount)
    if amount <= 0 then return 0 end
    if kind == "food" then return giveFood(camp, amount) end
    local names = {}
    for _, name in ipairs(Council.items[kind] or {}) do
        if validItem(name) then names[#names + 1] = name end
    end
    if #names == 0 then return 0 end
    local counts = {}
    for i = 1, amount do
        local name = names[(i - 1) % #names + 1]
        counts[name] = (counts[name] or 0) + 1
    end
    for _, name in ipairs(names) do
        if counts[name] ~= nil then Stock.deposit(camp, name, counts[name]) end
    end
    return amount
end

local function loseStock(camp, kind, amount)
    if amount <= 0 then return 0 end
    return Stock.consume(camp, kind, amount)
end

local function amountText(kind, amount)
    if kind == "food" then return say("CnAmtFood", round(amount / dayKcal() * 10) / 10) end
    if kind == "water" then return say("CnAmtWater", round(amount)) end
    return say("CnAmt", T("CnR_" .. kind), math.floor(amount))
end

Council.amount = amountText

local function listText(cost)
    local parts = {}
    for _, kind in ipairs(Stock.kinds) do
        local amount = cost[kind]
        if amount ~= nil and amount > 0 then parts[#parts + 1] = amountText(kind, amount) end
    end
    return table.concat(parts, ", ")
end

local function lackList(camp, cost)
    local stock = camp.stock or {}
    local out = {}
    for _, kind in ipairs(Stock.kinds) do
        local need = cost[kind]
        local have = stock[kind] or 0
        if need ~= nil and need > 0 and have < need then out[#out + 1] = { kind = kind, have = have, need = need } end
    end
    return out
end

local function lackText(list)
    local parts = {}
    for _, row in ipairs(list) do
        if row.kind == "food" then
            parts[#parts + 1] = say("CnLackFood", round(row.have / dayKcal() * 10) / 10, round(row.need / dayKcal() * 10) / 10)
        elseif row.kind == "water" then
            parts[#parts + 1] = say("CnLackWater", round(row.have), round(row.need))
        else
            parts[#parts + 1] = say("CnLackItem", T("CnR_" .. row.kind), math.floor(row.have), math.floor(row.need))
        end
    end
    return say("CnLack", table.concat(parts, ", "))
end

local function hourNow()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return hour
end

local function survey(camp)
    local gate, projects, farms = false, 0, 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.status == "done" then
            if project.kind == "fence" and not project.retired then gate = true end
            if project.kind == "farm" and not project.retired then farms = farms + 1 end
        else
            projects = projects + 1
        end
    end
    return gate, projects, farms
end

local function context(camp)
    local people = Store.settlerCount(camp)
    local gate, projects, farms = survey(camp)
    local hour = hourNow()
    return {
        people = people, level = camp.level or 1, day = Store.day(camp), stock = camp.stock or {},
        F = math.max(1, people) * dayKcal(), gate = gate, projects = projects, farms = farms,
        storage = type(camp.storage) == "table" and #camp.storage > 0,
        hour = hour, night = hour >= 21 or hour < 5, rep = state(camp).rep, defense = camp.defense or 0,
    }
end

local function foodShare(c, fraction, least)
    local want = c.F * fraction
    local cap = (c.stock.food or 0) * 0.45
    return niceFood(math.min(want, math.max(cap, least or 300)))
end

local function pickPeople(camp)
    local uids = {}
    for uid in pairs(camp.settlers) do uids[#uids + 1] = uid end
    table.sort(uids)
    local first, second
    if #uids >= 1 then first = uids[Council.rand(#uids)] end
    if #uids >= 2 then
        local rest = {}
        for _, uid in ipairs(uids) do
            if uid ~= first then rest[#rest + 1] = uid end
        end
        second = rest[Council.rand(#rest)]
    end
    local function nameOf(uid, fallback)
        if uid ~= nil and camp.settlers[uid] ~= nil then return tostring(camp.settlers[uid].name or uid) end
        return T(fallback)
    end
    return first, nameOf(first, "CnAnyone1"), second, nameOf(second, "CnAnyone2")
end

local function dismiss(camp, uid)
    local settlers = ALifeCamp.Settlers
    if uid == nil or settlers == nil or camp.settlers[uid] == nil then return false end
    return settlers.dismiss(camp, uid) == true
end

local function train(camp, skill, mainLevels, otherLevels)
    local skills = ALifeCamp.Skills
    if skills == nil then return 0 end
    local trained = 0
    for _, settler in pairs(camp.settlers) do
        local role = settler.role or "worker"
        local levels = (skills.primary or {})[role] == skill and mainLevels or otherLevels
        local data = skills.data(settler)
        local xp = data[skill] or 0
        local level = math.sqrt(xp / skills.xpUnit)
        local target = math.min(skills.maxLevel, level + levels)
        local gained = target * target * skills.xpUnit
        if gained > xp then
            data[skill] = gained
            trained = trained + 1
        end
    end
    return trained
end

local function lootRolls(count)
    local pool = {}
    for i = 1, #Council.loot do pool[i] = i end
    local rows = {}
    for _ = 1, count do
        local index = Council.rand(#pool)
        rows[#rows + 1] = Council.loot[pool[index]]
        table.remove(pool, index)
    end
    return rows
end

local function grantLoot(camp, count, multiplier)
    local level = camp.level or 1
    local texts = {}
    for _, row in ipairs(lootRolls(count)) do
        local base = row[2] * (1 + 0.25 * (level - 1)) * multiplier
        local amount = row[1] == "food" and niceFood(base) or nice(base)
        texts[#texts + 1] = amountText(row[1], giveStock(camp, row[1], amount))
    end
    return texts[1], texts[2], texts[3]
end

local function tradeAmount(kind, value)
    if kind == "food" then return niceFood(value) end
    return nice(value)
end

function Council.tradeRate(camp)
    local rate = 0.7 + state(camp).rep / 500 + progressBonus(camp, "trade")
    return clamp(rate, 0.5, 1)
end

function Council.goal(kind, c)
    local row = Council.goals[kind]
    if row == nil then return 1 end
    return (row[1] + row[2] * c.people) * (1 + 0.2 * (c.level - 1))
end

function Council.deal(want, pay, rate, force)
    local value = Council.value
    local get = want.goal * 0.28
    local give = get * value[want.kind] / (value[pay.kind] * rate)
    local room = pay.have - (force and 0 or pay.goal * 0.8)
    if room <= 0 then return nil end
    if give > room then
        local scale = room / give
        if scale < 0.35 and not force then return nil end
        get, give = get * scale, room
    end
    local giveAmount = tradeAmount(pay.kind, give)
    local getAmount = tradeAmount(want.kind, get)
    if giveAmount > pay.have then giveAmount = math.floor(pay.have) end
    if giveAmount < 1 or getAmount < 1 then return nil end
    return { g = pay.kind, gn = giveAmount, r = want.kind, rn = getAmount }
end

local function byRatio(ascending)
    return function(a, b)
        if a.ratio ~= b.ratio then
            if ascending then return a.ratio < b.ratio end
            return a.ratio > b.ratio
        end
        return (Council.importance[a.kind] or 99) < (Council.importance[b.kind] or 99)
    end
end

function Council.deals(camp, c, force)
    local rate = Council.tradeRate(camp)
    local rows = {}
    for _, kind in ipairs(Council.tradeKinds) do
        local goal = Council.goal(kind, c)
        local have = c.stock[kind] or 0
        rows[#rows + 1] = { kind = kind, goal = goal, have = have, ratio = have / math.max(1, goal) }
    end
    local wants, pays = {}, {}
    for _, row in ipairs(rows) do
        if row.ratio < 0.8 then wants[#wants + 1] = row end
        if row.ratio > 1.15 then pays[#pays + 1] = row end
    end
    if force then
        if #wants == 0 then
            for _, row in ipairs(rows) do wants[#wants + 1] = row end
        end
        if #pays == 0 then
            for _, row in ipairs(rows) do
                if row.have > 0 then pays[#pays + 1] = row end
            end
        end
    end
    table.sort(wants, byRatio(true))
    table.sort(pays, byRatio(false))
    local deals = {}
    for i, want in ipairs(wants) do
        if #deals >= 3 then break end
        local deal
        for step = 0, #pays - 1 do
            local pay = pays[(i - 1 + step) % #pays + 1]
            if pay.kind ~= want.kind then
                deal = Council.deal(want, pay, rate, force)
                if deal ~= nil then break end
            end
        end
        if deal ~= nil then deals[#deals + 1] = deal end
    end
    if #deals == 0 and force then deals[1] = { g = "planks", gn = 20, r = "nails", rn = 15 } end
    return deals, rate
end

function Council.settleDeal(camp, deal)
    local st = state(camp)
    local got = giveStock(camp, deal.r, deal.rn)
    st.trades = st.trades + 1
    Council.addRep(camp, 1)
    progressAdd(camp, 4)
    local gave, took = amountText(deal.g, deal.gn), amountText(deal.r, got)
    Store.log(camp, "cn_trade", gave, took)
    if roll(clamp(st.rep - 20, 0, 60)) then
        local extra = deal.r == "food" and niceFood(deal.rn * 0.15) or math.max(1, math.ceil(deal.rn * 0.15))
        return "db", gave, took, amountText(deal.r, giveStock(camp, deal.r, extra))
    end
    return "d", gave, took, 1
end

local function define(s)
    s.weight = s.weight or 10
    s.cool = s.cool or 72
    s.minLevel = s.minLevel or 1
    s.minPeople = s.minPeople or 2
    if s.store == nil then s.store = true end
    Council.list[#Council.list + 1] = s
    Council.byId[s.id] = s
end

define({
    id = "trader", tone = "gold", cool = 36,
    weight = function(c) return 14 + math.max(0, math.floor(c.rep / 20)) end,
    res = { "d", "db", "n", "t" },
    need = function(camp, c) return c.gate end,
    make = function(camp, c, force)
        local deals, rate = Council.deals(camp, c, force)
        if #deals == 0 then return nil end
        return { deals = deals, rate = round(rate * 100) }
    end,
    desc = function(p) return p.rate end,
    safe = function(p) return #p.deals + 1 end,
    options = function(p)
        local list = {}
        for _, deal in ipairs(p.deals) do
            list[#list + 1] = {
                key = "deal", hideCost = true, cost = { [deal.g] = deal.gn },
                text = function() return amountText(deal.g, deal.gn), amountText(deal.r, deal.rn) end,
                run = function(camp) return Council.settleDeal(camp, deal) end,
            }
        end
        list[#list + 1] = { key = "no", run = function() return "n" end }
        return list
    end,
    late = function() return "t" end,
})

define({
    id = "wounded", tone = "help", weight = 12, cool = 60, safe = 2,
    res = { "1a", "1b", "1c", "2a", "2b", "3a", "t" },
    make = function(camp, c)
        return { med = clamp(2 + math.floor(c.people / 4), 2, 4), food = foodShare(c, 0.15, 400) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { medicine = p.med } end,
            run = function(camp)
                local r, bonus = Council.rand(100), luck(camp)
                if r <= 62 + bonus then
                    Council.addRep(camp, 6)
                    addBuff(camp, "m", 3, 24)
                    progressAdd(camp, 3)
                    return "a", 6
                elseif r <= 85 + bonus then
                    local gift = giveStock(camp, "nails", nice(16 + 4 * (camp.level or 1)))
                    Council.addRep(camp, 6)
                    progressAdd(camp, 3)
                    return "b", amountText("nails", gift), 6
                end
                Council.addRep(camp, 2)
                addBuff(camp, "m", -4, 24)
                return "c"
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.food } end,
            run = function(camp)
                if roll(75 + luck(camp)) then
                    Council.addRep(camp, 3)
                    return "a", 3
                end
                Council.addRep(camp, 1)
                return "b", 1
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, -8)
                addBuff(camp, "m", -3, 18)
                return "a", -8
            end,
        },
    },
    late = function(camp)
        Council.addRep(camp, -4)
        addBuff(camp, "m", -2, 12)
        return "t", -4
    end,
})

define({
    id = "stash", tone = "gold", weight = 8, minPeople = 3, safe = 3,
    res = { "1a", "1b", "1c", "2a", "2b", "3a", "t" },
    make = function() return { small = 3, big = 8 } end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.small } end,
            run = function(camp)
                addBuff(camp, "l", 0.8, 8)
                local r, bonus = Council.rand(100), luck(camp)
                if r <= 55 + bonus then
                    return "a", (grantLoot(camp, 1, 1))
                elseif r <= 85 + bonus then
                    addBuff(camp, "m", -2, 12)
                    return "b"
                end
                local lost = loseStock(camp, "ammo", 4)
                addBuff(camp, "m", -4, 18)
                return "c", lost
            end,
        },
        {
            key = "2", cost = function(p) return { ammo = p.big } end,
            run = function(camp)
                addBuff(camp, "l", 0.7, 10)
                if roll(80 + luck(camp)) then
                    local first, second = grantLoot(camp, 2, 1.6)
                    return "a", first, second
                end
                addBuff(camp, "m", -2, 12)
                return "b"
            end,
        },
        {
            key = "3",
            run = function(camp)
                addBuff(camp, "m", -1, 12)
                return "a"
            end,
        },
    },
    late = function(camp)
        addBuff(camp, "m", -1, 12)
        return "t"
    end,
})

define({
    id = "quarrel", tone = "calm", weight = 9, minPeople = 3, store = false, safe = 1,
    res = { "1a", "1b", "2a", "2b", "3a", "3b", "t" },
    make = function(camp)
        local u1, n1, u2, n2 = pickPeople(camp)
        return { u1 = u1, n1 = n1, u2 = u2, n2 = n2, topic = Council.rand(3) }
    end,
    desc = function(p) return p.n1, p.n2, T("CnQt_" .. p.topic) end,
    options = {
        {
            key = "1",
            run = function(camp)
                addBuff(camp, "l", 0.92, 3)
                if roll(80 + luck(camp)) then
                    Council.addRep(camp, 2)
                    addBuff(camp, "m", 5, 36)
                    return "a", 2
                end
                addBuff(camp, "m", 1, 12)
                return "b"
            end,
        },
        {
            key = "2", text = function(p) return p.n1 end,
            run = function(camp, p)
                if Store.settlerCount(camp) >= 4 and roll(25) and dismiss(camp, p.u2) then
                    Council.addRep(camp, -2)
                    addBuff(camp, "m", -3, 24)
                    return "b", p.n2
                end
                Council.addRep(camp, -1)
                addBuff(camp, "m", 2, 24)
                return "a", p.n1, p.n2
            end,
        },
        {
            key = "3",
            run = function(camp)
                addBuff(camp, "m", -4, 24)
                if roll(20) then
                    addBuff(camp, "l", 0.85, 6)
                    return "b"
                end
                return "a"
            end,
        },
    },
    late = function(camp)
        addBuff(camp, "m", -3, 24)
        return "t"
    end,
})

define({
    id = "rats", tone = "danger", weight = 8, safe = 1,
    res = { "1a", "1b", "2a", "2b", "3a", "t" },
    need = function(camp, c) return (c.stock.food or 0) >= c.F end,
    make = function(camp, c)
        return { loss = niceFood(math.min((c.stock.food or 0) * 0.15, c.F * 0.7)), planks = 6, nails = 12 }
    end,
    desc = function(p) return amountText("food", p.loss) end,
    hint = function(p) return amountText("food", p.loss) end,
    options = {
        {
            key = "1", cost = function(p) return { planks = p.planks, nails = p.nails } end,
            run = function(camp, p)
                if roll(85) then
                    addBuff(camp, "m", 1, 12)
                    return "a"
                end
                return "b", amountText("food", loseStock(camp, "food", p.loss * 0.3))
            end,
        },
        {
            key = "2",
            run = function(camp, p)
                addBuff(camp, "l", 0.85, 4)
                if roll(60 + luck(camp)) then
                    addBuff(camp, "m", 1, 12)
                    return "a"
                end
                return "b", amountText("food", loseStock(camp, "food", p.loss * 0.5))
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                return "a", amountText("food", loseStock(camp, "food", p.loss))
            end,
        },
    },
    late = function(camp, p)
        return "t", amountText("food", loseStock(camp, "food", p.loss))
    end,
})

define({
    id = "radio", tone = "danger", weight = 7, minLevel = 2, minPeople = 4, safe = 2,
    res = { "1a", "1b", "1c", "2a", "3a", "t" },
    make = function(camp, c)
        return { ammo = 6 + 2 * c.level, food = foodShare(c, 0.25, 500) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo, food = p.food } end,
            run = function(camp)
                addBuff(camp, "l", 0.85, 8)
                local r, bonus = Council.rand(100), luck(camp)
                if r <= 58 + bonus then
                    local loot = grantLoot(camp, 1, 0.8)
                    Council.addRep(camp, 8)
                    addBuff(camp, "m", 4, 36)
                    progressAdd(camp, 8)
                    return "a", loot, 8
                elseif r <= 83 + bonus then
                    local lost = loseStock(camp, "ammo", 6)
                    Council.addRep(camp, 1)
                    addBuff(camp, "m", -3, 18)
                    return "b", lost
                end
                return "c", (grantLoot(camp, 1, 1.2))
            end,
        },
        {
            key = "2",
            run = function(camp)
                Council.addRep(camp, 2)
                return "a", 2
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, -2)
                addBuff(camp, "m", -1, 12)
                return "a", -2
            end,
        },
    },
    late = function(camp)
        Council.addRep(camp, -2)
        addBuff(camp, "m", -2, 18)
        return "t", -2
    end,
})

define({
    id = "dayoff", tone = "calm", weight = 10, minPeople = 3, store = false, safe = 2,
    res = { "1a", "2a", "3a", "3b", "t" },
    need = function(camp, c) return c.day >= 2 end,
    make = function() return { rest = 10 } end,
    options = {
        {
            key = "1", text = function(p) return p.rest end,
            run = function(camp, p)
                addBuff(camp, "l", 0.55, p.rest)
                addBuff(camp, "m", 9, 48)
                return "a", p.rest
            end,
        },
        {
            key = "2",
            run = function(camp)
                addBuff(camp, "l", 0.8, 6)
                addBuff(camp, "m", 4, 36)
                return "a"
            end,
        },
        {
            key = "3",
            run = function(camp)
                addBuff(camp, "m", -6, 36)
                if roll(20) then
                    addBuff(camp, "l", 0.9, 8)
                    return "b"
                end
                return "a"
            end,
        },
    },
    late = function(camp)
        addBuff(camp, "m", -2, 24)
        addBuff(camp, "l", 0.8, 6)
        return "t"
    end,
})

define({
    id = "refugees", tone = "help", safe = 2,
    weight = function(c) return 9 + math.max(0, math.floor(c.rep / 12)) end,
    res = { "1a", "1b", "2a", "3a", "t" },
    need = function(camp, c) return (c.stock.food or 0) >= c.F * 1.2 end,
    make = function(camp, c)
        local count = 2 + Council.rand(4)
        local full = niceFood(math.min(count * 1500, (c.stock.food or 0) * 0.4))
        return { count = count, full = full, half = niceFood(full / 2) }
    end,
    desc = function(p) return p.count end,
    options = {
        {
            key = "1", cost = function(p) return { food = p.full } end,
            run = function(camp)
                Council.addRep(camp, 10)
                addBuff(camp, "m", 3, 24)
                progressAdd(camp, 8)
                if roll(25 + luck(camp)) then
                    return "b", (grantLoot(camp, 1, 0.6)), 10
                end
                return "a", 10
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.half } end,
            run = function(camp)
                Council.addRep(camp, 4)
                return "a", 4
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, -10)
                addBuff(camp, "m", -4, 24)
                return "a", -10
            end,
        },
    },
    late = function(camp)
        Council.addRep(camp, -6)
        addBuff(camp, "m", -2, 12)
        return "t", -6
    end,
})

define({
    id = "doctor", tone = "help", minLevel = 2, minPeople = 3, safe = 3,
    weight = function(c) return 6 + math.max(0, math.floor(c.rep / 15)) end,
    res = { "1a", "2a", "3a", "t" },
    need = function(camp, c) return ALifeCamp.Skills ~= nil and (c.stock.food or 0) >= c.F end,
    make = function(camp, c)
        return { big = foodShare(c, 0.8, 1000), small = foodShare(c, 0.3, 500) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { food = p.big } end,
            run = function(camp)
                local trained = train(camp, "medic", 2, 1)
                Council.addRep(camp, 2)
                progressAdd(camp, 8)
                return "a", trained, 2
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.small } end,
            run = function(camp)
                progressAdd(camp, 4)
                return "a", train(camp, "medic", 1, 0.5)
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, 1)
                return "a", 1
            end,
        },
    },
    late = function() return "t" end,
})

define({
    id = "garden", tone = "help", weight = 7, safe = 2,
    res = { "1a", "1b", "2a", "3a", "t" },
    make = function(camp, c)
        return { yield = niceFood(c.F * 0.5), seeds = 4 + c.level }
    end,
    options = {
        {
            key = "1", text = function(p) return amountText("food", p.yield) end,
            run = function(camp, p)
                addBuff(camp, "l", 0.85, 6)
                progressAdd(camp, 5)
                if roll(80) then
                    addBuff(camp, "f", 1.15, 48)
                    local food = amountText("food", giveStock(camp, "food", p.yield))
                    return "a", food, amountText("seeds", giveStock(camp, "seeds", p.seeds))
                end
                addBuff(camp, "f", 1.1, 48)
                return "b", amountText("food", giveStock(camp, "food", p.yield * 0.4))
            end,
        },
        {
            key = "2", text = function(p) return amountText("food", p.yield * 0.5) end,
            run = function(camp, p)
                return "a", amountText("food", giveStock(camp, "food", p.yield * 0.5))
            end,
        },
        { key = "3", run = function() return "a" end },
    },
    late = function() return "t" end,
})

define({
    id = "well", tone = "help", weight = 6, minPeople = 3, once = "well", safe = 3,
    res = { "1a", "2a", "3a", "t" },
    make = function() return { planks = 12, nails = 10, rope = 3 } end,
    options = {
        {
            key = "1", cost = function(p) return { planks = p.planks, nails = p.nails, rope = p.rope } end,
            run = function(camp)
                addBuff(camp, "l", 0.9, 4)
                addBuff(camp, "m", 5, 72)
                addBuff(camp, "f", 1.15, 120)
                Council.addRep(camp, 1)
                progressAdd(camp, 10)
                state(camp).flags.well = true
                return "a"
            end,
        },
        {
            key = "2",
            run = function(camp)
                addBuff(camp, "l", 0.95, 2)
                addBuff(camp, "m", 2, 24)
                return "a"
            end,
        },
        { key = "3", run = function() return "a" end },
    },
    late = function() return "t" end,
})

define({
    id = "noise", tone = "danger", weight = 14, minPeople = 3, safe = 2,
    res = { "1a", "1b", "1c", "2a", "3a", "3b", "t" },
    need = function(camp, c) return c.gate and c.night end,
    make = function() return { ammo = 4, planks = 12 } end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo } end,
            run = function(camp)
                local r, bonus = Council.rand(100), luck(camp)
                if r <= 45 + bonus then
                    addBuff(camp, "m", 2, 12)
                    return "a"
                elseif r <= 75 + bonus then
                    return "b", (grantLoot(camp, 1, 0.5))
                end
                local lost = loseStock(camp, "ammo", 4)
                addBuff(camp, "m", -3, 12)
                return "c", lost
            end,
        },
        {
            key = "2",
            run = function(camp)
                addBuff(camp, "l", 0.9, 8)
                addBuff(camp, "d", 8, 14)
                addBuff(camp, "m", 1, 12)
                return "a"
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                if roll(30) then return "b", amountText("planks", loseStock(camp, "planks", p.planks)) end
                return "a"
            end,
        },
    },
    late = function(camp, p)
        return "t", amountText("planks", loseStock(camp, "planks", p.planks))
    end,
})

define({
    id = "fire", tone = "danger", weight = 6, minPeople = 3, safe = 2,
    res = { "1a", "1b", "2a", "2b", "3a", "t" },
    need = function(camp, c) return (c.stock.planks or 0) >= 25 end,
    make = function(camp, c)
        return { water = 5, loss = clamp(math.floor((c.stock.planks or 0) * 0.35), 8, 40) }
    end,
    hint = function(p) return p.loss end,
    options = {
        {
            key = "1", cost = function(p) return { water = p.water } end,
            run = function(camp, p)
                if roll(85) then return "a", loseStock(camp, "planks", math.max(2, math.floor(p.loss * 0.1))) end
                return "b", loseStock(camp, "planks", math.floor(p.loss / 2))
            end,
        },
        {
            key = "2",
            run = function(camp, p)
                addBuff(camp, "l", 0.85, 4)
                if roll(60 + luck(camp)) then return "a", loseStock(camp, "planks", math.floor(p.loss * 0.3)) end
                return "b", loseStock(camp, "planks", math.floor(p.loss * 0.7))
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                addBuff(camp, "m", -2, 18)
                return "a", loseStock(camp, "planks", p.loss)
            end,
        },
    },
    late = function(camp, p)
        return "t", loseStock(camp, "planks", p.loss)
    end,
})

define({
    id = "thief", tone = "calm", minPeople = 3, safe = 1,
    weight = function(c) return 8 + math.max(0, math.floor(-c.rep / 15)) end,
    res = { "1a", "2a", "2b", "3a", "3b", "t" },
    make = function(camp, c)
        return { food = foodShare(c, 0.2, 400) }
    end,
    hint = function(p) return amountText("food", p.food) end,
    options = {
        {
            key = "1",
            run = function(camp)
                Council.addRep(camp, -1)
                addBuff(camp, "m", 1, 12)
                return "a", -1
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.food } end,
            run = function(camp)
                Council.addRep(camp, 5)
                if roll(20) then return "b", (grantLoot(camp, 1, 0.4)), 5 end
                return "a", 5
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                addBuff(camp, "l", 0.95, 4)
                if roll(70) then return "a", giveStock(camp, "logs", 4 + (camp.level or 1)) end
                return "b", amountText("food", loseStock(camp, "food", p.food * 2))
            end,
        },
    },
    late = function(camp, p)
        return "t", amountText("food", loseStock(camp, "food", p.food))
    end,
})

define({
    id = "horde", tone = "danger", weight = 7, minLevel = 2, minPeople = 4, safe = 1,
    res = { "1a", "1b", "2a", "2b", "3a", "3b", "t" },
    need = function(camp, c) return c.gate end,
    make = function() return { ammo = 6, planks = 12 } end,
    hint = function(p) return p.planks end,
    options = {
        {
            key = "1",
            run = function(camp, p)
                addBuff(camp, "l", 0.7, 8)
                addBuff(camp, "d", 6, 8)
                if roll(80 + luck(camp)) then
                    addBuff(camp, "m", 1, 12)
                    return "a"
                end
                return "b", amountText("planks", loseStock(camp, "planks", p.planks))
            end,
        },
        {
            key = "2", cost = function(p) return { ammo = p.ammo } end,
            run = function(camp)
                if roll(70 + luck(camp)) then
                    Council.addRep(camp, 3)
                    addBuff(camp, "m", 3, 24)
                    return "a", 3
                end
                local lost = loseStock(camp, "ammo", 6)
                addBuff(camp, "m", -4, 18)
                addBuff(camp, "d", 6, 12)
                return "b", lost
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                if roll(60) then return "a" end
                addBuff(camp, "m", -3, 18)
                return "b", amountText("planks", loseStock(camp, "planks", p.planks))
            end,
        },
    },
    late = function(camp, p)
        addBuff(camp, "m", -3, 18)
        return "t", amountText("planks", loseStock(camp, "planks", p.planks))
    end,
})

define({
    id = "alliance", tone = "gold", minLevel = 2, minPeople = 4, safe = 3,
    weight = function(c) return 5 + math.max(0, math.floor(c.rep / 10)) end,
    res = { "1a", "2a", "3a", "t" },
    need = function(camp, c) return c.rep > -40 end,
    make = function(camp, c)
        local scale = 1 + 0.25 * (c.level - 1)
        return { ammo = 6 + c.level, food = foodShare(c, 0.4, 800), gift = nice(20 * scale), nails = nice(40 * scale) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo } end,
            run = function(camp)
                Council.addRep(camp, 8)
                addBuff(camp, "d", 6, 72)
                addBuff(camp, "m", 3, 36)
                progressAdd(camp, 15)
                return "a", 8
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.food } end,
            text = function(p) return amountText("planks", p.gift), amountText("nails", p.nails) end,
            run = function(camp, p)
                local planks = amountText("planks", giveStock(camp, "planks", p.gift))
                local nails = amountText("nails", giveStock(camp, "nails", p.nails))
                Council.addRep(camp, 3)
                progressAdd(camp, 6)
                return "a", planks, nails, 3
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, -1)
                return "a"
            end,
        },
    },
    late = function(camp)
        Council.addRep(camp, -2)
        return "t", -2
    end,
})

define({
    id = "bandits", tone = "danger", minLevel = 2, minPeople = 4, safe = 1,
    weight = function(c) return 7 + math.max(0, math.floor(-c.rep / 8)) end,
    res = { "1a", "2a", "2b", "3a", "3b", "t" },
    need = function(camp, c) return c.gate end,
    make = function(camp, c)
        return { food = foodShare(c, 0.5, 1000), ammo = 5 }
    end,
    hint = function(p) return amountText("food", p.food) end,
    options = {
        {
            key = "1", cost = function(p) return { food = p.food, ammo = p.ammo } end,
            run = function(camp)
                Council.addRep(camp, -4)
                addBuff(camp, "m", -2, 18)
                return "a", -4
            end,
        },
        {
            key = "2",
            run = function(camp)
                local chance = clamp(35 + round((camp.defense or 0) / 2), 30, 85) + luck(camp)
                if roll(chance) then
                    Council.addRep(camp, 8)
                    addBuff(camp, "m", 4, 36)
                    progressAdd(camp, 5)
                    return "a", 8
                end
                local lost = loseStock(camp, "ammo", 8)
                Council.addRep(camp, 2)
                addBuff(camp, "m", -5, 24)
                addBuff(camp, "d", 6, 24)
                return "b", lost
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                if roll(50) then return "a" end
                return "b", amountText("food", loseStock(camp, "food", p.food))
            end,
        },
    },
    late = function(camp, p)
        Council.addRep(camp, -6)
        return "t", amountText("food", loseStock(camp, "food", p.food)), -6
    end,
})

define({
    id = "hunters", tone = "gold", weight = 8, safe = 3,
    res = { "1a", "2a", "3a", "t" },
    need = function(camp, c) return (c.stock.ammo or 0) >= 4 or (c.stock.nails or 0) >= 30 end,
    make = function(camp, c)
        return { ammo = 4 + c.level, nails = 30, meat = niceFood(c.F * 0.4) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo } end,
            text = function(p) return amountText("food", p.meat) end,
            run = function(camp, p)
                Council.addRep(camp, 1)
                return "a", amountText("food", giveStock(camp, "food", p.meat))
            end,
        },
        {
            key = "2", cost = function(p) return { nails = p.nails } end,
            text = function(p) return amountText("food", p.meat * 0.8) end,
            run = function(camp, p)
                return "a", amountText("food", giveStock(camp, "food", p.meat * 0.8))
            end,
        },
        { key = "3", run = function() return "a" end },
    },
    late = function() return "t" end,
})

define({
    id = "storm", tone = "danger", weight = 8, minPeople = 3, safe = 2,
    res = { "1a", "1b", "2a", "2b", "3a", "3b", "t" },
    need = function(camp, c) return (c.stock.planks or 0) >= 15 end,
    make = function(camp, c)
        return {
            planks = 8, nails = 12, rope = 2,
            loss = clamp(math.floor((c.stock.planks or 0) * 0.25), 6, 30),
            nailLoss = clamp(math.floor((c.stock.nails or 0) * 0.15), 6, 40),
        }
    end,
    options = {
        {
            key = "1", cost = function(p) return { planks = p.planks, nails = p.nails, rope = p.rope } end,
            run = function(camp)
                if roll(90) then
                    addBuff(camp, "m", 1, 12)
                    return "a"
                end
                return "b", loseStock(camp, "planks", 4)
            end,
        },
        {
            key = "2",
            run = function(camp, p)
                addBuff(camp, "l", 0.7, 8)
                if roll(60 + luck(camp)) then return "a" end
                return "b", loseStock(camp, "planks", math.floor(p.loss / 2))
            end,
        },
        {
            key = "3",
            run = function(camp, p)
                if roll(50 + luck(camp)) then return "a" end
                addBuff(camp, "m", -3, 24)
                local planks = amountText("planks", loseStock(camp, "planks", p.loss))
                return "b", planks, amountText("nails", loseStock(camp, "nails", p.nailLoss))
            end,
        },
    },
    late = function(camp, p)
        addBuff(camp, "m", -3, 24)
        local planks = amountText("planks", loseStock(camp, "planks", p.loss))
        return "t", planks, amountText("nails", loseStock(camp, "nails", p.nailLoss))
    end,
})

define({
    id = "wreck", tone = "gold", weight = 6, minLevel = 2, minPeople = 4, safe = 3,
    res = { "1a", "1b", "1c", "2a", "2b", "3a", "t" },
    make = function() return { ammo = 4 } end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo } end,
            run = function(camp)
                addBuff(camp, "l", 0.75, 8)
                local r, bonus = Council.rand(100), luck(camp)
                if r <= 60 + bonus then
                    local first, second, third = grantLoot(camp, 3, 1)
                    return "a", first, second, third
                elseif r <= 85 + bonus then
                    return "b", (grantLoot(camp, 1, 0.4))
                end
                local lost = loseStock(camp, "ammo", 6)
                addBuff(camp, "m", -3, 18)
                return "c", lost
            end,
        },
        {
            key = "2",
            run = function(camp)
                addBuff(camp, "l", 0.95, 3)
                if roll(50) then return "a", (grantLoot(camp, 1, 0.3)) end
                return "b"
            end,
        },
        { key = "3", run = function() return "a" end },
    },
    late = function() return "t" end,
})

define({
    id = "crew", tone = "gold", weight = 8, minPeople = 3, safe = 3,
    res = { "1a", "2a", "3a", "t" },
    need = function(camp, c) return c.projects >= 1 end,
    make = function(camp, c)
        local planks = clamp(nice(15 + c.projects * 5), 15, 60)
        return { planks = planks, nails = nice(planks * 1.5), food = foodShare(c, 0.3, 600) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { planks = p.planks, nails = p.nails } end,
            run = function(camp)
                addBuff(camp, "l", 1.35, 24)
                Council.addRep(camp, 1)
                progressAdd(camp, 4)
                return "a"
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.food } end,
            run = function(camp)
                addBuff(camp, "l", 1.2, 12)
                return "a"
            end,
        },
        { key = "3", run = function() return "a" end },
    },
    late = function() return "t" end,
})

define({
    id = "dog", tone = "help", weight = 6, safe = 1,
    res = { "1a", "1b", "2a", "t" },
    make = function(camp, c)
        return { food = foodShare(c, 0.1, 300) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { food = p.food } end,
            run = function(camp)
                addBuff(camp, "m", 6, 72)
                Council.addRep(camp, 1)
                if roll(35) then
                    addBuff(camp, "d", 4, 96)
                    return "b"
                end
                return "a"
            end,
        },
        {
            key = "2",
            run = function(camp)
                addBuff(camp, "m", -2, 12)
                return "a"
            end,
        },
    },
    late = function(camp)
        addBuff(camp, "m", -1, 12)
        return "t"
    end,
})

define({
    id = "veteran", tone = "help", minLevel = 2, minPeople = 3, safe = 3,
    weight = function(c) return 5 + math.max(0, math.floor(c.rep / 15)) end,
    res = { "1a", "2a", "3a", "t" },
    need = function(camp, c)
        return ALifeCamp.Skills ~= nil and ((c.stock.ammo or 0) >= 8 or (c.stock.food or 0) >= c.F * 0.4)
    end,
    make = function(camp, c)
        return { ammo = 8, food = foodShare(c, 0.2, 500) }
    end,
    options = {
        {
            key = "1", cost = function(p) return { ammo = p.ammo } end,
            run = function(camp)
                local trained = train(camp, "guard", 2, 1)
                Council.addRep(camp, 2)
                progressAdd(camp, 8)
                return "a", trained, 2
            end,
        },
        {
            key = "2", cost = function(p) return { food = p.food } end,
            run = function(camp)
                progressAdd(camp, 4)
                return "a", train(camp, "guard", 1, 0.5)
            end,
        },
        {
            key = "3",
            run = function(camp)
                Council.addRep(camp, 1)
                return "a", 1
            end,
        },
    },
    late = function() return "t" end,
})

local function optionsOf(s, p)
    if type(s.options) == "function" then return s.options(p) end
    return s.options
end

local function costOf(option, p)
    local cost = option.cost
    if type(cost) == "function" then cost = cost(p) end
    return cost or {}
end

local function reportError(sid, err)
    if Council.reported[sid] then return end
    Council.reported[sid] = true
    print("[ALifeCamp:Council] scenario " .. tostring(sid) .. " failed: " .. tostring(err))
end

local function notify(camp, key, text)
    local work = ALifeCamp.Work
    if work == nil or type(work.notify) ~= "function" then return end
    if text ~= nil then
        pcall(work.notify, camp, key, text)
    else
        pcall(work.notify, camp, key)
    end
end

local function refresh(camp)
    pcall(Stock.refresh, camp)
end

local function findOpen(st, id)
    for _, d in ipairs(st.open) do
        if d.id == id then return d end
    end
    return nil
end

local function openHas(st, sid)
    for _, d in ipairs(st.open) do
        if d.sid == sid then return true end
    end
    return false
end

local function blocked(camp)
    return camp.phase == "clear" or Store.settlerCount(camp) < 2
end

local function eligible(camp, st, s, c, now, mode)
    if openHas(st, s.id) then return false end
    if mode == "force" then return true end
    if c.level < s.minLevel or c.people < s.minPeople then return false end
    if s.store and not c.storage then return false end
    if s.once ~= nil and st.flags[s.once] then return false end
    if s.need ~= nil then
        local ok, allowed = pcall(s.need, camp, c)
        if not ok or not allowed then return false end
    end
    if mode == "normal" then
        local last = st.last[s.id]
        if last ~= nil and now - last < s.cool then return false end
    end
    return true
end

local function pick(camp, st, c, mode)
    local now = Store.hours()
    local pool, total = {}, 0
    for _, s in ipairs(Council.list) do
        if eligible(camp, st, s, c, now, mode) then
            local ok, p = pcall(s.make, camp, c, mode ~= "normal")
            if ok and p ~= nil then
                local weight = type(s.weight) == "function" and s.weight(c) or s.weight
                weight = math.max(1, math.floor(weight))
                pool[#pool + 1] = { s = s, p = p, w = weight }
                total = total + weight
            end
        end
    end
    if total <= 0 then return nil end
    local ticket = Council.rand(total)
    for _, row in ipairs(pool) do
        ticket = ticket - row.w
        if ticket <= 0 then return row.s, row.p end
    end
    return pool[#pool].s, pool[#pool].p
end

local function place(camp, st, s, p)
    local now = Store.hours()
    st.serial = st.serial + 1
    local d = { id = st.serial, sid = s.id, at = now, due = now + Council.lifetime, p = p }
    st.open[#st.open + 1] = d
    st.last[s.id] = now
    st.rev = st.rev + 1
    local title = T("CnT_" .. s.id)
    Store.log(camp, "cn_new", title)
    notify(camp, "CnNew", title)
    return d
end

function Council.spawn(camp, sid, force)
    local st = state(camp)
    if #st.open >= Council.maxOpen then return nil, "full" end
    if not force and blocked(camp) then return nil, "blocked" end
    local c = context(camp)
    if sid ~= nil then
        local s = Council.byId[sid]
        if s == nil then return nil, "unknown" end
        if openHas(st, sid) then return nil, "open" end
        if not force and not eligible(camp, st, s, c, Store.hours(), "normal") then return nil, "conditions" end
        local ok, p = pcall(s.make, camp, c, force == true)
        if not ok then
            reportError(sid, p)
            return nil, "conditions"
        end
        if p == nil then return nil, "conditions" end
        return place(camp, st, s, p)
    end
    local s, p = pick(camp, st, c, force and "relaxed" or "normal")
    if s == nil and force then s, p = pick(camp, st, c, "force") end
    if s == nil then return nil, "none" end
    return place(camp, st, s, p)
end

function Council.available(camp)
    local st = state(camp)
    if blocked(camp) then return {} end
    local c = context(camp)
    local now = Store.hours()
    local out = {}
    for _, s in ipairs(Council.list) do
        if eligible(camp, st, s, c, now, "normal") then
            local ok, p = pcall(s.make, camp, c, false)
            if ok and p ~= nil then out[#out + 1] = s.id end
        end
    end
    return out
end

function Council.open(camp)
    local st = state(camp)
    local now = Store.hours()
    local out = {}
    for _, d in ipairs(st.open) do
        out[#out + 1] = { id = d.id, sid = d.sid, at = d.at, due = d.due, left = math.max(0, d.due - now) }
    end
    return out
end

function Council.stats(camp)
    local st = state(camp)
    return { resolved = st.resolved, trades = st.trades, rep = st.rep, open = #st.open }
end

function Council.reputation(camp)
    return state(camp).rep
end

local function conclude(camp, st, d, how, key, a, b, c)
    for i = #st.open, 1, -1 do
        if st.open[i] == d then table.remove(st.open, i) end
    end
    st.resolved = st.resolved + 1
    st.rev = st.rev + 1
    local list = st.history
    list[#list + 1] = { h = Store.hours(), sid = d.sid, k = key, a = a, b = b, c = c, o = how }
    while #list > Council.historyLimit do table.remove(list, 1) end
    return say("CnX_" .. d.sid .. "_" .. key, a, b, c)
end

local function refund(camp, cost)
    for _, kind in ipairs(Stock.kinds) do
        local amount = cost[kind]
        if amount ~= nil and amount > 0 and kind ~= "water" then giveStock(camp, kind, amount) end
    end
end

local function perform(camp, st, d, s, option, how)
    local cost = costOf(option, d.p)
    for _, kind in ipairs(Stock.kinds) do
        local amount = cost[kind]
        if amount ~= nil and amount > 0 then Stock.consume(camp, kind, amount) end
    end
    local ok, key, a, b, c = pcall(option.run, camp, d.p)
    if not ok then
        reportError(s.id, key)
        refund(camp, cost)
        refresh(camp)
        return false, T("CnFail")
    end
    key = key or "a"
    if tonumber(option.key) ~= nil then key = option.key .. key end
    local text = conclude(camp, st, d, how, key, a, b, c)
    refresh(camp)
    return true, text
end

function Council.answer(camp, id, index)
    if camp == nil then return false, T("CnGone") end
    local st = state(camp)
    local d = findOpen(st, id)
    if d == nil then return false, T("CnGone") end
    local s = Council.byId[d.sid]
    if s == nil then
        for i = #st.open, 1, -1 do
            if st.open[i] == d then table.remove(st.open, i) end
        end
        st.rev = st.rev + 1
        return false, T("CnGone")
    end
    local option = optionsOf(s, d.p)[tonumber(index) or 0]
    if option == nil then return false, T("CnBadOption") end
    refresh(camp)
    local lack = lackList(camp, costOf(option, d.p))
    if #lack > 0 then return false, lackText(lack) end
    local ok, text = perform(camp, st, d, s, option, "player")
    if not ok then return false, text end
    Store.log(camp, "cn_done", T("CnT_" .. s.id))
    notify(camp, "CnSay", text)
    return true, text
end

local function expire(camp, st, d, s, how)
    local ok, key, a, b, c = pcall(s.late, camp, d.p)
    if not ok then
        reportError(s.id, key)
        key, a, b, c = "t", nil, nil, nil
    end
    local text = conclude(camp, st, d, how, key or "t", a, b, c)
    refresh(camp)
    local title = T("CnT_" .. s.id)
    if how == "auto" then
        Store.log(camp, "cn_auto", title)
        notify(camp, "CnAuto", text)
    else
        Store.log(camp, "cn_late", title)
        notify(camp, "CnLate", text)
    end
end

local function settle(camp, st, d, s)
    local options = optionsOf(s, d.p)
    local index = type(s.safe) == "function" and s.safe(d.p) or s.safe
    local option = options[index or 0]
    if option ~= nil then
        refresh(camp)
        if #lackList(camp, costOf(option, d.p)) == 0 then
            local ok, text = perform(camp, st, d, s, option, "auto")
            if ok then
                Store.log(camp, "cn_auto", T("CnT_" .. s.id))
                notify(camp, "CnAuto", text)
                return
            end
        end
    end
    expire(camp, st, d, s, "auto")
end

local function sweep(camp, st, now)
    local auto = Options.on(camp, "autoCouncil")
    for i = #st.open, 1, -1 do
        local d = st.open[i]
        local s = Council.byId[d.sid]
        if s == nil then
            table.remove(st.open, i)
            st.rev = st.rev + 1
        elseif now >= d.due then
            expire(camp, st, d, s, "late")
        elseif auto and now >= d.at + Council.autoDelay then
            settle(camp, st, d, s)
        end
    end
end

local function prune(st, now)
    for i = #st.buffs, 1, -1 do
        if now >= st.buffs[i].t1 then
            table.remove(st.buffs, i)
            st.rev = st.rev + 1
        end
    end
end

local function shift(st, delta)
    for _, d in ipairs(st.open) do
        d.at = d.at + delta
        d.due = d.due + delta
    end
    if st.next ~= nil then st.next = st.next + delta end
    st.rev = st.rev + 1
end

local function schedule(st, now, level)
    local low = Council.interval[1]
    local high = math.max(low + 6, Council.interval[2] - Council.levelStep * (level - 1))
    st.next = now + low + Council.rand(high - low + 1) - 1
end

local function scheduleFirst(st, now)
    local low, high = Council.firstDelay[1], Council.firstDelay[2]
    st.next = now + low + Council.rand(high - low + 1) - 1
end

local function trace(camp, st, now, on)
    local hour = math.floor(now)
    if st.diag == hour then return end
    st.diag = hour
    local wait = st.next ~= nil and tostring(round((st.next - now) * 10) / 10) or "-"
    print("[ALifeCamp:Council] camp=" .. tostring(camp.id) .. " on=" .. tostring(on) .. " open=" .. #st.open
        .. " resolved=" .. st.resolved .. " trades=" .. st.trades .. " rep=" .. tostring(round(st.rep))
        .. " buffs=" .. #st.buffs .. " next=" .. wait)
end

function Council.step(camp, minutes)
    local st = state(camp)
    local now = Store.hours()
    local last = st.seen
    st.seen = now
    prune(st, now)
    local on = Options.on(camp, "council")
    if not on then
        if last ~= nil and now > last then shift(st, now - last) end
        trace(camp, st, now, on)
        return
    end
    sweep(camp, st, now)
    if blocked(camp) then
        if st.next ~= nil and st.next < now + 1 then st.next = now + 1 end
    elseif st.next == nil then
        scheduleFirst(st, now)
    elseif now >= st.next then
        if #st.open < Council.maxOpen then
            local d, why = Council.spawn(camp, nil, false)
            if d == nil and why == "none" then
                st.next = now + Council.retry
            else
                schedule(st, now, camp.level or 1)
            end
        else
            schedule(st, now, camp.level or 1)
        end
    end
    trace(camp, st, now, on)
end

function Council.cheat(camp, sid)
    local d, why = Council.spawn(camp, sid, true)
    if d ~= nil then return say("CnCheatDone", T("CnT_" .. d.sid)) end
    return T("CnNoSpawn_" .. tostring(why == "full" and "full" or (why == "open" and "open" or "none")))
end

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return 0
end

function Council.click(camp, id, index)
    local ms = nowMs()
    local last = Council.lastClick
    if Council.clickGap > 0 and ms > 0 and last ~= nil and ms >= last and ms - last < Council.clickGap then return end
    local ok, text = Council.answer(camp, id, index)
    if ok then
        Council.lastClick = ms
        return
    end
    local st = state(camp)
    st.note = { h = Store.hours(), t = text }
    st.rev = st.rev + 1
    notify(camp, "CnSay", text)
end

local function textWidth(text)
    local ok, value = pcall(function() return getTextManager():MeasureStringX(UIFont.Small, text) end)
    if ok and type(value) == "number" then return value end
    local count = 0
    for i = 1, #text do
        local byte = string.byte(text, i)
        if byte < 128 or byte >= 192 then count = count + 1 end
    end
    return count * 7
end

local function pixelWidth()
    local window = ALifeCamp.Window
    local width = window ~= nil and window.instance ~= nil and window.instance.width or nil
    if type(width) ~= "number" then width = 680 end
    return math.max(240, width - 44)
end

local function wrap(text, limit)
    local lines = {}
    local current = ""
    local position = 1
    local length = #text
    while position <= length + 1 do
        local stop = string.find(text, " ", position, true)
        local word
        if stop == nil then
            word = string.sub(text, position)
            position = length + 2
        else
            word = string.sub(text, position, stop - 1)
            position = stop + 1
        end
        if word ~= "" then
            local trial = current == "" and word or (current .. " " .. word)
            if current ~= "" and textWidth(trial) > limit then
                lines[#lines + 1] = current
                current = word
            else
                current = trial
            end
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = "" end
    return lines
end

local function addWrapped(lines, text, width, indent, r, g, b, click)
    local parts = wrap(text, width - indent)
    for i, part in ipairs(parts) do
        local line = Hooks.line(part, r, g, b, click)
        line.indent = i == 1 and indent or indent + 14
        lines[#lines + 1] = line
    end
end

local function rankKey(rep)
    if rep <= -60 then return 1 end
    if rep <= -20 then return 2 end
    if rep < 20 then return 3 end
    if rep < 60 then return 4 end
    return 5
end

local function buffTexts(st, now)
    local totals = { m = 0, l = 1, f = 1, d = 0 }
    local left = { m = 0, l = 0, f = 0, d = 0 }
    for _, buff in ipairs(st.buffs) do
        if now < buff.t1 and totals[buff.k] ~= nil then
            if buff.k == "m" then
                totals.m = totals.m + buff.v * clamp(1 - (now - buff.t0) / math.max(0.01, buff.t1 - buff.t0), 0, 1)
            elseif buff.k == "d" then
                totals.d = totals.d + buff.v
            else
                totals[buff.k] = totals[buff.k] * buff.v
            end
            left[buff.k] = math.max(left[buff.k], buff.t1 - now)
        end
    end
    local parts = {}
    for _, kind in ipairs({ "m", "l", "d", "f" }) do
        if left[kind] > 0 then
            local hours = math.max(1, math.ceil(left[kind]))
            if kind == "m" or kind == "d" then
                local shown = round(kind == "m" and clamp(totals.m, -25, 25) or totals.d)
                if shown ~= 0 then parts[#parts + 1] = say("CnBuf_" .. kind, (shown > 0 and "+" or "") .. shown, hours) end
            else
                parts[#parts + 1] = say("CnBuf_" .. kind, round(clamp(totals[kind], 0.4, 1.8) * 100) / 100, hours)
            end
        end
    end
    return parts
end

local function decisionLines(lines, camp, st, d, s, now, width, auto)
    local tone = Council.tones[s.tone] or Council.tones.calm
    addWrapped(lines, say("CnHead", T("CnT_" .. s.id)), width, 0, tone[1], tone[2], tone[3], nil)
    addWrapped(lines, sayWith("CnD_" .. s.id, s.desc, d.p), width, 10, 0.82, 0.82, 0.86, nil)
    for index, option in ipairs(optionsOf(s, d.p)) do
        local cost = costOf(option, d.p)
        local text = say("CnOptRow", index, sayWith("CnO_" .. s.id .. "_" .. (option.key or index), option.text, d.p))
        if not option.hideCost then
            local priced = listText(cost)
            if priced ~= "" then text = text .. " " .. say("CnCost", priced) end
        end
        local lack = lackList(camp, cost)
        local r, g, b = 0.65, 0.92, 1
        if #lack > 0 then
            text = text .. " " .. lackText(lack)
            r, g, b = 0.62, 0.52, 0.52
        end
        local id, number = d.id, index
        addWrapped(lines, text, width, 8, r, g, b, function(c) Council.click(c, id, number) end)
    end
    local left = math.max(0, math.ceil(d.due - now))
    local tail = say("CnTail", left, sayWith("CnH_" .. s.id, s.hint, d.p))
    if auto then
        tail = tail .. " " .. say("CnTailAuto", math.max(0, math.ceil(d.at + Council.autoDelay - now)))
    end
    local urgent = left <= 6
    addWrapped(lines, tail, width, 10, urgent and 1 or 0.7, urgent and 0.62 or 0.7, urgent and 0.4 or 0.62, nil)
    lines[#lines + 1] = Hooks.line("")
end

local function buildLines(camp, st, now, width, auto)
    local lines = {}
    if st.note ~= nil and now - st.note.h < Council.noteHours then
        addWrapped(lines, tostring(st.note.t), width, 0, 1, 0.7, 0.4, nil)
    end
    if #st.open > 0 then
        addWrapped(lines, say("CnHelp"), width, 0, 0.62, 0.62, 0.68, nil)
    end
    for _, d in ipairs(st.open) do
        local s = Council.byId[d.sid]
        if s ~= nil then decisionLines(lines, camp, st, d, s, now, width, auto) end
    end
    if #st.open == 0 then
        addWrapped(lines, say("CnIdle"), width, 0, 0.7, 0.7, 0.75, nil)
    end
    addWrapped(lines, say("CnRepLine", round(st.rep), T("CnRank_" .. rankKey(st.rep))), width, 0, 0.9, 0.85, 0.6, nil)
    local buffs = buffTexts(st, now)
    if #buffs > 0 then
        addWrapped(lines, say("CnBuffs", table.concat(buffs, ", ")), width, 0, 0.75, 0.85, 0.7, nil)
    end
    if #st.history > 0 then
        lines[#lines + 1] = Hooks.line(say("CnLast"), 0.6, 0.85, 1)
        local shown = 0
        for i = #st.history, 1, -1 do
            if shown >= Council.historyShown then break end
            local entry = st.history[i]
            local day = math.max(0, math.floor((entry.h - (camp.founded or 0)) / 24))
            local result = say("CnX_" .. entry.sid .. "_" .. entry.k, entry.a, entry.b, entry.c)
            addWrapped(lines, say("CnHistRow", day, T("CnT_" .. entry.sid), result), width, 8, 0.75, 0.8, 0.85, nil)
            shown = shown + 1
        end
    end
    return lines
end

function Council.lines(camp)
    if not Options.on(camp, "council") then return {} end
    local st = state(camp)
    local now = Store.hours()
    local width = pixelWidth()
    local auto = Options.on(camp, "autoCouncil")
    local minute = math.floor(now * 60)
    local signature = tostring(camp.id) .. ":" .. tostring(st.rev) .. ":" .. tostring(minute) .. ":" .. tostring(width) .. (auto and "a" or "m")
    local entry = Council.cache[camp.id]
    if entry ~= nil and entry.source == st and entry.signature == signature then return entry.lines end
    local lines = buildLines(camp, st, now, width, auto)
    Council.cache[camp.id] = { source = st, signature = signature, lines = lines }
    return lines
end

function Council.overview(camp)
    if not Options.on(camp, "council") then return nil end
    local st = state(camp)
    local count = #st.open
    if count == 1 then return { Hooks.line(say("CnOverview1"), 1, 0.45, 0.4) } end
    if count > 1 then return { Hooks.line(say("CnOverviewN", count), 1, 0.45, 0.4) } end
    return { Hooks.line(say("CnOverviewNone", round(st.rep)), 0.72, 0.72, 0.78) }
end

Options.define({ key = "council", group = "life", kind = "toggle", default = true, priority = 70 })
Options.define({ key = "autoCouncil", group = "life", kind = "toggle", default = false, priority = 71 })

Hooks.add("minute", function(camp, minutes) Council.step(camp, minutes) end, 60)
Hooks.add("morale", function(camp) return Council.mood(camp) end, 50)
Hooks.add("labor", function(camp) return Council.factor(camp, "l") end, 50)
Hooks.add("farm", function(camp) return Council.factor(camp, "f") end, 50)
Hooks.add("defense", function(camp) return Council.flat(camp, "d") end, 50)
Hooks.add("overview", function(camp) return Council.overview(camp) end, 50)
Hooks.section("life", "CnTitle", function(camp) return Council.lines(camp) end, 5)

return Council
