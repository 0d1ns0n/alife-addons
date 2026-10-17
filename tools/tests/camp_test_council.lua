dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Stock, Hooks, Options, Council = A.Store, A.Stock, A.Hooks, A.Options, A.Council
local Settlers, Skills, Stats, Build, Cheats = A.Settlers, A.Skills, A.Stats, A.Build, A.Cheats

local lcgSeed = 424242
local function lcg(a, b)
    lcgSeed = (lcgSeed * 1103515245 + 12345) % 2147483648
    local r = math.floor(lcgSeed / 65536)
    if b ~= nil then return a + r % math.max(1, b - a) end
    return r % math.max(1, a or 1)
end
ZombRand = lcg

local CATS = {
    ["Base.Bandage"] = "FirstAid", ["Base.Pills"] = "FirstAid", ["Base.Disinfectant"] = "FirstAid",
    ["Base.Bullets9mm"] = "Ammo", ["Base.CarrotBagSeed2"] = "Gardening", ["Base.BroccoliBagSeed2"] = "Gardening",
    ["Base.RedRadishBagSeed2"] = "Gardening",
}
local CALS = {
    ["Base.DriedBlackBeans"] = 3084, ["Base.PeanutButter"] = 2660, ["Base.CannedMilk"] = 472, ["Base.CannedCorn"] = 315,
    ["Base.TinnedBeans"] = 170, ["Base.DehydratedMeatStick"] = 100, ["Base.Crackers"] = 70,
}
local ItemMeta = {
    __index = {
        getFullType = function(self) return self.full end,
        getDisplayCategory = function(self) return self.cat or "" end,
        getCalories = function(self) return self.calories or 0 end,
        getFluidContainer = function(self) return self.fluid end,
        getContainer = function(self) return self.container end,
        getModData = function(self)
            self.mod = self.mod or {}
            return self.mod
        end,
        getActualWeight = function() return 0.5 end,
    },
}
function NEWITEM(fullType, calories)
    calories = calories or CALS[fullType]
    local item = setmetatable({ full = fullType, calories = calories, class = calories and "Food" or "Item", cat = CATS[fullType] }, ItemMeta)
    if calories then item.classes = { Food = true } end
    return item
end
Fluid = { Water = "Water" }

local CLOCK_HOUR = 12
function getGameTime()
    return { getWorldAgeHours = function() return HOURS end, getHour = function() return CLOCK_HOUR end }
end

local KIND_ITEM = {
    planks = "Base.Plank", nails = "Base.Nails", logs = "Base.Log", metal = "Base.ScrapMetal", rope = "Base.Rope",
    medicine = "Base.Bandage", ammo = "Base.Bullets9mm", seeds = "Base.CarrotBagSeed2",
}
local RICH = { planks = 120, nails = 130, logs = 12, metal = 20, rope = 10, medicine = 10, ammo = 30, seeds = 6, food = 60000, water = 30 }

local function has(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function sealed(value, path, seen, problems)
    local kind = type(value)
    if kind == "function" or kind == "userdata" or kind == "thread" then
        problems[#problems + 1] = path .. ":" .. kind
        return
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then problems[#problems + 1] = path .. ":nan" end
        return
    end
    if kind ~= "table" then return end
    if seen[value] then
        problems[#problems + 1] = path .. ":cycle"
        return
    end
    seen[value] = true
    local count, max = 0, 0
    for key, item in pairs(value) do
        local keyKind = type(key)
        if keyKind == "number" then
            if key ~= math.floor(key) or key < 1 then problems[#problems + 1] = path .. ":badkey" end
            count = count + 1
            if key > max then max = key end
        elseif keyKind ~= "string" then
            problems[#problems + 1] = path .. ":keytype"
        end
        sealed(item, path .. "." .. tostring(key), seen, problems)
    end
    if count ~= max then problems[#problems + 1] = path .. ":holes" end
    seen[value] = nil
end

local function plain(camp, label)
    local problems = {}
    sealed(camp.council, "council", {}, problems)
    check("state is plain data " .. label, #problems == 0, table.concat(problems, ","))
end

local function cleanText(text)
    return type(text) == "string" and text ~= "" and not text:find("%%%d") and not text:find("nil") and not text:find("UI_ALC_")
end

for x = 90, 150 do for y = 90, 150 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)

local camp = A.Camp.create({ x1 = 100, y1 = 100, x2 = 115, y2 = 112, z = 0 }, "Test")
check("camp created", camp ~= nil and #camp.storage >= 1)
camp.phase = "clear"
camp.options.autoPlan = false
camp.options.recruit = false

local counter = 0
local function addPeople(n, role, target)
    target = target or camp
    for _ = 1, n do
        counter = counter + 1
        local uid = "p" .. counter
        Settlers.settle(target, uid, "Man" .. counter)
        target.settlers[uid].role = role or "worker"
    end
end

local function ensurePeople(n)
    while Store.settlerCount(camp) < n do addPeople(1) end
end

local function containers(target)
    local list = {}
    for _, entry in ipairs(target.storage) do
        local crate = Stock.crate(target, entry)
        if crate ~= nil then list[#list + 1] = crate:getContainer() end
    end
    return list
end

local function setStock(spec, target)
    target = target or camp
    local list = containers(target)
    for _, container in ipairs(list) do container.items = {} end
    local first = list[1]
    if first == nil then return end
    for kind, count in pairs(spec) do
        if kind == "food" then
            local rest = count
            while rest > 0 do
                local part = math.min(rest, 2000)
                first:AddItem(NEWITEM("Base.Canned", part))
                rest = rest - part
            end
        elseif kind == "water" then
            local item = NEWITEM("Base.Barrel")
            item.fluid = { getAmount = function() return count end, contains = function() return true end }
            first:AddItem(item)
        else
            for _ = 1, count do first:AddItem(KIND_ITEM[kind]) end
        end
    end
    Stock.refresh(target)
end

local function stockOf(kind)
    Stock.refresh(camp)
    return camp.stock[kind] or 0
end

local function plan()
    return Build.plan(camp)
end

local function addProject(kind, status)
    local items = plan()
    items.serial = items.serial + 1
    items.items[tostring(items.serial)] = { id = items.serial, camp = camp.id, kind = kind, x = 101, y = 101, w = 4, h = 4, status = status, stage = 1, done = {} }
end

local function tick(hours)
    HOURS = HOURS + hours
    Hooks.each("minute", camp, 1)
end

local realRand = Council.rand
local function forceRand(value)
    Council.rand = function(n) return math.max(1, math.min(value, math.floor(n))) end
end
local function freeRand()
    Council.rand = realRand
end

local PG = { added = 0, bonus = 1 }
A.Progress = {
    add = function(c, points) PG.added = PG.added + points end,
    bonus = function(c, key) return PG.bonus end,
}

HOURS = 1000
addPeople(5)
setStock({ planks = 30, nails = 40, food = 40000 })
local st = Council.state(camp)

check("module api", type(Council.stats) == "function" and type(Council.answer) == "function" and type(Council.open) == "function")
check("options defined", Options.byKey.council ~= nil and Options.byKey.autoCouncil ~= nil and Options.byKey.council.group == "life")
check("council default on", Options.on(camp, "council") == true)
check("auto default off", Options.on(camp, "autoCouncil") == false)
check("scenario pool size", #Council.list >= 18, #Council.list)
local ids = {}
for _, s in ipairs(Council.list) do
    check("scenario unique " .. s.id, ids[s.id] == nil)
    ids[s.id] = true
    check("scenario shape " .. s.id, type(s.make) == "function" and type(s.late) == "function" and s.options ~= nil and type(s.res) == "table" and Council.tones[s.tone] ~= nil)
end

local missingStatic = {}
local function need(key)
    if UIJSON["UI_ALC_" .. key] == nil then missingStatic[#missingStatic + 1] = key end
end
for _, s in ipairs(Council.list) do
    need("CnT_" .. s.id)
    need("CnD_" .. s.id)
    need("CnH_" .. s.id)
    for _, key in ipairs(s.res) do need("CnX_" .. s.id .. "_" .. key) end
    if type(s.options) == "table" then
        check("scenario has 2..3 options " .. s.id, #s.options >= 2 and #s.options <= 3, #s.options)
        for _, option in ipairs(s.options) do
            need("CnO_" .. s.id .. "_" .. option.key)
            check("option runs " .. s.id .. option.key, type(option.run) == "function")
        end
    end
end
need("CnO_trader_deal")
need("CnO_trader_no")
need("CnT_trader")
for _, key in ipairs({ "CnTitle", "CnHead", "CnOptRow", "CnCost", "CnLack", "CnTail", "CnIdle", "CnRepLine", "CnLast", "CnHistRow", "CnBuffs",
    "CnNew", "CnLate", "CnAuto", "CnSay", "CnOverview1", "CnOverviewN", "CnOverviewNone", "Opt_council", "OptHint_council",
    "Opt_autoCouncil", "OptHint_autoCouncil", "Log_cn_new", "Log_cn_done", "Log_cn_late", "Log_cn_auto", "Log_cn_trade",
    "ChT_cn_new", "ChD_cn_new", "ChR_cn_new", "ChT_cn_trade", "ChD_cn_trade", "ChR_cn_trade", "ChT_cn_rep", "ChD_cn_rep", "ChR_cn_rep" }) do
    need(key)
end
check("static text keys present", #missingStatic == 0, table.concat(missingStatic, ","))

check("blocked in clear phase", select(2, Council.spawn(camp, nil, false)) == "blocked")
for _ = 1, 80 do tick(1) end
check("nothing while clearing", #st.open == 0 and st.resolved == 0 and st.next == nil)
check("available empty while clearing", #Council.available(camp) == 0)

local tiny = A.Camp.create({ x1 = 120, y1 = 100, x2 = 135, y2 = 112, z = 0 }, "Tiny")
tiny.phase = "plan"
addPeople(1, "worker", tiny)
setStock({ planks = 50, nails = 50, food = 20000 }, tiny)
local tinySt = Council.state(tiny)
for _ = 1, 80 do
    HOURS = HOURS + 1
    Hooks.each("minute", tiny, 1)
end
check("one person gets no decisions", #tinySt.open == 0 and tinySt.resolved == 0)
check("one person blocked", select(2, Council.spawn(tiny, nil, false)) == "blocked")
A.Camp.abandon(tiny)

camp.phase = "plan"
tick(1)
check("first decision scheduled within 3..8 hours", st.next ~= nil and st.next - HOURS >= 3 and st.next - HOURS <= 8, st.next and (st.next - HOURS))
tick(0.5)
check("nothing before the timer", #st.open == 0)
local logBefore = #camp.log
local notesBefore = #PLAYER.notes
HOURS = st.next + 0.01
Hooks.each("minute", camp, 1)
check("decision appeared", #st.open == 1, #st.open)
check("notified player", #PLAYER.notes == notesBefore + 1, PLAYER.notes[#PLAYER.notes])
check("journal entry for new decision", #camp.log == logBefore + 1 and camp.log[#camp.log].k == "cn_new", camp.log[#camp.log] and camp.log[#camp.log].k)
check("decision due in 24 hours", math.abs((st.open[1].due - st.open[1].at) - 24) < 0.001)
check("next timer set 12..30 hours ahead", st.next - HOURS >= 12 and st.next - HOURS <= 30, st.next - HOURS)

local maxOpen = 0
st.open = {}
st.last = {}
for _ = 1, 10 do
    st.next = HOURS
    HOURS = HOURS + 0.05
    Hooks.each("minute", camp, 1)
    maxOpen = math.max(maxOpen, #st.open)
end
check("open decisions capped at three", maxOpen == 3 and #st.open == 3, maxOpen)
local denied, why = Council.spawn(camp, nil, true)
check("forced spawn respects cap", denied == nil and why == "full", why)
check("explicit spawn respects cap", select(1, Council.spawn(camp, "dog", true)) == nil)
check("stats open count", Council.stats(camp).open == 3)
check("open list snapshots", #Council.open(camp) == 3 and Council.open(camp)[1].left > 0 and Council.open(camp)[1].left <= 24)
plain(camp, "after spawns")

local spanLow, spanHigh, means = {}, {}, {}
for level = 1, 4 do
    camp.level = level
    local low, high, sum = 1e9, -1, 0
    for _ = 1, 120 do
        st.open = {}
        st.last = {}
        st.next = HOURS
        HOURS = HOURS + 0.01
        Hooks.each("minute", camp, 1)
        local gap = st.next - HOURS
        low, high, sum = math.min(low, gap), math.max(high, gap), sum + gap
    end
    spanLow[level], spanHigh[level], means[level] = low, high, sum / 120
end
check("interval lower bound 12 hours", spanLow[1] >= 12 and spanLow[4] >= 12, spanLow[1] .. "/" .. spanLow[4])
check("interval upper bound 30 at level 1", spanHigh[1] <= 30 and spanHigh[1] > 24, spanHigh[1])
check("interval shorter at level 4", spanHigh[4] <= 21 and means[4] < means[1] - 2, means[4] .. " vs " .. means[1])
camp.level = 1

st.open = {}
st.last = {}
st.flags = {}
st.rep = 0
st.next = HOURS + 500
camp.storage[1].stock = nil
setStock({ planks = 200, nails = 20, food = 40000, metal = 2, ammo = 10 })
local list = Council.available(camp)
check("no gate means no trader", not has(list, "trader") and not has(list, "bandits") and not has(list, "noise"))
check("common scenarios available", has(list, "wounded") and has(list, "dog") and has(list, "quarrel"), table.concat(list, ","))
check("level gates hold at level 1", not has(list, "radio") and not has(list, "alliance") and not has(list, "doctor") and not has(list, "veteran") and not has(list, "wreck") and not has(list, "horde"))
check("projects gate crew", not has(list, "crew"))
check("food gates hold", has(list, "rats") and has(list, "refugees"))
addProject("house_s", "planned")
check("crew needs projects", has(Council.available(camp), "crew"))
plan().items = {}
addProject("fence", "done")
list = Council.available(camp)
check("trader needs gate", has(list, "trader"))
check("night gates noise", not has(list, "noise"))
CLOCK_HOUR = 23
check("noise appears at night", has(Council.available(camp), "noise"))
CLOCK_HOUR = 12
camp.level = 2
list = Council.available(camp)
check("level 2 unlocks stories", has(list, "radio") and has(list, "alliance") and has(list, "bandits") and has(list, "wreck") and has(list, "doctor") and has(list, "veteran") and has(list, "horde"), table.concat(list, ","))
st.rep = -50
check("bad reputation closes alliance", not has(Council.available(camp), "alliance"))
st.rep = 0
st.flags.well = true
check("well is once only", not has(Council.available(camp), "well"))
st.flags = {}
check("well available before repair", has(Council.available(camp), "well"))
setStock({ planks = 200, nails = 20, food = 5000, metal = 2, ammo = 10 })
list = Council.available(camp)
check("low food closes rats and refugees", not has(list, "rats") and not has(list, "refugees"))
setStock({ planks = 200, nails = 20, food = 40000, metal = 2, ammo = 10 })
local savedStorage = camp.storage
camp.storage = {}
list = Council.available(camp)
check("without storage only story scenarios", has(list, "quarrel") and has(list, "dayoff") and not has(list, "trader") and not has(list, "wounded") and not has(list, "dog"), table.concat(list, ","))
camp.storage = savedStorage
setStock({ planks = 200, nails = 20, food = 40000, metal = 2, ammo = 10 })
st.last = { wounded = HOURS - 1 }
check("cooldown hides recent scenario", not has(Council.available(camp), "wounded"))
st.last = {}
camp.level = 1

local deals, rate = Council.deals(camp, { people = 5, level = 1, stock = camp.stock }, false)
check("trader builds three deals", #deals == 3, #deals)
check("trader rate 70 at start", math.abs(rate - 0.7) < 0.001, rate)
local pay, want = deals[1], deals[1]
for _, deal in ipairs(deals) do
    check("deal pays from surplus " .. deal.g, deal.g == "planks" and deal.gn <= camp.stock.planks - 0.8 * (60 + 6 * 5), deal.gn)
    check("deal sells scarce " .. deal.r, deal.r ~= "planks" and deal.rn >= 1)
end
st.rep = 50
PG.bonus = 1.1
local _, betterRate = Council.deals(camp, { people = 5, level = 1, stock = camp.stock }, false)
check("reputation and progress improve rate", math.abs(betterRate - (0.7 + 0.1 + 0.1)) < 0.001, betterRate)
PG.bonus = 1
st.rep = 0

st.open = {}
st.last = {}
forceRand(100)
local trader = Council.spawn(camp, "trader", false)
check("trader spawned", trader ~= nil and #trader.p.deals == 3 and trader.p.rate == 70)
local deal = trader.p.deals[1]
local planksBefore, getBefore = stockOf(deal.g), stockOf(deal.r)
local repBefore, tradesBefore, resolvedBefore = st.rep, st.trades, st.resolved
local ok, text = Council.answer(camp, trader.id, 1)
check("trade answered", ok == true and cleanText(text), text)
check("trade took payment", stockOf(deal.g) == planksBefore - deal.gn, stockOf(deal.g) .. " vs " .. (planksBefore - deal.gn))
check("trade gave goods", stockOf(deal.r) >= getBefore + deal.rn * 0.99, stockOf(deal.r) .. " vs " .. getBefore .. "+" .. deal.rn)
check("trade bookkeeping", st.trades == tradesBefore + 1 and st.rep == repBefore + 1 and st.resolved == resolvedBefore + 1 and #st.open == 0)
check("trade logged", camp.log[#camp.log - 1] ~= nil and (camp.log[#camp.log].k == "cn_done" or camp.log[#camp.log - 1].k == "cn_trade"))
check("trade stats", Council.stats(camp).trades == 1 and Council.stats(camp).resolved == resolvedBefore + 1 and Council.stats(camp).rep == 1)
check("progress credited for trade", PG.added >= 4, PG.added)
check("history remembers trade", st.history[#st.history].sid == "trader" and st.history[#st.history].k == "d" and st.history[#st.history].o == "player")
check("answer on closed decision refused", select(1, Council.answer(camp, trader.id, 1)) == false)

st.last = {}
trader = Council.spawn(camp, "trader", false)
local first = trader.p.deals[1]
setStock({ planks = 1, nails = 20, food = 40000, metal = 2, ammo = 10 })
local nailsBefore = stockOf("nails")
ok, text = Council.answer(camp, trader.id, 1)
check("trade refused without stock", ok == false and text:find((UIJSON.UI_ALC_CnLack:gsub("%%1.*$", "")), 1, true) ~= nil, text)
check("refusal keeps decision open", #st.open == 1 and stockOf("nails") == nailsBefore and stockOf("planks") == 1)
check("bad option refused", select(1, Council.answer(camp, trader.id, 9)) == false)
local declineIndex = #trader.p.deals + 1
ok, text = Council.answer(camp, trader.id, declineIndex)
check("decline trader", ok == true and #st.open == 0 and st.history[#st.history].k == "n")
freeRand()

setStock({ planks = 100, nails = 100, food = 40000, medicine = 10, ammo = 20, water = 20 })
st.open = {}
st.last = {}
forceRand(100)
local wounded = Council.spawn(camp, "wounded", false)
check("wounded spawned", wounded ~= nil and wounded.p.med >= 2)
local medBefore = stockOf("medicine")
ok, text = Council.answer(camp, wounded.id, 1)
check("treatment spends medicine", ok and stockOf("medicine") == medBefore - wounded.p.med, stockOf("medicine"))
check("bad outcome at worst roll", st.history[#st.history].k == "1c" and cleanText(text))
check("bad outcome lowers mood", Council.mood(camp) < st.rep / 30)
freeRand()

setStock({ planks = 100, nails = 100, food = 40000, medicine = 1, ammo = 20 })
st.open = {}
st.last = {}
wounded = Council.spawn(camp, "wounded", false)
ok, text = Council.answer(camp, wounded.id, 1)
check("no medicine means refusal", ok == false and #st.open == 1 and stockOf("medicine") == 1, text)
Council.answer(camp, wounded.id, 3)

st.open = {}
st.last = {}
st.rep = 0
setStock({ planks = 100, nails = 100, food = 40000, medicine = 10, ammo = 40 })
local hunters = Council.spawn(camp, "hunters", false)
check("hunters spawned", hunters ~= nil)
local ammoBefore, foodBefore = stockOf("ammo"), stockOf("food")
ok, text = Council.answer(camp, hunters.id, 1)
check("hunters cost ammo and give food", ok and stockOf("ammo") == ammoBefore - hunters.p.ammo and stockOf("food") >= foodBefore + hunters.p.meat * 0.9, stockOf("food") - foodBefore)

st.open = {}
st.last = {}
local well = Council.spawn(camp, "well", false)
local planksBefore2, ropeBefore = stockOf("planks"), stockOf("rope")
setStock({ planks = 100, nails = 100, food = 40000, rope = 5 })
ok = Council.answer(camp, well.id, 1)
check("well repair paid and flagged", ok and stockOf("planks") == 100 - 12 and stockOf("nails") == 100 - 10 and stockOf("rope") == 5 - 3 and st.flags.well == true)
check("farm bonus after well", Hooks.product("farm", camp) > 1.1)
check("well not offered twice", Council.spawn(camp, "well", false) == nil)

st.open = {}
st.last = {}
local rep0 = st.rep
Council.addRep(camp, 500)
check("reputation capped high", st.rep == 100 and Council.stats(camp).rep == 100)
Council.addRep(camp, -900)
check("reputation capped low", st.rep == -100)
st.buffs = {}
check("reputation changes morale", Council.mood(camp) < -3 and Council.mood(camp) > -4)
st.rep = rep0

st.open = {}
st.last = {}
st.buffs = {}
setStock({ planks = 100, nails = 100, food = 60000, medicine = 10, ammo = 30, water = 20 })
local baseMorale = Stats.compute(camp).morale
local dayoff = Council.spawn(camp, "dayoff", false)
check("dayoff spawned", dayoff ~= nil)
forceRand(100)
ok, text = Council.answer(camp, dayoff.id, 1)
freeRand()
check("day off answered free", ok and cleanText(text))
local lifted = Stats.compute(camp).morale
check("morale hook adds mood", lifted - baseMorale >= 8, lifted - baseMorale)
check("labor drops after day off", math.abs(Hooks.product("labor", camp) - 0.55) < 0.001, Hooks.product("labor", camp))
HOURS = HOURS + 24
local halfway = Stats.compute(camp).morale
check("mood decays over time", halfway < lifted and halfway > baseMorale, halfway)
check("labor restored after rest", math.abs(Hooks.product("labor", camp) - 1) < 0.001)
HOURS = HOURS + 30
check("mood fully faded", Stats.compute(camp).morale == baseMorale and #st.buffs >= 0)
Hooks.each("minute", camp, 1)
check("expired buffs pruned", #st.buffs == 0, #st.buffs)

local guardDefense = Hooks.sum("defense", camp)
st.open = {}
st.last = {}
local noise = Council.spawn(camp, "noise", true)
forceRand(100)
Council.answer(camp, noise.id, 2)
freeRand()
check("defense hook adds alert", Hooks.sum("defense", camp) - guardDefense == 8)

st.open = {}
st.last = {}
local garden = Council.spawn(camp, "garden", false)
forceRand(1)
local foodBeforeGarden = stockOf("food")
Council.answer(camp, garden.id, 1)
freeRand()
check("garden grants food and boosts farm", stockOf("food") > foodBeforeGarden and Hooks.product("farm", camp) > 1.1 and stockOf("seeds") >= garden.p.seeds)

st.open = {}
st.last = {}
st.buffs = {}
setStock({ planks = 100, nails = 100, food = 40000, medicine = 10, ammo = 30 })
local before = st.resolved
local late = Council.spawn(camp, "wounded", false)
local repLate = st.rep
HOURS = late.due - 1
st.next = HOURS + 1000
Hooks.each("minute", camp, 1)
check("still open before the deadline", #st.open == 1 and st.resolved == before)
HOURS = late.due + 0.01
Hooks.each("minute", camp, 1)
check("expired decision resolved by default", #st.open == 0 and st.resolved == before + 1, #st.open)
check("default consequence applied", st.rep == repLate - 4 and st.history[#st.history].o == "late" and st.history[#st.history].k == "t")
check("late journal entry", camp.log[#camp.log].k == "cn_late", camp.log[#camp.log].k)

st.open = {}
st.last = {}
Options.set(camp, "autoCouncil", true)
setStock({ planks = 100, nails = 100, food = 40000, medicine = 10, ammo = 30 })
local auto = Council.spawn(camp, "wounded", false)
local foodAuto = stockOf("food")
HOURS = auto.at + 2.9
st.next = HOURS + 1000
Hooks.each("minute", camp, 1)
check("auto mode waits three hours", #st.open == 1)
HOURS = auto.at + 3.05
Hooks.each("minute", camp, 1)
check("auto mode resolves safely", #st.open == 0 and st.history[#st.history].o == "auto" and st.history[#st.history].k:sub(1, 1) == "2", st.history[#st.history].k)
check("auto choice paid its price", stockOf("food") <= foodAuto - auto.p.food + 2000, stockOf("food") .. " vs " .. foodAuto)
check("auto journal entry", camp.log[#camp.log].k == "cn_auto", camp.log[#camp.log].k)
setStock({ planks = 100, nails = 100, food = 100, medicine = 10, ammo = 30 })
st.last = {}
local broke = Council.spawn(camp, "wounded", true)
HOURS = broke.at + 3.1
st.next = HOURS + 1000
local repBroke = st.rep
Hooks.each("minute", camp, 1)
check("auto falls back to inaction without stock", #st.open == 0 and st.history[#st.history].o == "auto" and st.history[#st.history].k == "t" and st.rep == repBroke - 4)
st.last = {}
local trade2 = Council.spawn(camp, "trader", true)
setStock({ planks = 200, nails = 20, food = 40000, metal = 2, ammo = 10 })
trade2 = Council.spawn(camp, "trader", true) or trade2
HOURS = HOURS + 3.1
st.next = HOURS + 1000
Hooks.each("minute", camp, 1)
check("auto declines the trader", #st.open == 0 and st.history[#st.history].sid == "trader" and st.history[#st.history].k == "n", st.history[#st.history].k)
Options.set(camp, "autoCouncil", false)

st.open = {}
st.last = {}
setStock(RICH)
local pending = Council.spawn(camp, "dog", false)
local dueBefore = pending.due
Options.set(camp, "council", false)
check("disabled hides section", #Council.lines(camp) == 0)
local overviewShown = false
for _, line in ipairs(Hooks.overview(camp)) do
    if line.text:find(UIJSON.UI_ALC_CnOverviewNone:sub(1, 12), 1, true) or line.text:find(UIJSON.UI_ALC_CnOverview1:sub(1, 12), 1, true) then overviewShown = true end
end
check("disabled hides overview", Council.overview(camp) == nil and not overviewShown)
local serialBefore = st.serial
st.next = HOURS
for _ = 1, 100 do tick(1) end
check("disabled spawns nothing", st.serial == serialBefore and #st.open == 1)
check("disabled freezes the deadline", math.abs((pending.due - HOURS) - (dueBefore - (HOURS - 100))) < 0.5 and pending.due - HOURS > 20, pending.due - HOURS)
check("disabled blocks no answers", select(1, Council.state(camp)) ~= nil)
st.next = HOURS + 50
Options.set(camp, "council", true)
tick(0.01)
check("re-enabled keeps decision", #st.open == 1 and st.open[1] == pending)
Council.answer(camp, pending.id, 2)
st.open = {}

local win = A.Window.open(camp)
A.Window.createChildren(win)
win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
Council.clickGap = 0
local tabs = {}
for _, tab in ipairs(Hooks.tabs) do tabs[tab.id] = tab end
Hooks.section("life", "Tab_life", function() return { Hooks.line("other section") } end, 10)
local lines = Hooks.tabLines(tabs.life, camp)
check("empty council still shows reputation", lines[1].text == UIJSON.UI_ALC_CnTitle and UIJSON.UI_ALC_CnIdle:sub(1, #lines[2].text) == lines[2].text, lines[2] and lines[2].text)
check("council section goes first", lines[#lines - 2] ~= nil)

st.last = {}
setStock(RICH)
forceRand(100)
local q = Council.spawn(camp, "dayoff", false)
local w = Council.spawn(camp, "wounded", false)
local t3 = Council.spawn(camp, "trader", true)
freeRand()
HOURS = HOURS + 0.5
lines = Hooks.tabLines(tabs.life, camp)
check("ui shows title first", lines[1].text == UIJSON.UI_ALC_CnTitle, lines[1].text)
local headFound = false
for _, line in ipairs(lines) do
    if line.text:sub(1, 8) == UIJSON.UI_ALC_CnHead:sub(1, 8) then headFound = true end
end
check("ui lists decision heads", headFound and lines[2].text:sub(1, 8) == UIJSON.UI_ALC_CnHelp:sub(1, 8))
local clickable = 0
for _, line in ipairs(lines) do
    if line.click ~= nil then clickable = clickable + 1 end
end
local expectedOptions = 3 + 3 + (#t3.p.deals + 1)
check("every option row clickable", clickable >= expectedOptions, clickable .. " vs " .. expectedOptions)
local widthLimit = 672 - 44 + 20
local widest = 0
for _, line in ipairs(lines) do
    local px = getTextManager():MeasureStringX("Small", line.text) + (line.indent or 0)
    if px > widest then widest = px end
end
check("ui lines wrapped to window width", widest <= widthLimit + 1, widest)
local urgentFound = false
for _, line in ipairs(lines) do
    if line.text:find(UIJSON.UI_ALC_CnTail:sub(1, 8), 1, true) then urgentFound = true end
end
check("ui shows time left", urgentFound)
local over = Hooks.overview(camp)
local councilLine
for _, line in ipairs(over) do
    if line.text:find("3", 1, true) and line.r == 1 and line.g < 0.6 then councilLine = line end
end
check("overview shows red count", councilLine ~= nil)
st.open = { st.open[1] }
local single = Hooks.overview(camp)
check("overview singular form", single[#single].text == UIJSON.UI_ALC_CnOverview1)
st.open = {}
local none = Hooks.overview(camp)
check("overview calm when none", none[#none].r < 0.8 and none[#none].text:find("%d") ~= nil)

st.last = {}
local clickDecision = Council.spawn(camp, "dayoff", false)
win:selectTab("life")
win:prerender()
check("window life tab has clickable rows", #win.hitRows >= 3, #win.hitRows)
local resolvedUi = st.resolved
local rowFirst = win.hitRows[1]
win:onMouseDown(20, rowFirst.y1 + 1)
win:onMouseUp(20, rowFirst.y1 + 1)
check("click on option answers", st.resolved == resolvedUi + 1 and #st.open == 0, st.resolved)
check("answer shows result in history", st.history[#st.history].sid == "dayoff")

st.last = {}
setStock({ planks = 100, nails = 100, food = 40000, ammo = 20 })
local blockedDecision = Council.spawn(camp, "wounded", false)
win:prerender()
local notes = #PLAYER.notes
win:onContentClick(win.hitRows[1].y1 + 1)
check("unaffordable click keeps decision and explains", #st.open == 1 and #PLAYER.notes == notes + 1 and st.note ~= nil, #PLAYER.notes - notes)
local with = Hooks.tabLines(tabs.life, camp)
local lackShown = false
for _, line in ipairs(with) do
    if line.text:find((UIJSON.UI_ALC_CnLack:gsub("%%1.*$", "")), 1, true) then lackShown = true end
end
check("ui marks missing stock", lackShown)
Council.answer(camp, blockedDecision.id, 3)

st.open = {}
st.last = {}
setStock(RICH)
local g1 = Council.spawn(camp, "dayoff", false)
local g2 = Council.spawn(camp, "quarrel", false)
local cachedA = Council.lines(camp)
check("lines cached within a minute", Council.lines(camp) == cachedA)
Council.clickGap = 350
Council.lastClick = nil
Council.click(camp, g1.id, 2)
check("first click answers", #st.open == 1 and st.open[1].id == g2.id)
Council.click(camp, g2.id, 1)
check("rapid second click is ignored", #st.open == 1)
local realStamp = getTimestampMs
getTimestampMs = function() return 9000 end
Council.click(camp, g2.id, 1)
check("later click is accepted", #st.open == 0)
getTimestampMs = realStamp
Council.clickGap = 0
check("cache refreshed after change", Council.lines(camp) ~= cachedA)
local savedState = camp.council
camp.council = nil
local fresh0 = Council.stats(camp)
check("state rebuilt from nothing", fresh0.open == 0 and fresh0.resolved == 0 and fresh0.rep == 0 and type(fresh0.trades) == "number")
check("cache bound to the state table", Council.lines(camp) ~= cachedA)
camp.council = savedState
st = Council.state(camp)
local numeric = Council.stats(camp)
check("stats are plain numbers", type(numeric.resolved) == "number" and type(numeric.trades) == "number" and type(numeric.rep) == "number" and type(numeric.open) == "number")

st.history = {}
for _ = 1, 5 do
    st.open = {}
    st.last = {}
    setStock(RICH)
    forceRand(1)
    local d = Council.spawn(camp, "dayoff", false)
    Council.answer(camp, d.id, 2)
    freeRand()
end
check("history capped", #st.history == Council.historyLimit - 1 or #st.history <= Council.historyLimit)
st.rev = st.rev + 1
lines = Hooks.tabLines(tabs.life, camp)
local rows = 0
for _, line in ipairs(lines) do
    if line.text:find("^%S+ %d+%.") ~= nil and line.text:find(UIJSON.UI_ALC_CnHistRow:sub(1, 4), 1, true) then rows = rows + 1 end
end
check("only last three results shown", rows == 3, rows)
for _, tab in ipairs(win.tabs) do
    win:selectTab(tab.id)
    win:prerender()
end
win:selectTab("log")
local logLines = win:logLines(camp)
local rawLog = false
for _, line in ipairs(logLines) do
    if line.text:find("UI_ALC_") then rawLog = true end
end
check("journal renders council entries", not rawLog)
win:selectTab("settings")
local settingsLines = Options.lines(camp)
local seenOption = 0
for _, line in ipairs(settingsLines) do
    if line.text == UIJSON.UI_ALC_Opt_council .. ": " .. UIJSON.UI_ALC_OptOn or line.text == UIJSON.UI_ALC_Opt_autoCouncil .. ": " .. UIJSON.UI_ALC_OptOff then seenOption = seenOption + 1 end
end
check("options appear in settings", seenOption == 2, seenOption)

local skillCamp = camp
st.open = {}
st.last = {}
for uid, settler in pairs(skillCamp.settlers) do settler.skills = nil end
local medicUid
for uid, settler in pairs(skillCamp.settlers) do
    if medicUid == nil then
        medicUid = uid
        settler.role = "medic"
    end
end
setStock(RICH)
local doctor = Council.spawn(camp, "doctor", true)
local foodDoc = stockOf("food")
ok, text = Council.answer(camp, doctor.id, 1)
check("doctor course paid with food", ok and stockOf("food") <= foodDoc - doctor.p.big + 2000, stockOf("food") .. " vs " .. foodDoc)
check("doctor trained medics more", Skills.level(skillCamp.settlers[medicUid], "medic") == 2, Skills.level(skillCamp.settlers[medicUid], "medic"))
local otherUid
for uid in pairs(skillCamp.settlers) do
    if uid ~= medicUid then otherUid = uid end
end
check("doctor trained others", Skills.level(skillCamp.settlers[otherUid], "medic") == 1)
plain(camp, "after training")

ensurePeople(6)
st.open = {}
st.last = {}
setStock(RICH)
forceRand(1)
local quarrel = Council.spawn(camp, "quarrel", false)
check("quarrel picks two names", quarrel.p.n1 ~= quarrel.p.n2 and quarrel.p.u1 ~= quarrel.p.u2)
local peopleBefore = Store.settlerCount(camp)
ok, text = Council.answer(camp, quarrel.id, 2)
freeRand()
check("quarrel can cost a settler", ok and st.history[#st.history].k == "2b" and Store.settlerCount(camp) == peopleBefore - 1 and camp.settlers[quarrel.p.u2] == nil, st.history[#st.history].k)
ensurePeople(6)

local covered = {}
local rolls = { 1, 40, 75, 100 }
local sweepRep = 0
local function optionList(d)
    local s = Council.byId[d.sid]
    if type(s.options) == "function" then return s.options(d.p) end
    return s.options
end
local function fresh(sid)
    local state = Council.state(camp)
    state.open = {}
    state.last = {}
    state.flags = {}
    state.rep = sweepRep
    state.next = HOURS + 1000
    ensurePeople(6)
    camp.level = 2
    setStock(RICH)
    return Council.spawn(camp, sid, true)
end
local sweepFails = {}
local function sweep(only, withLate)
    for _, s in ipairs(Council.list) do
        if only == nil or only == s.id then
            covered[s.id] = covered[s.id] or {}
            for _, value in ipairs(rolls) do
                local d = fresh(s.id)
                local count = #optionList(d)
                for index = 1, count do
                    d = fresh(s.id)
                    forceRand(value)
                    local ok2, result = Council.answer(camp, d.id, index)
                    freeRand()
                    if not ok2 or not cleanText(result) then sweepFails[#sweepFails + 1] = s.id .. ":" .. index .. ":" .. value .. ":" .. tostring(result) end
                    local entry = Council.state(camp).history[#Council.state(camp).history]
                    if entry ~= nil then
                        covered[s.id][entry.k] = true
                        if not has(s.res, entry.k) then sweepFails[#sweepFails + 1] = s.id .. " undeclared " .. entry.k end
                    end
                end
            end
            if withLate then
                local d = fresh(s.id)
                HOURS = d.due + 0.01
                Council.state(camp).next = HOURS + 1000
                Hooks.each("minute", camp, 1)
                local entry = Council.state(camp).history[#Council.state(camp).history]
                if entry == nil or entry.o ~= "late" or not has(s.res, entry.k) then sweepFails[#sweepFails + 1] = s.id .. " late " .. tostring(entry and entry.k) end
                covered[s.id][entry and entry.k or "?"] = true
            end
        end
    end
end
sweep(nil, true)
sweepRep = 60
sweep("trader", false)
sweepRep = 0
check("every scenario answerable at every option and roll", #sweepFails == 0, table.concat(sweepFails, " | "))
local unreached = {}
for _, s in ipairs(Council.list) do
    for _, key in ipairs(s.res) do
        if not covered[s.id][key] then unreached[#unreached + 1] = s.id .. "_" .. key end
    end
end
check("every declared outcome reachable", #unreached == 0, table.concat(unreached, ","))
plain(camp, "after full sweep")
for _, line in ipairs(Hooks.tabLines(tabs.life, camp)) do
    check("rendered line is clean", line.text == "" or cleanText(line.text), line.text)
end

for _, s in ipairs(Council.list) do
    local d = fresh(s.id)
    local lines2 = Council.lines(camp)
    local clean = true
    for _, line in ipairs(lines2) do
        if line.text ~= "" and not cleanText(line.text) then clean = false end
    end
    check("scenario renders cleanly " .. s.id, clean and #lines2 >= 5, #lines2)
end

st.open = {}
st.last = {}
st.buffs = {}
st.rep = 0
Council.state(camp).next = HOURS + 1000
for _ = 1, 4 do
    local d = fresh("dayoff")
    forceRand(100)
    Council.answer(camp, d.id, 2)
    freeRand()
end
local buffLines = Council.lines(camp)
local tail = UIJSON.UI_ALC_CnBuf_m:match("%%2 (.*)$")
local entries = 0
for _, line in ipairs(buffLines) do
    local from = 1
    while true do
        local at = line.text:find(tail, from, true)
        if at == nil then break end
        entries = entries + 1
        from = at + 1
    end
end
check("buffs are merged by kind", entries == 2 and #st.buffs == 8, entries .. "/" .. #st.buffs)

local weighted = Council.byId.alliance.weight({ rep = 80 }) > Council.byId.alliance.weight({ rep = 0 })
    and Council.byId.bandits.weight({ rep = -80 }) > Council.byId.bandits.weight({ rep = 0 })
    and Council.byId.trader.weight({ rep = 100 }) > Council.byId.trader.weight({ rep = 0 })
check("reputation shifts story weights", weighted)

local ratsDecision = fresh("rats")
local foodRats = stockOf("food")
HOURS = ratsDecision.due + 0.01
Council.state(camp).next = HOURS + 1000
Hooks.each("minute", camp, 1)
check("rats eat food when ignored", foodRats - stockOf("food") >= ratsDecision.p.loss * 0.99, foodRats - stockOf("food"))

local hordeDecision = fresh("horde")
local ammoHorde = stockOf("ammo")
forceRand(100)
ok, text = Council.answer(camp, hordeDecision.id, "2")
freeRand()
check("horde noise backfires and costs ammo", ok and Council.state(camp).history[#Council.state(camp).history].k == "2b" and stockOf("ammo") <= ammoHorde - hordeDecision.p.ammo - 6 + 0, ammoHorde - stockOf("ammo"))

Council.state(camp).open = {}
Council.state(camp).last = {}
Council.state(camp).rep = 0
Council.state(camp).next = HOURS + 1000
ensurePeople(6)
setStock(RICH)
local cheatNote = Cheats.actions.cn_new ~= nil and Cheats.actions.cn_trade ~= nil and Cheats.actions.cn_rep ~= nil
check("cheats defined", cheatNote)
local sections = {}
for _, entry in ipairs(Cheats.order) do sections[entry.id] = entry.section end
check("cheats in life section", sections.cn_new == "life" and sections.cn_trade == "life" and sections.cn_rep == "life")
local result = Cheats.run("cn_new", PLAYER)
check("cheat opens a decision", #Council.state(camp).open == 1 and cleanText(result), result)
result = Cheats.run("cn_trade", PLAYER)
local hasTrader = false
for _, d in ipairs(Council.state(camp).open) do
    if d.sid == "trader" then hasTrader = true end
end
check("cheat calls trader", hasTrader and cleanText(result), result)
result = Cheats.run("cn_trade", PLAYER)
check("cheat trader twice refused politely", cleanText(result) and #Council.state(camp).open <= 2, result)
Cheats.run("cn_rep", PLAYER)
check("cheat adds fifty reputation", Council.stats(camp).rep == 50)
result = Cheats.run("cn_rep", PLAYER)
Cheats.run("cn_rep", PLAYER)
check("cheat reputation capped", Council.stats(camp).rep == 100 and cleanText(result), result)
for _ = 1, 4 do Cheats.run("cn_new", PLAYER) end
check("cheat respects cap", #Council.state(camp).open == 3)
check("cheat journal", camp.log[#camp.log].k == "cheat" or camp.log[#camp.log].k == "cn_new")
plain(camp, "after cheats")

local fuzzErrors = {}
local function attempt(label, fn)
    local good, err = pcall(fn)
    if not good then fuzzErrors[#fuzzErrors + 1] = label .. ": " .. tostring(err) end
end
local fuzzKinds = { "planks", "nails", "logs", "metal", "rope", "medicine", "ammo", "seeds", "food", "water" }
local fuzzStorage = camp.storage
local fuzzPlan = plan()
local printsFuzz = #PRINTS
for turn = 1, 3000 do
    local pick = ZombRand(100)
    if pick < 10 then
        local spec = {}
        for _, kind in ipairs(fuzzKinds) do
            local amount = ZombRand(4) == 0 and 0 or ZombRand(kind == "food" and 40000 or 120)
            if amount > 0 then spec[kind] = amount end
        end
        attempt("stock", function() setStock(spec) end)
    elseif pick < 14 then
        camp.storage = ZombRand(5) == 0 and {} or fuzzStorage
    elseif pick < 18 then
        for uid in pairs(camp.settlers) do camp.settlers[uid] = nil end
        addPeople(ZombRand(9))
    elseif pick < 22 then
        camp.level = ZombRand(4) + 1
        camp.phase = ({ "clear", "plan", "build", "plan" })[ZombRand(4) + 1]
        CLOCK_HOUR = ZombRand(24)
    elseif pick < 25 then
        fuzzPlan.items = {}
        if ZombRand(2) == 0 then addProject("fence", "done") end
        if ZombRand(2) == 0 then addProject("farm", "planned") end
    elseif pick < 30 then
        Options.set(camp, "council", ZombRand(4) ~= 0)
        Options.set(camp, "autoCouncil", ZombRand(2) == 0)
    elseif pick < 38 then
        attempt("spawn", function() Council.spawn(camp, ZombRand(3) == 0 and nil or Council.list[ZombRand(#Council.list) + 1].id, ZombRand(2) == 0) end)
    elseif pick < 58 then
        attempt("answer", function()
            local open = Council.state(camp).open
            if #open > 0 then Council.answer(camp, open[ZombRand(#open) + 1].id, ZombRand(5)) else Council.answer(camp, ZombRand(1000), 1) end
        end)
    elseif pick < 66 then
        attempt("click", function()
            local open = Council.state(camp).open
            if #open > 0 then Council.click(camp, open[ZombRand(#open) + 1].id, ZombRand(4) + 1) end
        end)
    elseif pick < 74 then
        attempt("lines", function()
            for _, line in ipairs(Council.lines(camp)) do
                if type(line.text) ~= "string" then error("bad line") end
            end
            Council.overview(camp)
            Hooks.sum("morale", camp)
            Hooks.product("labor", camp)
            Hooks.product("farm", camp)
            Hooks.sum("defense", camp)
        end)
    else
        HOURS = HOURS + ZombRand(300) / 60
    end
    attempt("step", function()
        HOURS = HOURS + ZombRand(40) / 60
        Hooks.each("minute", camp, 1)
    end)
    if turn % 500 == 0 then
        local problems = {}
        sealed(camp.council, "council", {}, problems)
        if #problems > 0 then fuzzErrors[#fuzzErrors + 1] = "plain: " .. table.concat(problems, ",") end
        local current = Council.state(camp)
        if #current.open > 3 then fuzzErrors[#fuzzErrors + 1] = "cap exceeded" end
        if current.rep > 100 or current.rep < -100 then fuzzErrors[#fuzzErrors + 1] = "rep range" end
    end
end
local fuzzReported = {}
for index = printsFuzz + 1, #PRINTS do
    if PRINTS[index]:find("failed", 1, true) then fuzzReported[#fuzzReported + 1] = PRINTS[index] end
end
check("random play raises no errors", #fuzzErrors == 0, fuzzErrors[1])
check("random play reports no scenario failures", #fuzzReported == 0, table.concat(fuzzReported, " | "))
camp.storage = fuzzStorage
fuzzPlan.items = {}
Options.set(camp, "council", true)
Options.set(camp, "autoCouncil", false)
camp.level = 2
camp.phase = "plan"
CLOCK_HOUR = 12
for uid in pairs(camp.settlers) do camp.settlers[uid] = nil end
addPeople(6)
Council.state(camp).open = {}
Council.state(camp).buffs = {}

local reg = MOCKALIFE()
local playersSquare = A.World.square(105, 105, 0)
for uid in pairs(camp.settlers) do ADDACTOR(reg, uid, "friendly", 105, 105, playersSquare) end
ZombRand = lcg
Council.state(camp).open = {}
Council.state(camp).last = {}
Council.state(camp).buffs = {}
Council.state(camp).flags = {}
Council.state(camp).next = HOURS + 1
camp.phase = "plan"
setStock({ planks = 150, nails = 150, food = 100000, medicine = 12, ammo = 40, metal = 30, rope = 14, logs = 20, seeds = 8 })
local serialStart = Council.state(camp).serial
local printsStart = #PRINTS
local people = Store.settlerCount(camp)
for _ = 1, 60 * 20 do
    HOURS = HOURS + 1 / 60
    fire("EveryOneMinute")
end
check("director loop keeps people", Store.settlerCount(camp) == people, Store.settlerCount(camp))
check("director loop produces decisions", Council.state(camp).serial > serialStart, Council.state(camp).serial - serialStart)
check("director never exceeds cap", #Council.state(camp).open <= 3)
local traces = 0
for index = printsStart + 1, #PRINTS do
    if PRINTS[index]:find("[ALifeCamp:Council]", 1, true) then traces = traces + 1 end
end
check("one trace line per hour", traces >= 18 and traces <= 22, traces)
local sampleTrace
for index = #PRINTS, 1, -1 do
    if PRINTS[index]:find("[ALifeCamp:Council]", 1, true) then sampleTrace = PRINTS[index] break end
end
check("trace format", sampleTrace ~= nil and sampleTrace:find("open=", 1, true) ~= nil and sampleTrace:find("rep=", 1, true) ~= nil, sampleTrace)
plain(camp, "after director run")
local hookErrors = {}
for _, line in ipairs(PRINTS) do
    if line:find("hook minute failed", 1, true) or line:find("hook morale failed", 1, true) or line:find("hook labor failed", 1, true)
        or line:find("hook overview failed", 1, true) or line:find("scenario ", 1, true) or line:find("tab:life failed", 1, true) then
        hookErrors[#hookErrors + 1] = line
    end
end
check("no hook errors reported", #hookErrors == 0, table.concat(hookErrors, " | "))

local missing = {}
for k in pairs(MISSING) do missing[#missing + 1] = k end
table.sort(missing)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missing }
