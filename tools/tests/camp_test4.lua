dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Work, Stats, Expand =
    A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Work, A.Stats, A.Expand
local reg, orders = MOCKALIFE()

for x = 30, 160 do for y = 30, 160 do NEWSQUARE(x, y, 0) end end
for x = 30, 160 do for y = 30, 160 do NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 91, y2 = 85, z = 0 }, "Рост")
camp.options.recruit = false
camp.phase = "plan"
local crate = Stock.crate(camp, camp.storage[1])
local box = crate:getContainer()
for _ = 1, 6000 do box:AddItem("Base.Plank") end
for _ = 1, 2500 do box:AddItem("Base.Nails") end
for _ = 1, 10 do box:AddItem("Base.Log") end
for _ = 1, 200 do box:AddItem("Base.ScrapMetal") end
for _ = 1, 200 do box:AddItem("Base.Rope") end
for _ = 1, 700 do local f = NEWITEM("Base.Canned", 1000) f.container = box table.insert(box.items, f) end
Stock.refresh(camp)

local names = { "alice", "bob", "cara", "dave", "eve", "finn" }
local roles = { "builder", "builder", "builder", "guard", "farmer", "farmer" }
for i, uid in ipairs(names) do
    ADDACTOR(reg, uid, "friendly", 70 + i, 70, A.World.square(70 + i, 70, 0))
    Settlers.settle(camp, uid, uid)
    camp.settlers[uid].role = roles[i]
end

check("generate", Plan.generate(camp) >= 4)
local function tick(n)
    for _ = 1, n do
        HOURS = HOURS + 1 / 60
        fire("EveryOneMinute")
    end
end

local guard = 0
local t0 = os.clock()
repeat
    tick(300)
    guard = guard + 1
    local open = 0
    for _, p in ipairs(Build.list(camp)) do if p.status ~= "done" then open = open + 1 end end
until open == 0 or guard > 40
local open = {}
for _, p in ipairs(Build.list(camp)) do
    if p.status ~= "done" then
        local miss = {}
        for k, v in pairs(Build.needs(camp, p)) do miss[#miss + 1] = k .. "=" .. v end
        open[#open + 1] = p.kind .. ":" .. p.status .. ":" .. p.stage .. (p.waiting and ":wait" or "") .. "[" .. table.concat(miss, ",") .. "]"
    end
end
check("all projects built", #open == 0, table.concat(open, ",") .. " stock logs=" .. tostring(camp.stock.logs) .. " rope=" .. tostring(camp.stock.rope) .. " metal=" .. tostring(camp.stock.metal) .. " nails=" .. tostring(camp.stock.nails) .. " planks=" .. tostring(camp.stock.planks))
check("phase plan", camp.phase == "plan", camp.phase)

camp.options.expand = false
tick(1600)
camp.options.expand = nil
local stats = Stats.compute(camp)
check("people", stats.people == 6, stats.people)
check("houses counted", stats.counts.houses >= 1, stats.counts.houses)
check("fence length", stats.fence > 100, stats.fence)
check("capacity", stats.capacity >= 4, stats.capacity)
check("defense positive", stats.defense > 20, stats.defense)
check("level >= 2", stats.level >= 2, stats.level)
check("morale range", stats.morale >= 0 and stats.morale <= 100, stats.morale)
check("next key", Stats.nextLevelKey(1) == "Next_2" and Stats.nextLevelKey(4) == "Next_5")

check("harvested something", camp.stats.harvested > 0, camp.stats.harvested)
Stock.refresh(camp)
check("camp level synced", (camp.level or 1) == stats.level, tostring(camp.level) .. "/" .. stats.level)

local gate = Work.gate(camp)
check("gate inside", Geo.contains(camp, gate.x, gate.y), gate.x .. "," .. gate.y)
local posts = Work.posts(camp)
check("posts include gate", #posts >= 1)

local oldRect = { x1 = camp.x1, y1 = camp.y1, x2 = camp.x2, y2 = camp.y2 }
local oldFence
for _, p in ipairs(Build.list(camp)) do if p.kind == "fence" then oldFence = p end end
check("old fence found", oldFence ~= nil and oldFence.status == "done")
local fenceSquare = A.World.square(oldRect.x2 + 1, 70, 0)
local function tagged(square, projectId)
    local n = 0
    for i = 0, square:getObjects():size() - 1 do
        local tag = A.World.tag(square:getObjects():get(i))
        if tag and tag.project == projectId then n = n + 1 end
    end
    return n
end
check("fence piece on east edge", tagged(fenceSquare, oldFence.id) >= 1, tagged(fenceSquare, oldFence.id))

local side, score = Expand.best(camp)
check("best side exists", side ~= nil, tostring(side))
local ok, why = Expand.request(camp, "E")
check("expand accepted", ok == true, tostring(why))
check("rect grew east", camp.x2 == oldRect.x2 + Expand.step and camp.x1 == oldRect.x1, camp.x2)
check("phase clear", camp.phase == "clear", camp.phase)
check("old fence retired", oldFence.retired == true and camp.retiredFence == oldFence.id)
check("expansions counted", camp.expansions == 1)

local houseBefore = Stats.counts(camp).houses
local strip = camp.expand.strip
local junk = A.World.square(strip.x1 + 2, strip.y1 + 3, 0)
NEWOBJ(junk, "IsoObject", "vegetation_foliage_01_1")
NEWWORLDITEM(junk, "Base.Plank")
local guard2 = 0
repeat
    tick(60)
    guard2 = guard2 + 1
until camp.phase ~= "clear" or guard2 > 120
check("clearing strip finished", camp.phase ~= "clear", camp.phase .. " after " .. guard2 * 60)
check("expansion state cleared", camp.expand == nil)
check("strip cleaned", #junk.wobjects == 0, #junk.wobjects)
local fresh
for _, p in ipairs(Build.list(camp)) do if p.kind == "fence" and not p.retired then fresh = p end end
check("new fence project", fresh ~= nil and fresh.w == Geo.width(camp), fresh and fresh.w)
local adopted = 0
for _ in pairs(fresh.done) do adopted = adopted + 1 end
check("adopted old fence pieces", adopted > 50, adopted)
check("adopted pieces retagged", tagged(A.World.square(oldRect.x1 - 1 + 1, 70, 0), fresh.id) >= 1 or tagged(A.World.square(oldRect.x1, 70, 0), fresh.id) >= 1)

local guard3 = 0
repeat
    tick(300)
    guard3 = guard3 + 1
    local pending = 0
    for _, p in ipairs(Build.list(camp)) do if p.status ~= "done" then pending = pending + 1 end end
until (pending == 0 and camp.retiredFence == nil) or guard3 > 40
check("old fence removed from plan", Build.get(camp, oldFence.id) == nil)
check("old east fence piece gone", tagged(fenceSquare, oldFence.id) == 0, tagged(fenceSquare, oldFence.id))
local newEast = A.World.square(camp.x2 + 1, 70, 0)
check("new east fence piece", tagged(newEast, fresh.id) >= 1 or fresh.status == "done", fresh.status)
check("fence done after expansion", fresh.status == "done", fresh.status .. "/" .. fresh.stage)
check("more projects after expansion", Stats.counts(camp).houses >= houseBefore)

RAIDS = {}
ALifeRU = { Events = {
    start = function(id, opts) RAIDS[#RAIDS + 1] = { id = id, site = opts.site, force = opts.force } return {} end,
    isEnabled = function() return true end,
} }
camp.level = 2
camp.nextRaid = 0
print("DBG", camp.level, camp.nextRaid, Store.hours(), tostring(camp.raid), tostring(camp.options.raids), Store.settlerCount(camp), tostring(ALifeRU), tostring(Work.raidEvents()))
tick(2)
print("DBG2", camp.level, camp.nextRaid, tostring(camp.raid), #RAIDS)
check("raid started", #RAIDS == 1 and RAIDS[1].id == "raid_town" and RAIDS[1].force == true, #RAIDS)
check("raid site is gate", RAIDS[1] ~= nil and Geo.contains(camp, RAIDS[1].site.x, RAIDS[1].site.y))
check("raid recorded", camp.raid ~= nil and camp.stats.raids == 1)
tick(40)
check("raid still running", camp.raid ~= nil)
local before = Store.settlerCount(camp)
for _ = 1, 4 do tick(60) end
check("raid ended repelled", camp.raid == nil and (camp.stats.repelled or 0) == 1, tostring(camp.stats.repelled))
check("next raid scheduled later", camp.nextRaid > Store.hours())

camp.options.raids = false
camp.nextRaid = 0
camp.raid = nil
tick(2)
check("raids option respected", #RAIDS == 1, #RAIDS)
camp.options.raids = nil

camp.nextRaid = 0
tick(2)
check("second raid", #RAIDS == 2, #RAIDS)
camp.settlers.finn = nil
for _ = 1, 4 do tick(60) end
check("raid with losses logged", camp.raid == nil)
local lost = false
for _, e in ipairs(camp.log) do if e.k == "raidlost" then lost = true end end
check("raid loss entry", lost)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
