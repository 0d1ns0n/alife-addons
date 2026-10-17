dofile(MOCK)
for _, n in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Buildings", "Buildings2", "Buildings3", "Scenery", "Shells", "Towers", "Perimeter", "Fortress", "Features", "Outposts" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. n .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. n .. ".lua"] = true
end
SKIPMOD["server/ALifeCamp/CampOutposts.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Camp, Gates, Build, SlideGate = A.Camp, A.Gates, A.Build, A.SlideGate

check("module loaded", SlideGate ~= nil)

for x = 90, 160 do for y = 90, 160 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
local camp = Camp.create({ x1 = 100, y1 = 100, x2 = 119, y2 = 119, z = 0 }, "SG", { demolish = false })
check("camp created", camp ~= nil)

local plan = Build.plan(camp)
plan.serial = plan.serial + 1
local fence = { id = plan.serial, camp = camp.id, kind = "fence", x = 100, y = 100, w = 20, h = 20,
    level = 1, wall = 2, stage = 1, status = "done", work = 0, paid = true, done = {} }
fence.gates = {
    { id = "g1", side = "N", index = 8, main = true },
    { id = "g2", side = "E", index = 8 },
}
plan.items[tostring(fence.id)] = fence

local gN = Gates.geometry(fence, fence.gates[1])
local nx, ny, no = SlideGate.catcher(gN)
check("N catcher x", nx == 110, nx)
check("N catcher y", ny == 100, ny)
check("N orientation N", no == "N", no)

local gE = Gates.geometry(fence, fence.gates[2])
local ex, ey, eo = SlideGate.catcher(gE)
check("E catcher x", ex == 120, ex)
check("E catcher y", ey == 106, ey)
check("E orientation W", eo == "W", eo)

local gS = Gates.geometry({ x = 100, y = 100, w = 20, h = 20 }, { id = "gs", side = "S", index = 8 })
local sx, sy, so = SlideGate.catcher(gS)
check("S orientation N", so == "N", so)
check("S catcher on wall row", sy == 120, sy)

local gW = Gates.geometry({ x = 100, y = 100, w = 20, h = 20 }, { id = "gw", side = "W", index = 8 })
local wx, wy, wo = SlideGate.catcher(gW)
check("W orientation W", wo == "W", wo)
check("W catcher on wall col", wx == 100, wx)
check("W catcher y", wy == 106, wy)

check("bad geo returns nil", SlideGate.catcher(nil) == nil)
check("hook registered", (function()
    for _, e in ipairs(A.Hooks.lists.minute or {}) do if e.fn == SlideGate.onMinute then return true end end
    return false
end)())

SGGate = nil
SGGateTypes = nil
check("not ready without mod", SlideGate.ready() == false)
check("sync no-op without mod", SlideGate.sync(camp) == 0)
check("no state without mod", camp.slideGates == nil)
local okNoMod = pcall(SlideGate.onMinute, camp)
check("onMinute no crash without mod", okNoMod == true)
check("still no state without mod", camp.slideGates == nil)

local calls, removes, reg = {}, {}, {}
SGGateTypes = { chainlink = { width = 2 }, chainlink4 = { width = 4 } }
SGGate = {
    build = function(sq, typeId, level, ori, dir, quality)
        local id = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
        calls[#calls + 1] = { id = id, typeId = typeId, level = level, ori = ori, dir = dir, quality = quality }
        reg[id] = { width = (SGGateTypes[typeId] or {}).width }
        return id
    end,
    registry = function() return reg end,
    remove = function(id) removes[#removes + 1] = id; reg[id] = nil end,
}

check("ready with mod", SlideGate.ready() == true)
check("width 2 for chainlink", SlideGate.width() == 2)

fence.status = "active"
check("not-done fence: no build", SlideGate.sync(camp) == 0 and #calls == 0, #calls)
fence.status = "done"

camp.raid = {}
SlideGate.onMinute(camp)
check("raid: no build via hook", #calls == 0, #calls)
camp.raid = nil

local made = SlideGate.sync(camp)
check("built both gates", made == 2, made)
check("two build calls", #calls == 2, #calls)

local byId = {}
for _, c in ipairs(calls) do byId[c.id] = c end
local bn = byId["110,100,0"]
check("N gate at catcher cell", bn ~= nil)
check("N gate typeId chainlink", bn ~= nil and bn.typeId == "chainlink")
check("N gate orientation N", bn ~= nil and bn.ori == "N")
check("N gate direction forward", bn ~= nil and bn.dir == "forward")
check("N gate level 8", bn ~= nil and bn.level == 8)
check("N gate quality high", bn ~= nil and bn.quality == "high")
check("N gate width 2 recorded", reg["110,100,0"] ~= nil and reg["110,100,0"].width == 2)
local be = byId["120,106,0"]
check("E gate at catcher cell", be ~= nil)
check("E gate orientation W", be ~= nil and be.ori == "W")
check("E gate direction forward", be ~= nil and be.dir == "forward")

local again = SlideGate.sync(camp)
check("idempotent: no new builds", again == 0 and #calls == 2, #calls)

camp.slideGates = {}
SlideGate.sync(camp)
check("registry dedup: no rebuild", #calls == 2, #calls)
check("state repopulated from registry", SlideGate.count(camp) == 2, SlideGate.count(camp))

fence.retired = true
SlideGate.sync(camp)
check("retired: gates removed", #removes == 2, #removes)
check("retired: state cleared", SlideGate.count(camp) == 0, SlideGate.count(camp))
check("retired: registry empty", (function() local k = 0 for _ in pairs(reg) do k = k + 1 end return k end)() == 0)
check("retired: no extra builds", #calls == 2, #calls)

fence.retired = nil
local re = SlideGate.sync(camp)
check("rebuild after un-retire", re == 2 and #calls == 4, #calls)

local want = A.T("SlideGate_overview", tostring(SlideGate.count(camp)))
check("overview text resolved", want ~= "UI_ALC_SlideGate_overview" and #want > 0, want)
local ov = A.Hooks.overview(camp)
local foundOv = false
for _, line in ipairs(ov) do if line.text == want then foundOv = true end end
check("overview line present", foundOv)

local okState = true
for k, v in pairs(camp.slideGates) do
    if type(k) ~= "string" or type(v) ~= "string" then okState = false end
end
check("state strings only", okState)

SlideGate.typeId = "chainlink4"
check("width 4 for chainlink4", SlideGate.width() == 4)
SlideGate.typeId = "chainlink"

MISSING.UI_ALC_Opt_uiRing = nil
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
