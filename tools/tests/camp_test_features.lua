dofile(MOCK)
SKIPMOD["shared/ALifeCamp/CampSanitary.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHealth.lua"] = true
SKIPMOD["shared/ALifeCamp/CampLife.lua"] = true
SKIPMOD["shared/ALifeCamp/CampProgress.lua"] = true
SKIPMOD["shared/ALifeCamp/CampCouncil.lua"] = true
SKIPMOD["shared/ALifeCamp/CampDuty.lua"] = true
SKIPMOD["shared/ALifeCamp/CampHouses.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings2.lua"] = true
SKIPMOD["shared/ALifeCamp/CampBuildings3.lua"] = true
SKIPMOD["shared/ALifeCamp/CampScenery.lua"] = true
SKIPMOD["shared/ALifeCamp/CampShells.lua"] = true
SKIPMOD["shared/ALifeCamp/CampTowers.lua"] = true
SKIPMOD["shared/ALifeCamp/CampPerimeter.lua"] = true
SKIPMOD["shared/ALifeCamp/CampFortress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsSanitary.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsHealth.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsLife.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsProgress.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsCouncil.lua"] = true
SKIPMOD["@addon/shared/ALifeCampCheats/CheatsFortress.lua"] = true
LOADMOD(ROOT)

local A = ALifeCamp
local Store, Options, Features = A.Store, A.Options, A.Features

local function cleanText(text)
    return type(text) == "string" and text ~= "" and not text:find("%%%d") and not text:find("nil") and not text:find("UI_ALC_")
end

local function sealed(value, path, seen, problems)
    local kind = type(value)
    if kind == "function" or kind == "userdata" or kind == "thread" then
        problems[#problems + 1] = path .. ":" .. kind
        return
    end
    if kind ~= "table" then return end
    if seen[value] then
        problems[#problems + 1] = path .. ":cycle"
        return
    end
    seen[value] = true
    local count, max = 0, 0
    for key, item in pairs(value) do
        local keyKind = type(key)
        if keyKind == "number" then
            if key ~= math.floor(key) or key < 1 then problems[#problems + 1] = path .. ":badkey" end
            count = count + 1
            if key > max then max = key end
        elseif keyKind ~= "string" then
            problems[#problems + 1] = path .. ":keytype"
        end
        sealed(item, path .. "." .. tostring(key), seen, problems)
    end
    if count ~= max then problems[#problems + 1] = path .. ":holes" end
    seen[value] = nil
end

local function findLine(lines, text)
    for _, line in ipairs(lines) do
        if line.text == text then return line end
    end
    return nil
end

for x = 90, 140 do for y = 90, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)

check("module present", Features ~= nil and type(Features) == "table")
check("api present", type(Features.define) == "function" and type(Features.on) == "function" and type(Features.set) == "function"
    and type(Features.get) == "function" and type(Features.toggle) == "function" and type(Features.list) == "function")
check("options wrapped for modules section", Options.alcFeaturesWrapped == true)

check("outposts seeded", Features.byKey.outposts ~= nil and Features.byKey.outposts.default == false)
check("outposts off by default", Features.on("outposts") == false)
check("get without camp works", Features.get("outposts") == false)

local defaultsOff = true
for _, entry in ipairs(Features.list()) do
    if entry.default ~= false or entry.on ~= false then defaultsOff = false end
end
check("every feature defaults off", defaultsOff)

local camp = A.Camp.create({ x1 = 100, y1 = 100, x2 = 115, y2 = 112, z = 0 }, "Feat")
check("camp created", camp ~= nil)

local onText = A.T("OptRow", A.T("Feat_outposts"), A.T("OptOn"))
local offText = A.T("OptRow", A.T("Feat_outposts"), A.T("OptOff"))

local settings = Options.lines(camp)
check("modules section header present", findLine(settings, A.T("FeatSection")) ~= nil)
local row = findLine(settings, offText)
check("outposts row shown off", row ~= nil and type(row.click) == "function")

local optionsBefore = {}
for k, v in pairs(camp.options) do optionsBefore[k] = v end
row.click(camp)
check("click enables global feature", Features.on("outposts") == true)
check("click left camp options untouched", camp.options.outposts == nil)
local unchanged = true
for k, v in pairs(optionsBefore) do if camp.options[k] ~= v then unchanged = false end end
for k in pairs(camp.options) do if optionsBefore[k] == nil then unchanged = false end end
check("camp options identical after feature click", unchanged)
check("stored in global modata", Store.data().features.outposts == true)

local settings2 = Options.lines(camp)
check("row now shows on", findLine(settings2, onText) ~= nil and findLine(settings2, offText) == nil)
local rowOn = findLine(settings2, onText)
rowOn.click(camp)
check("second click disables", Features.on("outposts") == false and Store.data().features.outposts == false)

for _, line in ipairs(Options.lines(camp)) do
    check("settings line clean", line.text == "" or cleanText(line.text), line.text)
end

local calls = {}
Features.define({ key = "testA", name = "Feat_outposts", desc = "FeatHint_outposts", default = false, after = function(v) calls[#calls + 1] = v end })
check("define returns off default", Features.on("testA") == false)
check("define stores nothing until set", Store.data().features.testA == nil)
Features.set("testA", true)
check("set turns on", Features.on("testA") == true and Store.data().features.testA == true)
check("after fired with true", #calls == 1 and calls[1] == true)
Features.toggle("testA")
check("toggle turns off", Features.on("testA") == false and Store.data().features.testA == false)
check("after fired with false", #calls == 2 and calls[2] == false)
Features.set("testA", false)
check("set calls after each time", #calls == 3 and calls[3] == false)
Features.set("testA", true)
check("after fires with new value", #calls == 4 and calls[4] == true and Features.on("testA") == true)

Features.define({ key = "testDefaultOn", name = "Feat_outposts", desc = "FeatHint_outposts", default = true })
check("default true honored before any write", Features.on("testDefaultOn") == true and Store.data().features.testDefaultOn == nil)

Features.set("persist", true)
check("set without spec still stores", Store.data().features.persist == true and Features.on("persist") == true)
Features.define({ key = "persist", name = "Feat_outposts", desc = "FeatHint_outposts", default = false })
check("stored value overrides default on reload", Features.on("persist") == true)

local camp2 = A.Camp.create({ x1 = 120, y1 = 100, x2 = 135, y2 = 112, z = 0 }, "Feat2")
Features.set("outposts", true)
check("feature is world global across camps", Features.on("outposts") == true)
check("second camp sees same feature", Features.on("outposts") == true and camp.options.outposts == nil and camp2.options.outposts == nil)
Features.set("outposts", false)

local list = Features.list()
check("list shape", #list >= 1 and type(list[1].key) == "string" and type(list[1].name) == "string" and type(list[1].desc) == "string" and type(list[1].on) == "boolean" and type(list[1].default) == "boolean")

local problems = {}
sealed(Store.data().features, "features", {}, problems)
check("global feature store is plain data", #problems == 0, table.concat(problems, ","))

local savedSpecs, savedByKey = Features.specs, Features.byKey
Features.specs, Features.byKey = {}, {}
check("no features defined yields no lines", #Features.lines() == 0)
local bare = Options.lines(camp)
check("no modules section when nothing defined", findLine(bare, A.T("FeatSection")) == nil)
Features.specs, Features.byKey = savedSpecs, savedByKey
check("registry restored", Features.byKey.outposts ~= nil)

local win = A.Window.open(camp)
A.Window.createChildren(win)
win.survey = { tree = 0, plant = 0, junk = 0, item = 0, corpse = 0, structure = 0, furniture = 0, buildings = 0, vehicles = 0, loaded = 1, total = 1 }
local okRender = pcall(function() win:selectTab("settings") win:prerender() end)
check("settings tab renders with modules", okRender and win.contentY ~= nil)

check("texts present", A.TN("FeatSection") ~= nil and A.TN("Feat_outposts") ~= nil and A.TN("FeatHint_outposts") ~= nil)

local traceSeen = false
for i = 1, #PRINTS do if PRINTS[i]:find("[ALifeCamp:Features]", 1, true) then traceSeen = true end end
check("toggle writes a trace line", traceSeen)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
