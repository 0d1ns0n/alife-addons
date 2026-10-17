require "ISUI/ISContextMenu"
require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampFlags"
require "ALifeCamp/CampSettlers"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Flags = ALifeCamp.Flags
local Settlers = ALifeCamp.Settlers
local T = ALifeCamp.T

local Menu = {}
ALifeCamp.Menu = Menu

local hideIcon = "media/textures/Item_Plumpabug_Left.png"

function Menu.square(worldObjects)
    for i = 1, #worldObjects do
        local square
        pcall(function() square = worldObjects[i]:getSquare() end)
        if square ~= nil then return square end
    end
    return nil
end

function Menu.flagObject(worldObjects)
    for i = 1, #worldObjects do
        local tag = World.tag(worldObjects[i])
        if type(tag) == "table" and tag.kind == "flag" and tag.pending == true then return worldObjects[i] end
    end
    return nil
end

function Menu.actors(square)
    local out = {}
    if square == nil or not Settlers.available() then return out end
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            if sq ~= nil then
                pcall(function()
                    local moving = sq:getMovingObjects()
                    for i = 0, moving:size() - 1 do
                        local shell = moving:get(i)
                        local identity = Settlers.identity(shell)
                        if identity ~= nil then out[#out + 1] = { shell = shell, identity = identity } end
                    end
                end)
            end
        end
    end
    return out
end

function Menu.invite(player, shell, camp)
    local ok, why = Settlers.invite(player, shell, camp)
    if not ok then Flags.say(player, "InviteNo_" .. tostring(why)) end
end

function Menu.setRole(camp, uid, role)
    Settlers.setRole(camp, uid, role)
end

function Menu.dismiss(camp, uid)
    Settlers.dismiss(camp, uid)
end

function Menu.cancelInvite(camp, uid)
    Settlers.cancelInvite(camp, uid)
end

function Menu.fill(playerNum, context, worldObjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if player == nil then return end
    local objects = {}
    for _, object in ipairs(worldObjects) do objects[#objects + 1] = object end
    local square = Menu.square(objects)
    local flagObject = Menu.flagObject(objects)
    local haveFlags = Flags.have(player) > 0
    local placed = Flags.placed()
    local camp
    if square ~= nil then
        camp = Store.campAt(square:getX(), square:getY(), square:getZ())
        if camp == nil then camp = Store.nearest(square:getX(), square:getY(), 12) end
    end
    local actors = {}
    local mine = Store.nearest(player:getX(), player:getY(), 400)
    if mine ~= nil then actors = Menu.actors(square) end
    if not (haveFlags or placed > 0 or camp ~= nil or flagObject ~= nil or #actors > 0) then return end
    local root = context:addOption(T("Menu"))
    pcall(function() root.iconTexture = getTexture(hideIcon) end)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    if haveFlags and square ~= nil and Flags.placed() < ALifeCamp.Config.flagCount then
        local ok = Flags.check(player, square)
        local label = T("PlaceFlag", tostring(placed + 1), tostring(ALifeCamp.Config.flagCount))
        local option = sub:addOption(label, player, Flags.queuePlace, square)
        option.notAvailable = not ok
    end
    if flagObject ~= nil then
        sub:addOption(T("TakeFlag"), player, Flags.queueTake, flagObject)
    end
    if placed > 0 then
        sub:addOption(T("CancelFlags"), player, Flags.cancel)
    end
    if camp ~= nil then
        sub:addOption(T("OpenCamp", camp.name), camp, function(c) ALifeCamp.Window.open(c) end)
    end
    for index, actor in ipairs(actors) do
        if index > 4 then break end
        local uid = actor.identity.uid
        local name = Settlers.name(actor.identity, actor.shell)
        local home
        for _, c in ipairs(Store.list()) do
            if c.settlers[uid] ~= nil then home = c end
        end
        if home ~= nil then
            local roleOption = sub:addOption(T("Settler", name))
            local roleMenu = ISContextMenu:getNew(sub)
            sub:addSubMenu(roleOption, roleMenu)
            for _, role in ipairs(Settlers.roles) do
                roleMenu:addOption(T("SetRole", T("Role_" .. role)), home, Menu.setRole, uid, role)
            end
            roleMenu:addOption(T("Dismiss"), home, Menu.dismiss, uid)
        else
            local target = mine
            local pendingCamp
            for _, c in ipairs(Store.list()) do
                if c.pending ~= nil and c.pending[uid] ~= nil then pendingCamp = c end
            end
            if pendingCamp ~= nil then
                sub:addOption(T("CancelInvite", name), pendingCamp, Menu.cancelInvite, uid)
            elseif target ~= nil then
                sub:addOption(T("Invite", target.name, name), player, Menu.invite, actor.shell, target)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(Menu.fill)

return Menu
