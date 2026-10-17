require "ALifeCamp/CampConfig"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampEntities"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampTowerData"

ALifeCamp = ALifeCamp or {}

local Hooks = ALifeCamp.Hooks
local Store = ALifeCamp.Store
local Build = ALifeCamp.Build
local Bp = ALifeCamp.Blueprints

local Towers = {}
ALifeCamp.Towers = Towers

Towers.size = 6
local TILES = ALifeCamp.TowerTiles or {}
Towers.tiles = TILES

local knownSprites = {}
local function known(name)
    if name == nil then return false end
    if knownSprites[name] then return true end
    local ok, found = pcall(function() return getSprite(name) end)
    if ok and found == nil then return false end
    knownSprites[name] = true
    return true
end

local STAIR_N = { "carpentry_02_96", "carpentry_02_97", "carpentry_02_98" }
local STAIR_PILLAR = "carpentry_02_95"

local function towerStages(project)
    local X, Y = project.x, project.y
    local byz = {}
    local function bucket(z)
        local b = byz[z]
        if b == nil then b = {} byz[z] = b end
        return b
    end
    for i = 1, #TILES do
        local t = TILES[i]
        local dx, dy, z, sprite, isFloor = t[1], t[2], t[3], t[4], t[5]
        if known(sprite) then
            local b = bucket(z)
            local x, y = X + dx, Y + dy
            local slot = "T" .. z .. "_" .. dx .. "_" .. dy .. "_" .. (#b + 1)
            if isFloor == 1 then
                b[#b + 1] = { t = "floor", sprite = sprite, x = x, y = y, z = z, slot = slot }
            else
                b[#b + 1] = { t = "prop", sprite = sprite, x = x, y = y, z = z, slot = slot, cost = {} }
            end
        end
    end
    if Towers.stairPlan ~= nil then
        for _, op in ipairs(Towers.stairPlan(project)) do
            local b = bucket(op.z)
            b[#b + 1] = op
        end
    end
    local stages = {}
    for z = 0, 4 do
        if byz[z] ~= nil and #byz[z] > 0 then
            stages[#stages + 1] = { id = "z" .. z, ops = byz[z] }
        end
    end
    if #stages == 0 then stages[1] = { id = "z0", ops = {} } end
    return stages
end

Towers.stages = towerStages

Towers.ropeAnchor = { dx = 2, dy = 4, z = 3, north = true, sprite = "fixtures_windows_01_1" }

Towers.stairPlan = function(project)
    local a = Towers.ropeAnchor
    if a == nil then return {} end
    return {
        { t = "window", sprite = a.sprite, x = project.x + a.dx, y = project.y + a.dy, z = a.z, north = a.north, slot = "TROPEWIN" },
    }
end

local function wrap()
    local def = Bp.kinds and Bp.kinds.tower
    if def == nil then return false end
    def.w = Towers.size
    def.h = Towers.size
    if def.towerBuild == nil then def.towerBuild = def.build end
    def.build = function(project)
        local ok, stages = pcall(towerStages, project)
        if ok and type(stages) == "table" and #stages > 0 then return stages end
        if def.towerBuild ~= nil then return def.towerBuild(project) end
        return { { id = "z0", ops = {} } }
    end
    return true
end

Towers.wrapped = wrap()

local lastHour = {}
Hooks.add("minute", function(camp)
    local hour = math.floor(Store.hours())
    if lastHour[camp.id] == hour then return end
    lastHour[camp.id] = hour
    local count = 0
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "tower" and not project.retired then count = count + 1 end
    end
    print("[ALifeCamp:Towers] wrapped=" .. tostring(Towers.wrapped)
        .. " tiles=" .. tostring(#TILES) .. " towers=" .. count)
end, 72)

return Towers
