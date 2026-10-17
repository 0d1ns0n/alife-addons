require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World

local Adopt = {}
ALifeCamp.Adopt = Adopt

local function set(list)
    local out = {}
    for _, name in ipairs(list) do out[name] = true end
    return out
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

Adopt.stages = { "salvage", "fortify", "fitout" }
Adopt.modules = { salvage = "Salvage", fortify = "Fortify", fitout = "Fitout" }
Adopt.nextStatus = { salvage = "fortify", fortify = "fitout", fitout = "done" }
Adopt.weights = { salvage = 0.25, fortify = 0.3, fitout = 0.45 }
Adopt.margin = 1
Adopt.cellSize = 16
Adopt.stride = 3
Adopt.scanBudget = 400
Adopt.restMinutes = 30
Adopt.maxItems = 150
Adopt.maxRooms = 40
Adopt.maxCountSquares = 3000
Adopt.minArea = 20
Adopt.minRoom = 16
Adopt.minRooms = 2
Adopt.maxFootprint = 2400
Adopt.roofMin = 0.6
Adopt.foreignMax = 0.34
Adopt.maxErrors = 5
Adopt.previewSamples = 20000

Adopt.bedrooms = set({ "bedroom", "kidsbedroom", "hoarderbedroom", "ww_bedroom" })
Adopt.livings = set({ "livingroom", "ww_livingroom", "homecinema", "recreation" })
Adopt.kitchens = set({ "kitchen", "ww_kitchen", "hoarderkitchen" })
Adopt.baths = set({ "bathroom" })
Adopt.homes = set({ "bedroom", "kidsbedroom", "hoarderbedroom", "ww_bedroom", "livingroom", "ww_livingroom", "homecinema",
    "recreation", "kitchen", "ww_kitchen", "hoarderkitchen", "bathroom", "hall", "ww_hall", "dining", "diningroom", "laundry",
    "closet", "hoarder", "basement", "attic" })
Adopt.neutral = set({ "empty", "vacated", "derelict", "storage", "shed", "garagestorage", "toolstorage", "smokingroom" })

Adopt.ready = {}
Adopt.index = {}

function Adopt.enabled(camp)
    return camp ~= nil and camp.options ~= nil and camp.options.adopt == true
end

function Adopt.state(camp)
    if type(camp.adopt) ~= "table" then camp.adopt = {} end
    local st = camp.adopt
    if type(st.items) ~= "table" then st.items = {} end
    if type(st.skipped) ~= "table" then st.skipped = {} end
    st.serial = st.serial or 0
    st.cursor = st.cursor or 0
    st.passes = st.passes or 0
    st.rev = st.rev or 0
    st.pending = st.pending or 0
    st.rest = st.rest or 0
    if st.size == nil then
        local n = 0
        for _ in pairs(st.items) do n = n + 1 end
        st.size = n
    end
    local stamp = camp.x1 .. "," .. camp.y1 .. "," .. camp.x2 .. "," .. camp.y2
    if st.stamp ~= stamp then
        st.stamp = stamp
        st.skipped = {}
        st.cursor = 0
        st.rest = 0
    end
    return st
end

function Adopt.list(camp)
    local out = {}
    local st = camp.adopt
    if type(st) ~= "table" or type(st.items) ~= "table" then return out end
    for _, rec in pairs(st.items) do out[#out + 1] = rec end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Adopt.get(camp, id)
    local st = camp.adopt
    if type(st) ~= "table" or type(st.items) ~= "table" then return nil end
    for _, rec in pairs(st.items) do
        if rec.id == id then return rec end
    end
    return nil
end

local function cellKey(cx, cy)
    return cx * 8192 + cy
end

function Adopt.padded(rec)
    local m = Adopt.margin
    return { x1 = rec.rect.x1 - m, y1 = rec.rect.y1 - m, x2 = rec.rect.x2 + m, y2 = rec.rect.y2 + m }
end

function Adopt.cells(camp)
    local st = camp.adopt
    if type(st) ~= "table" or type(st.items) ~= "table" then return nil end
    local cache = Adopt.index[camp.id]
    if cache ~= nil and cache.state == st and cache.rev == (st.rev or 0) then return cache end
    cache = { state = st, rev = st.rev or 0, cells = {}, count = 0 }
    local size = Adopt.cellSize
    for _, rec in pairs(st.items) do
        local box = Adopt.padded(rec)
        for cx = math.floor(box.x1 / size), math.floor(box.x2 / size) do
            for cy = math.floor(box.y1 / size), math.floor(box.y2 / size) do
                local key = cellKey(cx, cy)
                local bucket = cache.cells[key]
                if bucket == nil then
                    bucket = {}
                    cache.cells[key] = bucket
                end
                bucket[#bucket + 1] = { rec = rec, box = box }
            end
        end
        cache.count = cache.count + 1
    end
    Adopt.index[camp.id] = cache
    return cache
end

function Adopt.covered(camp, x, y)
    local cache = Adopt.cells(camp)
    if cache == nil or cache.count == 0 then return nil end
    local size = Adopt.cellSize
    local bucket = cache.cells[cellKey(math.floor(x / size), math.floor(y / size))]
    if bucket == nil then return nil end
    for i = 1, #bucket do
        local box = bucket[i].box
        if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then return bucket[i].rec end
    end
    return nil
end

function Adopt.overlaps(camp, rect)
    local cache = Adopt.cells(camp)
    if cache == nil or cache.count == 0 then return nil end
    local size = Adopt.cellSize
    for cx = math.floor(rect.x1 / size), math.floor(rect.x2 / size) do
        for cy = math.floor(rect.y1 / size), math.floor(rect.y2 / size) do
            local bucket = cache.cells[cellKey(cx, cy)]
            if bucket ~= nil then
                for i = 1, #bucket do
                    local box = bucket[i].box
                    if rect.x1 <= box.x2 and rect.x2 >= box.x1 and rect.y1 <= box.y2 and rect.y2 >= box.y1 then
                        return bucket[i].rec
                    end
                end
            end
        end
    end
    return nil
end

function Adopt.peek(building)
    local x, y
    pcall(function()
        local def = building:getDef()
        x, y = def:getX(), def:getY()
    end)
    return x, y
end

function Adopt.read(building)
    local info
    pcall(function()
        local def = building:getDef()
        local list = def:getRooms()
        local count = list:size()
        local rooms = {}
        local x1, y1, x2, y2 = def:getX(), def:getY(), def:getX() + def:getW() - 1, def:getY() + def:getH() - 1
        local low, high
        for i = 0, math.min(count, Adopt.maxRooms) - 1 do
            local room = list:get(i)
            local rx, ry = room:getX(), room:getY()
            local entry = {
                name = string.lower(tostring(room:getName() or "")),
                x1 = rx, y1 = ry, x2 = rx + room:getW() - 1, y2 = ry + room:getH() - 1,
                z = room:getZ(), area = room:getArea(),
            }
            rooms[#rooms + 1] = entry
            x1, y1 = math.min(x1, entry.x1), math.min(y1, entry.y1)
            x2, y2 = math.max(x2, entry.x2), math.max(y2, entry.y2)
            low = low == nil and entry.z or math.min(low, entry.z)
            high = high == nil and entry.z or math.max(high, entry.z)
        end
        if #rooms == 0 then return end
        local residential = false
        pcall(function() residential = building:isResidential() == true end)
        info = {
            rect = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }, rooms = rooms, roomCount = count,
            low = low, high = high, floors = high - low + 1, residential = residential,
        }
    end)
    return info
end

function Adopt.profile(info)
    local p = { area = 0, largest = 0, bedrooms = 0, living = 0, kitchen = 0, bath = 0, home = 0, foreign = 0 }
    for _, room in ipairs(info.rooms) do
        local name = room.name
        p.area = p.area + room.area
        p.largest = math.max(p.largest, room.area)
        if Adopt.bedrooms[name] then p.bedrooms = p.bedrooms + 1 end
        if Adopt.livings[name] then p.living = p.living + 1 end
        if Adopt.kitchens[name] then p.kitchen = p.kitchen + 1 end
        if Adopt.baths[name] then p.bath = p.bath + 1 end
        if Adopt.homes[name] then
            p.home = p.home + 1
        elseif not Adopt.neutral[name] then
            p.foreign = p.foreign + 1
        end
    end
    return p
end

function Adopt.score(info, p)
    local score = p.bedrooms * 3 + p.living * 2 + p.kitchen * 2 + p.bath * 2 + #info.rooms * 0.5
    score = score + math.min(p.area, 240) / 20 + (info.floors - 1) * 2
    if info.residential then score = score + 2 end
    return math.floor(score * 10 + 0.5) / 10
end

function Adopt.touchesProject(camp, rect)
    local Build = ALifeCamp.Build
    local Bp = ALifeCamp.Blueprints
    if Build == nil or Bp == nil or type(camp.plan) ~= "table" or type(camp.plan.items) ~= "table" then return false end
    for _, project in pairs(camp.plan.items) do
        if project.kind ~= "fence" and not project.retired then
            local box = Bp.footprint(project)
            if rect.x1 <= box.x2 and rect.x2 >= box.x1 and rect.y1 <= box.y2 and rect.y2 >= box.y1 then return true end
        end
    end
    return false
end

function Adopt.judge(camp, info)
    if info == nil then return false, "nodef" end
    local rect = info.rect
    if rect.x1 < camp.x1 or rect.y1 < camp.y1 or rect.x2 > camp.x2 or rect.y2 > camp.y2 then return false, "border" end
    if info.roomCount > Adopt.maxRooms or Geo.area(rect) > Adopt.maxFootprint then return false, "large" end
    local p = Adopt.profile(info)
    if p.area < Adopt.minArea or (#info.rooms < Adopt.minRooms and p.largest < Adopt.minRoom) then return false, "tiny" end
    local weighed = p.home + p.foreign
    if weighed > 0 and p.foreign / weighed > Adopt.foreignMax then return false, "shop" end
    if p.bedrooms < 1 and not (p.living >= 1 and p.kitchen >= 1) then return false, "nohome" end
    if Adopt.touchesProject(camp, rect) then return false, "project" end
    return true, nil, Adopt.score(info, p), p
end

local function upperCovered(x, y, z)
    local up = World.square(x, y, z + 1)
    if up == nil then return false end
    local covered = false
    local ok = pcall(function() covered = up:hasFloor() == true end)
    if not ok then pcall(function() covered = up:getFloor() ~= nil end) end
    return covered
end

function Adopt.roofShare(info)
    local seen, roofed = 0, 0
    for _, room in ipairs(info.rooms) do
        if room.z == info.high then
            local step = math.max(1, math.floor(math.sqrt(math.max(1, room.area) / 6)))
            for x = room.x1, room.x2, step do
                for y = room.y1, room.y2, step do
                    local square = World.square(x, y, room.z)
                    local inside = false
                    if square ~= nil then pcall(function() inside = square:getBuilding() ~= nil end) end
                    if inside then
                        seen = seen + 1
                        if upperCovered(x, y, room.z) then roofed = roofed + 1 end
                    end
                end
            end
        end
    end
    if seen == 0 then return nil end
    return roofed / seen
end

local function openingKind(object)
    local kind
    pcall(function()
        if instanceof(object, "IsoDoor") then
            kind = "door"
        elseif instanceof(object, "IsoWindow") or instanceof(object, "IsoWindowFrame") then
            kind = "window"
        elseif instanceof(object, "IsoThumpable") then
            if object:isDoor() == true then
                kind = "door"
            elseif object:isWindowN() == true or object:isWindowW() == true then
                kind = "window"
            end
        end
    end)
    return kind
end

function Adopt.openings(room, budget)
    local doors, windows = 0, 0
    local used = 0
    for x = room.x1, room.x2 + 1 do
        for y = room.y1, room.y2 + 1 do
            if used >= budget then return doors, windows, used end
            used = used + 1
            local square = World.square(x, y, room.z)
            if square ~= nil then
                pcall(function()
                    local objects = square:getObjects()
                    for i = 0, objects:size() - 1 do
                        local object = objects:get(i)
                        local kind = openingKind(object)
                        if kind ~= nil then
                            local north
                            pcall(function() north = object:getNorth() end)
                            local inside = x <= room.x2 and y <= room.y2
                            local south = north == true and y == room.y2 + 1 and x <= room.x2
                            local east = north == false and x == room.x2 + 1 and y <= room.y2
                            if inside or south or east then
                                if kind == "door" then doors = doors + 1 else windows = windows + 1 end
                            end
                        end
                    end
                end)
            end
        end
    end
    return doors, windows, used
end

function Adopt.evaluate(camp, building)
    local info = Adopt.read(building)
    if info == nil then return nil, false, "nodef" end
    local ok, reason, score = Adopt.judge(camp, info)
    if ok then
        local share = Adopt.roofShare(info)
        info.roof = share
        if share ~= nil and share < Adopt.roofMin then
            ok, reason = false, "ruin"
        end
    end
    return info, ok, reason, score
end

function Adopt.markKeep(camp, rec)
    rec.keep = type(rec.keep) == "table" and rec.keep or {}
    for _, entry in ipairs(camp.storage or {}) do
        local z = entry.z or camp.z
        if entry.x >= rec.rect.x1 and entry.x <= rec.rect.x2 and entry.y >= rec.rect.y1 and entry.y <= rec.rect.y2 then
            rec.keep[entry.x .. "," .. entry.y .. "," .. z] = true
        end
    end
end

function Adopt.create(camp, st, key, info, score)
    st.serial = st.serial + 1
    local budget = Adopt.maxCountSquares
    local rooms = {}
    for _, room in ipairs(info.rooms) do
        local doors, windows, used = Adopt.openings(room, budget)
        budget = math.max(0, budget - used)
        rooms[#rooms + 1] = {
            name = room.name, x1 = room.x1, y1 = room.y1, x2 = room.x2, y2 = room.y2, z = room.z,
            area = room.area, doors = doors, windows = windows,
        }
    end
    local p = Adopt.profile(info)
    local rect = { x1 = info.rect.x1, y1 = info.rect.y1, x2 = info.rect.x2, y2 = info.rect.y2, z = camp.z }
    local rec = {
        id = st.serial, key = key, rect = rect, floors = info.floors, rooms = rooms, status = "queued", capacity = 0,
        score = score, area = p.area, bedrooms = p.bedrooms, progress = 0, found = Store.hours(),
        partial = info.roof == nil, keep = {},
    }
    rec.estimate = Adopt.estimate(rec)
    Adopt.markKeep(camp, rec)
    st.items[key] = rec
    st.size = st.size + 1
    st.rev = st.rev + 1
    st.pending = st.pending + 1
    return rec
end

function Adopt.consider(camp, building)
    local x, y = Adopt.peek(building)
    if x == nil then return nil, "nodef" end
    local st = Adopt.state(camp)
    local key = x .. "," .. y .. "," .. camp.z
    local rec = st.items[key]
    if rec ~= nil then return rec end
    if st.skipped[key] ~= nil then return nil, st.skipped[key] end
    local info, ok, reason, score = Adopt.evaluate(camp, building)
    if not ok then
        st.skipped[key] = reason or "no"
        return nil, st.skipped[key]
    end
    if st.size >= Adopt.maxItems then
        st.skipped[key] = "limit"
        return nil, "limit"
    end
    return Adopt.create(camp, st, key, info, score)
end

function Adopt.guards(camp, square)
    if camp == nil or square == nil then return false end
    local x, y
    pcall(function() x, y = square:getX(), square:getY() end)
    if x == nil then return false end
    if Adopt.covered(camp, x, y) ~= nil then return true end
    if not Adopt.enabled(camp) then return false end
    local building
    pcall(function() building = square:getBuilding() end)
    if building == nil then return false end
    Adopt.consider(camp, building)
    return Adopt.covered(camp, x, y) ~= nil
end

function Adopt.scan(camp, budget)
    local st = Adopt.state(camp)
    local stride = Adopt.stride
    local cols = math.ceil(Geo.width(camp) / stride)
    local rows = math.ceil(Geo.height(camp) / stride)
    local total = cols * rows
    local spent = 0
    local finished = false
    while spent < budget do
        local i = st.cursor
        local x = camp.x1 + (i % cols) * stride
        local y = camp.y1 + math.floor(i / cols) * stride
        spent = spent + 1
        if Adopt.covered(camp, x, y) == nil then
            local square = World.square(x, y, camp.z)
            if square ~= nil then
                local building
                pcall(function() building = square:getBuilding() end)
                if building ~= nil then Adopt.consider(camp, building) end
            end
        end
        st.cursor = i + 1
        if st.cursor >= total then
            st.cursor = 0
            st.passes = st.passes + 1
            finished = true
            break
        end
    end
    return spent, finished
end

function Adopt.discover(camp, limit)
    local st = Adopt.state(camp)
    local passes = st.passes
    local spent = 0
    while spent < (limit or 20000) and st.passes == passes do
        local used = Adopt.scan(camp, 1000)
        spent = spent + used
    end
    st.rest = Adopt.restMinutes
    return st.size
end

function Adopt.preview(rect, z)
    local camp = {
        id = 0, x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2, z = z or rect.z or 0, options = {},
        plan = { items = {}, serial = 0 },
    }
    local area = Geo.area(rect)
    local stride = math.max(2, math.ceil(math.sqrt(area / Adopt.previewSamples)))
    local out = { buildings = 0, eligible = 0, beds = 0 }
    local seen = {}
    for x = rect.x1, rect.x2, stride do
        for y = rect.y1, rect.y2, stride do
            local square = World.square(x, y, camp.z)
            local building
            if square ~= nil then pcall(function() building = square:getBuilding() end) end
            if building ~= nil then
                local px, py = Adopt.peek(building)
                local key = px ~= nil and (px .. "," .. py) or nil
                if key == nil or not seen[key] then
                    if key ~= nil then seen[key] = true end
                    out.buildings = out.buildings + 1
                    if key ~= nil then
                        local info, ok = Adopt.evaluate(camp, building)
                        if ok then
                            out.eligible = out.eligible + 1
                            out.beds = out.beds + Adopt.estimate({ rooms = info.rooms })
                        end
                    end
                end
            end
        end
    end
    return out
end

function Adopt.estimate(rec)
    local beds = 0
    for _, room in ipairs(rec.rooms or {}) do
        if Adopt.bedrooms[room.name] then
            beds = beds + clamp(math.floor((room.area or 0) / 3), 1, 6)
        elseif Adopt.livings[room.name] then
            beds = beds + clamp(math.floor((room.area or 0) / 9), 0, 2)
        end
    end
    return beds
end

function Adopt.expected(rec)
    local beds = tonumber(rec.capacity) or 0
    if beds > 0 then return beds end
    return rec.estimate or Adopt.estimate(rec)
end

function Adopt.reduce(camp, houses)
    local list = Adopt.list(camp)
    if #list == 0 then return houses end
    local beds = 0
    for _, rec in ipairs(list) do beds = beds + Adopt.expected(rec) end
    local equivalent = math.max(#list, math.floor(beds / 3.5))
    return math.max(0, houses - equivalent)
end

function Adopt.module(stage)
    local mod = ALifeCamp[Adopt.modules[stage]]
    if type(mod) == "table" and type(mod.analyze) == "function" and type(mod.step) == "function" then return mod end
    return nil
end

function Adopt.summaryOf(rec, stage)
    local mod = Adopt.module(stage)
    if mod == nil or type(mod.summary) ~= "function" then return nil end
    local ok, value = pcall(mod.summary, rec)
    if ok and type(value) == "table" then return value end
    return nil
end

function Adopt.refresh(rec)
    local beds = 0
    local s = Adopt.summaryOf(rec, "fitout")
    if s ~= nil then beds = tonumber(s.beds) or tonumber(s.capacity) or 0 end
    if beds <= 0 and rec.status == "done" then beds = rec.estimate or Adopt.estimate(rec) end
    rec.capacity = beds
    rec.sealed, rec.stands = Adopt.defenseOf(rec)
    return beds
end

function Adopt.overall(rec)
    if rec.status == "done" then return 1 end
    if rec.status == "queued" then return 0 end
    local total = 0
    for _, stage in ipairs(Adopt.stages) do
        if stage == rec.status then
            total = total + Adopt.weights[stage] * clamp(tonumber(rec.progress) or 0, 0, 1)
            break
        end
        total = total + Adopt.weights[stage]
    end
    return total
end

function Adopt.missing(camp, rec)
    if type(rec.waiting) ~= "table" then return nil end
    return rec.waiting
end

local function normalizeWaiting(camp, rec, stage, extra)
    local value = extra
    if value == nil and type(rec[stage]) == "table" then value = rec[stage].waiting end
    if value == nil or value == false then return nil end
    if type(value) == "table" then
        if ALifeCamp.isEmpty(value) then return nil end
        local out = {}
        local any = false
        for kind, amount in pairs(value) do
            if type(amount) == "number" and amount > 0 then
                out[kind] = amount
                any = true
            end
        end
        if any then return out end
    end
    local stock = camp.stock or {}
    local out = {}
    for kind, amount in pairs(rec.needs or {}) do
        local short = amount - (stock[kind] or 0)
        if short > 0 then out[kind] = short end
    end
    if ALifeCamp.isEmpty(out) then return nil end
    return out
end

function Adopt.notify(camp, key, ...)
    local work = ALifeCamp.Work
    if work ~= nil and type(work.notify) == "function" then pcall(work.notify, camp, key, ...) end
end

function Adopt.finish(camp, rec, stage)
    Adopt.ready[rec.id] = nil
    rec.progress = 0
    rec.waiting = nil
    rec.errors = 0
    rec.needs = nil
    local target = Adopt.nextStatus[stage]
    if target == "done" then
        rec.status = "done"
        rec.finished = Store.hours()
        Adopt.refresh(rec)
        camp.stats.adopted = (camp.stats.adopted or 0) + 1
        Store.log(camp, "adopt_done", rec.id, rec.capacity)
        Adopt.notify(camp, "AdoptDone", tostring(rec.id), tostring(rec.capacity))
    else
        rec.status = target
        Adopt.refresh(rec)
        Store.log(camp, "adopt_stage", rec.id, stage)
        Adopt.notify(camp, "AdoptStage", tostring(rec.id), ALifeCamp.T("AdStage_" .. stage))
    end
end

function Adopt.advance(camp, rec, labor, minutes)
    if rec.status == "queued" then
        rec.status = "salvage"
        rec.started = Store.hours()
        Store.log(camp, "adopt_start", rec.id)
        Adopt.notify(camp, "AdoptStart", tostring(rec.id))
    end
    local stage = rec.status
    local mod = Adopt.module(stage)
    if mod == nil or (type(rec.skip) == "table" and rec.skip[stage]) then
        Adopt.finish(camp, rec, stage)
        return true
    end
    if Adopt.ready[rec.id] ~= stage then
        Adopt.markKeep(camp, rec)
        local ok, cost = pcall(mod.analyze, camp, rec)
        if not ok then
            Adopt.fail(camp, rec, stage, cost)
            return false
        end
        rec.needs = type(cost) == "table" and cost or {}
        Adopt.ready[rec.id] = stage
    end
    local ok, done, progress, spent, extra = pcall(mod.step, camp, rec, labor, minutes)
    if not ok then
        Adopt.fail(camp, rec, stage, done)
        return false
    end
    rec.errors = 0
    rec.progress = clamp(tonumber(progress) or 0, 0, 1)
    rec.spent = (rec.spent or 0) + (tonumber(spent) or 0)
    rec.waiting = normalizeWaiting(camp, rec, stage, extra)
    Adopt.refresh(rec)
    if done == true then
        Adopt.finish(camp, rec, stage)
        return true
    end
    return false
end

function Adopt.fail(camp, rec, stage, message)
    rec.errors = (rec.errors or 0) + 1
    print("[ALifeCamp] adopt " .. tostring(rec.id) .. " " .. tostring(stage) .. " failed: " .. tostring(message))
    if rec.errors >= Adopt.maxErrors then
        rec.skip = type(rec.skip) == "table" and rec.skip or {}
        rec.skip[stage] = true
        rec.errors = 0
    end
end

function Adopt.loaded(camp, rec)
    local r = rec.rect
    local z = r.z or camp.z
    local cx, cy = math.floor((r.x1 + r.x2) / 2), math.floor((r.y1 + r.y2) / 2)
    local spots = { { cx, cy }, { r.x1, r.y1 }, { r.x2, r.y2 }, { r.x1, r.y2 }, { r.x2, r.y1 } }
    for _, spot in ipairs(spots) do
        if World.square(spot[1], spot[2], z) ~= nil then return true end
    end
    return false
end

function Adopt.queue(camp)
    local running, waiting = {}, {}
    local cx, cy = Geo.center(camp)
    for _, rec in ipairs(Adopt.list(camp)) do
        if rec.status == "queued" then
            waiting[#waiting + 1] = rec
        elseif rec.status ~= "done" then
            running[#running + 1] = rec
        end
    end
    local function distance(rec)
        local x, y = (rec.rect.x1 + rec.rect.x2) / 2, (rec.rect.y1 + rec.rect.y2) / 2
        return (x - cx) * (x - cx) + (y - cy) * (y - cy)
    end
    table.sort(waiting, function(a, b)
        if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
        local da, db = distance(a), distance(b)
        if da ~= db then return da < db end
        return a.id < b.id
    end)
    for _, rec in ipairs(waiting) do running[#running + 1] = rec end
    return running
end

function Adopt.flush(camp)
    local st = camp.adopt
    if type(st) ~= "table" or (st.pending or 0) <= 0 then return end
    local count = st.pending
    st.pending = 0
    Store.log(camp, "adopt_found", count)
    Adopt.notify(camp, "AdoptFound", tostring(count))
end

function Adopt.step(camp, labor, minutes)
    if not Adopt.enabled(camp) then return 0 end
    local st = Adopt.state(camp)
    st.rest = st.rest - minutes
    if st.rest <= 0 then
        local _, finished = Adopt.scan(camp, Adopt.scanBudget)
        if finished then st.rest = Adopt.restMinutes else st.rest = 0 end
    end
    Adopt.flush(camp)
    camp.adoptActive = {}
    local queue = Adopt.queue(camp)
    if #queue == 0 or labor <= 0 then return 0 end
    local limit = math.max(1, math.floor(labor / 2))
    local active = {}
    for _, rec in ipairs(queue) do
        if #active >= limit then break end
        if Adopt.loaded(camp, rec) then active[#active + 1] = rec end
    end
    if #active == 0 then return 0 end
    local share = labor / #active
    local advanced = 0
    for _, rec in ipairs(active) do
        camp.adoptActive[#camp.adoptActive + 1] = rec.id
        if Adopt.advance(camp, rec, share, minutes) then advanced = advanced + 1 end
    end
    return advanced, active
end

function Adopt.counts(camp)
    local out = { all = 0, done = 0, beds = 0, expected = 0, openings = 0, posts = 0, defense = 0 }
    local st = camp.adopt
    if type(st) ~= "table" or type(st.items) ~= "table" then return out end
    for _, rec in pairs(st.items) do
        out.all = out.all + 1
        out.expected = out.expected + Adopt.expected(rec)
        if rec.status == "done" then out.done = out.done + 1 end
        if rec.status == "done" or rec.status == "fitout" then
            out.beds = out.beds + (tonumber(rec.capacity) or 0)
            out.openings = out.openings + (tonumber(rec.sealed) or 0)
            out.posts = out.posts + (tonumber(rec.stands) or 0)
        end
    end
    out.defense = out.openings + out.posts * 5
    return out
end

local function numeric(value)
    if type(value) == "number" then return value end
    if type(value) == "table" then
        local n = 0
        for _ in pairs(value) do n = n + 1 end
        return n
    end
    return 0
end

function Adopt.defenseOf(rec)
    local s = Adopt.summaryOf(rec, "fortify")
    local openings, posts = 0, 0
    if s ~= nil then
        openings = numeric(s.done)
        if openings == 0 then openings = numeric(s.sealed) + numeric(s.barricaded) end
        openings = math.max(0, openings - numeric(s.weak))
        posts = numeric(s.posts)
    end
    if posts == 0 and type(rec.fortify) == "table" then posts = numeric(rec.fortify.posts) end
    return openings, posts
end

local function anchors(rec, list, out, camp)
    if type(list) ~= "table" then return end
    for _, post in ipairs(list) do
        if type(post) == "table" and type(post.x) == "number" and type(post.y) == "number" then
            out[#out + 1] = { x = post.x, y = post.y, z = post.z or rec.rect.z or camp.z, exact = true }
        end
    end
end

function Adopt.posts(camp)
    local out = {}
    for _, rec in ipairs(Adopt.list(camp)) do
        if rec.status == "fitout" or rec.status == "done" then
            if type(rec.fortify) == "table" then anchors(rec, rec.fortify.posts, out, camp) end
        end
        if rec.status == "done" and type(rec.fitout) == "table" then anchors(rec, rec.fitout.posts, out, camp) end
    end
    table.sort(out, function(a, b)
        if a.z ~= b.z then return a.z < b.z end
        return a.x * 10000 + a.y < b.x * 10000 + b.y
    end)
    return out
end

function Adopt.center(rec)
    local r = rec.rect
    return { x = math.floor((r.x1 + r.x2) / 2), y = math.floor((r.y1 + r.y2) / 2), z = r.z or 0 }
end

function Adopt.describe(rec)
    if rec.status ~= "salvage" and rec.status ~= "fortify" and rec.status ~= "fitout" then return nil end
    local mod = Adopt.module(rec.status)
    if mod == nil or type(mod.describe) ~= "function" then return nil end
    local ok, text = pcall(mod.describe, rec)
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
end

function Adopt.summary(camp, rec)
    return {
        id = rec.id, key = rec.key, status = rec.status, rooms = #(rec.rooms or {}), floors = rec.floors or 1,
        area = rec.area or 0, bedrooms = rec.bedrooms or 0, capacity = tonumber(rec.capacity) or 0,
        expected = Adopt.expected(rec), stage = rec.status, stageProgress = clamp(tonumber(rec.progress) or 0, 0, 1),
        progress = Adopt.overall(rec), waiting = Adopt.missing(camp, rec), partial = rec.partial == true,
        score = rec.score or 0, rect = rec.rect, names = Adopt.roomNames(rec), detail = Adopt.describe(rec),
    }
end

function Adopt.roomNames(rec)
    local counts, order = {}, {}
    for _, room in ipairs(rec.rooms or {}) do
        if counts[room.name] == nil then
            counts[room.name] = 0
            order[#order + 1] = room.name
        end
        counts[room.name] = counts[room.name] + 1
    end
    local out = {}
    for _, name in ipairs(order) do out[#out + 1] = { name = name, count = counts[name] } end
    return out
end

function Adopt.summaries(camp)
    local out = {}
    for _, rec in ipairs(Adopt.list(camp)) do out[#out + 1] = Adopt.summary(camp, rec) end
    return out
end

function Adopt.totals(camp)
    local out = { items = 0, done = 0, active = 0, queued = 0, capacity = 0, skipped = 0 }
    for _, rec in ipairs(Adopt.list(camp)) do
        out.items = out.items + 1
        if rec.status == "done" then
            out.done = out.done + 1
        elseif rec.status == "queued" then
            out.queued = out.queued + 1
        else
            out.active = out.active + 1
        end
        out.capacity = out.capacity + (tonumber(rec.capacity) or 0)
    end
    if type(camp.adopt) == "table" and type(camp.adopt.skipped) == "table" then
        for _ in pairs(camp.adopt.skipped) do out.skipped = out.skipped + 1 end
    end
    return out
end

function Adopt.roomLabel(name)
    local text = ALifeCamp.TN("Room_" .. tostring(name))
    if text ~= nil then return text end
    return ALifeCamp.T("Room_other")
end

return Adopt
