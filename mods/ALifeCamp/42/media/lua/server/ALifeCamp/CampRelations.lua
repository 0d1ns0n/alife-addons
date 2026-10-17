require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store

local Rel = {}
ALifeCamp.Relations = Rel

function Rel.memberOf(record)
    if type(record) ~= "table" then return nil end
    local memory = record.memory
    if type(memory) ~= "table" or memory.camp == nil then return nil end
    local camp = Store.get(memory.camp)
    if camp == nil or type(camp.settlers) ~= "table" or camp.settlers[record.uid] == nil then return nil end
    return camp
end

local function regard(observed)
    local relations = ProjectALife ~= nil and ProjectALife.Relations or nil
    if relations == nil or type(relations.playerStance) ~= "function" then return "neutral" end
    local player = getPlayer ~= nil and getPlayer() or nil
    local ok, stance = pcall(relations.playerStance, observed, player)
    if ok and type(stance) == "string" then return stance end
    return "neutral"
end

local function mirror(observed)
    local stance = regard(observed)
    if stance == "hostile" then return "hostile" end
    if stance == "friendly" then return "friendly" end
    return "neutral"
end

Rel.logged = {}

local function grudge(source, target, why)
    local key = tostring(source.uid) .. ">" .. tostring(target.uid)
    local stamp = ALifeCamp.Store.hours()
    if Rel.logged[key] ~= nil and stamp - Rel.logged[key] < 0.25 then return end
    Rel.logged[key] = stamp
    print("[ALifeCamp] relation: " .. tostring(source.factionId) .. " " .. tostring(source.uid) .. " -> " .. tostring(target.factionId)
        .. " " .. tostring(target.uid) .. " hostile by " .. why)
end

function Rel.verdict(source, target)
    local sourceCamp, targetCamp = Rel.memberOf(source), Rel.memberOf(target)
    if sourceCamp == nil and targetCamp == nil then return nil end
    if sourceCamp ~= nil and targetCamp ~= nil then return "friendly" end
    if sourceCamp ~= nil then
        local memory = source.memory
        local grudges = type(memory) == "table" and memory.hostileToActorKeys or nil
        if type(grudges) == "table" and grudges[target.uid] == true then
            grudge(source, target, "grudge")
            return "hostile"
        end
        return mirror(target)
    end
    local grudges = type(source.memory) == "table" and source.memory.hostileToActorKeys or nil
    if type(grudges) == "table" and grudges[target.uid] == true then
        grudge(source, target, "grudge")
        return "hostile"
    end
    local verdict = mirror(source)
    if verdict == "hostile" then grudge(source, target, "stance to the player") end
    return verdict
end

Rel.patched = false

function Rel.patch()
    if Rel.patched then return true end
    local relations = ProjectALife ~= nil and ProjectALife.Relations or nil
    if relations == nil or type(relations.status) ~= "function" then return false end
    local original = relations.status
    relations.status = function(source, target)
        if relations.warfare == false then return original(source, target) end
        local ok, verdict = pcall(Rel.verdict, source, target)
        if ok and verdict ~= nil then return verdict end
        return original(source, target)
    end
    Rel.original = original
    Rel.patched = true
    print("[ALifeCamp] camp settlers now share the player's side in A-Life relations")
    return true
end

Rel.patch()

Events.OnGameStart.Add(Rel.patch)
Events.EveryOneMinute.Add(function()
    if not Rel.patched then Rel.patch() end
end)

return Rel
