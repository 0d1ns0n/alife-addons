require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampStock"
require "ALifeCamp/Camp"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Stock = ALifeCamp.Stock

local Director = { tickCount = 0 }
ALifeCamp.Director = Director

Director.steps = {}

function Director.step(camp, elapsed)
    Stock.refresh(camp, 0.05)
    camp.population = Store.settlerCount(camp)
    for _, step in ipairs(Director.steps) do
        local ok, err = pcall(step, camp, elapsed)
        if not ok then print("[ALifeCamp] step failed: " .. tostring(err)) end
    end
end

function Director.everyMinute()
    local hours = Store.hours()
    for _, camp in ipairs(Store.list()) do
        local elapsed = math.max(0, hours - (camp.lastHour or hours))
        camp.lastHour = hours
        camp.stats.days = Store.day(camp)
        local ok, err = pcall(Director.step, camp, elapsed)
        if not ok then print("[ALifeCamp] camp " .. tostring(camp.id) .. " failed: " .. tostring(err)) end
    end
end

function Director.onStart()
    local count = Store.count()
    print("[ALifeCamp] loaded, camps: " .. tostring(count))
    for _, camp in ipairs(Store.list()) do camp.lastHour = Store.hours() end
end

Events.OnGameStart.Add(Director.onStart)
Events.EveryOneMinute.Add(ALifeCamp.Hooks ~= nil and ALifeCamp.Hooks.timed("director.minute", Director.everyMinute) or Director.everyMinute)

return Director
