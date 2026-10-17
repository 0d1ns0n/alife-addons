dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter", "Houses" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Camp, Build, Tiers, Store, Settlers = A.Camp, A.Build, A.Tiers, A.Store, A.Settlers
local reg = MOCKALIFE()

check("tiers module", Tiers ~= nil and #Tiers.ladder == 5)
check("tiers option defined", A.Options.byKey["tiers"] ~= nil)

for x = 40, 170 do for y = 40, 170 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 400

local function settle(camp, count)
    local have = Store.settlerCount(camp)
    for i = have + 1, count do
        local uid = "t" .. i
        ADDACTOR(reg, uid, "friendly", camp.x1 + 2 + i, camp.y1 + 2, A.World.square(camp.x1 + 2 + i, camp.y1 + 2, 0))
        Settlers.settle(camp, uid, uid)
    end
end
local function addDone(camp, n)
    local plan = Build.plan(camp)
    for _ = 1, n do
        plan.serial = plan.serial + 1
        plan.items[tostring(plan.serial)] = { id = plan.serial, kind = "house_s", status = "done", x = 0, y = 0, w = 1, h = 1 }
    end
end

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 119, y2 = 119, z = 0 }, "Tiered")
check("new camp has tiersOn", camp.tiersOn == true)
check("tiers active on new camp", Tiers.on(camp) == true)

-- fresh: side 60, 0 people, 0 built -> camp (1)
local t1 = Tiers.update(camp)
check("fresh camp is tier 1 (Лагерь)", t1 == 1 and Tiers.index(camp) == 1, t1)

-- outpost: need people>=5, built>=12 (side 60 ok)
settle(camp, 5)
addDone(camp, 12)
local t2, up2 = Tiers.update(camp)
check("rises to outpost (2)", t2 == 2 and up2 == true, t2)

-- village: people>=12, built>=40 (side 60 ok)
settle(camp, 12)
addDone(camp, 30)
local t3, up3 = Tiers.update(camp)
check("rises to village (3)", t3 == 3 and up3 == true, t3)

-- town needs side>=120, but side is 60 -> stays village even with more people/built
settle(camp, 30)
addDone(camp, 100)
local t3b = Tiers.update(camp)
check("blocked at village by side (town needs side 120)", t3b == 3, t3b)

-- hysteresis: wipe built + settlers, tier must NOT drop
Build.plan(camp).items = {}
Build.plan(camp).serial = 0
camp.settlers = {}
local t4, up4 = Tiers.update(camp)
check("hysteresis keeps tier (no demote)", t4 == 3 and up4 == false, t4)
check("name reflects village", Tiers.name(camp) == A.T("Tier_village"), Tiers.name(camp))

-- option off disables
A.Options.set(camp, "tiers", false)
check("option off disables tiers", Tiers.on(camp) == false)
A.Options.set(camp, "tiers", true)

-- existing camp (no tiersOn) untouched
local old = Camp.create({ x1 = 130, y1 = 60, x2 = 180, y2 = 110, z = 0 }, "Old")
old.tiersOn = nil
check("existing camp: tiers off", Tiers.on(old) == false)
local ot, ou = Tiers.update(old)
check("existing camp update is no-op", ot == 1 and ou == false and old.tier == nil)
check("existing camp index 1", Tiers.index(old) == 1)

-- overview hook present for tiered camp, empty for old
local ovTier = A.Hooks.collect("overview", camp)
local ovOld = A.Hooks.collect("overview", old)
local tierLine = A.T("Tier_overview", A.T("Tier_village"))
local function hasTier(lines)
    for _, l in ipairs(lines) do if type(l) == "table" and l.text == tierLine then return true end end
    return false
end
check("overview shows tier line for tiered camp", hasTier(ovTier))
check("overview has no tier line for old camp", not hasTier(ovOld))

local function pure(v, d)
    if d > 8 then return false end
    local k = type(v)
    if k == "function" or k == "userdata" then return false end
    if k ~= "table" then return true end
    for _, item in pairs(v) do if not pure(item, d + 1) then return false end end
    return true
end
check("camp serializable", pure(camp.plan, 0) and type(camp.tier) == "number")

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
