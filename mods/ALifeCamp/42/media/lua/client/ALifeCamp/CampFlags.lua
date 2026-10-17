require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"
require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampLand"
require "ALifeCamp/Camp"
require "ALifeCamp/CampMarkers"
require "ALifeCamp/CampActions"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Land = ALifeCamp.Land
local Camp = ALifeCamp.Camp
local T = ALifeCamp.T

local Flags = { draft = nil }
ALifeCamp.Flags = Flags

function Flags.have(player)
    local count = 0
    pcall(function() count = player:getInventory():getCountTypeRecurse(Config.flagItem) end)
    return count
end

function Flags.placed()
    return #Store.pending()
end

function Flags.give(player)
    local need = Config.flagCount - Flags.have(player) - Flags.placed()
    if need <= 0 then return 0 end
    pcall(function() player:getInventory():AddItems(Config.flagItem, need) end)
    return need
end

function Flags.say(player, key, ...)
    local text = T(key, ...)
    pcall(function() player:setHaloNote(text) end)
end

function Flags.check(player, square)
    if square == nil then return false, "square" end
    if Flags.placed() >= Config.flagCount then return false, "full" end
    if Flags.have(player) < 1 then return false, "none" end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if z ~= 0 then return false, "level" end
    if Store.campAt(x, y, z) ~= nil then return false, "inside" end
    for _, flag in ipairs(Store.pending()) do
        if flag.x == x and flag.y == y then return false, "same" end
    end
    return true
end

function Flags.queuePlace(player, square)
    local ok, why = Flags.check(player, square)
    if not ok then
        Flags.say(player, "FlagNo_" .. tostring(why))
        return
    end
    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(ISALCPlaceFlag:new(player, square:getX(), square:getY(), square:getZ()))
    end
end

function Flags.queueTake(player, object)
    local square = object:getSquare()
    if square == nil then return end
    if luautils.walkAdj(player, square) then
        ISTimedActionQueue.add(ISALCTakeFlag:new(player, object))
    end
end

function Flags.commitPlace(player, x, y, z)
    local square = World.square(x, y, z)
    local ok, why = Flags.check(player, square)
    if not ok then
        Flags.say(player, "FlagNo_" .. tostring(why))
        return false
    end
    local item
    pcall(function() item = player:getInventory():getFirstTypeRecurse(Config.flagItem) end)
    if item == nil then return false end
    pcall(function() item:getContainer():Remove(item) end)
    local object = World.putFlag(x, y, z, { kind = "flag", pending = true })
    if object == nil then
        pcall(function() player:getInventory():AddItem(Config.flagItem) end)
        Flags.say(player, "FlagNo_square")
        return false
    end
    local list = Store.pending()
    list[#list + 1] = { x = x, y = y, z = z }
    ALifeCamp.Markers.refresh(player, true)
    Flags.say(player, "FlagPlaced", tostring(#list), tostring(Config.flagCount))
    if #list >= Config.flagCount then Flags.ask(player) end
    return true
end

function Flags.commitTake(player, object)
    if object == nil then return false end
    local square = object:getSquare()
    if square == nil then return false end
    local x, y = square:getX(), square:getY()
    local tag = World.tag(object)
    if type(tag) ~= "table" or tag.pending ~= true then return false end
    World.remove(object)
    local list = Store.pending()
    for i = #list, 1, -1 do
        if list[i].x == x and list[i].y == y then table.remove(list, i) end
    end
    pcall(function() player:getInventory():AddItem(Config.flagItem) end)
    ALifeCamp.Markers.refresh(player, true)
    Flags.say(player, "FlagTaken", tostring(#list), tostring(Config.flagCount))
    return true
end

function Flags.cancel(player)
    local list = Store.pending()
    for _, flag in ipairs(list) do
        local square = World.square(flag.x, flag.y, flag.z)
        local object = square ~= nil and World.find(square, "flag", nil) or nil
        if object ~= nil then
            local tag = World.tag(object)
            if type(tag) == "table" and tag.pending == true then World.remove(object) end
        end
        pcall(function() player:getInventory():AddItem(Config.flagItem) end)
    end
    Store.clearPending()
    ALifeCamp.Markers.refresh(player, true)
    Flags.say(player, "FlagCancelled")
end

function Flags.rect()
    local list = Store.pending()
    if #list < Config.flagCount then return nil end
    return Camp.rectFrom(list, list[1].z)
end

function Flags.ask(player)
    local rect = Flags.rect()
    local ok, why = Camp.check(rect)
    if not ok then
        Flags.say(player, "Bad_" .. tostring(why))
        local modal = ISModalDialog:new(0, 0, 360, 160, T("Bad_" .. tostring(why)), false, nil, nil, player:getPlayerNum())
        modal:initialise()
        modal:addToUIManager()
        return
    end
    local survey = Land.survey(rect, Land.stride(rect, 12000))
    Flags.draft = { rect = rect, survey = survey, player = player }
    local text = T("AskCreate", tostring(Geo.width(rect)), tostring(Geo.height(rect)), tostring(survey.tree),
        tostring(survey.buildings))
    local waterPct = (survey.loaded or 0) > 0 and math.floor(100 * (survey.water or 0) / survey.loaded) or 0
    if waterPct > 0 then text = text .. "\n" .. T("AskWater", tostring(waterPct)) end
    local modal = ISModalDialog:new(0, 0, 420, 190, text, true, nil, Flags.onCreateAnswer, player:getPlayerNum())
    modal:initialise()
    modal:addToUIManager()
end

function Flags.onCreateAnswer(target, button)
    if button.internal ~= "YES" then return end
    local draft = Flags.draft
    if draft == nil then return end
    local player = draft.player
    local box = ISTextBox:new(0, 0, 320, 180, T("AskName"), Camp.defaultName(), nil, Flags.onNameAnswer, player:getPlayerNum())
    box:initialise()
    box:addToUIManager()
end

function Flags.onNameAnswer(target, button)
    if button.internal ~= "OK" then return end
    local draft = Flags.draft
    if draft == nil then return end
    draft.name = button.parent.entry:getText()
    if draft.survey.buildings > 0 then
        local preview = ALifeCamp.Adopt ~= nil and ALifeCamp.Adopt.preview(draft.rect, draft.rect.z) or nil
        local text, handler
        if preview ~= nil and preview.eligible > 0 then
            text = T("AskAdopt", tostring(math.max(preview.buildings, draft.survey.buildings)), tostring(preview.eligible))
            handler = Flags.onAdoptAnswer
        else
            text = T("AskDemolish", tostring(draft.survey.buildings))
            handler = Flags.onDemolishAnswer
        end
        local modal = ISModalDialog:new(0, 0, 420, 190, text, true, nil, handler, draft.player:getPlayerNum())
        modal:initialise()
        modal:addToUIManager()
    else
        Flags.finish(false, false)
    end
end

function Flags.onDemolishAnswer(target, button)
    Flags.finish(button.internal == "YES", false)
end

function Flags.onAdoptAnswer(target, button)
    Flags.finish(true, button.internal == "YES")
end

function Flags.finish(demolish, adopt)
    local draft = Flags.draft
    if draft == nil then return end
    Flags.draft = nil
    local camp, why = Camp.create(draft.rect, draft.name, { demolish = demolish == true, adopt = adopt == true })
    if camp == nil then
        Flags.say(draft.player, "Bad_" .. tostring(why))
        return
    end
    camp.phase = "clear"
    if adopt == true and ALifeCamp.Adopt ~= nil then ALifeCamp.Adopt.discover(camp) end
    Store.log(camp, "cleaning")
    ALifeCamp.Markers.refresh(draft.player, true)
    Flags.say(draft.player, "Founded", camp.name)
    if ALifeCamp.Window ~= nil then ALifeCamp.Window.open(camp) end
end

return Flags
