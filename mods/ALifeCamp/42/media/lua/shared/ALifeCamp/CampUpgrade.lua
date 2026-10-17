require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampReset"
require "ALifeCamp/CampPlan"

ALifeCamp = ALifeCamp or {}

ALifeCamp.DESIGN_VERSION = 2

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Geo = ALifeCamp.Geo
local World = ALifeCamp.World

local Upgrade = {}
ALifeCamp.Upgrade = Upgrade

Upgrade.retryHours = 0.25

local nextTry = {}

local function enabled(camp)
    if camp == nil or type(camp.options) ~= "table" then return true end
    return camp.options.autoUpgrade ~= false
end
Upgrade.enabled = enabled

local function loadedCore(camp)
    local ok, yes = pcall(function()
        local cx, cy = Geo.center(camp)
        return World.loaded(cx, cy, camp.z)
    end)
    return ok and yes == true
end

function Upgrade.run(camp)
    local Reset = ALifeCamp.Reset
    local Plan = ALifeCamp.Plan
    if Reset == nil or Plan == nil then return false end
    local res
    local ok = pcall(function() res = Reset.run(camp) end)
    if not ok or type(res) ~= "table" or res.blocked == true then return false end
    pcall(function() Plan.generate(camp) end)
    camp.designVer = ALifeCamp.DESIGN_VERSION
    return true
end

Hooks.add("minute", function(camp)
    if camp == nil then return end
    if camp.designVer == ALifeCamp.DESIGN_VERSION then return end
    if not enabled(camp) then return end
    local now = Store.hours()
    if nextTry[camp.id] ~= nil and now < nextTry[camp.id] then return end
    nextTry[camp.id] = now + Upgrade.retryHours
    if not loadedCore(camp) then return end
    if Upgrade.run(camp) then
        print("[ALifeCamp:Upgrade] camp " .. tostring(camp.id) .. " -> design v" .. ALifeCamp.DESIGN_VERSION)
        pcall(function() Store.log(camp, "upgrade", ALifeCamp.DESIGN_VERSION) end)
    end
end, 4)

return Upgrade
