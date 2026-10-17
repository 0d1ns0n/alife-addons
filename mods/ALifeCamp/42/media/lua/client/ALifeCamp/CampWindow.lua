require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampLand"
require "ALifeCamp/Camp"
require "ALifeCamp/CampFlags"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampStats"
require "ALifeCamp/CampExpand"
require "ALifeCamp/CampAdopt"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampReset"
require "ALifeCamp/CampPlanner"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Land = ALifeCamp.Land
local Camp = ALifeCamp.Camp
local Flags = ALifeCamp.Flags
local Build = ALifeCamp.Build
local Stats = ALifeCamp.Stats
local Expand = ALifeCamp.Expand
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Window = ISCollapsableWindow:derive("ALCWindow")
Window.__index = Window
Window.instance = nil
Window.tabIds = { "overview", "adopt", "build", "settlers" }
Window.tailTabs = { "log", "settings" }

function Window.tabList()
    local list = {}
    local early, late = {}, {}
    for _, tab in ipairs(Hooks.tabs) do
        if (tab.priority or 50) < 20 then
            early[#early + 1] = tab
        else
            late[#late + 1] = tab
        end
    end
    for index, id in ipairs(Window.tabIds) do
        list[#list + 1] = { id = id, title = "Tab_" .. id }
        if index == 1 then
            for _, tab in ipairs(early) do list[#list + 1] = { id = tab.id, title = tab.title, hook = tab } end
        end
    end
    for _, tab in ipairs(late) do list[#list + 1] = { id = tab.id, title = tab.title, hook = tab } end
    for _, id in ipairs(Window.tailTabs) do list[#list + 1] = { id = id, title = "Tab_" .. id } end
    return list
end

Window.adoptColors = {
    queued = { 0.7, 0.75, 0.85 }, salvage = { 0.95, 0.75, 0.4 }, fortify = { 0.95, 0.6, 0.45 },
    fitout = { 0.7, 0.85, 0.5 }, done = { 0.6, 0.9, 0.7 },
}
Window.adoptOrder = { salvage = 1, fortify = 2, fitout = 3, queued = 4, done = 5 }
Window.current = "overview"
ALifeCamp.Window = Window

local FONT = UIFont.Small

local function fh()
    return getTextManager():getFontHeight(FONT)
end

local function textWidth(text)
    return getTextManager():MeasureStringX(FONT, text)
end

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return 0
end

function Window:camp()
    local camp = Store.get(self.campId)
    if camp == nil then
        local list = Store.list()
        camp = list[1]
        self.campId = camp ~= nil and camp.id or nil
    end
    return camp
end

function Window:button(label, fn)
    local b = ISButton:new(0, 0, 10, 10, label, self, fn)
    b:initialise()
    b:instantiate()
    b.borderColor = { r = 0.6, g = 0.6, b = 0.66, a = 0.8 }
    b.backgroundColor = { r = 0.13, g = 0.13, b = 0.16, a = 1 }
    b.backgroundColorMouseOver = { r = 0.3, g = 0.3, b = 0.36, a = 1 }
    self:addChild(b)
    return b
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.tabButtons = {}
    self.tabs = Window.tabList()
    for _, tab in ipairs(self.tabs) do
        local id = tab.id
        self.tabButtons[id] = self:button(T(tab.title), function() self:selectTab(id) end)
    end
    self.buttons = {
        kit = self:button(T("BtnKit"), function() self:onKit() end),
        plan = self:button(T("BtnPlan"), function() self:onPlan() end),
        expand = self:button(T("BtnExpand"), function() self:onExpand() end),
        grow = self:button(T("BtnGrowOn"), function() self:onGrow() end),
        raids = self:button(T("BtnRaidOn"), function() self:onRaids() end),
        adopt = self:button(T("BtnAdoptOff"), function() self:onAdopt() end),
        demolish = self:button(T("BtnDemolishOff"), function() self:onDemolish() end),
        border = self:button(T("BtnBorder"), function() self:onBorder() end),
        rename = self:button(T("BtnRename"), function() self:onRename() end),
        abandon = self:button(T("BtnAbandon"), function() self:onAbandon() end),
        prev = self:button("<", function() self:onStep(-1) end),
        next = self:button(">", function() self:onStep(1) end),
    }
    self:layoutAll()
    self:selectTab(Window.current)
end

function Window:layoutAll()
    self.laidW, self.laidH = self.width, self.height
    local th = self:titleBarHeight()
    local bh = fh() + 8
    local x, y = 6, th + 6
    for _, tab in ipairs(self.tabs) do
        local b = self.tabButtons[tab.id]
        local bw = textWidth(b.title) + 22
        if x + bw > self.width - 6 and x > 6 then
            x = 6
            y = y + bh + 4
        end
        b:setX(x)
        b:setY(y)
        b:setWidth(bw)
        b:setHeight(bh)
        x = x + bw + 4
    end
    self.contentY = y + bh + 8
    local by = self.height - self:resizeWidgetHeight() - bh - 6
    local bx = 6
    for _, id in ipairs({ "prev", "next", "plan", "expand", "grow", "raids", "adopt", "demolish", "kit", "border", "rename", "abandon" }) do
        local b = self.buttons[id]
        local bw = id == "prev" and bh or (id == "next" and bh or textWidth(b.title) + 22)
        if bx + bw > self.width - 6 then
            bx = 6
            by = by - bh - 4
        end
        b:setX(bx)
        b:setY(by)
        b:setWidth(bw)
        b:setHeight(bh)
        bx = bx + bw + 4
    end
    self.contentBottom = by - 6
end

Window.pageTtl = 450

function Window:selectTab(id)
    Window.current = id
    self.linesCache = nil
    for tabId, b in pairs(self.tabButtons) do
        if tabId == id then
            b.backgroundColor = { r = 0.2, g = 0.5, b = 0.26, a = 1 }
        else
            b.backgroundColor = { r = 0.13, g = 0.13, b = 0.16, a = 1 }
        end
    end
    self.scroll = 0
end

function Window.onResetAnswer(target, button, campId)
    if button.internal ~= "YES" then return end
    local camp = Store.get(campId)
    if camp == nil then return end
    local result = ALifeCamp.Reset.run(camp)
    local player = getPlayer()
    if player == nil then return end
    local key = result.blocked and "ResetBlocked" or (result.far > 0 and "ResetPartial" or "ResetDone")
    pcall(function() player:setHaloNote(T(key, tostring(result.projects), tostring(result.far))) end)
end

Options.action({
    key = "reset", priority = 10,
    run = function(camp)
        local modal = ISModalDialog:new(0, 0, 420, 190, T("AskReset", camp.name), true, nil, Window.onResetAnswer, 0, camp.id)
        modal:initialise()
        modal:addToUIManager()
    end,
})

function Window.onRegenAnswer(target, button, campId)
    if button.internal ~= "YES" then return end
    local camp = Store.get(campId)
    if camp == nil or ALifeCamp.Regen == nil then return end
    local result = ALifeCamp.Regen.run(camp)
    local player = getPlayer()
    if player == nil then return end
    pcall(function() player:setHaloNote(T("RegenDone", tostring(result.done), tostring(result.settlers))) end)
end

Options.action({
    key = "regen", priority = 11,
    run = function(camp)
        local modal = ISModalDialog:new(0, 0, 460, 240, T("AskRegen", camp.name), true, nil, Window.onRegenAnswer, 0, camp.id)
        modal:initialise()
        modal:addToUIManager()
    end,
})

function Window.onZeroCleanAnswer(target, button, campId)
    if button.internal ~= "YES" then return end
    local camp = Store.get(campId)
    if camp == nil or ALifeCamp.Reset == nil or ALifeCamp.Reset.zeroClean == nil then return end
    local result = ALifeCamp.Reset.zeroClean(camp)
    local player = getPlayer()
    if player == nil then return end
    pcall(function() player:setHaloNote(T("ZeroCleanDone", tostring(result.removed))) end)
end

Options.action({
    key = "zeroclean", priority = 12,
    run = function(camp)
        local modal = ISModalDialog:new(0, 0, 470, 230, T("AskZeroClean", camp.name), true, nil, Window.onZeroCleanAnswer, 0, camp.id)
        modal:initialise()
        modal:addToUIManager()
    end,
})

function Window:onKit()
    local player = getPlayer()
    if player == nil then return end
    local given = Flags.give(player)
    if given > 0 then
        Flags.say(player, "KitGiven", tostring(given))
    else
        Flags.say(player, "KitHave")
    end
end

function Window:onPlan()
    local camp = self:camp()
    if camp == nil then return end
    ALifeCamp.Planner.open(camp)
end

function Window:buildLines(camp)
    local lines = {}
    local list = Build.list(camp)
    if #list == 0 then
        lines[1] = { text = T("NoProjects"), r = 0.7, g = 0.7, b = 0.75 }
        return lines
    end
    for _, project in ipairs(list) do
        local stage, total = Build.currentStage(project)
        local name = T("Kind_" .. project.kind)
        local status
        if project.status == "done" then
            status = T("St_done")
        elseif project.waiting then
            local missing = Build.needs(camp, project)
            local parts = {}
            for kind, amount in pairs(missing) do parts[#parts + 1] = T("Short_" .. kind, tostring(math.ceil(amount))) end
            status = T("St_wait", table.concat(parts, ", "))
        elseif project.status == "active" then
            status = T("St_active")
        else
            status = T("St_planned")
        end
        local progress = tostring(math.floor(Build.progress(project) * 100))
        local stageName = stage ~= nil and T("Stage_" .. stage.id) or "-"
        lines[#lines + 1] = { text = T("BuildRow", name, tostring(math.min(project.stage, total)), tostring(total), stageName, progress, status),
            r = project.status == "done" and 0.6 or 0.9, g = project.status == "done" and 0.9 or 0.9, b = 0.7 }
    end
    return lines
end

function Window:adoptWaiting(waiting)
    local parts = {}
    local kinds = {}
    for kind in pairs(waiting or {}) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    for _, kind in ipairs(kinds) do
        local amount = tostring(math.ceil(waiting[kind]))
        local text = ALifeCamp.TN("Short_" .. kind)
        if text ~= nil then
            parts[#parts + 1] = T("Short_" .. kind, amount)
        else
            parts[#parts + 1] = T("Short_other", kind, amount)
        end
    end
    return table.concat(parts, ", ")
end

function Window:adoptRooms(names)
    local parts = {}
    for _, row in ipairs(names) do
        local label = ALifeCamp.Adopt.roomLabel(row.name)
        if row.count > 1 then label = T("AdRoomN", label, tostring(row.count)) end
        parts[#parts + 1] = label
    end
    return table.concat(parts, ", ")
end

function Window:adoptLines(camp)
    local lines = {}
    local function add(text, color)
        color = color or { 0.88, 0.88, 0.9 }
        lines[#lines + 1] = { text = text, r = color[1], g = color[2], b = color[3] }
    end
    local Adopt = ALifeCamp.Adopt
    local totals = Adopt.totals(camp)
    if totals.items == 0 then
        if camp.options.adopt == true then
            add(T("AdNone", tostring(totals.skipped)), { 0.7, 0.7, 0.75 })
        else
            add(T("AdOff"), { 0.7, 0.7, 0.75 })
        end
        return lines
    end
    add(T("AdTotals", tostring(totals.done), tostring(totals.items), tostring(totals.active), tostring(totals.queued)), { 1, 0.85, 0.35 })
    add(T("AdTotals2", tostring(totals.capacity), tostring(totals.skipped)), { 1, 0.85, 0.35 })
    local list = Adopt.summaries(camp)
    table.sort(list, function(a, b)
        local oa, ob = Window.adoptOrder[a.status] or 9, Window.adoptOrder[b.status] or 9
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)
    for _, s in ipairs(list) do
        local color = Window.adoptColors[s.status] or { 0.88, 0.88, 0.9 }
        local beds = s.capacity > 0 and s.capacity or s.expected
        local detail = T("AdDetail", tostring(s.rooms), tostring(s.floors), tostring(beds))
        add(T("AdRow", tostring(s.id), T("AdSt_" .. s.status), tostring(math.floor(s.progress * 100)), detail), color)
        local rooms = self:adoptRooms(s.names)
        if rooms ~= "" then add(T("AdRooms", rooms), { 0.72, 0.72, 0.78 }) end
        if s.detail ~= nil then add(T("AdDetailLine", s.detail), { 0.8, 0.8, 0.6 }) end
        if s.waiting ~= nil then
            local text = self:adoptWaiting(s.waiting)
            if text ~= "" then add(T("AdWait", text), { 1, 0.6, 0.45 }) end
        end
    end
    return lines
end

Window.districtCache = { id = nil, at = -100000, list = {} }

function Window:districtList(camp)
    local districts = ALifeCamp.Districts
    if districts == nil or type(districts.describe) ~= "function" then return {} end
    local cache = Window.districtCache
    local now = nowMs()
    if cache.id ~= camp.id or now - cache.at > 1500 then
        local ok, list = pcall(districts.describe, camp)
        cache.id, cache.at = camp.id, now
        cache.list = (ok and type(list) == "table") and list or {}
    end
    return cache.list
end

function Window:onExpand()
    local camp = self:camp()
    local player = getPlayer()
    if camp == nil or player == nil then return end
    if camp.phase == "clear" then
        Flags.say(player, "ExpandNo_busy")
        return
    end
    local side = Expand.best(camp)
    if side == nil then
        Flags.say(player, "ExpandNo_nospace")
        return
    end
    local modal = ISModalDialog:new(0, 0, 400, 170, T("AskExpand", T("Side_" .. side), tostring(Expand.amount(camp))), true, self, Window.onExpandAnswer, 0, camp.id, side)
    modal:initialise()
    modal:addToUIManager()
end

function Window.onExpandAnswer(target, button, campId, side)
    if button.internal ~= "YES" then return end
    local camp = Store.get(campId)
    if camp == nil then return end
    local ok, why = Expand.request(camp, side)
    local player = getPlayer()
    if player == nil then return end
    if ok then
        Flags.say(player, "ExpandStarted", T("Side_" .. side))
        ALifeCamp.Markers.refresh(player, true)
    else
        Flags.say(player, "ExpandNo_" .. tostring(why))
    end
end

function Window:onGrow()
    local camp = self:camp()
    if camp == nil then return end
    camp.options.expand = camp.options.expand == false
end

function Window:onRaids()
    local camp = self:camp()
    if camp == nil then return end
    camp.options.raids = camp.options.raids == false
end

function Window:onAdopt()
    local camp = self:camp()
    if camp == nil then return end
    camp.options.adopt = camp.options.adopt ~= true
    if camp.options.adopt and ALifeCamp.Adopt ~= nil then pcall(ALifeCamp.Adopt.discover, camp) end
end

function Window:onDemolish()
    local camp = self:camp()
    if camp == nil then return end
    camp.options.demolish = camp.options.demolish ~= true
end

function Window:onBorder()
    local camp = self:camp()
    if camp == nil then return end
    camp.options.border = camp.options.border == false
    ALifeCamp.Markers.refresh(getPlayer(), true)
end

function Window:onRename()
    local camp = self:camp()
    if camp == nil then return end
    local box = ISTextBox:new(0, 0, 320, 180, T("AskName"), camp.name, self, Window.onRenameAnswer, 0, camp.id)
    box:initialise()
    box:addToUIManager()
end

function Window.onRenameAnswer(target, button, campId)
    if button.internal ~= "OK" then return end
    Camp.rename(Store.get(campId), button.parent.entry:getText())
end

function Window:onAbandon()
    local camp = self:camp()
    if camp == nil then return end
    local modal = ISModalDialog:new(0, 0, 380, 170, T("AskAbandon", camp.name), true, self, Window.onAbandonAnswer, 0, camp.id)
    modal:initialise()
    modal:addToUIManager()
end

function Window.onAbandonAnswer(target, button, campId)
    if button.internal ~= "YES" then return end
    Camp.abandon(Store.get(campId))
    ALifeCamp.Markers.refresh(getPlayer(), true)
end

function Window:onStep(delta)
    local list = Store.list()
    if #list == 0 then return end
    local index = 1
    for i, camp in ipairs(list) do
        if camp.id == self.campId then index = i end
    end
    index = (index - 1 + delta) % #list + 1
    self.campId = list[index].id
    self.survey = nil
end

function Window:phaseText(camp)
    local phase = camp.phase or "plan"
    return T("Phase_" .. phase)
end

function Window:lines(camp)
    local lines = {}
    local function add(text, r, g, b)
        lines[#lines + 1] = { text = text, r = r or 0.88, g = g or 0.88, b = b or 0.9 }
    end
    add(T("OvName", camp.name, tostring(camp.level or 1)), 1, 0.85, 0.35)
    add(T("OvSize", tostring(Geo.width(camp)), tostring(Geo.height(camp)), tostring(Geo.area(camp))))
    add(T("OvDay", tostring(Store.day(camp)), self:phaseText(camp)))
    add(T("OvPeople", tostring(Store.settlerCount(camp))))
    local stats = Stats.compute(camp)
    add(T("OvLevel", tostring(stats.level), tostring(stats.defense), tostring(stats.morale)), 0.6, 0.95, 0.6)
    add(T("OvHouse", tostring(stats.counts.houses), tostring(stats.capacity), tostring(stats.people)))
    add(T("OvDefense", tostring(stats.fence), tostring(stats.counts.tower), tostring(stats.roles.guard or 0)))
    local adopted = ALifeCamp.Adopt.totals(camp)
    if adopted.items > 0 then add(T("OvAdopt", tostring(adopted.done), tostring(adopted.items), tostring(adopted.capacity)), 0.7, 0.9, 0.8) end
    local posts = ALifeCamp.Posts ~= nil and ALifeCamp.Posts.summary(camp) or nil
    if posts ~= nil and posts.gates > 0 then
        add(T("OvPosts", tostring(posts.gates), tostring(posts.posts), tostring(posts.postsPlanned), tostring(posts.vehicles), tostring(posts.armored)), 0.7, 0.85, 1)
    end
    local skills = ALifeCamp.Skills
    if skills ~= nil and stats.people > 0 then
        local total, topName, topSkill, topLevel = 0, nil, nil, -1
        for _, settler in pairs(camp.settlers) do
            total = total + skills.totalLevel(settler)
            local best, level = skills.best(settler)
            if best ~= nil and level > topLevel then topName, topSkill, topLevel = settler.name, best, level end
        end
        if topSkill ~= nil then
            add(T("OvSkills", tostring(math.floor(total / stats.people * 10) / 10), tostring(topName), T("Skill_" .. topSkill), tostring(topLevel)), 0.85, 0.8, 1)
        end
    end
    add(T("OvEconomy", tostring(camp.recycledTotal or 0), tostring((camp.stock and camp.stock.planks) or 0), tostring((camp.stock and camp.stock.nails) or 0)), 0.9, 0.85, 0.6)
    for _, line in ipairs(Hooks.overview(camp)) do lines[#lines + 1] = line end
    local districts = self:districtList(camp)
    if #districts > 0 then
        local parts = {}
        for _, d in ipairs(districts) do
            parts[#parts + 1] = T("OvDistrict", T(d.name_key or ("District_" .. tostring(d.key))), tostring(d.done or 0), tostring(d.count or 0))
        end
        add(T("OvDistricts", table.concat(parts, "; ")), 0.9, 0.8, 0.6)
    end
    add(T("OvNext", T(Stats.nextLevelKey(stats.level))), 0.85, 0.85, 0.6)
    if camp.raid ~= nil then add(T("OvRaidNow"), 1, 0.45, 0.4) end
    if camp.expand ~= nil then add(T("OvExpanding", T("Side_" .. tostring(camp.expand.side))), 0.95, 0.75, 0.4) end
    add("")
    add(T("OvStock"), 0.6, 0.85, 1)
    local stock = camp.stock or {}
    add(T("StFood", tostring(math.floor((stock.food or 0) / 10) / 100), tostring(math.floor((stock.food or 0) / 2000 * 10) / 10)))
    add(T("StWater", tostring(math.floor((stock.water or 0) * 10) / 10)))
    add(T("StBuild", tostring(stock.planks or 0), tostring(stock.nails or 0), tostring(stock.logs or 0)))
    add(T("StMetal", tostring(stock.metal or 0), tostring(stock.rope or 0)))
    add(T("StOther", tostring(stock.medicine or 0), tostring(stock.ammo or 0), tostring(stock.seeds or 0)))
    add("")
    add(T("OvLand"), 0.6, 0.85, 1)
    local survey = self.survey
    if survey ~= nil then
        add(T("LdTrees", tostring(survey.tree), tostring(survey.plant)))
        add(T("LdJunk", tostring(survey.junk), tostring(survey.item), tostring(survey.corpse)))
        add(T("LdBuilt", tostring(survey.structure + survey.furniture), tostring(survey.buildings), tostring(survey.vehicles)))
        add(T("LdLoaded", tostring(math.floor(survey.loaded / math.max(1, survey.total) * 100))))
    else
        add(T("LdNone"))
    end
    add("")
    add(T("OvStats", tostring(camp.stats.built), tostring(camp.stats.cleared), tostring(camp.stats.harvested)))
    add(T("OvRaids", tostring(camp.stats.raids or 0), tostring(camp.stats.repelled or 0), tostring(camp.expansions or 0)))
    if camp.options.demolish then add(T("OvDemolish"), 0.95, 0.6, 0.4) end
    return lines
end

function Window:settlerLines(camp)
    local lines = {}
    local any = false
    for uid, settler in pairs(camp.settlers) do
        any = true
        local text = T("SettlerRow", tostring(settler.name or uid), T("Role_" .. tostring(settler.role or "worker")))
        local skills = ALifeCamp.Skills
        if skills ~= nil then
            local best, level = skills.best(settler)
            if best ~= nil then text = T("SettlerSkill", text, T("Skill_" .. best), tostring(level)) end
        end
        local extra = Hooks.collect("settlerInfo", camp, uid, settler)
        if #extra > 0 then text = T("SettlerExtra", text, table.concat(extra, ", ")) end
        lines[#lines + 1] = { text = text, r = 0.88, g = 0.88, b = 0.9 }
    end
    if not any then lines[1] = { text = T("NoSettlers"), r = 0.7, g = 0.7, b = 0.75 } end
    return lines
end

function Window:logLines(camp)
    local lines = {}
    for i = #camp.log, 1, -1 do
        local entry = camp.log[i]
        local day = math.max(0, math.floor((entry.h - (camp.founded or 0)) / 24))
        local a = entry.a
        if (entry.k == "stage" or entry.k == "built" or entry.k == "planned") and a ~= nil then a = T("Kind_" .. tostring(a)) end
        if entry.k == "expand" and a ~= nil then a = T("Side_" .. tostring(a)) end
        local b = entry.b
        if entry.k == "adopt_stage" and b ~= nil then b = T("AdStage_" .. tostring(b)) end
        local message = T("Log_" .. tostring(entry.k), tostring(a or ""), tostring(b or ""))
        lines[#lines + 1] = { text = T("LogRow", tostring(day), message), r = 0.85, g = 0.85, b = 0.88 }
    end
    if #lines == 0 then lines[1] = { text = T("LogEmpty"), r = 0.7, g = 0.7, b = 0.75 } end
    return lines
end

function Window:update()
    ISCollapsableWindow.update(self)
    if self.laidW ~= self.width or self.laidH ~= self.height then self:layoutAll() end
    local camp = self:camp()
    if camp ~= nil and Window.current == "overview" then
        local now = nowMs()
        if self.survey == nil or now - (self.surveyAt or 0) > 4000 then
            self.survey = Land.survey(camp, Land.stride(camp, 4000))
            self.surveyAt = now
        end
    end
    if camp ~= nil then
        ALifeCamp.Stock.refresh(camp, 0.03)
        self.buttons.grow:setTitle(T(camp.options.expand == false and "BtnGrowOff" or "BtnGrowOn"))
        self.buttons.raids:setTitle(T(camp.options.raids == false and "BtnRaidOff" or "BtnRaidOn"))
        self.buttons.adopt:setTitle(T(camp.options.adopt == true and "BtnAdoptOn" or "BtnAdoptOff"))
        self.buttons.demolish:setTitle(T(camp.options.demolish == true and "BtnDemolishOn" or "BtnDemolishOff"))
    end
end

function Window:prerender()
    ISCollapsableWindow.prerender(self)
    local camp = self:camp()
    local x = 12
    local y = (self.contentY or 60)
    local line = fh() + 3
    local lines = self:cachedLines(camp)
    if lines == nil then
        lines = self:buildPage(camp)
        self:storeLines(camp, lines)
    end
    return self:drawPage(camp, lines, x, y, line)
end

Window.prerender = Hooks.timed("window.prerender", Window.prerender)

function Window:cacheKey(camp)
    return tostring(camp ~= nil and camp.id or "-") .. ":" .. tostring(Window.current) .. ":" .. tostring(self.width)
end

function Window:cachedLines(camp)
    if self.linesCache == nil or self.linesKey ~= self:cacheKey(camp) then return nil end
    if nowMs() - (self.linesAt or 0) > Window.pageTtl then return nil end
    return self.linesCache
end

function Window:storeLines(camp, lines)
    self.linesCache = lines
    self.linesKey = self:cacheKey(camp)
    self.linesAt = nowMs()
end

function Window:dropLines()
    self.linesCache = nil
end

function Window:buildPage(camp)
    local lines
    if camp == nil then
        lines = { { text = T("NoCamp"), r = 0.9, g = 0.9, b = 0.9 }, { text = T("NoCampHelp"), r = 0.7, g = 0.75, b = 0.8 } }
    elseif Window.current == "settlers" then
        lines = self:settlerLines(camp)
    elseif Window.current == "log" then
        lines = self:logLines(camp)
    elseif Window.current == "build" then
        lines = self:buildLines(camp)
    elseif Window.current == "adopt" then
        lines = self:adoptLines(camp)
    elseif Window.current == "settings" then
        lines = self:safeLines(Options.lines, camp)
    elseif Window.current ~= "overview" and self:hookTab(Window.current) ~= nil then
        lines = self:safeLines(function(c) return Hooks.tabLines(self:hookTab(Window.current), c) end, camp)
    else
        lines = self:lines(camp)
    end
    return self:wrapLines(lines, self.width - 28)
end

function Window:drawPage(camp, lines, x, y, line)
    local bottom = self.contentBottom or (self.height - 60)
    local visible = math.max(1, math.floor((bottom - y) / line))
    local maxScroll = math.max(0, #lines - visible)
    self.scroll = math.max(0, math.min(self.scroll or 0, maxScroll))
    self.hitRows = {}
    local mx, my = -1, -1
    pcall(function()
        mx, my = self:getMouseX(), self:getMouseY()
    end)
    if type(mx) ~= "number" or type(my) ~= "number" then mx, my = -1, -1 end
    for i = 1 + self.scroll, math.min(#lines, self.scroll + visible) do
        local l = lines[i]
        if l.click ~= nil then
            self.hitRows[#self.hitRows + 1] = { y1 = y, y2 = y + line, click = l.click }
            if my >= y and my < y + line and mx >= 0 and mx <= self.width then
                self:drawRect(6, y, self.width - 12, line, 0.25, 0.4, 0.55, 0.4)
            end
        end
        self:drawText(l.text, x + (l.indent or 0), y, l.r or 0.88, l.g or 0.88, l.b or 0.9, 1, FONT)
        y = y + line
    end
    if maxScroll > 0 then
        self:drawText(T("Scroll", tostring(self.scroll + 1), tostring(#lines)), self.width - 90, self.contentY or 60, 0.6, 0.6, 0.65, 1, FONT)
    end
end

function Window:onMouseWheel(del)
    self.scroll = (self.scroll or 0) + (del > 0 and 2 or -2)
    return true
end

function Window.wrapText(text, width)
    local parts, current = {}, ""
    for word in string.gmatch(text, "%S+") do
        local probe = current == "" and word or (current .. " " .. word)
        if textWidth(probe) > width and current ~= "" then
            parts[#parts + 1] = current
            current = word
        else
            current = probe
        end
    end
    if current ~= "" then parts[#parts + 1] = current end
    return parts
end

function Window:wrapLines(lines, width)
    local cache = self.wrapCache
    if type(cache) ~= "table" or cache.width ~= width or cache.size > 600 then
        cache = { width = width, size = 0, map = {} }
        self.wrapCache = cache
    end
    local out = {}
    for _, l in ipairs(lines) do
        local text = l.text or ""
        local indent = l.indent or 0
        local parts = cache.map[text .. "|" .. indent]
        if parts == nil then
            if text == "" or textWidth(text) <= width - indent then
                parts = false
            else
                parts = Window.wrapText(text, width - indent)
            end
            cache.map[text .. "|" .. indent] = parts
            cache.size = cache.size + 1
        end
        if parts == false or #parts <= 1 then
            out[#out + 1] = l
        else
            for i, part in ipairs(parts) do
                out[#out + 1] = { text = part, r = l.r, g = l.g, b = l.b, click = l.click, indent = indent + (i > 1 and 14 or 0) }
            end
        end
    end
    return out
end

function Window:hookTab(id)
    for _, tab in ipairs(Hooks.tabs) do
        if tab.id == id then return tab end
    end
    return nil
end

function Window:safeLines(fn, camp)
    local ok, lines = pcall(fn, camp)
    if ok and type(lines) == "table" then return lines end
    return { { text = tostring(lines), r = 0.9, g = 0.5, b = 0.5 } }
end

function Window:onMouseDown(x, y)
    self.pressAt = { x = x, y = y }
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function Window:onMouseUp(x, y)
    local press = self.pressAt
    self.pressAt = nil
    local result = ISCollapsableWindow.onMouseUp(self, x, y)
    if press ~= nil and math.abs(press.x - x) < 5 and math.abs(press.y - y) < 5 then
        self:onContentClick(y)
    end
    return result
end

function Window:onContentClick(y)
    local camp = self:camp()
    if camp == nil then return end
    for _, row in ipairs(self.hitRows or {}) do
        if y >= row.y1 and y < row.y2 then
            pcall(row.click, camp, self)
            self.linesCache = nil
            return
        end
    end
end

function Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
    Window.instance = nil
end

function Window.open(camp)
    local existing = Window.instance
    if existing ~= nil then
        if camp ~= nil then existing.campId = camp.id existing.survey = nil end
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end
    local core = getCore()
    local line = fh()
    local w = math.min(core:getScreenWidth() - 60, 420 + line * 18)
    local h = math.min(core:getScreenHeight() - 80, line * 34)
    local win = ISCollapsableWindow:new(core:getScreenWidth() / 2 - w / 2, core:getScreenHeight() / 2 - h / 2, w, h)
    setmetatable(win, Window)
    win.title = T("Title")
    win.resizable = true
    win.campId = camp ~= nil and camp.id or nil
    win:initialise()
    win:addToUIManager()
    win:setVisible(true)
    win:bringToTop()
    Window.instance = win
    return win
end

function Window.toggle()
    local existing = Window.instance
    if existing ~= nil and existing:getIsVisible() then
        existing:close()
    else
        Window.open(nil)
    end
end

Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_F6 then Window.toggle() end
end)

return Window
