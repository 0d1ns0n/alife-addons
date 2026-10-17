require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampSettlers"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local Store = ALifeCamp.Store
local Settlers = ALifeCamp.Settlers

local Shells = {}
ALifeCamp.Shells = Shells

Shells.every = 5
Shells.logEvery = 1
Shells.cursor = 0
Shells.loggedAt = -1000

local function flag(shell, name)
    local value
    local ok = pcall(function() value = shell[name](shell) end)
    if not ok then return nil end
    return value
end

function Shells.anomalies(shell)
    local found = {}
    if flag(shell, "isUseless") == false then found[#found + 1] = "useless" end
    if flag(shell, "isNoTeeth") == false then found[#found + 1] = "teeth" end
    if flag(shell, "isFakeDead") == true then found[#found + 1] = "fakedead" end
    if flag(shell, "isReanimate") == true then found[#found + 1] = "reanimate" end
    if flag(shell, "isReanimatedPlayer") == true then found[#found + 1] = "reanimatedplayer" end
    if flag(shell, "isBecomeCrawler") == true then found[#found + 1] = "becomecrawler" end
    if flag(shell, "isCrawling") == true then found[#found + 1] = "crawling" end
    if flag(shell, "isCanWalk") == false then found[#found + 1] = "cantwalk" end
    return found
end

local function biting(shell)
    local open = false
    pcall(function()
        local data = shell:getModData()
        local until_ = type(data) == "table" and tonumber(data.ProjectALifeBiteUntilMs) or nil
        if until_ ~= nil and type(getTimestampMs) == "function" and getTimestampMs() < until_ then open = true end
    end)
    return open
end

function Shells.normalize(shell)
    if shell == nil then return false end
    pcall(function() shell:setUseless(true) end)
    pcall(function() shell:setNoTeeth(true) end)
    pcall(function() shell:setFakeDead(false) end)
    pcall(function() shell:setForceFakeDead(false) end)
    pcall(function() shell:setReanimate(false) end)
    pcall(function() shell:setReanimatedPlayer(false) end)
    pcall(function() shell:setBecomeCrawler(false) end)
    pcall(function() shell:setCrawler(false) end)
    pcall(function() shell:setCanWalk(true) end)
    pcall(function() shell:setTarget(nil) end)
    if not biting(shell) then pcall(function() shell:setZombiesDontAttack(true) end) end
    return true
end

function Shells.sweep(camp, force)
    local checked, fixed = 0, 0
    for uid in pairs(camp.settlers) do
        local shell = Settlers.shell(uid)
        if shell ~= nil then
            checked = checked + 1
            local found = Shells.anomalies(shell)
            if force or #found > 0 then
                Shells.normalize(shell)
                fixed = fixed + 1
                if #found > 0 then
                    print("[ALifeCamp:Shells] fixed " .. tostring(uid) .. " " .. table.concat(found, ","))
                end
            end
        end
    end
    return checked, fixed
end

function Shells.reset(camp)
    local checked, fixed = Shells.sweep(camp, true)
    return { checked = checked, fixed = fixed }
end

Hooks.add("minute", function(camp, minutes)
    Shells.cursor = Shells.cursor + (tonumber(minutes) or 0)
    if Shells.cursor < Shells.every then return end
    Shells.cursor = 0
    local checked, fixed = Shells.sweep(camp, false)
    local stamp = Store.hours()
    if stamp - Shells.loggedAt >= Shells.logEvery then
        Shells.loggedAt = stamp
        print("[ALifeCamp:Shells] checked=" .. tostring(checked) .. " fixed=" .. tostring(fixed))
    end
end, 70)

Hooks.add("arrived", function(camp, settler, uid)
    local shell = Settlers.shell(uid)
    if shell ~= nil then Shells.normalize(shell) end
end)

Options.action({
    key = "shells", priority = 20,
    run = function(camp)
        local result = Shells.reset(camp)
        local player = getPlayer ~= nil and getPlayer() or nil
        if player == nil then return end
        pcall(function() player:setHaloNote(ALifeCamp.T("ShellsDone", tostring(result.checked), tostring(result.fixed))) end)
    end,
})

return Shells
