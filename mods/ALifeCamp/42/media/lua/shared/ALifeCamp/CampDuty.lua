require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampHooks"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Settlers = ALifeCamp.Settlers
local Hooks = ALifeCamp.Hooks
local Options = ALifeCamp.Options
local T = ALifeCamp.T

local Duty = {}
ALifeCamp.Duty = Duty

Duty.arriveRange = 2.5
Duty.resendHours = 0.17

Options.define({ key = "stations", group = "camp", priority = 16, default = true })
Options.define({ key = "sorties", group = "people", priority = 12, default = true })

Duty.lootMinutes = 20

local function hash(text)
    local h = 0
    text = tostring(text)
    for i = 1, #text do h = (h * 31 + string.byte(text, i)) % 1000003 end
    return h
end

Duty.hash = hash

local function enabled(camp)
    return Options.on(camp, "stations")
end

function Duty.enabled(camp)
    return enabled(camp)
end

function Duty.free(x, y, z, indoor)
    local square = World.square(x, y, z)
    if square == nil then return true end
    local ok = true
    pcall(function()
        if square:isFree(false) ~= true then
            ok = false
            return
        end
        if not indoor and square:isOutside() ~= true then ok = false end
    end)
    return ok
end

function Duty.begin(camp)
    Duty.claimed = { camp = camp.id, tiles = {} }
end

local function claim(uid, x, y, z)
    local claimed = Duty.claimed
    if claimed == nil then return true end
    local key = x .. "," .. y .. "," .. z
    local owner = claimed.tiles[key]
    if owner ~= nil and owner ~= uid then return false end
    claimed.tiles[key] = uid
    return true
end

local function score(uid, x, y)
    return (hash(uid) * 31 + math.abs(x) * 73856093 + math.abs(y) * 19349663) % 1009
end

local function choose(camp, uid, tiles, z, indoor, last)
    table.sort(tiles, function(a, b)
        local da, db = a.d or 0, b.d or 0
        if da ~= db then return da < db end
        local sa, sb = score(uid, a.x, a.y), score(uid, b.x, b.y)
        if sa ~= sb then return sa < sb end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    if last ~= nil then
        for _, tile in ipairs(tiles) do
            if tile.x == last.x and tile.y == last.y and Duty.free(tile.x, tile.y, z, indoor) and claim(uid, tile.x, tile.y, z) then
                return { x = tile.x, y = tile.y, z = z, exact = true, indoor = indoor }
            end
        end
    end
    for _, tile in ipairs(tiles) do
        if Duty.free(tile.x, tile.y, z, indoor) and claim(uid, tile.x, tile.y, z) then
            return { x = tile.x, y = tile.y, z = z, exact = true, indoor = indoor }
        end
    end
    local first = tiles[1]
    if first == nil then return nil end
    return { x = first.x, y = first.y, z = z, exact = true, indoor = indoor }
end

local function inRect(rect, x, y)
    return rect == nil or (x >= rect.x1 and x <= rect.x2 and y >= rect.y1 and y <= rect.y2)
end

function Duty.ring(camp, center, uid, inner, outer, indoor, anywhere)
    if center == nil then return nil end
    local z = math.floor(center.z or camp.z or 0)
    local cx, cy = math.floor(center.x), math.floor(center.y)
    inner = math.max(0, inner or 1)
    outer = math.max(inner, outer or (inner + 2))
    local tiles = {}
    for dx = -outer, outer do
        for dy = -outer, outer do
            local d = math.max(math.abs(dx), math.abs(dy))
            local x, y = cx + dx, cy + dy
            if d >= inner and d <= outer and inRect(center.rect, x, y) and (anywhere == true or Geo.contains(camp, x, y)) then
                tiles[#tiles + 1] = { x = x, y = y, d = d }
            end
        end
    end
    if #tiles == 0 then return { x = cx, y = cy, z = z, exact = true, indoor = indoor } end
    local settler = camp.settlers ~= nil and camp.settlers[uid] or nil
    local last = settler ~= nil and settler.station or nil
    return choose(camp, uid, tiles, z, indoor, last)
end

function Duty.inside(camp, rect, uid, z, indoor)
    local tiles = {}
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            tiles[#tiles + 1] = { x = x, y = y, d = 0 }
        end
    end
    local settler = camp.settlers ~= nil and camp.settlers[uid] or nil
    local last = settler ~= nil and settler.station or nil
    return choose(camp, uid, tiles, z or camp.z, indoor, last)
end

function Duty.edge(camp, rect, uid, gap)
    gap = gap or 1
    local tiles = {}
    local x1, y1, x2, y2 = rect.x1 - gap, rect.y1 - gap, rect.x2 + gap, rect.y2 + gap
    for x = x1, x2 do
        for y = y1, y2 do
            if (x == x1 or x == x2 or y == y1 or y == y2) and Geo.contains(camp, x, y) then
                tiles[#tiles + 1] = { x = x, y = y, d = 0 }
            end
        end
    end
    if #tiles == 0 then return nil end
    local settler = camp.settlers ~= nil and camp.settlers[uid] or nil
    local last = settler ~= nil and settler.station or nil
    return choose(camp, uid, tiles, camp.z, false, last)
end

function Duty.rectOf(project)
    return { x1 = project.x, y1 = project.y, x2 = project.x + project.w - 1, y2 = project.y + project.h - 1 }
end

function Duty.projects(camp)
    local Build = ALifeCamp.Build
    local out = {}
    if Build == nil then return out end
    local ok, plan = pcall(Build.plan, camp)
    if not ok or type(plan) ~= "table" or type(plan.items) ~= "table" then return out end
    for _, project in pairs(plan.items) do
        if not project.retired then out[#out + 1] = project end
    end
    table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
    return out
end

function Duty.firstDone(camp, kind)
    for _, project in ipairs(Duty.projects(camp)) do
        if project.kind == kind and project.status == "done" then return project end
    end
    return nil
end

function Duty.campfire(camp)
    local project = Duty.firstDone(camp, "campfire")
    if project == nil then return nil end
    return { x = project.x + 1, y = project.y + 1, z = camp.z }
end

function Duty.mess(camp)
    local canteen = Duty.firstDone(camp, "canteen")
    if canteen ~= nil then
        local rect = Duty.rectOf(canteen)
        return {
            x = math.floor((rect.x1 + rect.x2) / 2), y = math.floor((rect.y1 + rect.y2) / 2), z = camp.z,
            rect = rect, indoor = true, kind = "canteen",
        }
    end
    local fire = Duty.campfire(camp)
    if fire ~= nil then
        fire.kind = "campfire"
        return fire
    end
    local cx, cy = Geo.center(camp)
    return { x = cx, y = cy, z = camp.z, kind = "center" }
end

function Duty.night()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return hour >= 22 or hour < 6
end

function Duty.barracks(camp, uid)
    if camp.raid ~= nil or not Duty.night() then return nil end
    local barracks = Duty.firstDone(camp, "barracks")
    if barracks == nil then return nil end
    local spot = Duty.inside(camp, Duty.rectOf(barracks), uid, camp.z, true)
    if spot ~= nil then spot.kind = "home" end
    return spot
end

function Duty.depot(camp)
    local entry = camp.storage ~= nil and camp.storage[1] or nil
    if entry == nil then
        local cx, cy = Geo.center(camp)
        return { x = cx, y = cy, z = camp.z }
    end
    return { x = entry.x, y = entry.y, z = entry.z or camp.z }
end

function Duty.homes(camp)
    local Stats = ALifeCamp.Stats
    local beds = Stats ~= nil and Stats.beds or { house_s = 2, house_m = 4, house_l = 6 }
    local out = {}
    for _, project in ipairs(Duty.projects(camp)) do
        local count = beds[project.kind]
        if project.status == "done" and count ~= nil and project.kind ~= "campfire" then
            out[#out + 1] = { project = project, beds = count }
        end
    end
    return out
end

local function occupancy(camp)
    local taken = {}
    local uids = {}
    for uid in pairs(camp.settlers) do uids[#uids + 1] = uid end
    table.sort(uids)
    for _, uid in ipairs(uids) do
        local home = camp.settlers[uid].home
        if type(home) == "table" then
            local key = tostring(home.p) .. ":" .. tostring(home.s)
            if taken[key] == nil then taken[key] = uid end
        end
    end
    return taken
end

function Duty.home(camp, uid)
    local settler = camp.settlers[uid]
    if settler == nil then return nil end
    local sleeping = Duty.barracks(camp, uid)
    if sleeping ~= nil then return sleeping end
    local homes = Duty.homes(camp)
    if #homes == 0 then
        settler.home = nil
        return nil
    end
    local taken = occupancy(camp)
    local home = settler.home
    local valid = false
    local chosen
    if type(home) == "table" then
        for _, row in ipairs(homes) do
            if row.project.id == home.p and home.s >= 1 and home.s <= row.beds and taken[tostring(home.p) .. ":" .. tostring(home.s)] == uid then
                valid, chosen = true, row
            end
        end
    end
    if not valid then
        settler.home = nil
        for _, row in ipairs(homes) do
            for slot = 1, row.beds do
                local key = tostring(row.project.id) .. ":" .. tostring(slot)
                if taken[key] == nil and settler.home == nil then
                    settler.home = { p = row.project.id, s = slot }
                    chosen = row
                end
            end
        end
    end
    if settler.home == nil or chosen == nil then return nil end
    local spot = Duty.inside(camp, Duty.rectOf(chosen.project), uid, camp.z, true)
    if spot ~= nil then spot.kind = "home" end
    return spot
end

function Duty.context(camp)
    local ctx = { camp = camp, farms = {}, active = {}, posts = {}, gates = {} }
    local projects = Duty.projects(camp)
    ctx.projects = projects
    local byId = {}
    for _, project in ipairs(projects) do
        byId[project.id] = project
        if project.kind == "farm" and project.status == "done" then ctx.farms[#ctx.farms + 1] = project end
        if project.kind == "garage" and project.status == "done" then ctx.garage = ctx.garage or project end
        if project.kind == "motorpool" and project.status == "done" then ctx.motorpool = ctx.motorpool or project end
        if project.kind == "range" and project.status == "done" then ctx.range = ctx.range or project end
    end
    if camp.phase == "build" and type(camp.active) == "table" then
        for _, id in ipairs(camp.active) do
            local project = byId[id]
            if project ~= nil and project.kind ~= "fence" and project.status ~= "done" then
                ctx.active[#ctx.active + 1] = project
            end
        end
    end
    ctx.depot = Duty.depot(camp)
    ctx.campfire = Duty.campfire(camp)
    local cx, cy = Geo.center(camp)
    ctx.center = { x = cx, y = cy, z = camp.z }
    return ctx
end

local function rank(camp, uid, role)
    local list = {}
    for other, settler in pairs(camp.settlers) do
        if (settler.role or "worker") == role then list[#list + 1] = other end
    end
    table.sort(list)
    for index, other in ipairs(list) do
        if other == uid then return index, #list end
    end
    return 1, 1
end

function Duty.postFor(camp, uid, settler, posts)
    if #posts == 0 then return nil end
    local load = {}
    local guards = 0
    for other, row in pairs(camp.settlers) do
        if (row.role or "worker") == "guard" then
            guards = guards + 1
            if type(row.post) == "string" then load[row.post] = (load[row.post] or 0) + 1 end
        end
    end
    local target = math.max(1, math.ceil(guards / #posts))
    local key = type(settler.post) == "string" and settler.post or nil
    if key ~= nil and (load[key] or 0) <= target then
        for _, point in ipairs(posts) do
            if point.x .. "," .. point.y == key then return point end
        end
    end
    if key ~= nil then load[key] = math.max(0, (load[key] or 1) - 1) end
    local best, bestLoad
    for _, point in ipairs(posts) do
        local used = load[point.x .. "," .. point.y] or 0
        if bestLoad == nil or used < bestLoad then best, bestLoad = point, used end
    end
    if best ~= nil then settler.post = best.x .. "," .. best.y end
    return best
end

local function stationOf(kind, spot)
    if spot == nil then return nil end
    spot.kind = spot.kind or kind
    return spot
end

function Duty.station(camp, uid, settler, ctx)
    if not enabled(camp) then return nil end
    ctx = ctx or Duty.context(camp)
    local role = settler.role or "worker"
    if camp.raid ~= nil then return nil end
    if role == "guard" then
        local post = Duty.postFor(camp, uid, settler, ctx.posts or {})
        if post ~= nil then return stationOf("post", Duty.ring(camp, post, uid, 0, 1)) end
    end
    local sleeping = Duty.barracks(camp, uid)
    if sleeping ~= nil then return sleeping end
    if settler.job == "lumber" and ALifeCamp.Supply ~= nil then
        local target = ALifeCamp.Supply.target(camp)
        if target ~= nil then return stationOf("lumber", Duty.ring(camp, target, uid, 1, 2, false, true)) end
        return stationOf("depot", Duty.ring(camp, ctx.depot, uid, 1, 3))
    end
    if camp.phase == "clear" then
        local last = camp.clear ~= nil and camp.clear.last or nil
        local base = last ~= nil and { x = last.x, y = last.y, z = camp.z } or ctx.center
        return stationOf("clear", Duty.ring(camp, base, uid, 1, 4))
    end
    if role == "builder" or role == "worker" then
        if #ctx.active > 0 then
            local index = rank(camp, uid, role)
            local project = ctx.active[(index - 1) % #ctx.active + 1]
            return stationOf("site", Duty.edge(camp, Duty.rectOf(project), uid, 0))
        end
        return stationOf("depot", Duty.ring(camp, ctx.depot, uid, 1, 3))
    elseif role == "farmer" then
        if #ctx.farms > 0 then
            local index = rank(camp, uid, role)
            local farm = ctx.farms[(index - 1) % #ctx.farms + 1]
            return stationOf("farm", Duty.inside(camp, Duty.rectOf(farm), uid, camp.z, false))
        end
        return stationOf("depot", Duty.ring(camp, ctx.depot, uid, 1, 3))
    elseif role == "mechanic" then
        local bay = ctx.garage or ctx.motorpool
        if bay ~= nil then
            return stationOf("garage", Duty.edge(camp, Duty.rectOf(bay), uid, 1))
        end
    elseif role == "scavenger" or role == "sanitary" then
        local loot = camp.loot
        if role == "scavenger" and type(loot) == "table" and Options.on(camp, "sorties")
                and (Store.hours() - (loot.at or -100)) * 60 <= Duty.lootMinutes then
            return stationOf("loot", Duty.ring(camp, { x = loot.x, y = loot.y, z = loot.z }, uid, 0, 1, true, true))
        end
        return stationOf("depot", Duty.ring(camp, ctx.depot, uid, 1, 3))
    elseif role == "medic" then
        local home = Duty.firstDone(camp, "house_s") or Duty.firstDone(camp, "house_m") or Duty.firstDone(camp, "house_l")
        if home ~= nil then
            return stationOf("home", Duty.edge(camp, Duty.rectOf(home), uid, 1))
        end
    end
    local fire = ctx.campfire or ctx.center
    return stationOf("camp", Duty.ring(camp, fire, uid, 1, 4))
end

function Duty.pin(camp, uid, anchor, inner, outer)
    if anchor == nil or anchor.exact == true then return anchor end
    local spot = Duty.ring(camp, anchor, uid, inner or 0, outer or 2)
    if spot ~= nil and anchor.kind ~= nil then spot.kind = anchor.kind end
    return spot or anchor
end

function Duty.hold(camp, uid, anchor)
    local settler = camp.settlers[uid]
    if settler == nil then return false end
    local station = settler.station
    local x, y, z = Settlers.where(uid)
    local far = x ~= nil and (math.abs(x - anchor.x) > Duty.arriveRange or math.abs(y - anchor.y) > Duty.arriveRange)
    local now = Store.hours()
    local same = type(station) == "table" and station.x == anchor.x and station.y == anchor.y and station.z == (anchor.z or camp.z)
    if same and not far then return true end
    if same and far and station.sent ~= nil and now - station.sent < Duty.resendHours then return true end
    local ok = Settlers.order(uid, "hold", anchor, true)
    if ok then
        settler.station = {
            x = anchor.x, y = anchor.y, z = anchor.z or camp.z, kind = anchor.kind, sent = now,
        }
    end
    return ok
end

Hooks.add("settlerInfo", function(camp, uid, settler)
    local station = settler.station
    if type(station) ~= "table" or station.kind == nil then return nil end
    local text = ALifeCamp.TN("DutyAt_" .. tostring(station.kind))
    if text == nil then return nil end
    return { text }
end, 90)

return Duty
