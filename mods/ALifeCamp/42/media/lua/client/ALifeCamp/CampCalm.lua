require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampWorld"

ALifeCamp = ALifeCamp or {}

local World = ALifeCamp.World

local Calm = {}
ALifeCamp.Calm = Calm

Calm.every = 15
Calm.quietMs = 20000
Calm.logMs = 30000
Calm.floor = 5
Calm.range = 30
Calm.realRange = 25
Calm.ticks = 0
Calm.realAt = -1000000
Calm.loggedAt = -1000000

local function now()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return 0
end

function Calm.kind(zombie)
    local owned, uid = false, nil
    pcall(function()
        local data = zombie:getModData()
        if type(data) == "table" and (data.ProjectALifeOwned == true or data.ProjectALifeActor == true) then
            owned, uid = true, data.ProjectALifeUID
        end
    end)
    if not owned then return "real" end
    local relations = ALifeCamp.Relations
    local record
    pcall(function() record = ProjectALife.ActorRegistry.peek(uid) end)
    if relations ~= nil and record ~= nil and relations.memberOf(record) ~= nil then return "settler" end
    return "npc"
end

function Calm.census(player)
    local out = { real = 0, npc = 0, settlers = 0 }
    local list
    pcall(function() list = player:getSpottedList() end)
    World.each(list, function(object)
        local zombie = false
        pcall(function() zombie = instanceof(object, "IsoZombie") end)
        if zombie then
            local kind = Calm.kind(object)
            if kind == "settler" then out.settlers = out.settlers + 1
            elseif kind == "npc" then out.npc = out.npc + 1
            else out.real = out.real + 1 end
        end
    end)
    return out
end

function Calm.nearSettlers(player)
    local count = 0
    local bindings
    pcall(function() bindings = ProjectALife.Watchdog.bindings end)
    if type(bindings) ~= "table" then return 0 end
    local relations = ALifeCamp.Relations
    local px, py = player:getX(), player:getY()
    for uid, binding in pairs(bindings) do
        local shell = type(binding) == "table" and binding.shell or nil
        if shell ~= nil and relations ~= nil then
            pcall(function()
                if math.abs(shell:getX() - px) <= Calm.range and math.abs(shell:getY() - py) <= Calm.range then
                    local record = ProjectALife.ActorRegistry.peek(uid)
                    if record ~= nil and relations.memberOf(record) ~= nil then count = count + 1 end
                end
            end)
        end
    end
    return count
end

function Calm.nearReal(player)
    local cell
    pcall(function() cell = getCell() end)
    if cell == nil then return 0 end
    local list
    pcall(function() list = cell:getZombieList() end)
    local px, py = player:getX(), player:getY()
    local count = 0
    World.each(list, function(zombie)
        pcall(function()
            if math.abs(zombie:getX() - px) <= Calm.realRange and math.abs(zombie:getY() - py) <= Calm.realRange
                    and not zombie:isDead() and Calm.kind(zombie) ~= "settler" then
                count = count + 1
            end
        end)
    end)
    return count
end

function Calm.check(player)
    local stats
    pcall(function() stats = player:getStats() end)
    if stats == nil then return false end
    local panic = 0
    pcall(function() panic = tonumber(stats:get(CharacterStat.PANIC)) or 0 end)
    if panic <= Calm.floor then return false end
    local seen = Calm.census(player)
    local stamp = now()
    if seen.real > 0 or seen.npc > 0 then Calm.realAt = stamp end
    local settlers = seen.settlers
    if settlers == 0 then settlers = Calm.nearSettlers(player) end
    local visible, chasing = 0, 0
    pcall(function()
        visible = stats:getNumVisibleZombies()
        chasing = stats:getNumChasingZombies()
    end)
    local verdict = "keep"
    if seen.real == 0 and seen.npc == 0 and settlers > 0 and stamp - Calm.realAt >= Calm.quietMs then
        local near = Calm.nearReal(player)
        if near == 0 then
            verdict = "calm"
        else
            Calm.realAt = stamp
            verdict = "zombie"
        end
    end
    if stamp - Calm.loggedAt >= Calm.logMs then
        Calm.loggedAt = stamp
        print("[ALifeCamp] panic=" .. tostring(math.floor(panic)) .. " visible=" .. tostring(visible) .. " chasing=" .. tostring(chasing)
            .. " real=" .. tostring(seen.real) .. " npc=" .. tostring(seen.npc) .. " settlers=" .. tostring(settlers) .. " -> " .. verdict)
    end
    if verdict ~= "calm" then return false end
    local done = false
    pcall(function()
        stats:set(CharacterStat.PANIC, 0)
        done = true
    end)
    return done
end

function Calm.onUpdate(player)
    Calm.ticks = Calm.ticks + 1
    if Calm.ticks < Calm.every then return end
    Calm.ticks = 0
    if player == nil then return end
    local ok, err = pcall(Calm.check, player)
    if not ok and not Calm.failed then
        Calm.failed = true
        print("[ALifeCamp] calm failed: " .. tostring(err))
    end
end

local function timed(label, fn)
    local hooks = ALifeCamp.Hooks
    if hooks ~= nil and type(hooks.timed) == "function" then return hooks.timed(label, fn) end
    return fn
end

Events.OnPlayerUpdate.Add(timed("calm.update", Calm.onUpdate))

return Calm
