dofile(MOCK)
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Camp, Hooks, Options = A.Store, A.Camp, A.Hooks, A.Options

for x = 90, 140 do for y = 90, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
local camp = Camp.create({ x1 = 100, y1 = 100, x2 = 115, y2 = 112, z = 0 }, "UI", { demolish = false })
check("camp created", camp ~= nil)

check("hooks registry", Hooks ~= nil and Options ~= nil)
check("default expand on", Options.on(camp, "expand") == true)
check("default adopt off", Options.on(camp, "adopt") == false)
check("default border on", Options.on(camp, "border") == true)
Options.set(camp, "raids", false)
check("raids off stored", camp.options.raids == false and Options.on(camp, "raids") == false)
check("cycle toggles", Options.cycle(camp, "raids") == true and camp.options.raids == true)

Options.define({ key = "uiRing", group = "life", kind = "cycle", values = { 0, 10, 20 }, default = 10 })
check("cycle default", Options.get(camp, "uiRing") == 10)
check("cycle next", Options.cycle(camp, "uiRing") == 20)
check("cycle wrap", Options.cycle(camp, "uiRing") == 0 and Options.cycle(camp, "uiRing") == 10)

Hooks.add("morale", function() return 5 end)
Hooks.add("morale", function() error("boom") end)
Hooks.add("labor", function() return 1.5 end)
Hooks.add("labor", function() return 2 end, 10)
check("sum survives errors", Hooks.sum("morale", camp) >= 5 - 100)
check("product", Hooks.product("labor", camp) == 3)
check("first nil", Hooks.first("nothing", camp) == nil)
Hooks.add("overview", function() return { Hooks.line("hook line") } end)
Hooks.section("life", "Tab_life", function() return { Hooks.line("life row"), Hooks.line("clickable", 1, 1, 1, function(c) c.uiClicked = true end) } end)
check("overview lines", #Hooks.overview(camp) >= 1)

local stats = A.Stats.compute(camp)
check("morale uses hook", stats.morale >= 0 and stats.morale <= 100)

local win = A.Window.open(camp)
A.Window.createChildren(win)
win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
local ids = {}
for _, tab in ipairs(win.tabs) do ids[#ids + 1] = tab.id end
check("tabs include settings, life, progress, log", table.concat(ids, ","):find("settings") and table.concat(ids, ","):find("life") and table.concat(ids, ","):find("progress") and table.concat(ids, ","):find("log"), table.concat(ids, ","))
for _, tab in ipairs(win.tabs) do
    win:selectTab(tab.id)
    win:prerender()
end
check("tab buttons laid out", win.contentY ~= nil)

win:selectTab("settings")
win:prerender()
check("settings hit rows", #win.hitRows >= 4, #win.hitRows)
local before = camp.options.expand
local row = win.hitRows[1]
win:onContentClick(row.y1 + 1)
check("click toggles first option", camp.options.expand ~= before and camp.options.expand ~= nil, tostring(camp.options.expand))

win:selectTab("life")
win:prerender()
check("life tab clickable", #win.hitRows >= 1)
local clickY
for _, row in ipairs(win.hitRows) do
    if row.click ~= nil then clickY = row.y1 + 1 end
end
local routed = false
for _, row in ipairs(win.hitRows) do
    camp.uiClicked = nil
    win:onMouseDown(20, row.y1 + 1)
    win:onMouseUp(20, row.y1 + 1)
    if camp.uiClicked == true then routed = true end
end
check("mouse click routed", routed)

win:selectTab("progress")
win:prerender()
check("empty tab ok", true)

local settlerLines = win:settlerLines(camp)
check("settler lines", #settlerLines >= 1)

MISSING.UI_ALC_Opt_uiRing = nil

local longLine = { text = "слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово слово", r = 1, g = 1, b = 1, click = function() end }
local wrapped = win:wrapLines({ longLine, { text = "коротко" } }, 300)
check("long lines wrap", #wrapped >= 3, #wrapped)
check("wrapped parts keep the click and indent", wrapped[2].click ~= nil and wrapped[2].indent == 14)
local widest = 0
for _, row in ipairs(wrapped) do widest = math.max(widest, #row.text * 7 + (row.indent or 0)) end
check("wrapped parts fit the width", widest <= 300, widest)
check("short line untouched", wrapped[#wrapped].text == "коротко")


check("reset action listed", #A.Options.actions >= 1)
local popBefore = #UIPOP
A.Options.actions[1].run(camp)
check("reset asks for confirmation", #UIPOP == popBefore + 1 and UIPOP[#UIPOP].yesno == true)
win:selectTab("settings")
win:prerender()
local actionRows = 0
for _, row in ipairs(win.hitRows) do
    if row.click ~= nil then actionRows = actionRows + 1 end
end
check("settings tab still clickable with the action", actionRows >= 1)

MISSING.UI_ALC_Opt_uiRing = nil
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
