require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampSettlers"
require "ALifeCamp/CampPosts"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Settlers = ALifeCamp.Settlers
local Posts = ALifeCamp.Posts

local Motor = {}
ALifeCamp.Motor = Motor

Motor.military = {
    "tank", "btr", "bmp", "bmd", "brdm", "apc", "humvee", "hmmwv", "m113", "m1a", "abrams", "bradley", "stryker",
    "leopard", "t72", "t80", "t90", "army", "military", "swat", "armored", "armoured", "camo", "ural", "kamaz", "uaz",
}
Motor.excluded = { "burnt", "smashed", "trailer", "wreck" }
Motor.range = 260
Motor.scanEvery = 10
Motor.repairEvery = 20
Motor.walkSpeed = 4
Motor.goTimeout = 25
Motor.jobTimeout = 360
Motor.maxJobs = 2
Motor.repairMetal = 6
Motor.armorMilitary = 25
Motor.armorOther = 3
Motor.serviceMargin = 3
Motor.serviceRadius = 14

function Motor.state(camp)
    if type(camp.motor) ~= "table" then
        camp.motor = { parked = {}, jobs = {}, serial = 0, scanClock = 0, repairClock = 0, armor = 0, moved = 0, repaired = 0 }
    end
    return camp.motor
end

local function lowered(text)
    return string.lower(tostring(text or ""))
end

function Motor.isMilitary(name)
    local text = lowered(name)
    for _, bad in ipairs(Motor.excluded) do
        if string.find(text, bad, 1, true) ~= nil then return false end
    end
    for _, word in ipairs(Motor.military) do
        if string.find(text, word, 1, true) ~= nil then return true end
    end
    return false
end

function Motor.scriptOf(vehicle)
    local name
    pcall(function() name = vehicle:getScriptName() end)
    if name == nil or name == "" then
        pcall(function() name = vehicle:getScript():getFullName() end)
    end
    if name == nil then return nil end
    if string.find(name, ".", 1, true) == nil then name = "Base." .. name end
    return name
end

Motor.listWarned = false

local function listMember(list, name)
    local member
    pcall(function() member = list[name] end)
    if type(member) == "function" then return member end
    return nil
end

function Motor.each(fn)
    local list
    pcall(function() list = getCell():getVehicles() end)
    if list == nil then return end
    local size, get, iterator = listMember(list, "size"), listMember(list, "get"), listMember(list, "iterator")
    if size ~= nil and get ~= nil then
        local count = 0
        pcall(function() count = size(list) end)
        for i = 0, (tonumber(count) or 0) - 1 do
            local vehicle
            pcall(function() vehicle = get(list, i) end)
            if vehicle ~= nil then fn(vehicle) end
        end
        return
    end
    if iterator ~= nil then
        pcall(function()
            local walker = iterator(list)
            while walker:hasNext() do fn(walker:next()) end
        end)
        return
    end
    if not Motor.listWarned then
        Motor.listWarned = true
        print("[ALifeCamp] vehicle list has no size/get/iterator, fleet features are off")
    end
end

function Motor.find(id)
    local found
    Motor.each(function(vehicle)
        local current
        pcall(function() current = vehicle:getId() end)
        if current == id then found = vehicle end
    end)
    return found
end

local function position(vehicle)
    local x, y
    pcall(function() x, y = vehicle:getX(), vehicle:getY() end)
    return x, y
end

function Motor.idle(vehicle)
    local gone = false
    pcall(function() gone = vehicle:isRemovedFromWorld() end)
    if gone then return false end
    local driver
    pcall(function() driver = vehicle:getDriver() end)
    if driver ~= nil then return false end
    local speed = 0
    pcall(function() speed = math.abs(vehicle:getCurrentSpeedKmHour()) end)
    if speed > 2 then return false end
    local towing, towed
    pcall(function() towing, towed = vehicle:getVehicleTowing(), vehicle:getVehicleTowedBy() end)
    return towing == nil and towed == nil
end

local function parkedIds(camp)
    local ids = {}
    for _, entry in pairs(Motor.state(camp).parked) do ids[entry.id] = true end
    return ids
end

local function claimed(camp)
    local ids = {}
    for _, job in pairs(Motor.state(camp).jobs) do ids[job.vid] = true end
    return ids
end

function Motor.occupied(camp, bay)
    local entry = Motor.state(camp).parked[bay.key]
    if entry ~= nil and Motor.find(entry.id) ~= nil then return true end
    local square = World.square(bay.x, bay.y, bay.z)
    if square == nil then return true end
    local present
    pcall(function() present = square:getVehicleContainer() end)
    return present ~= nil
end

function Motor.freeBay(camp)
    local state = Motor.state(camp)
    local taken = {}
    for _, job in pairs(state.jobs) do taken[job.bay] = true end
    for _, bay in ipairs(Posts.bays(camp)) do
        if bay.kind == "post" and not taken[bay.key] and not Motor.occupied(camp, bay) then return bay end
    end
    return nil
end

function Motor.candidate(camp)
    local cx, cy = Geo.center(camp)
    local parked, busy = parkedIds(camp), claimed(camp)
    local best, bestDistance
    Motor.each(function(vehicle)
        local id
        pcall(function() id = vehicle:getId() end)
        if id == nil or parked[id] or busy[id] then return end
        local marked
        pcall(function() marked = vehicle:getModData().ALCPark end)
        if marked ~= nil then return end
        local script = Motor.scriptOf(vehicle)
        if script == nil or not Motor.isMilitary(script) or not Motor.idle(vehicle) then return end
        local x, y = position(vehicle)
        if x == nil then return end
        local distance = math.abs(x - cx) + math.abs(y - cy)
        if distance <= Motor.range * 2 and (bestDistance == nil or distance < bestDistance) then best, bestDistance = vehicle, distance end
    end)
    return best
end

function Motor.pickCrew(camp, count)
    local busy = {}
    for _, job in pairs(Motor.state(camp).jobs) do
        for _, uid in ipairs(job.crew) do busy[uid] = true end
    end
    local order = { "mechanic", "worker", "scavenger", "builder", "farmer", "medic" }
    local crew = {}
    for _, role in ipairs(order) do
        local uids = {}
        for uid, settler in pairs(camp.settlers) do
            if (settler.role or "worker") == role and not busy[uid] then uids[#uids + 1] = uid end
        end
        table.sort(uids)
        for _, uid in ipairs(uids) do
            if #crew < count then
                crew[#crew + 1] = uid
                busy[uid] = true
            end
        end
    end
    return crew
end

function Motor.startJob(camp, vehicle, bay)
    local crew = Motor.pickCrew(camp, 2)
    if #crew == 0 then return nil end
    local state = Motor.state(camp)
    state.serial = state.serial + 1
    local x, y = position(vehicle)
    local id
    pcall(function() id = vehicle:getId() end)
    local job = {
        id = state.serial, vid = id, script = Motor.scriptOf(vehicle), x = math.floor(x), y = math.floor(y),
        bay = bay.key, bx = bay.x, by = bay.y, stage = "go", started = Store.hours(), crew = crew,
    }
    state.jobs[tostring(job.id)] = job
    Store.log(camp, "haulstart", job.script)
    return job
end

function Motor.crewAnchor(camp, uid)
    for _, job in pairs(Motor.state(camp).jobs) do
        for _, member in ipairs(job.crew) do
            if member == uid then
                if job.stage == "go" then return { x = job.x, y = job.y, z = camp.z } end
                return { x = job.bx, y = job.by, z = camp.z }
            end
        end
    end
    return nil
end

local function copyParts(old, fresh)
    pcall(function()
        local count = old:getPartCount()
        for i = 0, count - 1 do
            local part = old:getPartByIndex(i)
            local id = part:getId()
            local twin = fresh:getPartById(id)
            if twin ~= nil then
                pcall(function() twin:setCondition(part:getCondition()) end)
                pcall(function()
                    if id == "GasTank" then twin:setContainerContentAmount(part:getContainerContentAmount()) end
                end)
                pcall(function()
                    local from, to = part:getItemContainer(), twin:getItemContainer()
                    if from ~= nil and to ~= nil then
                        local items = from:getItems()
                        for j = items:size() - 1, 0, -1 do
                            local item = items:get(j)
                            from:Remove(item)
                            to:AddItem(item)
                        end
                    end
                end)
            end
        end
    end)
    pcall(function() fresh:setRust(old:getRust()) end)
end

function Motor.relocate(camp, vehicle, bay)
    local square = World.square(bay.x, bay.y, bay.z)
    if square == nil then return false, "unloaded" end
    local script = Motor.scriptOf(vehicle)
    if script == nil then return false, "script" end
    local direction
    pcall(function() direction = IsoDirections[bay.dir] end)
    local fresh
    local skin
    pcall(function() skin = vehicle:getSkinIndex() end)
    pcall(function() fresh = addVehicleDebug(script, direction, skin, square) end)
    if fresh == nil then pcall(function() fresh = addVehicleDebug(script, direction, nil, square) end) end
    if fresh == nil then return false, "spawn" end
    copyParts(vehicle, fresh)
    pcall(function() vehicle:permanentlyRemove() end)
    pcall(function() fresh:getModData().ALCPark = camp.id end)
    local id
    pcall(function() id = fresh:getId() end)
    local state = Motor.state(camp)
    state.parked[bay.key] = { id = id, script = script, military = Motor.isMilitary(script), at = Store.hours() }
    state.moved = state.moved + 1
    return true
end

function Motor.spawn(camp, bay, script)
    local square = World.square(bay.x, bay.y, bay.z)
    if square == nil then return false end
    local direction
    pcall(function() direction = IsoDirections[bay.dir] end)
    local fresh
    pcall(function() fresh = addVehicleDebug(script, direction, nil, square) end)
    if fresh == nil then return false end
    local id
    pcall(function() id = fresh:getId() end)
    pcall(function() fresh:getModData().ALCPark = camp.id end)
    local state = Motor.state(camp)
    state.parked[bay.key] = { id = id, script = script, military = Motor.isMilitary(script), at = Store.hours() }
    return true
end

function Motor.advance(camp, job)
    local vehicle = Motor.find(job.vid)
    if vehicle == nil then return "lost" end
    local now = Store.hours()
    local waited = (now - job.started) * 60
    if waited > Motor.jobTimeout then return "timeout" end
    local vx, vy = position(vehicle)
    if job.stage == "go" then
        local near = false
        for _, uid in ipairs(job.crew) do
            local x, y = Settlers.where(uid)
            if x ~= nil and vx ~= nil and math.abs(x - vx) + math.abs(y - vy) <= 14 then near = true end
        end
        if near or waited >= Motor.goTimeout then
            job.stage = "tow"
            local distance = (vx ~= nil) and (math.abs(vx - job.bx) + math.abs(vy - job.by)) or 40
            job.eta = now + distance / Motor.walkSpeed / 60
        end
        return "run"
    end
    if now < (job.eta or now) then return "run" end
    local bay
    for _, candidate in ipairs(Posts.bays(camp)) do
        if candidate.key == job.bay then bay = candidate end
    end
    if bay == nil then return "lost" end
    local ok = Motor.relocate(camp, vehicle, bay)
    if ok then return "done" end
    return "failed"
end

function Motor.jobs(camp, minutes)
    local state = Motor.state(camp)
    for key, job in pairs(state.jobs) do
        local result = Motor.advance(camp, job)
        if result ~= "run" then
            state.jobs[key] = nil
            if result == "done" then
                Store.log(camp, "hauled", job.script)
                if ALifeCamp.Work ~= nil then ALifeCamp.Work.notify(camp, "Hauled", job.script) end
            elseif result == "failed" then
                Store.log(camp, "haulfail", job.script)
            end
        end
    end
end

function Motor.scan(camp, minutes)
    local state = Motor.state(camp)
    state.scanClock = state.scanClock + minutes
    if state.scanClock < Motor.scanEvery then return end
    state.scanClock = 0
    local active = 0
    for _ in pairs(state.jobs) do active = active + 1 end
    if active >= Motor.maxJobs then return end
    local bay = Motor.freeBay(camp)
    if bay == nil then return end
    local vehicle = Motor.candidate(camp)
    if vehicle == nil then return end
    Motor.startJob(camp, vehicle, bay)
end

local function inService(camp, x, y)
    for _, project in pairs(ALifeCamp.Build.plan(camp).items) do
        if project.status == "done" and not project.retired and (project.kind == "bay" or project.kind == "motorpool") then
            local rect = ALifeCamp.Blueprints.footprint(project)
            local m = Motor.serviceMargin
            if x >= rect.x1 - m and x <= rect.x2 + m and y >= rect.y1 - m and y <= rect.y2 + m then return true end
        end
    end
    local garage = Posts.garageDone(camp)
    if garage ~= nil then
        local gx, gy = garage.x + garage.w / 2, garage.y + garage.h / 2
        if math.abs(x - gx) + math.abs(y - gy) <= Motor.serviceRadius then return true end
    end
    return false
end

function Motor.condition(vehicle)
    local total, count = 0, 0
    pcall(function()
        for i = 0, vehicle:getPartCount() - 1 do
            local part = vehicle:getPartByIndex(i)
            local value = part:getCondition()
            if value ~= nil and value >= 0 then
                total = total + value
                count = count + 1
            end
        end
    end)
    if count == 0 then return 100 end
    return total / count
end

function Motor.serviceable(camp)
    local out = {}
    Motor.each(function(vehicle)
        local x, y = position(vehicle)
        if x ~= nil and Geo.contains(camp, math.floor(x), math.floor(y)) and Motor.idle(vehicle) and inService(camp, x, y) then
            out[#out + 1] = vehicle
        end
    end)
    return out
end

function Motor.service(camp, minutes)
    if Posts.garageDone(camp) == nil then return 0 end
    local state = Motor.state(camp)
    state.repairClock = state.repairClock + minutes
    local mechanics = Settlers.counts(camp).mechanic or 0
    local pace = Motor.repairEvery / (1 + mechanics)
    if state.repairClock < pace then return 0 end
    state.repairClock = 0
    local fixed = 0
    for _, vehicle in ipairs(Motor.serviceable(camp)) do
        if fixed < 1 and Motor.condition(vehicle) < 95 then
            local taken = Stock.consume(camp, "metal", Motor.repairMetal)
            if taken >= Motor.repairMetal then
                pcall(function() vehicle:repair() end)
                fixed = fixed + 1
                state.repaired = state.repaired + 1
                Store.log(camp, "serviced", Motor.scriptOf(vehicle))
                if ALifeCamp.Skills ~= nil then
                    for uid, settler in pairs(camp.settlers) do
                        if settler.role == "mechanic" then ALifeCamp.Skills.gain(camp, uid, "mech", 12) end
                    end
                end
            elseif taken > 0 then
                Stock.deposit(camp, "Base.ScrapMetal", taken)
            end
        end
    end
    return fixed
end

function Motor.armor(camp)
    local state = Motor.state(camp)
    local total = 0
    for key, entry in pairs(state.parked) do
        if Motor.find(entry.id) == nil then
            state.parked[key] = nil
        else
            total = total + (entry.military and Motor.armorMilitary or Motor.armorOther)
        end
    end
    state.armor = total
    return total
end

function Motor.step(camp, minutes)
    if camp.options.vehicles == false then return end
    if Posts.tier(camp) < 2 then return end
    Motor.jobs(camp, minutes)
    Motor.scan(camp, minutes)
    Motor.service(camp, minutes)
    Motor.armor(camp)
end

return Motor
