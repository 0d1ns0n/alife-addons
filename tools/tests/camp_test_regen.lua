dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Fortress", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter", "Houses", "Duty" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Camp, Build, Plan, Regen, Store = A.Camp, A.Build, A.Plan, A.Regen, A.Store

check("regen module", Regen ~= nil and type(Regen.run) == "function")

for x = 40, 170 do for y = 40, 170 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 110, y2 = 110, z = 0 }, "Regen")
camp.phase = "plan"
camp.settlers = { a = { role = "worker" }, b = { role = "guard" }, c = {} }
camp.population = 3
Plan.generate(camp)
local before = 0
for _ in pairs(Build.plan(camp).items) do before = before + 1 end
check("has projects before", before > 0, before)

local result = Regen.run(camp)
check("run returns table", type(result) == "table")
check("settlers counted and cleared", result.settlers == 3, result.settlers)
local scount = 0
for _ in pairs(camp.settlers) do scount = scount + 1 end
check("settlers now empty", scount == 0)
check("population zeroed", camp.population == 0)
local after = 0
for _ in pairs(Build.plan(camp).items) do after = after + 1 end
check("plan wiped", after == 0, after)
check("phase reset to plan", camp.phase == "plan")
check("clear state reset", camp.clear == nil)
check("regen chunk calls fail gracefully (no real chunk api in mock)", result.processed == 0, result.processed)
check("zone queued as pending (unloaded in mock)", result.pending == true)

-- re-plan works after regen
Plan.generate(camp)
local again = 0
for _ in pairs(Build.plan(camp).items) do again = again + 1 end
check("camp can re-plan after regen", again > 0, again)

check("nil camp safe", type(Regen.run(nil)) == "table")

local function pure(v, d)
    if d > 8 then return false end
    local k = type(v)
    if k == "function" or k == "userdata" then return false end
    if k ~= "table" then return true end
    for _, item in pairs(v) do if not pure(item, d + 1) then return false end end
    return true
end
check("camp serializable after regen", pure(camp.plan, 0) and pure(camp.settlers or {}, 0))

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
