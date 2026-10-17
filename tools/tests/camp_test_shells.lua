dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Shells, Camp, Hooks = A.Shells, A.Camp, A.Hooks
check("shells module loaded", Shells ~= nil)

for x = 20, 140 do for y = 20, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 900
local reg = MOCKALIFE()
local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Shells")

local function fake(state)
    local s = { state = state, calls = {}, mod = {} }
    local function getter(name, key)
        s[name] = function(self) return self.state[key] end
    end
    getter("isUseless", "useless")
    getter("isNoTeeth", "teeth")
    getter("isFakeDead", "fakedead")
    getter("isReanimate", "reanimate")
    getter("isReanimatedPlayer", "rp")
    getter("isBecomeCrawler", "bc")
    getter("isCrawling", "crawling")
    getter("isCanWalk", "canwalk")
    local function setter(name, key)
        s[name] = function(self, v) self.state[key] = v self.calls[name] = (self.calls[name] or 0) + 1 end
    end
    setter("setUseless", "useless")
    setter("setNoTeeth", "teeth")
    setter("setFakeDead", "fakedead")
    setter("setReanimate", "reanimate")
    setter("setReanimatedPlayer", "rp")
    setter("setBecomeCrawler", "bc")
    setter("setCrawler", "crawling")
    setter("setCanWalk", "canwalk")
    s.setForceFakeDead = function() end
    s.setTarget = function(self, t) self.state.target = t end
    s.setZombiesDontAttack = function(self, v) self.state.dontattack = v end
    s.getModData = function(self) return self.mod end
    return s
end

local clean = { useless = true, teeth = true, fakedead = false, reanimate = false, rp = false, bc = false, crawling = false, canwalk = true }
local dirty = { useless = false, teeth = false, fakedead = true, reanimate = true, rp = true, bc = true, crawling = true, canwalk = false, target = "x" }

ADDACTOR(reg, "good", "friendly", 70, 70, nil)
ADDACTOR(reg, "bad", "friendly", 71, 70, nil)
A.Settlers.settle(camp, "good", "Good")
A.Settlers.settle(camp, "bad", "Bad")
local good, bad = fake(clean), fake(dirty)
ProjectALife.Watchdog.bindings.good = { shell = good }
ProjectALife.Watchdog.bindings.bad = { shell = bad }

check("clean shell has no anomalies", #Shells.anomalies(good) == 0)
check("dirty shell lists all anomalies", #Shells.anomalies(bad) == 8)

local checked, fixed = Shells.sweep(camp, false)
check("sweep checks both", checked == 2)
check("sweep fixes only the dirty one", fixed == 1 and good.calls.setUseless == nil)
check("dirty shell is clean afterwards", #Shells.anomalies(bad) == 0 and bad.state.target == nil and bad.state.dontattack == true)

bad.state.useless = false
Hooks.each("minute", camp, 5)
check("minute hook repairs a relapse", bad.state.useless == true)

bad.state.useless = false
Hooks.each("minute", camp, 1)
check("minute hook waits between sweeps", bad.state.useless == false)

dirty = { useless = false, teeth = false, fakedead = true, reanimate = true, rp = true, bc = false, crawling = false, canwalk = true }
local revived = fake(dirty)
ADDACTOR(reg, "third", "friendly", 72, 70, nil)
ProjectALife.Watchdog.bindings.third = { shell = revived }
A.Settlers.settle(camp, "third", "Third")
check("arrival normalizes the shell", #Shells.anomalies(revived) == 0)

local result = Shells.reset(camp)
check("reset forces every shell", result.checked == 3 and result.fixed == 3)

local biter = fake({ useless = true, teeth = true })
biter.mod.ProjectALifeBiteUntilMs = 999999999
getTimestampMs = function() return 1000 end
Shells.normalize(biter)
check("bite window keeps attack open", biter.state.dontattack == nil)

check("no shell is not an error", Shells.normalize(nil) == false)
check("settings action registered", (function()
    for _, spec in ipairs(A.Options.actions) do if spec.key == "shells" then return true end end
    return false
end)())
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
