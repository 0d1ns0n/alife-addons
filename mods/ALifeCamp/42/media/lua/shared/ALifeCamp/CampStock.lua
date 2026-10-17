require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampHooks"

ALifeCamp = ALifeCamp or {}

local Config = ALifeCamp.Config
local Store = ALifeCamp.Store
local World = ALifeCamp.World

local Stock = {}
ALifeCamp.Stock = Stock

Stock.kinds = { "food", "water", "planks", "nails", "logs", "metal", "rope", "medicine", "ammo", "seeds" }

Stock.exact = {
    ["Base.Plank"] = "planks",
    ["Base.Nails"] = "nails",
    ["Base.Log"] = "logs",
    ["Base.ScrapMetal"] = "metal",
    ["Base.SmallSheetMetal"] = "metal",
    ["Base.SheetMetal"] = "metal",
    ["Base.MetalPipe"] = "metal",
    ["Base.Rope"] = "rope",
    ["Base.Twine"] = "rope",
    ["Base.SheetRope"] = "rope",
    ["Base.RippedSheets"] = "rope",
}

local function category(item)
    local value = ""
    pcall(function() value = tostring(item:getDisplayCategory() or "") end)
    return value
end

function Stock.classify(item)
    local full = ""
    pcall(function() full = item:getFullType() end)
    local kind = Stock.exact[full]
    if kind ~= nil then return kind, 1 end
    local cat = category(item)
    if cat == "FirstAid" then return "medicine", 1 end
    if cat == "Ammo" then return "ammo", 1 end
    if cat == "Gardening" and string.find(string.lower(full), "seed", 1, true) ~= nil then return "seeds", 1 end
    local isFood = false
    pcall(function() isFood = instanceof(item, "Food") end)
    if isFood then
        local calories = 0
        pcall(function() calories = tonumber(item:getCalories()) or 0 end)
        return "food", math.max(calories, 0)
    end
    local water = 0
    pcall(function()
        local fluid = item:getFluidContainer()
        if fluid ~= nil and fluid:getAmount() > 0 and fluid:contains(Fluid.Water) then water = fluid:getAmount() end
    end)
    if water > 0 then return "water", water end
    return nil, 0
end

function Stock.empty()
    local out = {}
    for _, kind in ipairs(Stock.kinds) do out[kind] = 0 end
    return out
end

Stock.typeCache = {}

local function cachedKind(item)
    local full
    pcall(function() full = item:getFullType() end)
    if full == nil then return Stock.classify(item) end
    local cached = Stock.typeCache[full]
    if cached == nil then
        local kind, amount = Stock.classify(item)
        if kind == nil then
            local fluid = false
            pcall(function() fluid = item:getFluidContainer() ~= nil end)
            if fluid then return nil, 0 end
            Stock.typeCache[full] = false
            return nil, 0
        end
        Stock.typeCache[full] = kind
        return kind, amount
    end
    if cached == false then return nil, 0 end
    if cached == "food" or cached == "water" then return Stock.classify(item) end
    return cached, 1
end

function Stock.countContainer(container)
    local counts = Stock.empty()
    if container == nil then return counts end
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local kind, amount = cachedKind(items:get(i))
            if kind ~= nil then counts[kind] = counts[kind] + amount end
        end
    end)
    return counts
end

function Stock.crate(camp, entry)
    local square = World.square(entry.x, entry.y, entry.z or camp.z)
    if square == nil then return nil end
    return World.find(square, "storage", camp.id)
end

function Stock.takeFromContainer(container, kind, amount)
    local removed = 0
    pcall(function()
        local items = container:getItems()
        for i = items:size() - 1, 0, -1 do
            if removed >= amount then break end
            local item = items:get(i)
            local itemKind, itemAmount = Stock.classify(item)
            if itemKind == kind then
                container:Remove(item)
                removed = removed + itemAmount
            end
        end
    end)
    return removed
end

local function settle(entry, container)
    if type(entry.owe) == "table" then
        for kind, amount in pairs(entry.owe) do
            if amount > 0 then Stock.takeFromContainer(container, kind, amount) end
        end
        entry.owe = nil
    end
    if type(entry.add) == "table" then
        for fullType, count in pairs(entry.add) do
            pcall(function()
                for _ = 1, count do container:AddItem(fullType) end
            end)
        end
        entry.add = nil
    end
end

local uncapped = {}

local function bottomless(container, key)
    if uncapped[key] == container then return end
    pcall(function() container:setCapacity(Config.crateCapacity) end)
    uncapped[key] = container
end

function Stock.refresh(camp, maxAge)
    local now = Store.hours()
    if maxAge ~= nil and camp.stockAt ~= nil and now - camp.stockAt < maxAge and now >= camp.stockAt then return true end
    local anyLoaded = false
    for _, entry in ipairs(camp.storage) do
        local object = Stock.crate(camp, entry)
        if object ~= nil then
            anyLoaded = true
            local container
            pcall(function() container = object:getContainer() end)
            if container ~= nil then
                bottomless(container, entry.x .. "," .. entry.y .. "," .. tostring(entry.z or camp.z))
                settle(entry, container)
            end
            entry.stock = Stock.countContainer(container)
            entry.seen = now
        end
    end
    local total = Stock.empty()
    for _, entry in ipairs(camp.storage) do
        if type(entry.stock) == "table" then
            for _, kind in ipairs(Stock.kinds) do total[kind] = total[kind] + (entry.stock[kind] or 0) end
        end
    end
    camp.stock = total
    camp.stockAt = now
    return anyLoaded
end

function Stock.take(camp, kind, amount)
    local removed = 0
    for _, entry in ipairs(camp.storage) do
        if removed >= amount then break end
        local object = Stock.crate(camp, entry)
        if object ~= nil then
            local container
            pcall(function() container = object:getContainer() end)
            if container ~= nil then removed = removed + Stock.takeFromContainer(container, kind, amount - removed) end
        end
    end
    return removed
end

function Stock.consume(camp, kind, amount)
    local taken = Stock.take(camp, kind, amount)
    local left = amount - taken
    local abstract = 0
    if left > 0 then
        for _, entry in ipairs(camp.storage) do
            if left <= 0 then break end
            if Stock.crate(camp, entry) == nil and type(entry.stock) == "table" then
                local have = entry.stock[kind] or 0
                local use = math.min(have, left)
                if use > 0 then
                    entry.stock[kind] = have - use
                    entry.owe = entry.owe or {}
                    entry.owe[kind] = (entry.owe[kind] or 0) + use
                    left = left - use
                    abstract = abstract + use
                end
            end
        end
    end
    if camp.stock ~= nil then camp.stock[kind] = math.max(0, (camp.stock[kind] or 0) - taken - abstract) end
    return taken + abstract
end

function Stock.give(camp, fullType, count)
    for _, entry in ipairs(camp.storage) do
        local object = Stock.crate(camp, entry)
        if object ~= nil then
            local ok = false
            pcall(function()
                local container = object:getContainer()
                for _ = 1, count do container:AddItem(fullType) end
                ok = true
            end)
            if ok then return true end
        end
    end
    return false
end

function Stock.deposit(camp, fullType, count)
    if Stock.give(camp, fullType, count) then return true end
    local entry = camp.storage[1]
    if entry == nil then return false end
    entry.add = entry.add or {}
    entry.add[fullType] = (entry.add[fullType] or 0) + count
    return true
end

function Stock.consolidate(camp)
    local warehouse
    for _, entry in ipairs(camp.storage) do
        if entry.warehouse == true and Stock.crate(camp, entry) ~= nil then
            warehouse = entry
            break
        end
    end
    if warehouse == nil then return 0 end
    local target
    pcall(function() target = Stock.crate(camp, warehouse):getContainer() end)
    if target == nil then return 0 end
    local moved = 0
    for i = #camp.storage, 1, -1 do
        local entry = camp.storage[i]
        local object = entry ~= warehouse and entry.warehouse ~= true and Stock.crate(camp, entry) or nil
        local tag = object ~= nil and World.tag(object) or nil
        if object ~= nil and type(tag) == "table" and tag.project == nil then
            pcall(function()
                local container = object:getContainer()
                local items = container:getItems()
                for j = items:size() - 1, 0, -1 do
                    local item = items:get(j)
                    container:Remove(item)
                    target:AddItem(item)
                    moved = moved + 1
                end
            end)
            if type(entry.add) == "table" then
                warehouse.add = warehouse.add or {}
                for fullType, count in pairs(entry.add) do warehouse.add[fullType] = (warehouse.add[fullType] or 0) + count end
            end
            if World.remove(object) then table.remove(camp.storage, i) end
        end
    end
    if moved > 0 then Stock.refresh(camp) end
    return moved
end

if ALifeCamp.Hooks ~= nil then
    ALifeCamp.Hooks.add("minute", function(camp, minutes)
        camp.consolidateClock = (camp.consolidateClock or 0) + minutes
        if camp.consolidateClock < 10 then return end
        camp.consolidateClock = 0
        Stock.consolidate(camp)
    end, 5)
end

return Stock
