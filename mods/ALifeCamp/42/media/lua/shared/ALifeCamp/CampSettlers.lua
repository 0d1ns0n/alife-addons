require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampText"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local T = ALifeCamp.T

local Settlers = {}
ALifeCamp.Settlers = Settlers

Settlers.roles = { "builder", "farmer", "guard", "scavenger", "medic", "sanitary", "worker" }
Settlers.inviteLimit = 12
Settlers.tierCaps = { camp = 12, outpost = 20, village = 32, town = 52, city = 80 }

function Settlers.tierKey(camp)
    local key
    pcall(function()
        local Tiers = ALifeCamp.Tiers
        if Tiers == nil then return end
        local idx
        if type(camp.tier) == "number" then idx = camp.tier else idx = (Tiers.compute(camp)) end
        local spec = Tiers.ladder[idx] or Tiers.ladder[1]
        key = spec ~= nil and spec.key or nil
    end)
    return key
end

function Settlers.cap(camp)
    local key = Settlers.tierKey(camp)
    return (key ~= nil and Settlers.tierCaps[key]) or Settlers.inviteLimit
end

function Settlers.uncapped(camp)
    return type(camp.options) == "table" and camp.options.uncap == true
end

function Settlers.headcount(camp)
    local n = Store.settlerCount(camp)
    if type(camp.pending) == "table" then
        for _ in pairs(camp.pending) do n = n + 1 end
    end
    return n
end

function Settlers.full(camp)
    if Settlers.uncapped(camp) then return false end
    return Settlers.headcount(camp) >= Settlers.cap(camp)
end

local function alife()
    return ProjectALife
end

function Settlers.available()
    local a = alife()
    return a ~= nil and a.ActorRegistry ~= nil and a.DecisionLoop ~= nil
end

function Settlers.identity(shell)
    if shell == nil or not Settlers.available() then return nil end
    local uid, generation
    pcall(function()
        local data = shell:getModData()
        if type(data) == "table" and (data.ProjectALifeOwned == true or data.ProjectALifeActor == true) then
            uid = data.ProjectALifeUID
            generation = tonumber(data.ProjectALifeGeneration)
        end
    end)
    if type(uid) ~= "string" then return nil end
    local record = Settlers.record(uid)
    if record == nil or record.lifecycle == "dead" then return nil end
    return { uid = uid, generation = generation or record.generation, record = record }
end

function Settlers.record(uid)
    local record
    pcall(function() record = alife().ActorRegistry.peek(uid) end)
    return record
end

function Settlers.shell(uid)
    local shell
    pcall(function()
        local binding = alife().Watchdog.bindings[uid]
        if binding ~= nil then shell = binding.shell end
    end)
    return shell
end

function Settlers.alive(uid)
    local record = Settlers.record(uid)
    return record ~= nil and record.lifecycle ~= "dead"
end

function Settlers.stance(record, player)
    local stance
    pcall(function() stance = alife().Relations.playerStance(record, player) end)
    return stance or "neutral"
end

function Settlers.patch(uid, mutation)
    local ok, result = pcall(function()
        local registry = alife().ActorRegistry
        local record = registry.peek(uid)
        if record == nil then return false end
        return registry.update(uid, record.revision, mutation) ~= nil
    end)
    return ok and result == true
end

function Settlers.name(identity, shell)
    local name
    pcall(function()
        local descriptor = shell:getDescriptor()
        if descriptor ~= nil then
            local forename = descriptor:getForename()
            local surname = descriptor:getSurname()
            if forename ~= nil and forename ~= "" then name = forename end
            if name ~= nil and surname ~= nil and surname ~= "" then name = name .. " " .. surname end
        end
    end)
    if name == nil then
        pcall(function()
            local profile = alife().Catalog.npc(identity.record.profileId)
            name = profile and profile.general and profile.general.name
        end)
    end
    return name and tostring(name) or tostring(identity.uid)
end

function Settlers.order(uid, kind, anchor, quiet)
    if not Settlers.available() then return false end
    local record = Settlers.record(uid)
    if record == nil or record.lifecycle ~= "active" then return false end
    local order = { kind = kind, source = "player", quiet = quiet ~= false }
    if kind == "follow" then
        order.player = getPlayer()
    else
        order.anchor = { x = anchor.x, y = anchor.y, z = anchor.z or 0 }
        if kind == "hold" then order.source = "leader" end
    end
    local ok, accepted = pcall(function()
        return alife().DecisionLoop.setOrder(uid, record.generation, order)
    end)
    return ok and accepted == true
end

function Settlers.release(uid)
    pcall(function()
        local orders = alife().DecisionLoop.orders
        if type(orders) == "table" then orders[uid] = nil end
    end)
end

function Settlers.say(shell, key, ...)
    if shell == nil then return end
    local text = T(key, ...)
    pcall(function() shell:addLineChatElement(text, 0.6, 0.95, 0.6) end)
end

function Settlers.canInvite(player, shell, camp)
    local identity = Settlers.identity(shell)
    if identity == nil then return false, "notactor" end
    if camp.settlers[identity.uid] ~= nil then return false, "already" end
    if camp.pending ~= nil and camp.pending[identity.uid] ~= nil then return false, "pending" end
    if Settlers.full(camp) then return false, "full" end
    local stance = Settlers.stance(identity.record, player)
    if stance == "hostile" then return false, "hostile" end
    return true, stance, identity
end

function Settlers.acceptChance(camp, stance)
    if stance == "friendly" then return 1 end
    local chance = stance == "careful" and 0.2 or 0.55
    local people = math.max(1, Store.settlerCount(camp))
    local stock = camp.stock or {}
    if (stock.food or 0) > 2000 * people then chance = chance + 0.15 end
    if (camp.level or 1) >= 2 then chance = chance + 0.1 end
    return math.min(0.95, chance)
end

function Settlers.invite(player, shell, camp)
    local ok, why, identity = Settlers.canInvite(player, shell, camp)
    if not ok then return false, why end
    local chance = Settlers.acceptChance(camp, why)
    local roll = ZombRand ~= nil and ZombRand(100) / 100 or math.random()
    if roll > chance then
        Settlers.say(shell, "Refuse")
        return false, "refused"
    end
    local name = Settlers.name(identity, shell)
    local work = ALifeCamp.Work
    local role = work ~= nil and work.pickRole(camp) or "worker"
    local settler = Settlers.settle(camp, identity.uid, name)
    settler.role = role
    local cx, cy = Geo.center(camp)
    local anchor = work ~= nil and work.center(camp) or { x = cx, y = cy, z = camp.z }
    Settlers.order(identity.uid, "patrol", anchor, false)
    Settlers.say(shell, "Accept", camp.name)
    Store.log(camp, "invited", name)
    if work ~= nil then work.notify(camp, "Arrived", name) end
    return true
end

function Settlers.cancelInvite(camp, uid)
    if camp.pending == nil then return end
    camp.pending[uid] = nil
    Settlers.release(uid)
    Settlers.patch(uid, function(record)
        if type(record.memory) == "table" then record.memory.campInvite = nil end
    end)
end

function Settlers.settle(camp, uid, name)
    camp.pending = camp.pending or {}
    camp.pending[uid] = nil
    camp.settlers[uid] = { name = name or uid, role = "worker", since = Store.hours() }
    Settlers.patch(uid, function(record)
        local memory = type(record.memory) == "table" and record.memory or {}
        record.memory = memory
        memory.campInvite = nil
        memory.camp = camp.id
        memory.persistent = true
        memory.hostileOverride = false
        memory.spawnStance = "friendly"
    end)
    camp.stats.arrived = camp.stats.arrived + 1
    Store.log(camp, "settled", camp.settlers[uid].name)
    if ALifeCamp.Hooks ~= nil then ALifeCamp.Hooks.each("arrived", camp, camp.settlers[uid], uid) end
    return camp.settlers[uid]
end

function Settlers.dismiss(camp, uid)
    local settler = camp.settlers[uid]
    if settler == nil then return false end
    camp.settlers[uid] = nil
    Settlers.release(uid)
    Settlers.patch(uid, function(record)
        if type(record.memory) == "table" then
            record.memory.camp = nil
            record.memory.campInvite = nil
        end
    end)
    camp.stats.left = camp.stats.left + 1
    Store.log(camp, "left", settler.name)
    if ALifeCamp.Hooks ~= nil then ALifeCamp.Hooks.each("left", camp, settler, uid) end
    return true
end

function Settlers.where(uid)
    local shell = Settlers.shell(uid)
    if shell ~= nil then
        local x, y, z
        pcall(function() x, y, z = shell:getX(), shell:getY(), shell:getZ() end)
        if x ~= nil then return x, y, z, true end
    end
    local record = Settlers.record(uid)
    if record ~= nil and record.worldPosition ~= nil then
        return record.worldPosition.x, record.worldPosition.y, record.worldPosition.z, false
    end
    return nil
end

function Settlers.inside(camp, uid)
    local x, y = Settlers.where(uid)
    if x == nil then return false end
    return Geo.contains(camp, math.floor(x), math.floor(y))
end

function Settlers.counts(camp)
    local out = { total = 0, present = 0, builder = 0, farmer = 0, guard = 0, scavenger = 0, medic = 0, worker = 0 }
    for uid, settler in pairs(camp.settlers) do
        out.total = out.total + 1
        out[settler.role or "worker"] = (out[settler.role or "worker"] or 0) + 1
        if Settlers.inside(camp, uid) then out.present = out.present + 1 end
    end
    return out
end

function Settlers.setRole(camp, uid, role)
    local settler = camp.settlers[uid]
    if settler == nil then return false end
    settler.role = role
    return true
end

return Settlers
