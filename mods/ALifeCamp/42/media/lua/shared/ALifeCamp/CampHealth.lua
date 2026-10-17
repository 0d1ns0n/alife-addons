require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampStats"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock
local Settlers = ALifeCamp.Settlers
local T = ALifeCamp.T

local Health = {}
ALifeCamp.Health = Health

Health.kinds = { "fever", "infection", "poison", "wound" }
Health.valid = { fever = true, infection = true, poison = true, wound = true }
Health.helperRoles = { worker = true, scavenger = true }
Health.maxLevel = 3
Health.quarantineLevel = 2
Health.sickWork = 0.35
Health.perMedic = 3
Health.helperSlots = 2
Health.helperSpeed = 0.5
Health.doseHours = 12
Health.stepNeed = 6
Health.immuneHours = 48
Health.contactRange = 14
Health.alertGap = 24
Health.listLimit = 8
Health.epidemicSick = 3
Health.epidemicShare = 0.3
Health.endBelow = 2
Health.catchUp = 3
Health.moralePerSick = 2
Health.moraleSickCap = 15
Health.moraleEpidemic = 10
Health.wardRefresh = 0.5

Health.chance = {
    base = 0.0012,
    cap = 0.2,
    cleanRef = 70,
    cleanSlope = 0.0216,
    cleanMin = 0.35,
    cleanMax = 3,
    crowd = 0.05,
    crowdMax = 1.6,
    hunger = 1.8,
    water = 1.4,
    gloom = 1.2,
    gloomBelow = 30,
    severe2 = 0.2,
    severe3 = 0.25,
    spread = 0.02,
    quarantine = 0.25,
    epidemic = 1.25,
    wound = 0.25,
    woundLost = 0.15,
    woundCap = 0.9,
    woundSevere2 = 0.35,
    woundSevere3 = 0.15,
    fester = 0.012,
    cough = 0.004,
}

Health.contagion = { fever = 1, infection = 0.2, poison = 0, wound = 0 }
Health.selfRate = { fever = 0.3, infection = 0.08, poison = 0.5, wound = 0.15 }
Health.worsen = { fever = 0.012, infection = 0.03, poison = 0.01, wound = 0.008 }
Health.rates = { dose = 4, care = 1.8, ward = 1.2, hungry = 0.7 }
Health.weights = { fever = 4, poison = 1, poisonHunger = 4, poisonDry = 2, infection = 1 }
Health.xp = { dose = 30, care = 5 }

Health.wardCache = {}
Health.faults = {}

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function number(value, default)
    if type(value) == "number" and value == value then return value end
    return default
end

local function roll(chance)
    if type(chance) ~= "number" or chance <= 0 then return false end
    if chance >= 1 then return true end
    return Hooks.rand(10000) <= chance * 10000
end

local function pickFrom(list)
    if #list == 0 then return nil end
    return list[Hooks.rand(#list)]
end

local function hashOf(text)
    local value = 0
    text = tostring(text)
    for i = 1, #text do value = (value * 31 + string.byte(text, i)) % 1000003 end
    return value
end

local function byText(a, b)
    return tostring(a) < tostring(b)
end

local function roster(camp)
    local list = {}
    if type(camp) ~= "table" or type(camp.settlers) ~= "table" then return list end
    for uid, settler in pairs(camp.settlers) do
        if type(settler) == "table" then list[#list + 1] = uid end
    end
    table.sort(list, byText)
    return list
end

local function levelOf(settler)
    if type(settler) ~= "table" or type(settler.ill) ~= "table" then return 0 end
    local level = math.floor(number(settler.ill.level, 0))
    if level < 1 then return 0 end
    if level > Health.maxLevel then return Health.maxLevel end
    return level
end

local function immune(settler, now)
    return number(settler.hlImmune, 0) > now
end

local function nameOf(camp, uid)
    local settler = camp.settlers[uid]
    if type(settler) == "table" and settler.name ~= nil then return tostring(settler.name) end
    return tostring(uid)
end

local function illText(kind, level)
    return T("HlKind_" .. tostring(kind)) .. " " .. tostring(level)
end

local function journal(camp, key, a, b)
    if type(camp.log) ~= "table" then return end
    pcall(Store.log, camp, key, a, b)
end

local function notify(camp, key, a)
    local work = ALifeCamp.Work
    if work == nil or type(work.notify) ~= "function" then return end
    if a == nil then
        pcall(work.notify, camp, key)
    else
        pcall(work.notify, camp, key, a)
    end
end

local function skillFactor(camp)
    local skills = ALifeCamp.Skills
    if skills == nil or type(skills.factor) ~= "function" then return 1 end
    local ok, value = pcall(skills.factor, camp, "medic")
    if ok and type(value) == "number" and value > 0 then return value end
    return 1
end

local function medicLevel(settler)
    local skills = ALifeCamp.Skills
    if skills == nil or type(skills.level) ~= "function" then return 0 end
    local ok, value = pcall(skills.level, settler, "medic")
    if ok and type(value) == "number" then return value end
    return 0
end

local function gainXp(camp, uid, xp)
    local skills = ALifeCamp.Skills
    if skills == nil or type(skills.gain) ~= "function" or xp <= 0 then return end
    pcall(skills.gain, camp, uid, "medic", xp)
end

local function progressBonus(camp)
    local progress = ALifeCamp.Progress
    if progress == nil or type(progress.bonus) ~= "function" then return 1 end
    local ok, value = pcall(progress.bonus, camp, "heal")
    if ok and type(value) == "number" and value > 0 then return clamp(value, 0.25, 4) end
    return 1
end

local function cleanliness(camp)
    local sanitary = ALifeCamp.Sanitary
    if sanitary ~= nil and type(sanitary.score) == "function" then
        local ok, value = pcall(sanitary.score, camp)
        if ok and type(value) == "number" then return clamp(value, 0, 100) end
    end
    return Health.chance.cleanRef
end

function Health.fault(name, err)
    if Health.faults[name] then return end
    Health.faults[name] = true
    print("[ALifeCamp:Health] " .. tostring(name) .. " failed: " .. tostring(err))
end

function Health.state(camp)
    local state = camp.health
    if type(state) ~= "table" then
        state = {}
        camp.health = state
    end
    state.clock = number(state.clock, 0)
    state.hours = number(state.hours, 0)
    state.epidemic = state.epidemic == true
    state.epidemics = number(state.epidemics, 0)
    state.recovered = number(state.recovered, 0)
    state.treated = number(state.treated, 0)
    state.penalty = number(state.penalty, 0)
    return state
end

function Health.sickLevel(camp, uid)
    if type(camp) ~= "table" or type(camp.settlers) ~= "table" then return 0 end
    return levelOf(camp.settlers[uid])
end

function Health.stats(camp)
    local sick, medics = 0, 0
    local state = {}
    if type(camp) == "table" then
        if type(camp.health) == "table" then state = camp.health end
        if type(camp.settlers) == "table" then
            for _, settler in pairs(camp.settlers) do
                if type(settler) == "table" then
                    if levelOf(settler) > 0 then sick = sick + 1 end
                    if settler.role == "medic" then medics = medics + 1 end
                end
            end
        end
    end
    return {
        sick = sick, medics = medics, treated = number(state.treated, 0), recovered = number(state.recovered, 0),
        epidemics = number(state.epidemics, 0), epidemic = state.epidemic == true,
    }
end

function Health.infect(camp, uid, kind, level, quiet)
    if type(camp) ~= "table" or type(camp.settlers) ~= "table" then return false end
    local settler = camp.settlers[uid]
    if type(settler) ~= "table" or not Health.valid[kind] or levelOf(settler) > 0 then return false end
    level = clamp(math.floor(number(level, 1)), 1, Health.maxLevel)
    settler.ill = { kind = kind, since = Store.hours(), level = level, prog = 0, dose = 0 }
    settler.hlImmune = nil
    if quiet ~= true then journal(camp, "hl_sick", nameOf(camp, uid), illText(kind, level)) end
    return true
end

function Health.cure(camp, uid)
    if type(camp) ~= "table" or type(camp.settlers) ~= "table" then return false end
    local settler = camp.settlers[uid]
    if type(settler) ~= "table" then return false end
    local was = levelOf(settler) > 0
    settler.ill = nil
    return was
end

function Health.recover(camp, uid)
    local settler = camp.settlers[uid]
    if type(settler) ~= "table" then return false end
    local state = Health.state(camp)
    settler.ill = nil
    settler.hlImmune = Store.hours() + Health.immuneHours
    state.recovered = state.recovered + 1
    journal(camp, "hl_recovered", nameOf(camp, uid))
    return true
end

function Health.cureAll(camp)
    local count = 0
    for _, uid in ipairs(roster(camp)) do
        if Health.cure(camp, uid) then count = count + 1 end
    end
    Health.judge(camp)
    return count
end

function Health.sicken(camp, count, kind, level)
    count = number(count, 0)
    local pool = {}
    for _, uid in ipairs(roster(camp)) do
        if levelOf(camp.settlers[uid]) == 0 then pool[#pool + 1] = uid end
    end
    local made = 0
    while made < count and #pool > 0 do
        local uid = table.remove(pool, Hooks.rand(#pool))
        if Health.infect(camp, uid, kind or "fever", level or 2) then made = made + 1 end
    end
    Health.judge(camp)
    return made
end

function Health.declareEpidemic(camp)
    local uids = roster(camp)
    if #uids < 2 then return 0 end
    Options.set(camp, "epidemics", true)
    local want = math.min(#uids, math.max(Health.epidemicSick, math.ceil(#uids * Health.epidemicShare)))
    local infectious = 0
    local pool = {}
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if levelOf(settler) == 0 then
            pool[#pool + 1] = uid
        elseif settler.ill.kind ~= "wound" then
            infectious = infectious + 1
        end
    end
    while infectious < want and #pool > 0 do
        local uid = table.remove(pool, Hooks.rand(#pool))
        if Health.infect(camp, uid, "fever", 2) then infectious = infectious + 1 end
    end
    Health.judge(camp, true)
    return Health.stats(camp).sick
end

local function scanAdopted(camp)
    local adopt = ALifeCamp.Adopt
    if adopt == nil or type(adopt.list) ~= "function" then return nil end
    local ok, list = pcall(adopt.list, camp)
    if not ok or type(list) ~= "table" then return nil end
    local cx, cy = Geo.center(camp)
    local best, bestCost
    for _, rec in ipairs(list) do
        local fit = type(rec) == "table" and rec.fitout or nil
        local live = type(rec) == "table" and (rec.status == "done" or rec.status == "fitout")
        if live and type(fit) == "table" and fit.phase == "ready" and fit.provisional ~= true and type(fit.rooms) == "table" then
            for _, room in ipairs(fit.rooms) do
                if type(room) == "table" and room.kind == "infirmary" and type(room.x1) == "number" and type(room.y1) == "number"
                    and type(room.x2) == "number" and type(room.y2) == "number" then
                    local z = math.floor(number(room.z, camp.z or 0))
                    local cost = (rec.status == "done" and 0 or 100000) + (z == (camp.z or 0) and 0 or 10000)
                        + math.abs((room.x1 + room.x2) / 2 - cx) + math.abs((room.y1 + room.y2) / 2 - cy)
                    if bestCost == nil or cost < bestCost then
                        best = {
                            x1 = math.floor(math.min(room.x1, room.x2)), y1 = math.floor(math.min(room.y1, room.y2)),
                            x2 = math.floor(math.max(room.x1, room.x2)), y2 = math.floor(math.max(room.y1, room.y2)), z = z,
                        }
                        bestCost = cost
                    end
                end
            end
        end
    end
    return best
end

local function scanWard(camp)
    local best = scanAdopted(camp)
    if best ~= nil then return best end
    local build = ALifeCamp.Build
    if build == nil then return nil end
    local ok, plan = pcall(build.plan, camp)
    if not ok or type(plan) ~= "table" or type(plan.items) ~= "table" then return nil end
    for _, project in pairs(plan.items) do
        if project.kind == "infirmary" and project.status == "done" and not project.retired then
            return { x1 = project.x, y1 = project.y, x2 = project.x + project.w - 1, y2 = project.y + project.h - 1, z = camp.z or 0 }
        end
    end
    return nil
end

function Health.ward(camp, fresh)
    local id = camp.id or 0
    local now = Store.hours()
    local entry = Health.wardCache[id]
    if fresh == true or entry == nil or now < entry.at or now - entry.at >= Health.wardRefresh then
        entry = { at = now, room = scanWard(camp) or false }
        Health.wardCache[id] = entry
    end
    return entry.room or nil
end

function Health.wardPoint(camp, uid)
    local room = Health.ward(camp)
    if room == nil then
        local cx, cy = Geo.center(camp)
        return { x = cx, y = cy, z = camp.z or 0 }
    end
    local width = room.x2 - room.x1 + 1
    local height = room.y2 - room.y1 + 1
    local seed = hashOf(uid)
    return { x = room.x1 + seed % width, y = room.y1 + math.floor(seed / width) % height, z = room.z, exact = true }
end

function Health.patients(camp, uids)
    local list = {}
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if levelOf(settler) > 0 then list[#list + 1] = { uid = uid, settler = settler } end
    end
    table.sort(list, function(a, b)
        local la, lb = levelOf(a.settler), levelOf(b.settler)
        if la ~= lb then return la > lb end
        local sa, sb = number(a.settler.ill.since, 0), number(b.settler.ill.since, 0)
        if sa ~= sb then return sa < sb end
        return tostring(a.uid) < tostring(b.uid)
    end)
    return list
end

function Health.caregivers(camp, uids)
    local medics, helpers = {}, {}
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if levelOf(settler) == 0 then
            local role = settler.role or "worker"
            if role == "medic" then
                medics[#medics + 1] = uid
            elseif Health.helperRoles[role] == true then
                helpers[#helpers + 1] = uid
            end
        end
    end
    local function better(a, b)
        local la, lb = medicLevel(camp.settlers[a]), medicLevel(camp.settlers[b])
        if la ~= lb then return la > lb end
        return tostring(a) < tostring(b)
    end
    table.sort(medics, better)
    if #medics > 0 then return medics, Health.perMedic, 1, true end
    table.sort(helpers, better)
    if #helpers > 0 then return { helpers[1] }, Health.helperSlots, Health.helperSpeed, false end
    return {}, 0, 0, false
end

function Health.dispense(camp)
    if type(camp.storage) ~= "table" then return false end
    local ok, taken = pcall(Stock.consume, camp, "medicine", 1)
    return ok and number(taken, 0) >= 1
end

function Health.alert(camp, state, sick)
    local now = Store.hours()
    if state.alertAt ~= nil and now >= state.alertAt and now - state.alertAt < Health.alertGap then return end
    state.alertAt = now
    journal(camp, "hl_nomeds", tostring(sick))
    notify(camp, "HlNoMeds", tostring(sick))
end

function Health.progress(camp, patient, carer, power, bonus, ward, festering, ctx)
    local uid, settler = patient.uid, patient.settler
    local ill = settler.ill
    local kind = ill.kind
    local level = levelOf(settler)
    local dose = number(ill.dose, 0)
    local attended = carer ~= nil
    if dose <= 0 and level < Health.maxLevel then
        local chance = (Health.worsen[kind] or 0.01) * (attended and 0.5 or 1) * (ctx.hungry and 1.5 or 1)
        if roll(chance) then
            ill.level = level + 1
            ill.prog = 0
            if ill.level >= Health.maxLevel then journal(camp, "hl_worse", nameOf(camp, uid), illText(kind, ill.level)) end
            return
        end
    end
    if kind == "wound" and festering and dose <= 0 then
        local chance = Health.chance.fester * ctx.cleanMul * (attended and 0.5 or 1)
        if roll(chance) then
            ill.kind = "infection"
            ill.prog = 0
            journal(camp, "hl_festered", nameOf(camp, uid))
            return
        end
    end
    local effect = 1
    if dose > 0 then
        effect = Health.rates.dose
    elseif attended then
        effect = Health.rates.care
    end
    local factor = attended and power or Health.helperSpeed
    local rate = (Health.selfRate[kind] or 0.2) * (1 + (effect - 1) * factor) * bonus
    if ctx.hungry then rate = rate * Health.rates.hungry end
    if ward and level >= Health.quarantineLevel then rate = rate * Health.rates.ward end
    ill.prog = number(ill.prog, 0) + rate
    local need = math.max(0.1, Health.stepNeed)
    while ill.prog >= need and level > 0 do
        ill.prog = ill.prog - need
        level = level - 1
    end
    ill.level = level
    if level <= 0 then
        Health.recover(camp, uid)
    else
        ill.dose = math.max(0, dose - 1)
    end
end

function Health.treat(camp, uids, ctx)
    local state = Health.state(camp)
    local patients = Health.patients(camp, uids)
    if #patients == 0 then return 0 end
    local carers, slots, speed, trained = Health.caregivers(camp, uids)
    local load = {}
    for _, id in ipairs(carers) do load[id] = 0 end
    local power = speed * (trained and skillFactor(camp) or 1)
    local bonus = progressBonus(camp)
    local ward = Options.on(camp, "quarantine") and Health.ward(camp) ~= nil
    local festering = Options.on(camp, "epidemics")
    local lacking = 0
    local spoke = {}
    for _, patient in ipairs(patients) do
        local ill = patient.settler.ill
        local carer
        for _, id in ipairs(carers) do
            if load[id] < slots and (carer == nil or load[id] < load[carer]) then carer = id end
        end
        ill.by = carer
        if carer ~= nil then
            load[carer] = load[carer] + 1
            gainXp(camp, carer, Health.xp.care)
            if number(ill.dose, 0) <= 0 then
                if Health.dispense(camp) then
                    ill.dose = Health.doseHours
                    state.treated = state.treated + 1
                    gainXp(camp, carer, Health.xp.dose)
                    if not spoke[carer] then
                        spoke[carer] = true
                        Settlers.say(Settlers.shell(carer), "HlCare")
                    end
                else
                    lacking = lacking + 1
                end
            end
        end
        Health.progress(camp, patient, carer, power, bonus, ward, festering, ctx)
    end
    if lacking > 0 then Health.alert(camp, state, #patients) end
    return #patients
end

function Health.context(camp, uids)
    local chance = Health.chance
    local state = Health.state(camp)
    local people = #uids
    local capacity, morale = people, 70
    local stats = ALifeCamp.Stats
    if stats ~= nil and type(stats.compute) == "function" then
        local ok, result = pcall(stats.compute, camp)
        if ok and type(result) == "table" then
            capacity = number(result.capacity, people)
            morale = number(result.morale, 70) + state.penalty
        end
    end
    local clean = cleanliness(camp)
    local stock = type(camp.stock) == "table" and camp.stock or {}
    return {
        people = people, capacity = capacity, morale = morale, clean = clean,
        hungry = number(camp.hunger, 0) > 0,
        dry = number(stock.water, 0) <= 0,
        gloomy = morale < chance.gloomBelow,
        crowd = clamp(1 + chance.crowd * math.max(0, people - capacity), 1, chance.crowdMax),
        cleanMul = clamp(1 + (chance.cleanRef - clean) * chance.cleanSlope, chance.cleanMin, chance.cleanMax),
    }
end

function Health.onset(ctx)
    local chance = Health.chance
    local value = chance.base * ctx.cleanMul * ctx.crowd
    if ctx.hungry then value = value * chance.hunger end
    if ctx.dry then value = value * chance.water end
    if ctx.gloomy then value = value * chance.gloom end
    return math.min(chance.cap, value)
end

function Health.pickKind(ctx)
    local weights = Health.weights
    local fever = weights.fever * ctx.crowd
    local poison = weights.poison + (ctx.hungry and weights.poisonHunger or 0) + (ctx.dry and weights.poisonDry or 0)
    local infection = weights.infection * ctx.cleanMul
    local ticket = Hooks.rand(1000) / 1000 * (fever + poison + infection)
    if ticket <= fever then return "fever" end
    if ticket <= fever + poison then return "poison" end
    return "infection"
end

function Health.spontaneous(camp, uids, ctx, now)
    local chance = Health.chance
    local value = Health.onset(ctx)
    local made = 0
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if levelOf(settler) == 0 and not immune(settler, now) and roll(value) then
            local level = 1
            if roll(chance.severe2) then
                level = 2
                if roll(chance.severe3) then level = 3 end
            end
            if Health.infect(camp, uid, Health.pickKind(ctx), level) then made = made + 1 end
        end
    end
    return made
end

function Health.spread(camp, uids, ctx, now)
    local chance = Health.chance
    local state = Health.state(camp)
    local quarantine = Options.on(camp, "quarantine")
    local places = {}
    for _, uid in ipairs(uids) do
        local x, y = Settlers.where(uid)
        if x ~= nil then places[uid] = { x = x, y = y } end
    end
    local made = 0
    for _, source in ipairs(Health.patients(camp, uids)) do
        local ill = source.settler.ill
        local weight = Health.contagion[ill.kind] or 0
        local level = levelOf(source.settler)
        if weight > 0 and level > 0 then
            local value = chance.spread * weight * (0.6 + 0.4 * level) * ctx.crowd
            if quarantine and level >= Health.quarantineLevel then value = value * chance.quarantine end
            if state.epidemic then value = value * chance.epidemic end
            if roll(value) then
                local pool = {}
                local from = places[source.uid]
                for _, uid in ipairs(uids) do
                    local other = camp.settlers[uid]
                    if uid ~= source.uid and levelOf(other) == 0 and not immune(other, now) then
                        local at = places[uid]
                        local near = from == nil or at == nil
                            or (math.abs(from.x - at.x) <= Health.contactRange and math.abs(from.y - at.y) <= Health.contactRange)
                        if near then pool[#pool + 1] = uid end
                    end
                end
                local victim = pickFrom(pool)
                if victim ~= nil and Health.infect(camp, victim, ill.kind, math.max(1, level - 1), true) then made = made + 1 end
            end
        end
    end
    if made > 0 then journal(camp, "hl_spread", tostring(made)) end
    return made
end

function Health.judge(camp, force)
    local state = Health.state(camp)
    local people, infectious = 0, 0
    for _, settler in pairs(camp.settlers or {}) do
        if type(settler) == "table" then
            people = people + 1
            if levelOf(settler) > 0 and settler.ill.kind ~= "wound" then infectious = infectious + 1 end
        end
    end
    local enabled = Options.on(camp, "epidemics")
    if state.epidemic then
        if infectious < Health.endBelow or (not enabled and force ~= true) then
            state.epidemic = false
            state.since = nil
            journal(camp, "hl_epidemic_end")
            notify(camp, "HlEpidemicEnd")
        end
    elseif (enabled or force == true) and infectious >= 2
        and (infectious >= Health.epidemicSick or infectious >= people * Health.epidemicShare) then
        state.epidemic = true
        state.since = Store.hours()
        state.epidemics = state.epidemics + 1
        journal(camp, "hl_epidemic", tostring(infectious))
        notify(camp, "HlEpidemic", tostring(infectious))
    end
    return state.epidemic
end

function Health.tidy(camp, uids, now)
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if settler.ill ~= nil then
            if levelOf(settler) == 0 then
                settler.ill = nil
            else
                local ill = settler.ill
                if not Health.valid[ill.kind] then ill.kind = "fever" end
                ill.level = levelOf(settler)
                ill.since = number(ill.since, now)
                ill.prog = math.max(0, number(ill.prog, 0))
                ill.dose = math.max(0, number(ill.dose, 0))
                if ill.by ~= nil and camp.settlers[ill.by] == nil then ill.by = nil end
            end
        end
        if settler.hlImmune ~= nil and number(settler.hlImmune, 0) <= now then settler.hlImmune = nil end
    end
end

function Health.trace(camp, state, uids)
    local counts = {}
    local sick = 0
    for _, uid in ipairs(uids) do
        local settler = camp.settlers[uid]
        if levelOf(settler) > 0 then
            sick = sick + 1
            counts[settler.ill.kind] = (counts[settler.ill.kind] or 0) + 1
        end
    end
    local parts = {}
    for _, kind in ipairs(Health.kinds) do
        if counts[kind] ~= nil then parts[#parts + 1] = kind .. "=" .. tostring(counts[kind]) end
    end
    local stock = type(camp.stock) == "table" and camp.stock or {}
    local stats = Health.stats(camp)
    print("[ALifeCamp:Health] camp=" .. tostring(camp.id) .. " people=" .. tostring(#uids) .. " sick=" .. tostring(sick)
        .. " medics=" .. tostring(stats.medics) .. " medicine=" .. tostring(math.floor(number(stock.medicine, 0)))
        .. " epidemic=" .. (state.epidemic and "1" or "0") .. " recovered=" .. tostring(state.recovered)
        .. " treated=" .. tostring(state.treated) .. (#parts > 0 and (" " .. table.concat(parts, " ")) or ""))
end

function Health.hour(camp)
    local state = Health.state(camp)
    state.hours = state.hours + 1
    local uids = roster(camp)
    local now = Store.hours()
    Health.tidy(camp, uids, now)
    if #uids == 0 then
        Health.judge(camp)
        Health.trace(camp, state, uids)
        return
    end
    local ctx = Health.context(camp, uids)
    local ok, err = pcall(Health.treat, camp, uids, ctx)
    if not ok then Health.fault("treat", err) end
    if Options.on(camp, "epidemics") then
        ok, err = pcall(Health.spontaneous, camp, uids, ctx, now)
        if not ok then Health.fault("spontaneous", err) end
        ok, err = pcall(Health.spread, camp, uids, ctx, now)
        if not ok then Health.fault("spread", err) end
    end
    ok, err = pcall(Health.judge, camp)
    if not ok then Health.fault("judge", err) end
    Health.trace(camp, state, uids)
end

local function anySick(camp)
    for _, settler in pairs(camp.settlers or {}) do
        if levelOf(settler) > 0 then return true end
    end
    return false
end

local function coughKey(kind)
    local key = "HlCough_" .. tostring(kind)
    if ALifeCamp.TN(key) ~= nil then return key end
    return "HlCough"
end

function Health.chatter(camp, minutes)
    local value = Health.chance.cough
    if value <= 0 or minutes <= 0 or not anySick(camp) then return 0 end
    local spoke = 0
    for _, uid in ipairs(roster(camp)) do
        local settler = camp.settlers[uid]
        local level = levelOf(settler)
        if level > 0 and roll(value * minutes * (0.7 + 0.3 * level)) then
            local shell = Settlers.shell(uid)
            if shell ~= nil then
                Settlers.say(shell, coughKey(settler.ill.kind))
                spoke = spoke + 1
            end
        end
    end
    return spoke
end

function Health.minute(camp, minutes)
    local state = Health.state(camp)
    minutes = math.max(0, number(minutes, 0))
    state.clock = state.clock + minutes
    local guard = 0
    while state.clock >= 60 and guard < Health.catchUp do
        state.clock = state.clock - 60
        guard = guard + 1
        local ok, err = pcall(Health.hour, camp)
        if not ok then Health.fault("hour", err) end
    end
    if state.clock >= 60 then state.clock = 0 end
    local ok, err = pcall(Health.chatter, camp, minutes)
    if not ok then Health.fault("chatter", err) end
end

function Health.raidWounds(camp, lost)
    lost = math.max(0, number(lost, 0))
    local chance = Health.chance
    local value = math.min(chance.woundCap, chance.wound + chance.woundLost * lost)
    local hurt = 0
    for _, uid in ipairs(roster(camp)) do
        local settler = camp.settlers[uid]
        if settler.role == "guard" and levelOf(settler) == 0 and roll(value) then
            local level = 1
            if roll(chance.woundSevere2 + 0.1 * lost) then
                level = 2
                if roll(chance.woundSevere3 + 0.05 * lost) then level = 3 end
            end
            if Health.infect(camp, uid, "wound", level, true) then hurt = hurt + 1 end
        end
    end
    if hurt > 0 then journal(camp, "hl_wounded", tostring(hurt)) end
    return hurt
end

function Health.laborFactor(camp)
    local total, sick = 0, 0
    for _, settler in pairs(camp.settlers or {}) do
        if type(settler) == "table" then
            total = total + 1
            if levelOf(settler) > 0 then sick = sick + 1 end
        end
    end
    if total == 0 or sick == 0 then return 1 end
    return (total - sick + sick * Health.sickWork) / total
end

function Health.moraleShift(camp)
    local state = Health.state(camp)
    local sick = 0
    for _, settler in pairs(camp.settlers or {}) do
        if levelOf(settler) > 0 then sick = sick + 1 end
    end
    local value = 0
    if sick > 0 then value = value + math.min(Health.moraleSickCap, sick * Health.moralePerSick) end
    if state.epidemic then value = value + Health.moraleEpidemic end
    state.penalty = value
    return -value
end

function Health.roles(camp)
    local stats = Health.stats(camp)
    if stats.sick == 0 then return nil end
    return { { "medic", stats.epidemic and 0.3 or 0.2 } }
end

function Health.charge(camp, carer)
    local best, bestLevel
    for uid, settler in pairs(camp.settlers or {}) do
        local level = levelOf(settler)
        if level > 0 and settler.ill.by == carer then
            if best == nil or level > bestLevel or (level == bestLevel and tostring(uid) < tostring(best)) then
                best, bestLevel = uid, level
            end
        end
    end
    return best
end

function Health.load(camp, carer)
    local count = 0
    for _, settler in pairs(camp.settlers or {}) do
        if levelOf(settler) > 0 and settler.ill.by == carer then count = count + 1 end
    end
    return count
end

function Health.anchor(camp, uid, settler, current)
    if camp.raid ~= nil or type(settler) ~= "table" then return nil end
    if not Options.on(camp, "quarantine") then return nil end
    local level = levelOf(settler)
    if level >= Health.quarantineLevel then return Health.wardPoint(camp, uid) end
    if level > 0 then return nil end
    local patient = Health.charge(camp, uid)
    if patient == nil then return nil end
    if levelOf(camp.settlers[patient]) >= Health.quarantineLevel then return Health.wardPoint(camp, uid) end
    local x, y, z = Settlers.where(patient)
    if x == nil then return nil end
    return { x = math.floor(x), y = math.floor(y), z = math.floor(number(z, camp.z or 0)) }
end

function Health.info(camp, uid, settler)
    local out = {}
    local level = levelOf(settler)
    if level > 0 then
        out[#out + 1] = T("HlInfo", T("HlKind_" .. tostring(settler.ill.kind)), tostring(level))
        if settler.ill.by ~= nil then out[#out + 1] = T("HlInfoCare") end
    end
    local load = Health.load(camp, uid)
    if load > 0 then out[#out + 1] = T("HlInfoNurse", tostring(load)) end
    return out
end

function Health.list(camp)
    local out = {}
    local quarantine = Options.on(camp, "quarantine")
    for _, patient in ipairs(Health.patients(camp, roster(camp))) do
        local level = levelOf(patient.settler)
        out[#out + 1] = {
            uid = patient.uid, name = nameOf(camp, patient.uid), kind = patient.settler.ill.kind, level = level,
            cared = patient.settler.ill.by ~= nil, ward = quarantine and level >= Health.quarantineLevel,
        }
    end
    return out
end

local function medicineOf(camp)
    local stock = type(camp.stock) == "table" and camp.stock or {}
    return math.floor(number(stock.medicine, 0))
end

local LEVEL_COLORS = { { 1, 0.9, 0.55 }, { 1, 0.7, 0.4 }, { 1, 0.5, 0.45 } }

function Health.sectionLines(camp)
    local people = Store.settlerCount(camp)
    if people == 0 then return {} end
    local stats = Health.stats(camp)
    local lines = {}
    lines[#lines + 1] = Hooks.line(T("HlSecSick", tostring(stats.sick), tostring(people)),
        stats.sick > 0 and 1 or 0.6, stats.sick > 0 and 0.8 or 0.9, stats.sick > 0 and 0.5 or 0.65)
    lines[#lines + 1] = Hooks.line(T("HlSecCare", tostring(stats.medics), tostring(medicineOf(camp))), 0.85, 0.85, 0.9)
    if stats.epidemic then
        lines[#lines + 1] = Hooks.line(T("HlSecEpi", T("HlYes")), 1, 0.45, 0.4)
    else
        lines[#lines + 1] = Hooks.line(T("HlSecEpi", T("HlNo")), 0.6, 0.9, 0.65)
    end
    local quarantine = T(Options.on(camp, "quarantine") and "OptOn" or "OptOff")
    lines[#lines + 1] = Hooks.line(T("HlSecWard", quarantine, T(Health.ward(camp) ~= nil and "HlHave" or "HlNo")), 0.75, 0.8, 0.9)
    local list = Health.list(camp)
    for i = 1, math.min(#list, Health.listLimit) do
        local row = list[i]
        local text = T("HlPatient", row.name, T("HlKind_" .. tostring(row.kind)), tostring(row.level), T(row.cared and "HlCared" or "HlNotCared"))
        if row.ward then text = text .. " " .. T("HlWardTag") end
        local color = LEVEL_COLORS[row.level] or LEVEL_COLORS[1]
        lines[#lines + 1] = Hooks.line(text, color[1], color[2], color[3])
    end
    if #list > Health.listLimit then
        lines[#lines + 1] = Hooks.line(T("HlMore", tostring(#list - Health.listLimit)), 0.7, 0.7, 0.75)
    end
    return lines
end

function Health.overview(camp)
    local people = Store.settlerCount(camp)
    if people == 0 then return {} end
    local stats = Health.stats(camp)
    local medicine = tostring(medicineOf(camp))
    if stats.epidemic then
        return { Hooks.line(T("HlOvEpi", tostring(stats.sick), tostring(people), medicine), 1, 0.45, 0.4) }
    end
    if stats.sick > 0 then
        return { Hooks.line(T("HlOvSick", tostring(stats.sick), tostring(people), tostring(stats.medics), medicine), 1, 0.8, 0.5) }
    end
    return { Hooks.line(T("HlOvAll", tostring(stats.medics), medicine), 0.6, 0.9, 0.65) }
end

Options.define({ key = "epidemics", group = "life", kind = "toggle", default = true, priority = 20 })
Options.define({ key = "quarantine", group = "life", kind = "toggle", default = true, priority = 21 })

Hooks.add("minute", function(camp, minutes) Health.minute(camp, minutes) end)
Hooks.add("labor", function(camp) return Health.laborFactor(camp) end)
Hooks.add("morale", function(camp) return Health.moraleShift(camp) end)
Hooks.add("anchor", function(camp, uid, settler, current) return Health.anchor(camp, uid, settler, current) end, 20)
Hooks.add("settlerInfo", function(camp, uid, settler) return Health.info(camp, uid, settler) end)
Hooks.add("raidend", function(camp, raid, lost) Health.raidWounds(camp, lost) end)
Hooks.add("roles", function(camp) return Health.roles(camp) end)
Hooks.add("overview", function(camp) return Health.overview(camp) end)
Hooks.section("life", "HlSection", function(camp) return Health.sectionLines(camp) end, 20)

return Health
