require "ALifeCamp/CampStore"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampBlueprints"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store
local Settlers = ALifeCamp.Settlers
local Build = ALifeCamp.Build
local Bp = ALifeCamp.Blueprints

local BuildAnim = {}
ALifeCamp.BuildAnim = BuildAnim

BuildAnim.period = 2500
BuildAnim.reach = 1
BuildAnim.work = { "board_up", "board_up", "forage", "search_mid", "search_low" }

local last = 0

local function clock()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return math.floor(os.time() * 1000)
end

local function animations()
    local pa = _G.ProjectALife
    if pa == nil or type(pa.Animations) ~= "table" or type(pa.Animations.apply) ~= "function" then return nil end
    return pa.Animations
end

local function nearActive(camp, sx, sy)
    for _, project in pairs(Build.plan(camp).items) do
        if project.status ~= "done" and project.kind ~= "fence" and not project.retired then
            local ok, r = pcall(Bp.footprint, project)
            if ok and type(r) == "table"
                and sx >= r.x1 - BuildAnim.reach and sx <= r.x2 + BuildAnim.reach
                and sy >= r.y1 - BuildAnim.reach and sy <= r.y2 + BuildAnim.reach then
                return true
            end
        end
    end
    return false
end

function BuildAnim.tick()
    local now = clock()
    if now - last < BuildAnim.period then return end
    last = now
    local anims = animations()
    if anims == nil then return end
    local camps = Store.list()
    if type(camps) ~= "table" then return end
    for _, camp in ipairs(camps) do
        if type(camp.settlers) == "table" then
            for uid, settler in pairs(camp.settlers) do
                local role = settler.role or "worker"
                if role == "builder" or role == "worker" then
                    local shell = Settlers.shell(uid)
                    if shell ~= nil then
                        local ok, sx, sy = pcall(function()
                            return math.floor(shell:getX()), math.floor(shell:getY())
                        end)
                        if ok and sx ~= nil and nearActive(camp, sx, sy) then
                            local salt = math.abs(tonumber(uid) or #uid or 0)
                            local idx = (salt + math.floor(now / 4000)) % #BuildAnim.work + 1
                            pcall(anims.apply, shell, BuildAnim.work[idx])
                        end
                    end
                end
            end
        end
    end
end

if Events ~= nil and Events.OnTick ~= nil then
    local hooks = ALifeCamp.Hooks
    local run = function() pcall(BuildAnim.tick) end
    if hooks ~= nil and type(hooks.timed) == "function" then run = hooks.timed("buildanim.tick", run) end
    Events.OnTick.Add(run)
end

return BuildAnim
