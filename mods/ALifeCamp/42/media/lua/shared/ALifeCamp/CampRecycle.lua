require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock

local Recycle = {}
ALifeCamp.Recycle = Recycle

Recycle.rules = {
    Clothing = "rags", Accessory = "rags", Bag = "rags", ProtectiveGear = "rags", Appearance = "rags",
    Memento = "rags", Camping = "rags", Fishing = "rags",
    Literature = "paper", Cartography = "paper",
    Junk = "scrap", Tool = "scrap", ToolWeapon = "scrap", MaterialWeapon = "scrap", JunkWeapon = "scrap",
    HouseholdWeapon = "scrap", GardeningWeapon = "scrap", CookingWeapon = "scrap", Cooking = "scrap",
    Electronics = "scrap", Communications = "scrap", Security = "scrap", Paint = "scrap", LightSource = "scrap",
    VehicleMaintenance = "scrap", Trapping = "scrap", Household = "scrap", Container = "scrap",
    Furniture = "wood", WeaponCrafted = "wood", SportsWeapon = "wood", InstrumentWeapon = "wood", Sports = "wood",
}

Recycle.yields = {
    rags = { "Base.RippedSheets", 3, 1, 6 },
    scrap = { "Base.ScrapMetal", 1.5, 1, 8 },
    wood = { "Base.Plank", 1, 1, 6 },
}

Recycle.extraNails = { scrap = 2 }
Recycle.rate = 5
Recycle.maxPerCall = 80
Recycle.forgeRate = 4
Recycle.nailsPerMetal = 6
Recycle.nailsPerPlank = 2
Recycle.nailFloor = 150
Recycle.plankFloor = 120
Recycle.kit = { { "Base.Nails", 120 }, { "Base.ScrapMetal", 12 }, { "Base.Rope", 6 }, { "Base.Plank", 30 } }
Recycle.mark = "ALCj"

local function categoryOf(item)
    local value = ""
    pcall(function() value = tostring(item:getDisplayCategory() or "") end)
    return value
end

local function weightOf(item)
    local weight = 0.5
    pcall(function() weight = tonumber(item:getActualWeight()) or weight end)
    return weight
end

function Recycle.ruleOf(item)
    local rule = Recycle.rules[categoryOf(item)]
    if rule == nil then return nil end
    if Stock.classify(item) ~= nil then return nil end
    return rule
end

function Recycle.flag(item)
    pcall(function() item:getModData()[Recycle.mark] = true end)
end

local function flagged(item)
    local value = false
    pcall(function() value = item:getModData()[Recycle.mark] == true end)
    return value
end

function Recycle.flagContainer(container)
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if Recycle.ruleOf(item) ~= nil then Recycle.flag(item) end
        end
    end)
end

function Recycle.migrate(camp)
    if camp.recycleReady then return end
    camp.recycleReady = true
    for _, entry in ipairs(camp.storage) do
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then
            local container
            pcall(function() container = crate:getContainer() end)
            if container ~= nil then Recycle.flagContainer(container) end
        end
    end
end

local function emptyBag(container, item)
    pcall(function()
        if not instanceof(item, "InventoryContainer") then return end
        local inner = item:getInventory()
        local list = inner:getItems()
        for i = list:size() - 1, 0, -1 do
            local sub = list:get(i)
            inner:Remove(sub)
            Recycle.flag(sub)
            container:AddItem(sub)
        end
    end)
end

local function amountOf(spec, item)
    local weight = weightOf(item)
    return math.max(spec[3], math.min(spec[4], math.floor(weight * spec[2] + 0.5)))
end

local function digest(container, budget, made)
    local count = 0
    local items = container:getItems()
    for i = items:size() - 1, 0, -1 do
        if count >= budget then break end
        local item = items:get(i)
        if item ~= nil and flagged(item) then
            local rule = Recycle.ruleOf(item)
            if rule ~= nil then
                local spec = Recycle.yields[rule]
                local fullType, amount
                if spec ~= nil then
                    fullType, amount = spec[1], amountOf(spec, item)
                end
                emptyBag(container, item)
                container:Remove(item)
                if fullType ~= nil then made[fullType] = (made[fullType] or 0) + amount end
                local nails = Recycle.extraNails[rule]
                if nails ~= nil then made["Base.Nails"] = (made["Base.Nails"] or 0) + nails end
                count = count + 1
            end
        end
    end
    return count
end

function Recycle.nailGoal(camp)
    local Build = ALifeCamp.Build
    local goal = Recycle.nailFloor
    if Build == nil then return goal end
    local need, shown = 0, 0
    for _, project in ipairs(Build.list(camp)) do
        if project.status ~= "done" and shown < 3 then
            local stage = Build.currentStage(project)
            if stage ~= nil then
                local cost = ALifeCamp.Blueprints.cost(Build.openOps(project, stage))
                need = need + (cost.nails or 0)
                shown = shown + 1
            end
        end
    end
    return math.max(goal, need)
end

function Recycle.plankReserve(camp)
    local Build = ALifeCamp.Build
    local reserve = Recycle.plankFloor
    if Build == nil then return reserve end
    local need, shown = 0, 0
    for _, project in ipairs(Build.list(camp)) do
        if project.status ~= "done" and shown < 3 then
            local stage = Build.currentStage(project)
            if stage ~= nil then
                local cost = ALifeCamp.Blueprints.cost(Build.openOps(project, stage))
                need = need + (cost.planks or 0)
                shown = shown + 1
            end
        end
    end
    return math.max(reserve, need * 2)
end

function Recycle.forge(camp, workers, minutes)
    local goal = Recycle.nailGoal(camp)
    local stock = camp.stock or {}
    local nails = stock.nails or 0
    if nails >= goal then return 0 end
    local budget = math.max(1, math.floor(workers * Recycle.forgeRate * minutes))
    local made = 0
    local metal = math.min(budget, stock.metal or 0)
    if metal > 0 then
        local taken = Stock.consume(camp, "metal", metal)
        if taken > 0 then
            Stock.deposit(camp, "Base.Nails", taken * Recycle.nailsPerMetal)
            made = made + taken * Recycle.nailsPerMetal
        end
    end
    if nails + made < goal then
        local spare = (stock.planks or 0) - Recycle.plankReserve(camp)
        local planks = math.min(budget * 2, spare)
        if planks > 0 then
            local taken = Stock.consume(camp, "planks", planks)
            if taken > 0 then
                Stock.deposit(camp, "Base.Nails", taken * Recycle.nailsPerPlank)
                made = made + taken * Recycle.nailsPerPlank
            end
        end
    end
    return made
end

function Recycle.step(camp, workers, minutes)
    if workers <= 0 then return 0, 0 end
    Recycle.migrate(camp)
    local budget = math.min(Recycle.maxPerCall, math.ceil(workers * Recycle.rate * minutes))
    local processed, made = 0, {}
    for _, entry in ipairs(camp.storage) do
        if processed >= budget then break end
        local crate = Stock.crate(camp, entry)
        if crate ~= nil then
            local container
            pcall(function() container = crate:getContainer() end)
            if container ~= nil then
                local ok, count = pcall(digest, container, budget - processed, made)
                if ok then processed = processed + count end
            end
        end
    end
    for fullType, amount in pairs(made) do Stock.deposit(camp, fullType, amount) end
    if processed > 0 then Stock.refresh(camp) end
    local forged = Recycle.forge(camp, workers, minutes)
    if forged > 0 then Stock.refresh(camp) end
    if processed > 0 then
        camp.recycledTotal = (camp.recycledTotal or 0) + processed
        camp.recycledLogged = camp.recycledLogged or 0
        if camp.recycledTotal - camp.recycledLogged >= 60 then
            camp.recycledLogged = camp.recycledTotal
            Store.log(camp, "recycled", camp.recycledTotal)
        end
    end
    return processed, forged
end

function Recycle.starterKit(camp)
    if camp.kitGiven then return false end
    if #camp.storage == 0 then return false end
    local loaded = false
    for _, entry in ipairs(camp.storage) do
        if Stock.crate(camp, entry) ~= nil then loaded = true end
    end
    if not loaded then return false end
    for _, row in ipairs(Recycle.kit) do Stock.deposit(camp, row[1], row[2]) end
    camp.kitGiven = true
    Stock.refresh(camp)
    Store.log(camp, "kit")
    return true
end

return Recycle
