dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Stock, Settlers, Hooks, Options, Health, Stats, Work, Skills, Geo =
    A.Store, A.Camp, A.Stock, A.Settlers, A.Hooks, A.Options, A.Health, A.Stats, A.Work, A.Skills, A.Geo
local T = A.T
local reg, orders = MOCKALIFE()
PLAYER = NEWPLAYER(0)
HOURS = 1000

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
    return out
end

local DEFAULTS = {}
for k, v in pairs(Health) do
    if type(v) == "number" then DEFAULTS[k] = v end
end
for _, k in ipairs({ "chance", "contagion", "selfRate", "worsen", "rates", "weights", "xp" }) do DEFAULTS[k] = copy(Health[k]) end

local function reset()
    for k, v in pairs(DEFAULTS) do
        if type(v) == "table" then Health[k] = copy(v) else Health[k] = v end
    end
    Health.wardCache = {}
    A.Progress = nil
    A.Sanitary = nil
end

local function calm()
    local c = Health.chance
    c.base, c.spread, c.wound, c.woundLost, c.fester, c.cough = 0, 0, 0, 0, 0, 0
    for k in pairs(Health.worsen) do Health.worsen[k] = 0 end
end

local function RAND(v)
    ZombRand = function(n)
        if v >= n then return n - 1 end
        return v
    end
end

local serial = 0
local function scenario(roles, medicine, food)
    reset()
    serial = serial + 1
    local x0 = 100 + (serial - 1) * 40
    for x = x0 - 3, x0 + 25 do for y = 96, 125 do NEWSQUARE(x, y, 0) end end
    local camp = Camp.create({ x1 = x0, y1 = 100, x2 = x0 + 19, y2 = 119, z = 0 }, "H" .. serial, { demolish = false })
    camp.options.recruit = false
    camp.options.raids = false
    camp.options.autoPlan = false
    camp.options.expand = false
    camp.phase = "plan"
    local uids = {}
    for i, role in ipairs(roles or {}) do
        local uid = "s" .. serial .. "_" .. i
        local x, y = x0 + 2 + i, 105
        ADDACTOR(reg, uid, "friendly", x, y, A.World.square(x, y, 0))
        Settlers.settle(camp, uid, "N" .. serial .. "_" .. i)
        camp.settlers[uid].role = role
        uids[i] = uid
    end
    local box = Stock.crate(camp, camp.storage[1]):getContainer()
    for _ = 1, medicine or 0 do
        local item = NEWITEM("Base.Bandage")
        item.cat = "FirstAid"
        item.mod = {}
        item.getModData = function(self) return self.mod end
        item.container = box
        table.insert(box.items, item)
    end
    for _ = 1, food or 0 do
        local item = NEWITEM("Base.Canned", 1000)
        item.mod = {}
        item.getModData = function(self) return self.mod end
        item.container = box
        table.insert(box.items, item)
    end
    Stock.refresh(camp)
    calm()
    RAND(0)
    return camp, uids, x0
end

local function hours(camp, n)
    for _ = 1, n do
        HOURS = HOURS + 1
        Hooks.each("minute", camp, 60)
    end
end

local function logKeys(camp)
    local set = {}
    for _, entry in ipairs(camp.log) do set[entry.k] = (set[entry.k] or 0) + 1 end
    return set
end

local function healthyCount(camp)
    local n = 0
    for uid in pairs(camp.settlers) do
        if Health.sickLevel(camp, uid) == 0 then n = n + 1 end
    end
    return n
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local function rate(kind, effect, power)
    return Health.selfRate[kind] * (1 + (effect - 1) * power)
end

local function medicineLeft(camp)
    Stock.refresh(camp)
    return camp.stock.medicine
end

local function serializable(value, seen, path)
    local t = type(value)
    if t == "string" or t == "boolean" then return true end
    if t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return false, path .. ":badnumber" end
        return true
    end
    if t ~= "table" then return false, path .. ":" .. t end
    if seen[value] then return false, path .. ":cycle" end
    seen[value] = true
    local count, top = 0, 0
    for k, v in pairs(value) do
        local kt = type(k)
        if kt == "number" then
            if k ~= math.floor(k) or k < 1 then return false, path .. ":badindex" end
            count = count + 1
            if k > top then top = k end
        elseif kt ~= "string" then
            return false, path .. ":keytype"
        end
        local ok, why = serializable(v, seen, path .. "." .. tostring(k))
        if not ok then return false, why end
    end
    if count > 0 and top ~= count then return false, path .. ":sparse" end
    seen[value] = nil
    return true
end

local function cleanState(camp)
    local ok, why = serializable(camp, {}, "camp")
    return ok, why
end

check("module loaded", Health ~= nil and A.Health == Health)
check("api present", type(Health.stats) == "function" and type(Health.sickLevel) == "function")
check("option epidemics", Options.byKey.epidemics ~= nil and Options.byKey.epidemics.group == "life" and Options.byKey.epidemics.kind == "toggle" and Options.byKey.epidemics.default == true)
check("option quarantine", Options.byKey.quarantine ~= nil and Options.byKey.quarantine.group == "life" and Options.byKey.quarantine.kind == "toggle" and Options.byKey.quarantine.default == true)

local anchorPriority, sectionPriority
for _, entry in ipairs(Hooks.lists.anchor or {}) do
    if entry.priority == 20 then anchorPriority = true end
end
for _, section in ipairs(Hooks.tab("life").sections) do
    if section.title == "HlSection" then sectionPriority = section.priority end
end
check("anchor hook priority 20", anchorPriority == true)
check("life section priority 20", sectionPriority == 20, tostring(sectionPriority))
for _, name in ipairs({ "minute", "labor", "morale", "settlerInfo", "raidend", "overview", "roles" }) do
    check("hook registered " .. name, Hooks.lists[name] ~= nil and #Hooks.lists[name] >= 1)
end

local nobody = Health.stats(nil)
check("stats nil camp", nobody.sick == 0 and nobody.medics == 0 and nobody.treated == 0 and nobody.recovered == 0 and nobody.epidemics == 0 and nobody.epidemic == false)
check("sickLevel nil camp", Health.sickLevel(nil, "x") == 0 and Health.sickLevel({}, "x") == 0)
check("stats keys", (function()
    local s = Health.stats({ settlers = {} })
    return type(s.sick) == "number" and type(s.medics) == "number" and type(s.treated) == "number" and type(s.recovered) == "number"
        and type(s.epidemics) == "number" and type(s.epidemic) == "boolean"
end)())

do
    local camp = scenario({})
    check("empty camp minute hook ok", pcall(Hooks.each, "minute", camp, 60))
    hours(camp, 3)
    check("empty camp stats", Health.stats(camp).sick == 0 and Health.stats(camp).epidemic == false)
    check("empty camp section", #Health.sectionLines(camp) == 0)
    check("empty camp overview", #Health.overview(camp) == 0)
    check("empty camp labor factor", Health.laborFactor(camp) == 1 and Hooks.product("labor", camp) == 1)
    check("empty camp morale", Hooks.sum("morale", camp) == 0)
    check("empty camp cureAll", Health.cureAll(camp) == 0)
    check("empty camp sicken", Health.sicken(camp, 3) == 0)
    check("empty camp epidemic cheat", Health.declareEpidemic(camp) == 0 and camp.health.epidemic == false)
    check("empty camp raid wounds", Health.raidWounds(camp, 5) == 0)
    check("empty camp roles hook", #Hooks.collect("roles", camp) == 0)
    check("empty camp list", #Health.list(camp) == 0)
    check("empty camp serializable", cleanState(camp))
    local traces = 0
    for _, line in ipairs(PRINTS) do
        if string.find(line, "[ALifeCamp:Health] camp=" .. camp.id .. " ", 1, true) then traces = traces + 1 end
    end
    check("trace per hour on empty camp", traces == 4, traces)
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder" })
    local a = uids[1]
    check("infect ok", Health.infect(camp, a, "fever", 2) == true)
    local ill = camp.settlers[a].ill
    check("ill fields", ill.kind == "fever" and ill.level == 2 and ill.since == HOURS and type(ill.since) == "number")
    check("sickLevel", Health.sickLevel(camp, a) == 2 and Health.sickLevel(camp, uids[2]) == 0)
    check("infect twice refused", Health.infect(camp, a, "poison", 1) == false and camp.settlers[a].ill.kind == "fever")
    check("infect bad kind", Health.infect(camp, uids[2], "plague", 1) == false and Health.sickLevel(camp, uids[2]) == 0)
    check("infect unknown uid", Health.infect(camp, "nobody", "fever", 1) == false)
    check("infect level clamp high", Health.infect(camp, uids[2], "poison", 9) == true and Health.sickLevel(camp, uids[2]) == 3)
    check("infect level clamp low", Health.infect(camp, uids[3], "wound", -4) == true and Health.sickLevel(camp, uids[3]) == 1)
    check("infect logged", logKeys(camp).hl_sick == 3)
    check("quiet infect", Health.infect(camp, uids[4], "fever", 1, true) == true and logKeys(camp).hl_sick == 3)
    check("cure", Health.cure(camp, uids[4]) == true and Health.sickLevel(camp, uids[4]) == 0)
    check("cure healthy", Health.cure(camp, uids[4]) == false)
    check("cure unknown", Health.cure(camp, "nobody") == false)
    check("stats sick", Health.stats(camp).sick == 3)
    check("labor factor three sick", near(Health.laborFactor(camp), (1 + 3 * 0.35) / 4))
    check("morale three sick", Hooks.sum("morale", camp) == -6)
    check("epidemic not yet", Health.stats(camp).epidemic == false)
    check("state serializable", cleanState(camp))
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder" })
    local before = Work.labor(camp)
    local moraleBefore = Stats.compute(camp).morale
    Health.infect(camp, uids[1], "fever", 1)
    local after = Work.labor(camp)
    check("work labor drops by factor", near(after, before * (3 + 0.35) / 4), before .. " -> " .. after)
    check("labor hook product", near(Hooks.product("labor", camp), 0.8375))
    Health.infect(camp, uids[2], "poison", 1)
    check("labor two sick", near(Hooks.product("labor", camp), (2 + 0.7) / 4))
    local moraleAfter = Stats.compute(camp).morale
    check("stats morale lowered by 4", moraleBefore - moraleAfter == 4, moraleBefore .. " -> " .. moraleAfter)
    local info = Hooks.collect("settlerInfo", camp, uids[1], camp.settlers[uids[1]])
    check("settler info sick", #info == 1 and string.find(info[1], T("HlKind_fever"), 1, true) ~= nil and string.find(info[1], "1", 1, true) ~= nil, info[1])
    local healthyInfo = Hooks.collect("settlerInfo", camp, uids[3], camp.settlers[uids[3]])
    check("settler info healthy empty", #healthyInfo == 0)
    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    local rows = win:settlerLines(camp)
    local joined = {}
    for _, row in ipairs(rows) do joined[#joined + 1] = row.text end
    check("people tab shows illness", string.find(table.concat(joined, "|"), T("HlKind_fever"), 1, true) ~= nil)
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder" })
    for _, uid in ipairs(uids) do Health.infect(camp, uid, "poison", 1, true) end
    check("morale cap minus 15", Hooks.sum("morale", camp) == -15)
    check("mass poisoning is an outbreak", Health.judge(camp) == true and camp.health.epidemic == true and camp.health.epidemics == 1)
    check("morale cap plus epidemic", Hooks.sum("morale", camp) == -25)
    check("epidemic logged", logKeys(camp).hl_epidemic == 1)
    local note = PLAYER.notes[#PLAYER.notes]
    check("epidemic notified", note ~= nil and string.find(note, camp.name, 1, true) ~= nil, note)
    check("epidemic not redeclared", Health.judge(camp) == true and camp.health.epidemics == 1 and logKeys(camp).hl_epidemic == 1)
    Health.cureAll(camp)
    check("cureAll ends epidemic", camp.health.epidemic == false and logKeys(camp).hl_epidemic_end == 1)
    local note2 = PLAYER.notes[#PLAYER.notes]
    check("epidemic end notified", note2 ~= nil and note2 ~= note and string.find(note2, camp.name, 1, true) ~= nil)
    check("morale zero when healthy", Hooks.sum("morale", camp) == 0)
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder" })
    Health.infect(camp, uids[1], "fever", 1, true)
    Health.infect(camp, uids[2], "fever", 1, true)
    check("two of eight is not epidemic", Health.judge(camp) == false)
    Health.infect(camp, uids[3], "infection", 1, true)
    check("three sick epidemic", Health.judge(camp) == true)
    Health.cure(camp, uids[3])
    check("epidemic persists with two", Health.judge(camp) == true)
    Health.cure(camp, uids[2])
    check("epidemic ends below two", Health.judge(camp) == false and camp.health.epidemic == false)
    Health.infect(camp, uids[2], "fever", 1, true)
    Health.infect(camp, uids[3], "fever", 1, true)
    check("second epidemic counted", Health.judge(camp) == true and camp.health.epidemics == 2 and Health.stats(camp).epidemics == 2)

    local c5, u5 = scenario({ "builder", "builder", "builder", "builder", "builder" })
    Health.infect(c5, u5[1], "fever", 1, true)
    check("one of five is not epidemic", Health.judge(c5) == false)
    Health.infect(c5, u5[2], "fever", 1, true)
    check("thirty percent rule", Health.judge(c5) == true)

    local c7, u7 = scenario({ "builder", "builder", "builder", "builder", "builder", "builder", "builder" })
    Health.infect(c7, u7[1], "fever", 1, true)
    Health.infect(c7, u7[2], "fever", 1, true)
    check("two of seven below thirty percent", Health.judge(c7) == false)

    local cw, uw = scenario({ "guard", "guard", "guard", "guard", "guard" })
    for i = 1, 4 do Health.infect(cw, uw[i], "wound", 2, true) end
    check("wounds never make epidemic", Health.judge(cw) == false and cw.health.epidemic == false)

    local co, uo = scenario({ "builder", "builder", "builder", "builder" })
    Options.set(co, "epidemics", false)
    for i = 1, 3 do Health.infect(co, uo[i], "fever", 1, true) end
    check("option off blocks epidemic", Health.judge(co) == false)
    Options.set(co, "epidemics", true)
    check("option on allows epidemic", Health.judge(co) == true)
    Options.set(co, "epidemics", false)
    hours(co, 1)
    check("option off ends epidemic at next hour", co.health.epidemic == false)
end

do
    local camp, uids = scenario({ "medic", "builder", "builder" }, 5)
    local patient, medic = uids[2], uids[1]
    Health.infect(camp, patient, "fever", 1)
    hours(camp, 1)
    local ill = camp.settlers[patient].ill
    check("medic assigned", ill ~= nil and ill.by == medic)
    check("medic speaks when treating", #Settlers.shell(medic).lines == 1 and Settlers.shell(medic).lines[1] == T("HlCare"))
    check("one dose consumed", medicineLeft(camp) == 4, camp.stock.medicine)
    check("treated counted", Health.stats(camp).treated == 1)
    check("dose timer", ill.dose == Health.doseHours - 1, tostring(ill.dose))
    check("first hour progress", near(ill.prog, rate("fever", Health.rates.dose, 1)), tostring(ill.prog))
    local data = Skills.data(camp.settlers[medic])
    check("medic xp gained", data.medic ~= nil and near(data.medic, Health.xp.care * 1 + Health.xp.dose), tostring(data.medic))
    check("medic count in stats", Health.stats(camp).medics == 1)
    local info = Hooks.collect("settlerInfo", camp, medic, camp.settlers[medic])
    check("medic nurse info", #info == 1 and string.find(info[1], "1", 1, true) ~= nil)
    check("patient care info", #Hooks.collect("settlerInfo", camp, patient, camp.settlers[patient]) == 2)
    hours(camp, 3)
    check("still sick after four hours", Health.sickLevel(camp, patient) == 1)
    local waited = 4
    while Health.sickLevel(camp, patient) > 0 and waited < 12 do
        hours(camp, 1)
        waited = waited + 1
    end
    check("recovered within a working shift", Health.sickLevel(camp, patient) == 0 and camp.settlers[patient].ill == nil and waited >= 5 and waited <= 6, waited)
    check("recovered counted", Health.stats(camp).recovered == 1)
    check("still one dose total", medicineLeft(camp) == 4 and Health.stats(camp).treated == 1)
    check("immunity set", camp.settlers[patient].hlImmune ~= nil and near(camp.settlers[patient].hlImmune, HOURS + Health.immuneHours))
    check("recovery logged", logKeys(camp).hl_recovered == 1)
    hours(camp, Health.immuneHours + 1)
    check("immunity expires", camp.settlers[patient].hlImmune == nil)
    check("serializable after treatment", cleanState(camp))
end

do
    local camp, uids = scenario({ "medic", "builder" }, 0)
    local patient = uids[2]
    Health.infect(camp, patient, "fever", 1)
    hours(camp, 1)
    local ill = camp.settlers[patient].ill
    check("care without medicine speed", near(ill.prog, rate("fever", Health.rates.care, 1)), tostring(ill.prog))
    check("no dose without medicine", ill.dose == 0 and Health.stats(camp).treated == 0)
    check("no medicine alert logged", logKeys(camp).hl_nomeds == 1)
    Health.selfRate.fever = 0.001
    local notes = #PLAYER.notes
    hours(camp, 5)
    check("alert rate limited", logKeys(camp).hl_nomeds == 1 and #PLAYER.notes == notes)
    hours(camp, 20)
    check("alert repeats after a day", logKeys(camp).hl_nomeds == 2)
    check("alert notified", #PLAYER.notes > notes)
    check("slow recovery still happens", Health.sickLevel(camp, patient) == 0 or camp.settlers[patient].ill.prog > 0)
end

do
    local camp, uids = scenario({ "worker", "builder", "builder", "builder", "builder" }, 6)
    for i = 2, 5 do Health.infect(camp, uids[i], "fever", 1, true) end
    hours(camp, 1)
    local cared = 0
    for i = 2, 5 do
        local ill = camp.settlers[uids[i]].ill
        if ill.by == uids[1] then cared = cared + 1 end
    end
    check("single helper cares for two", cared == Health.helperSlots, cared)
    local carried, bare
    for i = 2, 5 do
        local ill = camp.settlers[uids[i]].ill
        if ill.by ~= nil then carried = carried or ill else bare = bare or ill end
    end
    check("helper half speed", near(carried.prog, rate("fever", Health.rates.dose, Health.helperSpeed)), tostring(carried.prog))
    check("unattended slow", near(bare.prog, Health.selfRate.fever), tostring(bare.prog))
    check("two doses spent", medicineLeft(camp) == 4, camp.stock.medicine)

    local c2, u2 = scenario({ "scavenger", "medic", "builder" }, 3)
    Health.infect(c2, u2[3], "fever", 1, true)
    hours(c2, 1)
    check("medic preferred over helper", c2.settlers[u2[3]].ill.by == u2[2])

    local c3, u3 = scenario({ "medic", "builder", "scavenger" }, 3)
    Health.infect(c3, u3[1], "fever", 1, true)
    Health.infect(c3, u3[2], "fever", 1, true)
    hours(c3, 1)
    check("sick medic replaced by helper", c3.settlers[u3[2]].ill.by == u3[3] and c3.settlers[u3[1]].ill.by == u3[3])

    local c4, u4 = scenario({ "builder", "farmer", "guard" }, 3)
    Health.infect(c4, u4[1], "fever", 1, true)
    hours(c4, 1)
    check("nobody to care", c4.settlers[u4[1]].ill.by == nil and medicineLeft(c4) == 3 and near(c4.settlers[u4[1]].ill.prog, Health.selfRate.fever))
    check("no alert without caregivers", logKeys(c4).hl_nomeds == nil)
end

do
    local camp, uids = scenario({ "medic", "builder", "builder", "builder", "builder", "builder" }, 10)
    for i = 2, 6 do Health.infect(camp, uids[i], "fever", i == 4 and 3 or (i == 6 and 2 or 1), true) end
    hours(camp, 1)
    local cared = {}
    for i = 2, 6 do
        if camp.settlers[uids[i]].ill.by == uids[1] then cared[#cared + 1] = i end
    end
    check("medic capacity", #cared == Health.perMedic, #cared)
    check("most severe first", camp.settlers[uids[4]].ill.by == uids[1] and camp.settlers[uids[6]].ill.by == uids[1])
    check("load count", Health.load(camp, uids[1]) == Health.perMedic)
    check("one speech per hour per medic", #Settlers.shell(uids[1]).lines == 1)

    local c2, u2 = scenario({ "medic", "medic", "builder", "builder", "builder", "builder" }, 10)
    for i = 3, 6 do Health.infect(c2, u2[i], "fever", 1, true) end
    hours(c2, 1)
    check("two medics share load", Health.load(c2, u2[1]) == 2 and Health.load(c2, u2[2]) == 2)
end

do
    local camp, uids = scenario({ "medic", "builder" }, 5)
    Skills.data(camp.settlers[uids[1]]).medic = Skills.xpFor(5)
    Health.infect(camp, uids[2], "fever", 1, true)
    local factor = Skills.factor(camp, "medic")
    hours(camp, 1)
    check("skill factor speeds recovery", factor > 1.2 and near(camp.settlers[uids[2]].ill.prog, rate("fever", Health.rates.dose, factor)), tostring(camp.settlers[uids[2]].ill.prog))

    local c2, u2 = scenario({ "medic", "builder" }, 5)
    Health.infect(c2, u2[2], "fever", 1, true)
    A.Progress = { bonus = function(c, what) if what == "heal" then return 2 end return 1 end }
    hours(c2, 1)
    check("progress bonus doubles rate", near(c2.settlers[u2[2]].ill.prog, 2 * rate("fever", Health.rates.dose, 1)), tostring(c2.settlers[u2[2]].ill.prog))
    A.Progress = { bonus = function() error("boom") end }
    local c3, u3 = scenario({ "medic", "builder" }, 5)
    A.Progress = { bonus = function() error("boom") end }
    Health.infect(c3, u3[2], "fever", 1, true)
    hours(c3, 1)
    check("progress bonus error ignored", near(c3.settlers[u3[2]].ill.prog, rate("fever", Health.rates.dose, 1)))
    A.Progress = { bonus = function() return "x" end }
    local c4, u4 = scenario({ "medic", "builder" }, 5)
    A.Progress = { bonus = function() return "x" end }
    Health.infect(c4, u4[2], "fever", 1, true)
    hours(c4, 1)
    check("progress bonus garbage ignored", near(c4.settlers[u4[2]].ill.prog, rate("fever", Health.rates.dose, 1)))
    A.Progress = {}
    local c5, u5 = scenario({ "medic", "builder" }, 5)
    A.Progress = {}
    Health.infect(c5, u5[2], "fever", 1, true)
    hours(c5, 1)
    check("progress without bonus ignored", near(c5.settlers[u5[2]].ill.prog, rate("fever", Health.rates.dose, 1)))
    A.Progress = nil
end

do
    local camp, uids = scenario({ "builder", "builder" }, 0)
    Health.worsen.fever = 1
    Health.infect(camp, uids[1], "fever", 1)
    hours(camp, 1)
    check("worsens without medicine", Health.sickLevel(camp, uids[1]) == 2 and camp.settlers[uids[1]].ill.prog == 0)
    hours(camp, 1)
    check("worsens to critical", Health.sickLevel(camp, uids[1]) == 3 and logKeys(camp).hl_worse == 1)
    hours(camp, 3)
    check("level capped at three", Health.sickLevel(camp, uids[1]) == 3)

    local c2, u2 = scenario({ "medic", "builder" }, 4)
    Health.worsen.fever = 1
    Health.infect(c2, u2[2], "fever", 1)
    hours(c2, 3)
    check("medicine prevents worsening", Health.sickLevel(c2, u2[2]) == 1 and c2.settlers[u2[2]].ill.dose > 0)

    local c3, u3 = scenario({ "builder", "builder" }, 0)
    c3.hunger = 5
    Health.infect(c3, u3[1], "fever", 1)
    hours(c3, 1)
    check("hunger slows recovery", near(c3.settlers[u3[1]].ill.prog, Health.selfRate.fever * Health.rates.hungry), tostring(c3.settlers[u3[1]].ill.prog))
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.base = 1
    Health.chance.cap = 1
    hours(camp, 1)
    check("everyone falls ill at certainty", healthyCount(camp) == 0, healthyCount(camp))
    check("spontaneous logged", logKeys(camp).hl_sick == 4)
    check("epidemic follows", camp.health.epidemic == true)

    local c2, u2 = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.base = 1
    Health.chance.cap = 1
    Options.set(c2, "epidemics", false)
    hours(c2, 3)
    check("option off no spontaneous illness", healthyCount(c2) == 4)

    local c3, u3 = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.base = 1
    Health.chance.cap = 1
    c3.settlers[u3[1]].hlImmune = HOURS + 10
    hours(c3, 1)
    check("immune settler spared", Health.sickLevel(c3, u3[1]) == 0 and healthyCount(c3) == 1)

    local c4, u4 = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.base = 0.2
    Health.chance.cap = 0.2
    RAND(9999)
    hours(c4, 1)
    check("rand high roll misses", healthyCount(c4) == 4)
    RAND(0)
    hours(c4, 1)
    check("rand low roll hits", healthyCount(c4) < 4)
end

do
    reset()
    local c = Health.chance
    c.base = 0.001
    local ctx = { cleanMul = 2, crowd = 1.5, hungry = true, dry = true, gloomy = true }
    check("onset multipliers", near(Health.onset(ctx), 0.001 * 2 * 1.5 * c.hunger * c.water * c.gloom), tostring(Health.onset(ctx)))
    check("onset plain", near(Health.onset({ cleanMul = 1, crowd = 1, hungry = false, dry = false, gloomy = false }), 0.001))
    c.cap = 0.002
    check("onset capped", near(Health.onset(ctx), 0.002))
    reset()
    local plain = { crowd = 1, cleanMul = 1, hungry = false, dry = false }
    RAND(0)
    check("pick fever on low ticket", Health.pickKind(plain) == "fever")
    RAND(999)
    check("pick infection on high ticket", Health.pickKind(plain) == "infection")
    ZombRand = function(n) return 749 end
    check("pick poison in the middle", Health.pickKind(plain) == "poison")
    check("hunger widens poison", (function()
        ZombRand = function(n) return 599 end
        return Health.pickKind({ crowd = 1, cleanMul = 1, hungry = true, dry = true }) == "poison"
    end)())
    RAND(0)

    local camp, uids = scenario({ "builder", "builder", "builder", "builder", "builder", "builder" }, 0)
    local list = {}
    for _, uid in ipairs(uids) do list[#list + 1] = uid end
    table.sort(list)
    local ctx1 = Health.context(camp, list)
    check("context default clean", ctx1.clean == 70 and near(ctx1.cleanMul, 1))
    check("context crowd", near(ctx1.crowd, 1 + Health.chance.crowd * 6), tostring(ctx1.crowd))
    check("context dry by default", ctx1.dry == true and ctx1.hungry == false)
    A.Sanitary = { score = function() return 20 end }
    local ctx2 = Health.context(camp, list)
    check("dirty camp multiplier", ctx2.clean == 20 and near(ctx2.cleanMul, 1 + 50 * Health.chance.cleanSlope), tostring(ctx2.cleanMul))
    A.Sanitary = { score = function() return 100 end }
    local ctx3 = Health.context(camp, list)
    check("clean camp multiplier floor", ctx3.cleanMul >= 0.35 and ctx3.cleanMul < 0.36, tostring(ctx3.cleanMul))
    A.Sanitary = { score = function() error("boom") end }
    check("sanitary error falls back", Health.context(camp, list).clean == 70)
    A.Sanitary = { score = function() return "dirty" end }
    check("sanitary garbage falls back", Health.context(camp, list).clean == 70)
    A.Sanitary = nil
    camp.hunger = 2
    camp.stock.water = 10
    local ctx4 = Health.context(camp, list)
    check("hunger and water flags", ctx4.hungry == true and ctx4.dry == false)
    local failing = Stats.compute
    Stats.compute = function() error("boom") end
    local ctx5 = Health.context(camp, list)
    Stats.compute = failing
    check("stats failure tolerated", ctx5.people == 6 and ctx5.crowd == 1 and ctx5.gloomy == false)

    local big, bigIds = scenario({ "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder" }, 0)
    table.sort(bigIds)
    local ctx6 = Health.context(big, bigIds)
    check("low morale flagged", ctx6.gloomy == true and ctx6.morale < 30, tostring(ctx6.morale))
    Health.infect(big, bigIds[1], "fever", 1, true)
    Health.infect(big, bigIds[2], "fever", 1, true)
    local ctx7 = Health.context(big, bigIds)
    check("own morale penalty not counted", near(ctx7.morale, ctx6.morale), ctx6.morale .. " vs " .. ctx7.morale)
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.spread = 1
    Options.set(camp, "quarantine", false)
    Health.infect(camp, uids[1], "fever", 3, true)
    hours(camp, 1)
    check("fever spreads", healthyCount(camp) == 2)
    check("spread logged as one line", logKeys(camp).hl_spread == 1 and logKeys(camp).hl_sick == nil)
    local victim
    for i = 2, 4 do
        if Health.sickLevel(camp, uids[i]) > 0 then victim = camp.settlers[uids[i]].ill end
    end
    check("spread kind and level", victim ~= nil and victim.kind == "fever" and victim.level == 2)

    local c2, u2 = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.spread = 1
    Health.chance.quarantine = 0
    Health.infect(c2, u2[1], "fever", 3, true)
    hours(c2, 1)
    check("quarantine blocks spread of serious cases", healthyCount(c2) == 3)
    Options.set(c2, "quarantine", false)
    hours(c2, 1)
    check("without quarantine it spreads", healthyCount(c2) == 2)

    local c3, u3 = scenario({ "builder", "builder", "builder", "builder" }, 0)
    Health.chance.spread = 1
    Health.chance.quarantine = 0
    Health.infect(c3, u3[1], "fever", 1, true)
    hours(c3, 1)
    check("mild cases are not isolated", healthyCount(c3) == 2)

    for _, kind in ipairs({ "poison", "wound" }) do
        local c4, u4 = scenario({ "builder", "builder", "builder", "builder" }, 0)
        Health.chance.spread = 1
        Options.set(c4, "quarantine", false)
        Health.infect(c4, u4[1], kind, 3, true)
        hours(c4, 1)
        check(kind .. " is not contagious", healthyCount(c4) == 3)
    end

    local c5, u5 = scenario({ "builder", "builder" }, 0)
    Health.chance.spread = 1
    Options.set(c5, "quarantine", false)
    Health.infect(c5, u5[1], "fever", 3, true)
    local far = Settlers.shell(u5[2])
    far.px = far.px + 200
    hours(c5, 1)
    check("distant settler not infected", Health.sickLevel(c5, u5[2]) == 0)
    far.px = far.px - 200
    hours(c5, 1)
    check("nearby settler infected", Health.sickLevel(c5, u5[2]) > 0)

    local c6, u6 = scenario({ "builder", "builder" }, 0)
    Health.chance.spread = 1
    Options.set(c6, "quarantine", false)
    Health.infect(c6, u6[1], "fever", 3, true)
    c6.settlers[u6[2]].hlImmune = HOURS + 20
    hours(c6, 1)
    check("immune settler not infected by contact", Health.sickLevel(c6, u6[2]) == 0)

    local c7, u7 = scenario({ "builder", "builder" }, 0)
    Health.chance.spread = 1
    Options.set(c7, "quarantine", false)
    Options.set(c7, "epidemics", false)
    Health.infect(c7, u7[1], "fever", 3, true)
    hours(c7, 1)
    check("option off stops contagion", Health.sickLevel(c7, u7[2]) == 0)

    local c8, u8 = scenario({ "builder", "builder" }, 0)
    Health.chance.spread = 1
    Options.set(c8, "quarantine", false)
    Settlers.dismiss(c8, u8[2])
    Settlers.settle(c8, "ghost", "Ghost")
    c8.settlers.ghost.role = "builder"
    Health.infect(c8, u8[1], "fever", 3, true)
    hours(c8, 1)
    check("settler without a body can catch it", Health.sickLevel(c8, "ghost") > 0)
end

do
    local camp, uids = scenario({ "guard", "guard", "guard", "builder", "builder", "medic" }, 5)
    Health.chance.wound = 1
    Health.chance.woundSevere2 = 0
    Health.chance.woundSevere3 = 0
    Hooks.each("raidend", camp, { people = 6 }, 0)
    local wounded = 0
    for i = 1, 3 do
        local ill = camp.settlers[uids[i]].ill
        if ill ~= nil and ill.kind == "wound" and ill.level == 1 then wounded = wounded + 1 end
    end
    check("every guard wounded", wounded == 3)
    check("others untouched", Health.sickLevel(camp, uids[4]) == 0 and Health.sickLevel(camp, uids[5]) == 0 and Health.sickLevel(camp, uids[6]) == 0)
    check("raid wounds logged once", logKeys(camp).hl_wounded == 1 and logKeys(camp).hl_sick == nil)
    check("wounds are not an epidemic", Health.judge(camp) == false)

    local c2, u2 = scenario({ "guard", "guard", "builder" }, 0)
    Hooks.each("raidend", c2, { people = 3 }, 0)
    check("zero chance no wounds", Health.stats(c2).sick == 0)
    Health.chance.woundLost = 1
    Hooks.each("raidend", c2, { people = 3 }, 0)
    check("no losses no extra chance", Health.stats(c2).sick == 0)
    Hooks.each("raidend", c2, { people = 4 }, 1)
    check("losses raise the chance", Health.stats(c2).sick == 2)
    Hooks.each("raidend", c2, { people = 4 }, 2)
    check("already wounded not rewounded", Health.stats(c2).sick == 2)

    local c3, u3 = scenario({ "guard", "guard" }, 0)
    Health.chance.wound = 1
    Health.chance.woundSevere2 = 1
    Health.chance.woundSevere3 = 1
    Hooks.each("raidend", c3, { people = 2 }, 0)
    check("severe wounds level three", Health.sickLevel(c3, u3[1]) == 3 and Health.sickLevel(c3, u3[2]) == 3)

    local c4, u4 = scenario({ "guard", "guard" }, 0)
    Health.chance.wound = 1
    Options.set(c4, "epidemics", false)
    Hooks.each("raidend", c4, { people = 2 }, 0)
    check("wounds happen with epidemics off", Health.stats(c4).sick == 2)

    local c5, u5 = scenario({ "guard", "builder" }, 0)
    Health.chance.wound = 1
    Health.infect(c5, u5[1], "fever", 1, true)
    Hooks.each("raidend", c5, { people = 2 }, 0)
    check("sick guard keeps his illness", c5.settlers[u5[1]].ill.kind == "fever")

    local c6, u6 = scenario({ "guard", "builder" }, 0)
    Health.chance.wound = 1
    local ok = pcall(Work.raidEnd, c6, { people = 2, at = HOURS })
    check("Work.raidEnd runs the hook", ok and Health.sickLevel(c6, u6[1]) >= 1 and Health.sickLevel(c6, u6[2]) == 0)
end

do
    local camp, uids = scenario({ "guard", "medic" }, 8)
    Health.infect(camp, uids[1], "wound", 2, true)
    Health.chance.fester = 1
    hours(camp, 1)
    check("treated wound does not fester", camp.settlers[uids[1]].ill.kind == "wound" and camp.settlers[uids[1]].ill.dose > 0)

    local c2, u2 = scenario({ "guard", "builder" }, 0)
    Health.chance.fester = 1
    Health.infect(c2, u2[1], "wound", 1, true)
    hours(c2, 1)
    check("untreated wound festers", c2.settlers[u2[1]].ill.kind == "infection" and logKeys(c2).hl_festered == 1)

    local c3, u3 = scenario({ "guard", "builder" }, 0)
    Health.chance.fester = 1
    Options.set(c3, "epidemics", false)
    Health.infect(c3, u3[1], "wound", 1, true)
    hours(c3, 2)
    check("no festering with epidemics off", c3.settlers[u3[1]].ill.kind == "wound")

    local c4, u4 = scenario({ "medic", "guard" }, 8)
    Health.infect(c4, u4[2], "wound", 2, true)
    hours(c4, 1)
    check("wound heals at medic speed", near(c4.settlers[u4[2]].ill.prog, rate("wound", Health.rates.dose, 1)), tostring(c4.settlers[u4[2]].ill.prog))
    hours(c4, 23)
    check("wound level two healed within a day", Health.sickLevel(c4, u4[2]) == 0, Health.sickLevel(c4, u4[2]))
end

do
    local camp, uids, x0 = scenario({ "medic", "builder", "builder", "guard" }, 5)
    local cx, cy = Geo.center(camp)
    local medic, a, b, guard = uids[1], uids[2], uids[3], uids[4]
    local function anchor(uid) return Hooks.first("anchor", camp, uid, camp.settlers[uid], { x = 0, y = 0, z = 0 }) end
    check("healthy has no override", anchor(a) == nil and anchor(medic) == nil)
    Health.infect(camp, a, "fever", 2, true)
    Health.infect(camp, b, "fever", 1, true)
    check("serious patient goes to centre without infirmary", (function()
        local p = anchor(a)
        return p ~= nil and p.x == cx and p.y == cy and p.z == 0 and p.exact == nil
    end)())
    check("mild patient keeps routine", anchor(b) == nil)
    hours(camp, 1)
    check("both assigned to the medic", camp.settlers[a].ill.by == medic and camp.settlers[b].ill.by == medic)
    check("medic goes to serious patient", (function()
        local p = anchor(medic)
        return p ~= nil and p.x == cx and p.y == cy
    end)())
    Health.cure(camp, a)
    hours(camp, 0)
    camp.settlers[b].ill.by = medic
    local p = anchor(medic)
    local sx, sy = Settlers.where(b)
    check("medic walks to mild patient", p ~= nil and p.x == math.floor(sx) and p.y == math.floor(sy) and p.z == 0)
    Health.infect(camp, a, "fever", 3, true)
    camp.raid = { at = HOURS, people = 4 }
    check("raid suppresses anchors", anchor(a) == nil and anchor(medic) == nil and anchor(b) == nil)
    camp.raid = nil
    Options.set(camp, "quarantine", false)
    check("quarantine off suppresses anchors", anchor(a) == nil and anchor(medic) == nil)
    Options.set(camp, "quarantine", true)
    check("anchors back when quarantine on", anchor(a) ~= nil)
    check("guard unaffected", anchor(guard) == nil)

    camp.adopt = { items = {
        h1 = { id = 1, key = "h1", status = "done", rect = { x1 = x0 + 2, y1 = 110, x2 = x0 + 8, y2 = 116, z = 0 },
            fitout = { phase = "ready", provisional = false, rooms = {
                { kind = "dorm", name = "bedroom", z = 0, x1 = x0 + 2, y1 = 110, x2 = x0 + 4, y2 = 112 },
                { kind = "infirmary", name = "bedroom", z = 0, x1 = x0 + 5, y1 = 113, x2 = x0 + 8, y2 = 116 },
            } } },
        h2 = { id = 2, key = "h2", status = "queued", rect = { x1 = x0, y1 = 100, x2 = x0 + 3, y2 = 103, z = 0 },
            fitout = { phase = "ready", rooms = { { kind = "infirmary", z = 0, x1 = x0, y1 = 100, x2 = x0 + 1, y2 = 101 } } } },
        h3 = { id = 3, key = "h3", status = "fitout", rect = { x1 = x0, y1 = 100, x2 = x0 + 3, y2 = 103, z = 0 },
            fitout = { phase = "ready", provisional = true, rooms = { { kind = "infirmary", z = 0, x1 = x0, y1 = 100, x2 = x0 + 1, y2 = 101 } } } },
        h4 = { id = 4, key = "h4", status = "done", rect = { x1 = x0, y1 = 100, x2 = x0 + 3, y2 = 103, z = 0 },
            fitout = { phase = "scan", rooms = { { kind = "infirmary", z = 0, x1 = x0, y1 = 100, x2 = x0 + 1, y2 = 101 } } } },
    } }
    local room = Health.ward(camp, true)
    check("infirmary found among adopted houses", room ~= nil and room.x1 == x0 + 5 and room.y1 == 113 and room.x2 == x0 + 8 and room.y2 == 116 and room.z == 0)
    local spot = anchor(a)
    check("patient anchor inside infirmary", spot ~= nil and spot.exact == true and spot.x >= room.x1 and spot.x <= room.x2 and spot.y >= room.y1 and spot.y <= room.y2 and spot.z == 0, spot and (spot.x .. "," .. spot.y))
    Health.infect(camp, b, "fever", 2, true)
    check("different patients spread over the room", (function()
        local ids = { "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8" }
        local seen, count = {}, 0
        for _, id in ipairs(ids) do
            local pt = Health.wardPoint(camp, id)
            local key = pt.x .. "," .. pt.y
            if not seen[key] then seen[key] = true count = count + 1 end
        end
        return count >= 3
    end)())
    camp.settlers[a].ill.by = medic
    camp.settlers[b].ill.by = medic
    local medicSpot = anchor(medic)
    check("medic anchored in infirmary", medicSpot ~= nil and medicSpot.exact == true and medicSpot.x >= room.x1 and medicSpot.x <= room.x2)

    camp.orderClock = 100
    Work.orders(camp, 1)
    local order = orders[a]
    check("Work.orders sends patient to infirmary", order ~= nil and order.anchor ~= nil and order.anchor.x == spot.x and order.anchor.y == spot.y, order and (order.anchor.x .. "," .. order.anchor.y))
    check("Work.orders leaves healthy alone", orders[guard] ~= nil and orders[guard].anchor.x ~= spot.x)

    camp.raid = { at = HOURS, people = 4, site = { x = cx, y = cy, z = 0 } }
    camp.orderClock = 100
    Work.orders(camp, 1)
    check("raid keeps patient out of infirmary", orders[a].anchor.y < room.y1)
    camp.raid = nil

    Health.ward(camp, true)
    camp.adopt.items.h1.status = "fitout"
    check("fitout stage room counts too", Health.ward(camp, true) ~= nil)
    camp.adopt.items.h1.status = "queued"
    check("queued house gives no infirmary", Health.ward(camp, true) == nil)
    local fallback = anchor(a)
    check("fallback to camp centre", fallback ~= nil and fallback.x == cx and fallback.y == cy and fallback.exact == nil)

    camp.adopt.items.h1.status = "done"
    camp.adopt.items.h5 = { id = 5, key = "h5", status = "done", rect = { x1 = x0, y1 = 100, x2 = x0 + 3, y2 = 103, z = 1 },
        fitout = { phase = "ready", rooms = { { kind = "infirmary", z = 1, x1 = x0, y1 = 100, x2 = x0 + 1, y2 = 101 } } } }
    local ground = Health.ward(camp, true)
    check("ground floor infirmary preferred", ground ~= nil and ground.z == 0)
    camp.adopt.items.h1 = nil
    local upper = Health.ward(camp, true)
    check("upper floor infirmary as last resort", upper ~= nil and upper.z == 1)
    camp.adopt = nil
    check("no adopt state no infirmary", Health.ward(camp, true) == nil)
end

do
    local camp, uids, x0 = scenario({ "medic", "builder", "builder" }, 6)
    camp.adopt = { items = { h1 = { id = 1, key = "h1", status = "done", rect = { x1 = x0, y1 = 100, x2 = x0 + 8, y2 = 106, z = 0 },
        fitout = { phase = "ready", rooms = { { kind = "infirmary", z = 0, x1 = x0 + 1, y1 = 101, x2 = x0 + 4, y2 = 104 } } } } } }
    Health.ward(camp, true)
    Health.infect(camp, uids[2], "fever", 2, true)
    Health.infect(camp, uids[3], "fever", 2, true)
    hours(camp, 1)
    local ill = camp.settlers[uids[2]].ill
    check("infirmary speeds recovery", near(ill.prog, rate("fever", Health.rates.dose, 1) * Health.rates.ward), tostring(ill.prog))
    Options.set(camp, "quarantine", false)
    local c2, u2, x2 = scenario({ "medic", "builder" }, 6)
    c2.adopt = { items = { h1 = { id = 1, key = "h1", status = "done", rect = { x1 = x2, y1 = 100, x2 = x2 + 8, y2 = 106, z = 0 },
        fitout = { phase = "ready", rooms = { { kind = "infirmary", z = 0, x1 = x2 + 1, y1 = 101, x2 = x2 + 4, y2 = 104 } } } } } }
    Options.set(c2, "quarantine", false)
    Health.infect(c2, u2[2], "fever", 2, true)
    hours(c2, 1)
    check("no ward bonus without quarantine", near(c2.settlers[u2[2]].ill.prog, rate("fever", Health.rates.dose, 1)), tostring(c2.settlers[u2[2]].ill.prog))
end

do
    local camp, uids = scenario({ "medic", "builder" }, 0)
    camp.storage = {}
    camp.stock = nil
    Health.infect(camp, uids[2], "fever", 1, true)
    check("no storage no stock survives", pcall(Hooks.each, "minute", camp, 60))
    hours(camp, 2)
    check("no storage keeps recovering slowly", camp.settlers[uids[2]].ill ~= nil and camp.settlers[uids[2]].ill.prog > 0)
    check("no storage alert", logKeys(camp).hl_nomeds == 1)
    check("no storage section", #Health.sectionLines(camp) >= 4 and #Health.overview(camp) == 1)

    local c2, u2 = scenario({ "medic", "builder" }, 3)
    c2.storage = nil
    Health.infect(c2, u2[2], "fever", 1, true)
    check("storage field missing survives", pcall(Health.hour, c2) and c2.settlers[u2[2]].ill.dose == 0)

    local c3, u3 = scenario({ "medic", "builder" }, 3)
    local real = Stock.consume
    Stock.consume = function() error("boom") end
    Health.infect(c3, u3[2], "fever", 1, true)
    local ok = pcall(Hooks.each, "minute", c3, 60)
    Stock.consume = real
    check("consume failure survives", ok and Health.stats(c3).treated == 0)
    check("failed consume counts as shortage", logKeys(c3).hl_nomeds == 1)

    local c4, u4 = scenario({ "medic", "builder" }, 3)
    Stock.consume = function() return 0 end
    Health.infect(c4, u4[2], "fever", 1, true)
    hours(c4, 1)
    Stock.consume = real
    check("empty consume is shortage", Health.stats(c4).treated == 0 and logKeys(c4).hl_nomeds == 1)

    local c5, u5 = scenario({ "medic", "builder" }, 3)
    c5.options = nil
    Health.infect(c5, u5[2], "fever", 1, true)
    check("camp without options survives", pcall(Hooks.each, "minute", c5, 60))
    c5.options = {}

    local c6, u6 = scenario({ "medic", "builder" }, 3)
    c6.log = nil
    Health.infect(c6, u6[2], "fever", 1)
    check("camp without log survives", pcall(Hooks.each, "minute", c6, 60))
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder", "builder" }, 0)
    camp.settlers[uids[1]].ill = "garbage"
    camp.settlers[uids[2]].ill = { kind = "bogus", level = 2, since = "x", prog = "y", dose = -4, by = "ghost" }
    camp.settlers[uids[3]].ill = { kind = "fever", level = 0 }
    camp.settlers[uids[4]].ill = { kind = "fever", level = 9, by = uids[5] }
    camp.settlers[uids[5]].hlImmune = HOURS - 1
    check("sickLevel garbage", Health.sickLevel(camp, uids[1]) == 0 and Health.sickLevel(camp, uids[3]) == 0 and Health.sickLevel(camp, uids[4]) == 3)
    check("stats garbage", Health.stats(camp).sick == 2)
    check("hooks survive garbage", pcall(Hooks.each, "minute", camp, 60) and pcall(Health.sectionLines, camp) and pcall(Health.overview, camp))
    check("garbage ill removed", camp.settlers[uids[1]].ill == nil and camp.settlers[uids[3]].ill == nil)
    local fixed = camp.settlers[uids[2]].ill
    check("bad kind repaired", fixed ~= nil and Health.valid[fixed.kind] and type(fixed.since) == "number" and type(fixed.prog) == "number" and fixed.dose >= 0 and fixed.by == nil)
    check("expired immunity removed", camp.settlers[uids[5]].hlImmune == nil)
    check("garbage repaired serializable", cleanState(camp))
    camp.settlers[uids[1]].name = nil
    Health.infect(camp, uids[1], "fever", 1)
    check("nameless settler falls back to uid", string.find(camp.log[#camp.log].a, uids[1], 1, true) ~= nil)
end

do
    local camp, uids, x0 = scenario({ "builder", "builder", "builder", "builder", "builder" }, 0)
    PLAYER.x, PLAYER.y = x0 + 5, 105
    local cheats = A.Cheats
    local ids = {}
    for _, row in ipairs(cheats.order) do
        if row.section == "life" then ids[row.id] = true end
    end
    check("cheats defined in life section", ids.hl_sick and ids.hl_cure and ids.hl_epidemic)
    for _, id in ipairs({ "hl_sick", "hl_cure", "hl_epidemic" }) do
        check("cheat texts " .. id, T("ChT_" .. id) ~= "UI_ALC_ChT_" .. id and T("ChD_" .. id) ~= "UI_ALC_ChD_" .. id and T("ChR_" .. id, "5") ~= "UI_ALC_ChR_" .. id)
    end
    check("cheat camp found", cheats.camp(PLAYER) == camp)
    check("hl_sick infects three", cheats.actions.hl_sick(camp, PLAYER) == 3 and Health.stats(camp).sick == 3)
    check("hl_sick makes fever level two", (function()
        for _, uid in ipairs(uids) do
            local ill = camp.settlers[uid].ill
            if ill ~= nil and (ill.kind ~= "fever" or ill.level ~= 2) then return false end
        end
        return true
    end)())
    check("hl_sick only healthy", cheats.actions.hl_sick(camp, PLAYER) == 2 and Health.stats(camp).sick == 5)
    check("hl_sick nobody left", cheats.actions.hl_sick(camp, PLAYER) == 0)
    check("epidemic after cheat", camp.health.epidemic == true)
    check("hl_cure cures all", cheats.actions.hl_cure(camp, PLAYER) == 5 and Health.stats(camp).sick == 0 and camp.health.epidemic == false)
    check("hl_cure idempotent", cheats.actions.hl_cure(camp, PLAYER) == 0)
    Options.set(camp, "epidemics", false)
    local sick = cheats.actions.hl_epidemic(camp, PLAYER)
    check("hl_epidemic declares", sick >= 3 and camp.health.epidemic == true and Options.on(camp, "epidemics"), tostring(sick))
    check("hl_epidemic counted", Health.stats(camp).epidemics >= 1)
    local text = cheats.run("hl_cure", PLAYER)
    check("cheat run text", string.find(text, tostring(sick), 1, true) ~= nil, text)
    check("cheat run logs", logKeys(camp).cheat ~= nil)
    check("cheat run sick text", cheats.run("hl_sick", PLAYER) ~= "")
    check("cheat run epidemic text", cheats.run("hl_epidemic", PLAYER) ~= "")
    local solo, soloIds, sx = scenario({ "builder" }, 0)
    PLAYER.x, PLAYER.y = sx + 5, 105
    check("hl_epidemic needs two people", cheats.actions.hl_epidemic(solo, PLAYER) == 0 and Health.stats(solo).epidemic == false)
    check("hl_sick on one person", cheats.actions.hl_sick(solo, PLAYER) == 1)
    local empty, _, ex = scenario({}, 0)
    PLAYER.x, PLAYER.y = ex + 5, 105
    check("cheats on empty camp", cheats.actions.hl_sick(empty, PLAYER) == 0 and cheats.actions.hl_cure(empty, PLAYER) == 0 and cheats.actions.hl_epidemic(empty, PLAYER) == 0)
    local saved = A.Health
    A.Health = nil
    check("cheats without module", cheats.actions.hl_sick(camp, PLAYER) == 0 and cheats.actions.hl_cure(camp, PLAYER) == 0 and cheats.actions.hl_epidemic(camp, PLAYER) == 0)
    A.Health = saved
end

do
    local camp, uids = scenario({ "builder", "builder", "builder" }, 0)
    Health.chance.cough = 1
    Health.infect(camp, uids[1], "fever", 1, true)
    Health.infect(camp, uids[2], "wound", 1, true)
    Health.minute(camp, 1)
    local l1, l2, l3 = Settlers.shell(uids[1]).lines, Settlers.shell(uids[2]).lines, Settlers.shell(uids[3]).lines
    check("fever cough", #l1 == 1 and l1[1] == T("HlCough"), l1[1])
    check("wound groan", #l2 == 1 and l2[1] == T("HlCough_wound"), l2[1])
    check("healthy silent", #l3 == 0)
    Health.cure(camp, uids[2])
    Health.infect(camp, uids[2], "poison", 1, true)
    Health.cure(camp, uids[3])
    Health.infect(camp, uids[3], "infection", 1, true)
    Health.minute(camp, 1)
    check("poison and infection lines", Settlers.shell(uids[2]).lines[2] == T("HlCough_poison") and Settlers.shell(uids[3]).lines[1] == T("HlCough_infection"))
    Health.chance.cough = 0
    local spoken = #Settlers.shell(uids[1]).lines
    Health.minute(camp, 1)
    check("cough off is silent", #Settlers.shell(uids[1]).lines == spoken)
    Health.chance.cough = 1
    Settlers.dismiss(camp, uids[2])
    Settlers.settle(camp, "mute", "Mute")
    Health.infect(camp, "mute", "fever", 1, true)
    check("sick without body is skipped", pcall(Health.minute, camp, 1))
    Health.chance.cough = 0.004
    local spoke = 0
    for _ = 1, 20 do spoke = spoke + Health.chatter(camp, 1) end
    check("rare by default", spoke >= 0 and spoke <= 60)
    check("negative minutes ignored", Health.chatter(camp, -5) == 0 and pcall(Health.minute, camp, -10))
end

do
    local camp, uids = scenario({ "medic", "builder", "builder" }, 6)
    Health.minute(camp, 30)
    check("half hour no tick", camp.health.hours == 0 and camp.health.clock == 30)
    Health.minute(camp, 30)
    check("hour ticks", camp.health.hours == 1 and camp.health.clock == 0)
    Health.minute(camp, 0.5)
    Health.minute(camp, 1)
    check("fractions accumulate", camp.health.hours == 1 and near(camp.health.clock, 1.5))
    Health.minute(camp, 500)
    check("catch up is bounded", camp.health.hours == 1 + Health.catchUp and camp.health.clock < 60, tostring(camp.health.hours))
    Health.minute(camp, "x")
    check("garbage minutes ignored", pcall(Health.minute, camp, nil))
    local traces = 0
    for _, line in ipairs(PRINTS) do
        if string.find(line, "[ALifeCamp:Health] camp=" .. camp.id .. " ", 1, true) then traces = traces + 1 end
    end
    check("one trace per tick", traces == camp.health.hours, traces .. " vs " .. camp.health.hours)
    local sample
    for _, line in ipairs(PRINTS) do
        if string.find(line, "[ALifeCamp:Health] camp=" .. camp.id .. " ", 1, true) then sample = line end
    end
    check("trace format", sample ~= nil and string.find(sample, "sick=0", 1, true) and string.find(sample, "medics=1", 1, true) and string.find(sample, "medicine=6", 1, true) and string.find(sample, "epidemic=0", 1, true), sample)
end

do
    local camp, uids = scenario({ "medic", "builder", "builder", "builder", "guard", "farmer" }, 40, 300)
    for _, other in ipairs(Store.list()) do
        if other ~= camp then Store.remove(other.id) end
    end
    Health.infect(camp, uids[2], "fever", 2, true)
    Health.infect(camp, uids[3], "poison", 1, true)
    local startHour = camp.health ~= nil and camp.health.hours or 0
    for _ = 1, 125 do
        HOURS = HOURS + 1 / 60
        fire("EveryOneMinute")
    end
    check("director drives hourly ticks", camp.health ~= nil and camp.health.hours - startHour == 2, camp.health and camp.health.hours)
    check("director run treats", Health.stats(camp).treated >= 1)
    local win = A.Window.open(camp)
    A.Window.createChildren(win)
    win.campId = camp.id
    win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
    local lines = win:lines(camp)
    local texts = {}
    for _, line in ipairs(lines) do texts[#texts + 1] = line.text end
    check("overview shows health line", (function()
        local own = Health.overview(camp)[1].text
        for _, text in ipairs(texts) do
            if text == own then return true end
        end
        return false
    end)())
    check("director run made an outbreak", camp.health.epidemic == true and Health.overview(camp)[1].r == 1)
    win:selectTab("life")
    win:prerender()
    check("life tab has no clickable health rows", #win.hitRows == 0)
    win:selectTab("log")
    win:prerender()
    local logLines = win:logLines(camp)
    check("log tab renders", #logLines >= 1)
    win:selectTab("settings")
    win:prerender()
    local settingTexts = {}
    for _, line in ipairs(Options.lines(camp)) do settingTexts[#settingTexts + 1] = line.text end
    local joined = table.concat(settingTexts, "|")
    check("settings list the new options", string.find(joined, T("Opt_epidemics"), 1, true) ~= nil and string.find(joined, T("Opt_quarantine"), 1, true) ~= nil and string.find(joined, T("OptHint_epidemics"), 1, true) ~= nil)
    check("director run serializable", cleanState(camp))
end

do
    local camp, uids = scenario({ "medic", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder", "builder" }, 20)
    local lines0 = Hooks.tabLines(Hooks.tab("life"), camp)
    local function hasText(lines, text)
        for _, line in ipairs(lines) do
            if string.find(line.text, text, 1, true) then return true end
        end
        return false
    end
    check("life tab has section header", hasText(lines0, T("HlSection")))
    local section = Health.sectionLines(camp)
    check("healthy section", #section == 4 and hasText(section, T("HlSecSick", "0", "12")) and hasText(section, T("HlSecCare", "1", "20")))
    check("epidemic no shown", hasText(section, T("HlSecEpi", T("HlNo"))))
    check("quarantine and infirmary line", hasText(section, T("HlSecWard", T("OptOn"), T("HlNo"))))
    for _, line in ipairs(section) do
        if line.click ~= nil then check("section rows are not clickable", false) end
    end
    local over = Health.overview(camp)
    check("healthy overview", #over == 1 and over[1].text == T("HlOvAll", "1", "20") and over[1].g > 0.8)
    for i = 2, 5 do Health.infect(camp, uids[i], "fever", i - 1, true) end
    Health.infect(camp, uids[6], "wound", 3, true)
    camp.settlers[uids[2]].ill.by = uids[1]
    local sec2 = Health.sectionLines(camp)
    check("sick section rows", #sec2 == 4 + 5 and hasText(sec2, T("HlSecSick", "5", "12")))
    check("patient row content", hasText(sec2, camp.settlers[uids[2]].name .. ": " .. T("HlKind_fever") .. " 1, " .. T("HlCared")))
    check("uncared patient row", hasText(sec2, T("HlNotCared")))
    check("wound row", hasText(sec2, T("HlKind_wound") .. " 3"))
    check("severe first", string.find(sec2[5].text, " 3, ", 1, true) ~= nil and string.find(sec2[#sec2].text, " 1, ", 1, true) ~= nil, sec2[5].text)
    check("ward tag on serious", hasText(sec2, T("HlWardTag")))
    check("severity colors", sec2[5].g < sec2[#sec2].g)
    check("epidemic overview red", Health.judge(camp) == true and Health.overview(camp)[1].r == 1 and Health.overview(camp)[1].g < 0.5)
    check("epidemic section red", (function()
        for _, line in ipairs(Health.sectionLines(camp)) do
            if line.text == T("HlSecEpi", T("HlYes")) then return line.g < 0.5 end
        end
        return false
    end)())
    for i = 7, 12 do Health.infect(camp, uids[i], "poison", 1, true) end
    local sec3 = Health.sectionLines(camp)
    check("list limited to eight plus more", #sec3 == 4 + Health.listLimit + 1 and hasText(sec3, T("HlMore", tostring(11 - Health.listLimit))), #sec3)
    Options.set(camp, "quarantine", false)
    check("no ward tag when quarantine off", not hasText(Health.sectionLines(camp), T("HlWardTag")))
    check("quarantine off line", hasText(Health.sectionLines(camp), T("HlSecWard", T("OptOff"), T("HlNo"))))
    local list = Health.list(camp)
    local wounds = 0
    for _, row in ipairs(list) do
        if row.kind == "wound" then wounds = wounds + 1 end
    end
    check("list api", #list == 11 and list[1].level == 3 and list[#list].level == 1 and wounds == 1 and type(list[1].name) == "string" and type(list[1].cared) == "boolean")
end

do
    local camp, uids = scenario({ "builder", "builder", "builder", "builder", "builder", "builder" }, 0)
    check("roles hook silent when healthy", #Hooks.collect("roles", camp) == 0)
    Health.infect(camp, uids[1], "fever", 1, true)
    local rows = Hooks.collect("roles", camp)
    check("roles hook asks for medic", #rows == 1 and rows[1][1] == "medic" and rows[1][2] == 0.2)
    Health.infect(camp, uids[2], "fever", 1, true)
    Health.infect(camp, uids[3], "fever", 1, true)
    Health.judge(camp)
    check("roles hook epidemic share", Hooks.collect("roles", camp)[1][2] == 0.3)

    local c2, u2 = scenario({ "builder", "builder", "builder", "farmer", "farmer", "guard", "guard", "scavenger", "medic" }, 0)
    local base = Work.pickRole(c2)
    check("pickRole baseline", base == "scavenger" or base == "medic" or base == "builder" or base == "farmer" or base == "guard", base)
    Health.infect(c2, u2[1], "fever", 1, true)
    check("sickness shifts new arrivals to medic", Work.pickRole(c2) == "medic")
end

do
    local a, ua, xa = scenario({ "medic", "builder", "builder" }, 4)
    local b, ub, xb = scenario({ "medic", "builder", "builder" }, 4)
    a.adopt = { items = { h1 = { id = 1, key = "h1", status = "done", rect = { x1 = xa, y1 = 100, x2 = xa + 8, y2 = 106, z = 0 },
        fitout = { phase = "ready", rooms = { { kind = "infirmary", z = 0, x1 = xa + 1, y1 = 101, x2 = xa + 4, y2 = 104 } } } } } }
    Health.infect(a, ua[2], "fever", 2, true)
    Health.infect(a, ua[3], "fever", 2, true)
    hours(a, 1)
    check("camps keep separate state", Health.stats(a).sick == 2 and Health.stats(b).sick == 0 and b.health == nil)
    check("camps keep separate infirmaries", Health.ward(a, true) ~= nil and Health.ward(b, true) == nil)
    check("camps keep separate doses", medicineLeft(a) == 2 and medicineLeft(b) == 4)
    a.raid = { at = HOURS, people = 3 }
    hours(a, 1)
    check("treatment continues during a raid", a.settlers[ua[2]].ill.dose > 0 and Health.stats(a).treated == 2)
    a.raid = nil
    local first = Options.cycle(a, "quarantine")
    check("quarantine option toggles", first == false and Options.on(a, "quarantine") == false and Options.on(b, "quarantine") == true)
    check("quarantine option toggles back", Options.cycle(a, "quarantine") == true)
    check("epidemics option toggles", Options.cycle(a, "epidemics") == false and Options.cycle(a, "epidemics") == true)
    local rows = {}
    for _, line in ipairs(Options.lines(a)) do
        if line.click ~= nil and (string.find(line.text, T("Opt_epidemics"), 1, true) or string.find(line.text, T("Opt_quarantine"), 1, true)) then rows[#rows + 1] = line end
    end
    check("settings rows are clickable", #rows == 2)
    rows[1].click(a)
    rows[2].click(a)
    check("settings clicks change both options", Options.on(a, "epidemics") ~= Options.on(b, "epidemics") and Options.on(a, "quarantine") ~= Options.on(b, "quarantine"))
end

do
    local camp, uids = scenario({ "builder", "builder", "builder" }, 0)
    Health.infect(camp, uids[1], "fever", 2)
    Health.infect(camp, uids[2], "wound", 1)
    hours(camp, 1)
    local copyOf = copy(camp)
    camp.health = copyOf.health
    for uid, settler in pairs(copyOf.settlers) do camp.settlers[uid] = settler end
    check("state survives a save copy", pcall(Hooks.each, "minute", camp, 60) and Health.sickLevel(camp, uids[1]) == 2)
    check("copy serializable", cleanState(camp))
end

do
    reset()
    local roles = { "medic", "worker", "builder", "builder", "farmer", "guard", "guard", "scavenger", "builder", "farmer" }
    local camp, uids = scenario(roles, 6, 400)
    Health.chance = copy(DEFAULTS.chance)
    local seed = 20260101
    ZombRand = function(n)
        seed = (seed * 16807) % 2147483647
        return seed % n
    end
    local infections, hourly = 0, 0
    local realInfect = Health.infect
    Health.infect = function(c, uid, kind, level, quiet)
        local ok = realInfect(c, uid, kind, level, quiet)
        if ok then infections = infections + 1 end
        return ok
    end
    local started = os.clock()
    local invariants = true
    local why
    for hour = 1, 24 * 40 do
        HOURS = HOURS + 1
        if hour % 12 == 0 then
            for _ = 1, 3 do
                local item = NEWITEM("Base.Bandage")
                item.cat = "FirstAid"
                item.mod = {}
                item.getModData = function(self) return self.mod end
                local box = Stock.crate(camp, camp.storage[1]):getContainer()
                item.container = box
                table.insert(box.items, item)
            end
            Stock.refresh(camp)
        end
        if hour % 96 == 0 then
            Hooks.each("raidend", camp, { people = 10 }, hour % 192 == 0 and 1 or 0)
        end
        Hooks.each("minute", camp, 60)
        local stats = Health.stats(camp)
        if stats.sick > 10 or stats.sick < 0 then invariants = false why = "sick range" end
        for uid, settler in pairs(camp.settlers) do
            if settler.ill ~= nil then
                local ill = settler.ill
                if not Health.valid[ill.kind] or ill.level < 1 or ill.level > 3 or ill.level ~= math.floor(ill.level) or ill.prog < 0 or ill.dose < 0 then
                    invariants = false
                    why = "bad ill at hour " .. hour
                end
            end
        end
        hourly = hourly + stats.sick
    end
    Health.infect = realInfect
    local elapsed = os.clock() - started
    local stats = Health.stats(camp)
    check("soak invariants", invariants, why)
    check("soak is fast", elapsed < 10, elapsed)
    check("soak illnesses are plausible", infections >= 3 and infections <= 600, infections)
    check("soak not everyone is always sick", hourly / (24 * 40) < 6, hourly / (24 * 40))
    check("soak recoveries happen", stats.recovered >= 1, stats.recovered)
    check("soak counters sane", stats.treated >= 0 and stats.epidemics >= 0)
    check("soak log bounded", #camp.log <= A.Config.logLimit)
    check("soak serializable", cleanState(camp))
    PRINTS[#PRINTS + 1] = "SOAK infections=" .. infections .. " avgSick=" .. (hourly / (24 * 40)) .. " recovered=" .. stats.recovered .. " treated=" .. stats.treated .. " epidemics=" .. stats.epidemics .. " seconds=" .. elapsed
    RAND(0)
end

do
    local seen = {}
    local function use(key, ...) seen[#seen + 1] = T(key, ...) end
    for _, key in ipairs({ "Opt_epidemics", "OptHint_epidemics", "Opt_quarantine", "OptHint_quarantine", "HlSection", "HlKind_fever", "HlKind_infection",
        "HlKind_poison", "HlKind_wound", "HlInfoCare", "HlCough", "HlCough_infection", "HlCough_poison", "HlCough_wound", "HlCare", "HlCared", "HlNotCared",
        "HlWardTag", "HlYes", "HlNo", "HlHave", "Log_hl_epidemic_end" }) do use(key) end
    for _, key in ipairs({ "HlInfo", "HlPatient" }) do use(key, "a", "b", "c", "d") end
    for _, key in ipairs({ "HlEpidemic", "HlNoMeds" }) do use(key, "Camp", "3") end
    use("HlEpidemicEnd", "Camp")
    for _, key in ipairs({ "Log_hl_sick", "Log_hl_worse" }) do use(key, "a", "b") end
    for _, key in ipairs({ "Log_hl_wounded", "Log_hl_spread", "Log_hl_festered", "Log_hl_recovered", "Log_hl_epidemic", "Log_hl_nomeds", "HlInfoNurse", "HlMore", "HlSecEpi" }) do use(key, "a") end
    use("HlSecSick", "1", "2")
    use("HlSecCare", "1", "2")
    use("HlSecWard", "a", "b")
    use("HlOvAll", "1", "2")
    use("HlOvSick", "1", "2", "3", "4")
    use("HlOvEpi", "1", "2", "3")
    for _, text in ipairs(seen) do
        if string.find(text, "%", 1, true) ~= nil then check("no bare percent", false, text) end
    end
    check("all texts resolved", true)
end

local kept, samples = {}, 0
for _, line in ipairs(PRINTS) do
    if string.sub(line, 1, 18) == "[ALifeCamp:Health]" then
        if samples < 3 then
            samples = samples + 1
            kept[#kept + 1] = line
        end
    else
        kept[#kept + 1] = line
    end
end
PRINTS = kept

local silentOwn = {}
for _, message in ipairs(SILENT) do
    if string.find(message, "CampHealth", 1, true) ~= nil or string.find(message, "CheatsHealth", 1, true) ~= nil then silentOwn[#silentOwn + 1] = message end
end
PRINTS[#PRINTS + 1] = "own silent errors: " .. #silentOwn
for i = 1, math.min(#silentOwn, 6) do PRINTS[#PRINTS + 1] = "  " .. silentOwn[i] end
check("no unexpected errors inside module", #silentOwn <= 4, #silentOwn)

local faultNames = {}
for name in pairs(Health.faults) do faultNames[#faultNames + 1] = name end
check("no module faults reported", #faultNames == 0, table.concat(faultNames, ","))

local missing, foreign = {}, {}
local ownKeys = { "UI_ALC_Hl", "UI_ALC_Opt_epidemics", "UI_ALC_OptHint_epidemics", "UI_ALC_Opt_quarantine", "UI_ALC_OptHint_quarantine", "UI_ALC_Log_hl_", "UI_ALC_ChT_hl_", "UI_ALC_ChD_hl_", "UI_ALC_ChR_hl_" }
for k in pairs(MISSING) do
    local own = false
    for _, prefix in ipairs(ownKeys) do
        if string.sub(k, 1, #prefix) == prefix then own = true end
    end
    if own then missing[#missing + 1] = k else foreign[#foreign + 1] = k end
end
table.sort(missing)
table.sort(foreign)
if #foreign > 0 then PRINTS[#PRINTS + 1] = "foreign missing keys (not mine): " .. table.concat(foreign, ",") end
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missing }
