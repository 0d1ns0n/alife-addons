dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Geo, Flags, Camp, Stock, Land = A.Store, A.Geo, A.Flags, A.Camp, A.Stock, A.Land

for x = 90, 140 do for y = 90, 140 do NEWSQUARE(x, y, 0) end end

PLAYER = NEWPLAYER(0)
check("no camps", Store.count() == 0)
check("kit given", Flags.give(PLAYER) == 4 and Flags.have(PLAYER) == 4)
check("kit not doubled", Flags.give(PLAYER) == 0)

local sq1 = A.World.square(100, 100, 0)
check("check ok", Flags.check(PLAYER, sq1) == true)
check("place 1", Flags.commitPlace(PLAYER, 100, 100, 0) == true)
check("flag object", A.World.find(sq1, "flag", nil) ~= nil)
check("flags left", Flags.have(PLAYER) == 3 and Flags.placed() == 1)
check("same spot refused", Flags.check(PLAYER, sq1) == false)

check("place 2", Flags.commitPlace(PLAYER, 115, 100, 0))
check("place 3", Flags.commitPlace(PLAYER, 115, 112, 0))
check("markers exist", #MARKERS > 0, #MARKERS)
NEWTREE(A.World.square(105, 105, 0))
NEWTREE(A.World.square(106, 105, 0))
A.World.square(110, 108, 0).building = { id = 1 }
check("no dialog yet", #UIPOP == 0)
check("place 4", Flags.commitPlace(PLAYER, 100, 112, 0))
check("all flags used", Flags.have(PLAYER) == 0 and Flags.placed() == 4)
check("dialog asked", #UIPOP == 1 and UIPOP[1].yesno == true, UIPOP[1] and UIPOP[1].text)
check("dialog text has size", UIPOP[1].text:find("16") ~= nil and UIPOP[1].text:find("13") ~= nil, UIPOP[1].text)

local rect = Flags.rect()
check("rect", rect.x1 == 100 and rect.x2 == 115 and rect.y1 == 100 and rect.y2 == 112)
local survey = Land.survey(rect)
check("survey trees", survey.tree == 2, survey.tree)
check("survey building", survey.buildings == 1, survey.buildings)

UIPOP[1].onclick(nil, { internal = "NO" })
check("no answer no box", #UIPOP == 1)
UIPOP[1].onclick(nil, { internal = "YES" })
check("name box", #UIPOP == 2 and UIPOP[2].default ~= nil, UIPOP[2] and UIPOP[2].default)
UIPOP[2].onclick(nil, { internal = "OK", parent = { entry = { getText = function() return "Мой лагерь" end } } })
check("demolish dialog", #UIPOP == 3 and UIPOP[3].yesno == true, UIPOP[3] and UIPOP[3].text)
UIPOP[3].onclick(nil, { internal = "YES" })

check("camp created", Store.count() == 1)
local camp = Store.list()[1]
check("camp name", camp.name == "Мой лагерь", camp.name)
check("camp phase", camp.phase == "clear")
check("camp demolish", camp.options.demolish == true)
check("camp rect", camp.x1 == 100 and camp.y2 == 112)
check("one bottomless storage crate", #camp.storage == 1, #camp.storage)
local cx, cy = Geo.center(camp)
local crate = Stock.crate(camp, camp.storage[1])
check("crate object", crate ~= nil and crate:getContainer() ~= nil)
check("pending cleared", Flags.placed() == 0)
local corner = A.World.find(A.World.square(100, 100, 0), "flag", nil)
local tag = A.World.tag(corner)
check("corner tagged", tag ~= nil and tag.camp == camp.id and tag.corner == true)
check("flags not pending anymore", tag.pending == nil)

local cont = crate:getContainer()
cont:AddItem("Base.Plank") cont:AddItem("Base.Plank") cont:AddItem("Base.Nails")
local food = NEWITEM("Base.TinnedBeans", 600)
food.container = cont table.insert(cont.items, food)
Stock.refresh(camp)
check("stock planks", camp.stock.planks == 2, camp.stock.planks)
check("stock nails", camp.stock.nails == 1)
check("stock food", camp.stock.food == 600, camp.stock.food)
check("take planks", Stock.take(camp, "planks", 1) == 1)
Stock.refresh(camp)
check("stock after take", camp.stock.planks == 1)
check("give", Stock.give(camp, "Base.Log", 3) == true)
Stock.refresh(camp)
check("stock logs", camp.stock.logs == 3, camp.stock.logs)

check("inside refused", Flags.check(NEWPLAYER(1), A.World.square(105, 105, 0)) == false)
check("overlap refused", select(1, Camp.check({ x1 = 110, y1 = 105, x2 = 125, y2 = 115, z = 0 })) == false)
check("far ok", Camp.check({ x1 = 120, y1 = 100, x2 = 135, y2 = 115, z = 0 }) == true)
check("too small", select(2, Camp.check({ x1 = 120, y1 = 100, x2 = 123, y2 = 103, z = 0 })) == "small")

HOURS = 100 + 30
fire("EveryOneMinute")
check("director days", camp.stats.days == 1, camp.stats.days)
fire("OnGameStart")

A.Markers.refresh(PLAYER, true)
check("camp border markers", #MARKERS > 0)

local p2 = NEWPLAYER(1)
PLAYER = p2
check("flag cancel flow", Flags.commitPlace(p2, 125, 100, 0))
Flags.cancel(p2)
check("cancel returns flag", Flags.have(p2) == 1 and Flags.placed() == 0)

check("camp at", Store.campAt(105, 105, 0) == camp and Store.campAt(130, 130, 0) == nil)
check("rename", Camp.rename(camp, "Тест") and camp.name == "Тест")
check("abandon", Camp.abandon(camp) and Store.count() == 0)

local missing = {}
for k in pairs(MISSING) do missing[#missing + 1] = k end
table.sort(missing)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missing }
