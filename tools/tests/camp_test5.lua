dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Camp, Stock, Build, Plan, Bp, Settlers, Work, Site = A.Store, A.Geo, A.Camp, A.Stock, A.Build, A.Plan, A.Blueprints, A.Settlers, A.Work, A.Site
local reg = MOCKALIFE()

for x = 30, 160 do for y = 30, 160 do NEWSQUARE(x, y, 0) end end
for x = 30, 160 do for y = 30, 160 do NEWSQUARE(x, y, 1) end end
PLAYER = NEWPLAYER(0)
HOURS = 300

check("module loaded", Site ~= nil)
check("class small", Site.class({ kind = "house_s", w = 4, h = 4 }) == "small")
check("class shed small", Site.class({ kind = "shed", w = 4, h = 3 }) == "small")
check("class medium", Site.class({ kind = "house_m", w = 6, h = 5 }) == "medium")
check("class large", Site.class({ kind = "house_l", w = 8, h = 6 }) == "large")
check("class tower", Site.class({ kind = "tower", w = 2, h = 2 }) == "tower")
check("class farm", Site.class({ kind = "farm", w = 5, h = 4 }) == "farm")
check("no site for fence", Site.class({ kind = "fence", w = 20, h = 20 }) == nil)
check("no site for campfire", Site.class({ kind = "campfire", w = 3, h = 3 }) == nil)
check("sets grow with size", #Site.sets.small < #Site.sets.medium and #Site.sets.medium < #Site.sets.large)

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 100, y2 = 90, z = 0 }, "Площадка")
camp.phase = "plan"
local box = Stock.crate(camp, camp.storage[1]):getContainer()
for _ = 1, 1500 do box:AddItem("Base.Plank") end
for _ = 1, 2500 do box:AddItem("Base.Nails") end
for _ = 1, 100 do box:AddItem("Base.Log") end
for _ = 1, 100 do box:AddItem("Base.Rope") end
for _ = 1, 100 do box:AddItem("Base.ScrapMetal") end
for _ = 1, 400 do local f = NEWITEM("Base.Canned", 1000) f.container = box table.insert(box.items, f) end
Stock.refresh(camp)

local small = Build.add(camp, "house_s", 64, 64, { door = "S" })
local medium = Build.add(camp, "house_m", 74, 64, { door = "S" })
local large = Build.add(camp, "house_l", 86, 64, { door = "S" })
local tower = Build.add(camp, "tower", 64, 80, {})
local farm = Build.add(camp, "farm", 74, 78, {})
local fence = Build.add(camp, "fence", camp.x1, camp.y1, { w = Geo.width(camp), h = Geo.height(camp), gate = "S" })
check("projects added", small and medium and large and tower and farm and fence)

local function siteObjects(project)
    local n, kinds = 0, {}
    for x = camp.x1, camp.x2 do
        for y = camp.y1, camp.y2 do
            local square = A.World.square(x, y, 0)
            for i = 0, square:getObjects():size() - 1 do
                local tag = A.World.tag(square:getObjects():get(i))
                if tag and tag.kind == "site" and tag.project == project.id then
                    n = n + 1
                    kinds[#kinds + 1] = x .. "," .. y
                end
            end
        end
    end
    return n, kinds
end

check("small placed", Site.place(camp, small) == 2)
check("medium placed", Site.place(camp, medium) == 5)
check("large placed", Site.place(camp, large) == 10)
check("tower placed", Site.place(camp, tower) == 3)
check("farm placed", Site.place(camp, farm) == 2)
check("fence gets nothing", Site.place(camp, fence) == 0 and fence.site ~= nil)
check("place is once", Site.place(camp, small) == 0)
check("small objects", (siteObjects(small)) == 2)
check("medium objects", (siteObjects(medium)) == 5)
check("large objects", (siteObjects(large)) == 10)

local function insideAny(x, y, except)
    for _, p in ipairs(Build.list(camp)) do
        if p.kind ~= "fence" and p ~= except then
            local r = Bp.footprint(p)
            if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then return true end
        end
    end
    return false
end
local bad = 0
for _, p in ipairs({ small, medium, large, tower, farm }) do
    for _, e in ipairs(p.site) do
        local r = Bp.footprint(p)
        local own = e.x >= r.x1 and e.x <= r.x2 and e.y >= r.y1 and e.y <= r.y2
        if own or insideAny(e.x, e.y, p) or not Geo.contains(camp, e.x, e.y) then bad = bad + 1 end
    end
end
check("props stay outside footprints and inside camp", bad == 0, bad)

local seen, dup = {}, 0
for _, p in ipairs({ small, medium, large, tower, farm }) do
    for _, e in ipairs(p.site) do
        local key = e.x .. "," .. e.y
        if seen[key] then dup = dup + 1 end
        seen[key] = true
    end
end
check("no shared squares", dup == 0, dup)

local doorSide = 0
for _, e in ipairs(medium.site) do
    local r = Bp.footprint(medium)
    if e.y > r.y2 and e.x >= r.x1 and e.x <= r.x2 then doorSide = doorSide + 1 end
end
check("door side stays mostly free", doorSide <= 1, doorSide)

local removed = Site.clear(camp, medium)
check("clear removes", removed == 5 and medium.site == nil and (siteObjects(medium)) == 0, removed)
check("replace after clear", Site.place(camp, medium) == 5)
Build.remove(camp, medium.id)
check("remove clears props", (siteObjects(medium)) == 0)

large.status = "done"
check("sweep clears done", Site.sweep(camp) == 10 and large.site == nil and (siteObjects(large)) == 0)
check("done project not replaced", Site.place(camp, large) == 0)

local reg2 = reg
ADDACTOR(reg, "alice", "friendly", 70, 70, A.World.square(70, 70, 0))
ADDACTOR(reg, "bob", "friendly", 71, 70, A.World.square(71, 70, 0))
Settlers.settle(camp, "alice", "Alice")
Settlers.settle(camp, "bob", "Bob")
camp.settlers.alice.role = "builder"
camp.settlers.bob.role = "builder"
Build.remove(camp, small.id)
Build.remove(camp, tower.id)
Build.remove(camp, farm.id)
local fresh = Build.add(camp, "house_s", 66, 66, { door = "S" })
for _ = 1, 3 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("started project got its site", fresh.site ~= nil and #fresh.site == 2, fresh.site and #fresh.site)
check("site objects exist", (siteObjects(fresh)) == 2)
local guard = 0
repeat
    for _ = 1, 100 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
    guard = guard + 1
until fresh.status == "done" or guard > 40
check("house finished", fresh.status == "done", fresh.status .. "/" .. fresh.stage)
for _ = 1, 3 do HOURS = HOURS + 1 / 60 fire("EveryOneMinute") end
check("site removed after finish", (siteObjects(fresh)) == 0 and fresh.site == nil)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
