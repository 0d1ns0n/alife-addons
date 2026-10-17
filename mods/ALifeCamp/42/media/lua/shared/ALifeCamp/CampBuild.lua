require "ALifeCamp/CampConfig"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampWorld"
require "ALifeCamp/CampStock"
require "ALifeCamp/CampPlace"
require "ALifeCamp/CampBlueprints"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local World = ALifeCamp.World
local Stock = ALifeCamp.Stock
local Place = ALifeCamp.Place
local Bp = ALifeCamp.Blueprints

local Build = {}
ALifeCamp.Build = Build

Build.maxProjects = 600
Build.workRate = 1.0

function Build.plan(camp)
    if type(camp.plan) ~= "table" then camp.plan = {} end
    if type(camp.plan.items) ~= "table" then camp.plan.items = {} end
    camp.plan.serial = camp.plan.serial or 0
    return camp.plan
end

local function mergeSort(arr, less)
    local n = #arr
    if n < 2 then return arr end
    local buf = {}
    local width = 1
    while width < n do
        local i = 1
        while i <= n do
            local l = i
            local m = math.min(i + width, n + 1)
            local r = math.min(i + 2 * width, n + 1)
            local a, b, k = l, m, l
            while a < m and b < r do
                if less(arr[b], arr[a]) then buf[k] = arr[b] b = b + 1 else buf[k] = arr[a] a = a + 1 end
                k = k + 1
            end
            while a < m do buf[k] = arr[a] a = a + 1 k = k + 1 end
            while b < r do buf[k] = arr[b] b = b + 1 k = k + 1 end
            i = i + 2 * width
        end
        for j = 1, n do arr[j] = buf[j] end
        width = width * 2
    end
    return arr
end
Build.mergeSort = mergeSort

function Build.list(camp)
    local items = Build.plan(camp).items
    local out = {}
    for _, project in pairs(items) do out[#out + 1] = project end
    mergeSort(out, function(a, b)
        local pa = Bp.kinds[a.kind] and Bp.kinds[a.kind].priority or 9
        local pb = Bp.kinds[b.kind] and Bp.kinds[b.kind].priority or 9
        if pa ~= pb then return pa < pb end
        return a.id < b.id
    end)
    return out
end

function Build.get(camp, id)
    return Build.plan(camp).items[tostring(id)]
end

function Build.footprint(project)
    return Bp.footprint(project)
end

function Build.overlaps(a, b)
    return a.x1 <= b.x2 and a.x2 >= b.x1 and a.y1 <= b.y2 and a.y2 >= b.y1
end

Build.spaceGap = 3
Build.spaceKinds = {
    house_s = true, house_m = true, house_l = true, shed = true, barracks = true, tents = true,
    canteen = true, infirmary = true, forge = true, greenhouse = true, powerhouse = true, market = true,
    guardhouse = true, garage = true, vault = true, motorpool = true, bay = true, post = true,
    range = true, workyard = true,
}

function Build.fits(camp, kind, x, y, w, h, ignoreId, door)
    local def = Bp.kinds[kind]
    if def == nil then return false, "kind" end
    local probe = { kind = kind, x = x, y = y, w = w or def.w, h = h or def.h, door = door }
    local rect = Bp.footprint(probe)
    if kind ~= "fence" then
        if rect.x1 < camp.x1 or rect.y1 < camp.y1 or rect.x2 > camp.x2 or rect.y2 > camp.y2 then return false, "outside" end
        local adopt = ALifeCamp.Adopt
        if adopt ~= nil and adopt.overlaps(camp, rect) ~= nil then return false, "adopted" end
    end
    for _, other in pairs(Build.plan(camp).items) do
        if other.id ~= ignoreId then
            local orect = Bp.footprint(other)
            local fenceInvolved = kind == "fence" or other.kind == "fence"
            if not fenceInvolved then
                if Build.overlaps(rect, orect) then return false, "overlap" end
                if Build.spaceKinds[kind] and Build.spaceKinds[other.kind] then
                    local gap = Build.spaceGap
                    local grown = { x1 = rect.x1 - gap, y1 = rect.y1 - gap, x2 = rect.x2 + gap, y2 = rect.y2 + gap }
                    if Build.overlaps(grown, orect) then return false, "space" end
                end
            end
        end
    end
    if kind ~= "fence" then
        local avoidMap = not (camp.options ~= nil and camp.options.demolish == true)
        for px = rect.x1, rect.x2 do
            for py = rect.y1, rect.y2 do
                local square = World.square(px, py, camp.z)
                if square ~= nil then
                    if Place.blocked(px, py, camp.z) then return false, "blocked" end
                    if avoidMap then
                        local inBuilding = false
                        pcall(function() inBuilding = square:getBuilding() ~= nil end)
                        if inBuilding then return false, "building" end
                    end
                end
            end
        end
    end
    return true
end

function Build.add(camp, kind, x, y, options)
    options = options or {}
    local def = Bp.kinds[kind]
    if def == nil then return nil, "kind" end
    local plan = Build.plan(camp)
    local count = 0
    for _ in pairs(plan.items) do count = count + 1 end
    if count >= Build.maxProjects then return nil, "limit" end
    local w, h = options.w or def.w, options.h or def.h
    local ok, why = Build.fits(camp, kind, x, y, w, h, nil, options.door)
    if not ok then return nil, why end
    plan.serial = plan.serial + 1
    local project = {
        id = plan.serial, camp = camp.id, kind = kind, x = x, y = y, w = w, h = h,
        door = options.door, gate = options.gate, level = options.level or 1, wall = options.wall,
        stage = 1, status = "planned", work = 0, paid = false, done = {}, added = Store.hours(),
    }
    if Bp.buildingKinds[kind] and ALifeCamp.Houses ~= nil then project.palette = ALifeCamp.Houses.pick(project) end
    plan.items[tostring(project.id)] = project
    return project
end

function Build.remove(camp, id)
    local items = Build.plan(camp).items
    local project = items[tostring(id)]
    if project == nil then return false end
    if ALifeCamp.Site ~= nil then ALifeCamp.Site.clear(camp, project) end
    items[tostring(id)] = nil
    return true
end

function Build.stages(project)
    return Bp.stages(project)
end

function Build.currentStage(project)
    local stages = Bp.stages(project)
    return stages[project.stage], #stages
end

function Build.openOps(project, stage)
    local out = {}
    for _, op in ipairs(stage.ops) do
        if not project.done[stage.id .. "/" .. op.slot] then out[#out + 1] = op end
    end
    return out
end

function Build.needs(camp, project)
    local stage = Build.currentStage(project)
    if stage == nil then return {} end
    local cost = Bp.cost(Build.openOps(project, stage))
    local missing = {}
    local have = camp.stock or {}
    for kind, amount in pairs(cost) do
        local short = amount - (have[kind] or 0)
        if short > 0 and not project.paid then missing[kind] = short end
    end
    return missing, cost
end

function Build.pay(camp, project)
    if project.paid then return true end
    local stage = Build.currentStage(project)
    if stage == nil then return false end
    local cost = Bp.cost(Build.openOps(project, stage))
    for kind, amount in pairs(cost) do
        if (camp.stock[kind] or 0) < amount then return false end
    end
    for kind, amount in pairs(cost) do Stock.consume(camp, kind, amount) end
    project.paid = true
    project.work = 0
    return true
end

local function applyOp(camp, project, stage, op)
    local tag = Place.tag(project, op.slot)
    local square = Place.square(op.x, op.y, op.z or 0)
    if square == nil then return false, "unloaded" end
    local ground = (op.z or 0) == 0 and square or ALifeCamp.World.square(op.x, op.y, 0)
    if ground ~= nil and ALifeCamp.World.isWaterSquare(ground) then
        return true, "water"
    end
    local object, why
    if op.t == "floor" then
        object, why = Place.floor(op.x, op.y, op.z or 0, op.sprite or Place.sprite(op.e or "WoodFloorLvl1", "W"), tag)
    elseif op.t == "roof" then
        object, why = Place.floor(op.x, op.y, op.z or 1, op.sprite, tag)
    elseif op.t == "dirt" then
        object, why = Place.floor(op.x, op.y, op.z or 0, op.sprite, tag)
    elseif op.t == "piece" then
        if op.replace then Place.removeSlot(square, op.slot) end
        object, why = Place.piece(op.e, op.x, op.y, op.z or 0, op.north, tag, op.extra)
        if object ~= nil and op.corner then Place.corner(op.x, op.y, op.z or 0, op.north, op.e, Place.tag(project, "C" .. op.slot)) end
    elseif op.t == "door" then
        object, why = Place.door(op.e, op.x, op.y, op.z or 0, op.north, tag)
    elseif op.t == "window" then
        object, why = Place.window(op.sprite, op.x, op.y, op.z or 0, op.north, tag)
    elseif op.t == "stairs" then
        object, why = Place.stairs(op.x, op.y, op.z or 0, op.north, op.level, op.sprite, op.pillar, tag)
    elseif op.t == "prop" or op.t == "crop" then
        tag.kind = op.t == "crop" and "crop" or "built"
        object, why = Place.prop(op.sprite, op.x, op.y, op.z or 0, tag, op.container)
        if object ~= nil and op.storage then
            object:getModData().ALC = { kind = "storage", camp = camp.id, project = project.id, slot = op.slot }
            camp.storage[#camp.storage + 1] = { x = op.x, y = op.y, z = op.z or 0, warehouse = true }
        end
    end
    return object ~= nil, why
end

function Build.apply(camp, project, limit)
    local stage = Build.currentStage(project)
    if stage == nil then return true, 0 end
    local pending, applied = 0, 0
    for _, op in ipairs(stage.ops) do
        local key = stage.id .. "/" .. op.slot
        if not project.done[key] then
            if applied < (limit or 200) then
                local ok = applyOp(camp, project, stage, op)
                if ok then
                    project.done[key] = true
                    applied = applied + 1
                else
                    pending = pending + 1
                end
            else
                pending = pending + 1
            end
        end
    end
    return pending == 0, applied
end

function Build.finishStage(camp, project)
    local stages = Bp.stages(project)
    project.stage = project.stage + 1
    project.paid = false
    project.work = 0
    if project.stage > #stages then
        project.status = "done"
        project.finished = Store.hours()
        camp.stats.built = camp.stats.built + 1
        return true
    end
    return false
end

function Build.progress(project)
    local stages = Bp.stages(project)
    if project.status == "done" then return 1 end
    local total = #stages
    if total == 0 then return 0 end
    local stage = stages[project.stage]
    local within = 0
    if stage ~= nil and project.paid then
        local need = Bp.work(Build.openOps(project, stage))
        within = math.min(1, (project.work or 0) / math.max(0.1, need))
    end
    return ((project.stage - 1) + within) / total
end

function Build.work(camp, project, crew, minutes)
    if project.status == "done" then return false end
    project.status = "active"
    local stage = Build.currentStage(project)
    if stage == nil then return false end
    if not project.paid and not Build.pay(camp, project) then
        project.waiting = true
        return false
    end
    project.waiting = false
    local need = Bp.work(Build.openOps(project, stage))
    if project.work < need then
        project.work = project.work + crew * minutes * Build.workRate
        if project.work < need then return false end
    end
    local complete = Build.apply(camp, project, 400)
    if not complete then
        project.stalled = true
        return false
    end
    project.stalled = false
    local finished = Build.finishStage(camp, project)
    return true, finished
end

function Build.step(camp, labor, minutes)
    local list = Build.list(camp)
    local open = {}
    for _, project in ipairs(list) do
        if project.status ~= "done" and project.prepared == true then open[#open + 1] = project end
    end
    if #open == 0 or labor <= 0 then return 0 end
    local activeMax = math.max(1, math.floor(labor / 2))
    local active = {}
    for _, project in ipairs(open) do
        if #active >= activeMax then break end
        if project.paid or Build.pay(camp, project) then
            active[#active + 1] = project
        else
            project.waiting = true
        end
    end
    if #active == 0 then return 0 end
    local share = labor / #active
    local advanced = 0
    for _, project in ipairs(active) do
        local ok, finished = Build.work(camp, project, share, minutes)
        if ok then
            advanced = advanced + 1
            Store.log(camp, finished and "built" or "stage", project.kind, project.stage)
        end
    end
    return advanced, active
end

return Build
