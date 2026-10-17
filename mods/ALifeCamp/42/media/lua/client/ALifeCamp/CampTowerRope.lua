require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampTowers"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Build = ALifeCamp.Build

local Rope = {}
ALifeCamp.TowerRope = Rope

Rope.range = 40

local function windowAt(square)
    local win
    pcall(function()
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if instanceof(o, "IsoWindow") or instanceof(o, "IsoWindowFrame") then win = o break end
        end
    end)
    return win
end

local function tieOne(project, player)
    local a = ALifeCamp.Towers and ALifeCamp.Towers.ropeAnchor
    if a == nil then return false end
    local wx, wy, wz = project.x + a.dx, project.y + a.dy, a.z
    local square = World.square(wx, wy, wz)
    if square == nil then return false end
    local win = windowAt(square)
    if win == nil then return false end
    local done = false
    pcall(function()
        if win.haveSheetRope ~= nil and win:haveSheetRope() then
            project.roped = true
            done = true
            return
        end
        local need = 4
        pcall(function() need = win:countAddSheetRope() or 4 end)
        if need < 1 then need = 4 end
        local inv = player:getInventory()
        for _ = 1, need do pcall(function() inv:AddItem("Base.SheetRope") end) end
        win:addSheetRope(player, "SheetRope")
        project.roped = true
        done = true
    end)
    return done
end

function Rope.sweep()
    local player = getPlayer()
    if player == nil then return end
    local camps = Store.list()
    if type(camps) ~= "table" then return end
    local px, py = player:getX(), player:getY()
    for _, camp in ipairs(camps) do
        for _, project in pairs(Build.plan(camp).items) do
            if project.kind == "tower" and project.status == "done" and not project.roped and not project.retired then
                if math.abs(px - project.x) + math.abs(py - project.y) < Rope.range then
                    pcall(tieOne, project, player)
                end
            end
        end
    end
end

if Events ~= nil and Events.EveryOneMinute ~= nil then
    Events.EveryOneMinute.Add(function() pcall(Rope.sweep) end)
end

return Rope
