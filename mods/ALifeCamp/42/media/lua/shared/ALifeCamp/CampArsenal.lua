require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampWorld"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Settlers = ALifeCamp.Settlers
local Stock = ALifeCamp.Stock

local Arsenal = {}
ALifeCamp.Arsenal = Arsenal

Arsenal.radius = 7
Arsenal.everyMinutes = 20
Arsenal.loadRounds = 90
Arsenal.infiniteAmmo = true

local function isWeapon(item)
    if item == nil then return false end
    local yes = false
    pcall(function() yes = instanceof(item, "HandWeapon") and item:IsWeapon() == true end)
    return yes
end

local function isRanged(item)
    local yes = false
    pcall(function() yes = item:isRanged() == true end)
    return yes
end

local function condFrac(item)
    local frac = 1
    pcall(function()
        local max = item:getConditionMax()
        if max ~= nil and max > 0 then frac = item:getCondition() / max end
    end)
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    return frac
end

local function score(item)
    if not isWeapon(item) then return -1 end
    local maxd, mind, hits = 1, 0, 1
    pcall(function() maxd = tonumber(item:getMaxDamage()) or 1 end)
    pcall(function() mind = tonumber(item:getMinDamage()) or 0 end)
    pcall(function() hits = tonumber(item:getMaxHitCount()) or 1 end)
    if hits < 1 then hits = 1 end
    local base = ((maxd + mind) / 2) * hits * (0.5 + 0.5 * condFrac(item))
    if isRanged(item) then
        local hc = 0
        pcall(function() hc = tonumber(item:getHitChance()) or 0 end)
        return base * 2.5 + hc / 100 + 5
    end
    return base
end

local function loadFirearm(item)
    pcall(function()
        local max = item:getMaxAmmo()
        if max ~= nil and max > 0 then item:setCurrentAmmoCount(max) end
        if item.usesExternalMagazine ~= nil and item:usesExternalMagazine() then
            pcall(function() item:setContainsClip(true) end)
        end
        if item.haveChamber ~= nil and item:haveChamber() then
            pcall(function() item:setRoundChambered(true) end)
        end
        pcall(function() item:setJammed(false) end)
    end)
end

local function equip(shell, item)
    local ranged = isRanged(item)
    local fullType = ""
    pcall(function() fullType = item:getFullType() end)
    pcall(function() shell:getInventory():AddItem(item) end)
    pcall(function() item:getModData().ProjectALifeWeaponSlot = "primary" end)
    if ranged then loadFirearm(item) end
    pcall(function()
        local md = shell:getModData()
        md.ProjectALifeFirearmsAuthored = true
        if ranged and Arsenal.infiniteAmmo then md.ProjectALifeInfiniteAmmo = true end
    end)
    local PA = ProjectALife
    if PA ~= nil then
        if ranged and PA.MagazineState ~= nil and PA.MagazineState.initialize ~= nil then
            pcall(function() PA.MagazineState.initialize(shell, item, "primary", Arsenal.loadRounds, "rounds") end)
        end
        if PA.Weapons ~= nil and PA.Weapons.select ~= nil then
            pcall(function() PA.Weapons.select(shell, item, "primary") end)
        end
        if ranged then
            pcall(function() shell:getModData().ProjectALifeWeaponClass = "rifle" end)
        end
        if PA.Animations ~= nil then
            if ranged and PA.Animations.presentWeapon ~= nil then
                pcall(function() PA.Animations.presentWeapon(shell, item, fullType, "rifle", false) end)
            end
            pcall(function() if PA.Animations.refreshWeapon ~= nil then PA.Animations.refreshWeapon(shell, true) end end)
            pcall(function() if PA.Animations.syncPresentation ~= nil then PA.Animations.syncPresentation(shell) end end)
        end
    end
    pcall(function() shell:setPrimaryHandItem(item) end)
    pcall(function() if item:isRequiresEquippedBothHands() then shell:setSecondaryHandItem(item) end end)
    return true
end

local function crateGuns(camp)
    local out = {}
    if type(camp.storage) ~= "table" then return out end
    for _, entry in ipairs(camp.storage) do
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then
            pcall(function()
                local container = crate:getContainer()
                if container == nil then return end
                local items = container:getItems()
                for i = 0, items:size() - 1 do
                    local item = items:get(i)
                    if isWeapon(item) then out[#out + 1] = { item = item, container = container } end
                end
            end)
        end
    end
    return out
end

local function takeGround(square, world)
    local ok = false
    pcall(function()
        square:transmitRemoveItemFromSquare(world)
        ok = true
    end)
    pcall(function() world:removeFromWorld() end)
    pcall(function() world:removeFromSquare() end)
    return ok
end

local function scanGround(shell, bestScore)
    local best, bestWorld, bestSquare = nil, nil, nil
    local cell = getCell()
    if cell == nil then return nil end
    local sx, sy, sz = 0, 0, 0
    pcall(function() sx, sy, sz = math.floor(shell:getX()), math.floor(shell:getY()), math.floor(shell:getZ()) end)
    local r = Arsenal.radius
    for dx = -r, r do
        for dy = -r, r do
            local square
            pcall(function() square = cell:getGridSquare(sx + dx, sy + dy, sz) end)
            if square ~= nil then
                pcall(function()
                    local list = square:getWorldObjects()
                    if list == nil then return end
                    for i = list:size() - 1, 0, -1 do
                        local world = list:get(i)
                        local item = world ~= nil and world:getItem() or nil
                        if isWeapon(item) then
                            local s = score(item)
                            if s > bestScore then
                                best, bestWorld, bestSquare, bestScore = item, world, square, s
                            end
                        end
                    end
                end)
            end
        end
    end
    if best == nil then return nil end
    return { item = best, world = bestWorld, square = bestSquare, score = bestScore }
end

function Arsenal.rearm(camp)
    if type(camp.settlers) ~= "table" then return 0 end
    local guns = crateGuns(camp)
    local taken = {}
    local upgraded = 0
    for uid in pairs(camp.settlers) do
        local shell = Settlers.shell(uid)
        if shell ~= nil then
            local current
            pcall(function() current = shell:getPrimaryHandItem() end)
            if not (isWeapon(current) and isRanged(current)) then
                local curScore = score(current)
                local best, bestScore, pick = nil, curScore, nil
                local g = scanGround(shell, bestScore)
                if g ~= nil then best, bestScore, pick = g.item, g.score, g end
                for index, entry in ipairs(guns) do
                    if not taken[index] then
                        local s = score(entry.item)
                        if s > bestScore then best, bestScore, pick = entry.item, s, { crate = entry, index = index } end
                    end
                end
                if best ~= nil and bestScore > curScore + 0.01 then
                    local removed = false
                    if pick.world ~= nil then
                        removed = takeGround(pick.square, pick.world)
                    elseif pick.crate ~= nil then
                        pcall(function() pick.crate.container:Remove(best) end)
                        taken[pick.index] = true
                        removed = true
                    end
                    if removed and equip(shell, best) then upgraded = upgraded + 1 end
                end
            end
        end
    end
    return upgraded
end

local cursor = {}
local lastHour = {}

Hooks.add("minute", function(camp, minutes)
    if camp.raid ~= nil then
        pcall(function() Arsenal.rearm(camp) end)
        return
    end
    cursor[camp.id] = (cursor[camp.id] or 0) + (tonumber(minutes) or 1)
    if cursor[camp.id] < Arsenal.everyMinutes then return end
    cursor[camp.id] = 0
    local ok, n = pcall(Arsenal.rearm, camp)
    if ok and Store ~= nil then
        local hour = math.floor(Store.hours())
        if lastHour[camp.id] ~= hour then
            lastHour[camp.id] = hour
            print("[ALifeCamp:Arsenal] rearmed=" .. tostring(n))
        end
    end
end, 70)

return Arsenal
