require "ALifeRU/ALifeRUText"

ALifeRU = ALifeRU or {}
local Text = ALifeRU.Text

local E = ALifeRU.Events or {}
ALifeRU.Events = E

E.defs = E.defs or {}
E.order = E.order or {}
E.active = {}
E.serial = 0
E.debug = true
E.lastTickMs = 0
E.lastDirectorHour = -1e9
E.metrics = { started = 0, failed = 0, spawned = 0, refused = 0 }
E.reasons = {}
E.protectors = E.protectors or {}

local Ctx = {}
Ctx.__index = Ctx
E.Ctx = Ctx

local function log(text)
    print("[ALifeRU-EV] " .. tostring(text))
end
E.log = log

local function rnd(n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    if type(ZombRand) == "function" then return ZombRand(n) + 1 end
    return math.random(n)
end

local function unit()
    if type(ZombRandFloat) == "function" then return ZombRandFloat(0, 1) end
    return math.random()
end

local function between(low, high)
    low, high = math.floor(tonumber(low) or 1), math.floor(tonumber(high) or tonumber(low) or 1)
    if high <= low then return low end
    return low + rnd(high - low + 1) - 1
end

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return math.floor(os.time() * 1000)
end

local function worldHours()
    local hours = 0
    pcall(function() hours = getGameTime():getWorldAgeHours() end)
    return tonumber(hours) or 0
end

local function gameMinutes()
    return worldHours() * 60
end

local function hourOfDay()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return tonumber(hour) or 12
end

local function floor(v)
    return math.floor(tonumber(v) or 0)
end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = rnd(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function javaList(list)
    local out = {}
    if list == nil then return out end
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

E.intensity = {
    { key = "UI_ALRU_Int_1", gap = 6, chance = 0.08, size = 0.8 },
    { key = "UI_ALRU_Int_2", gap = 3, chance = 0.14, size = 1.0 },
    { key = "UI_ALRU_Int_3", gap = 1.5, chance = 0.22, size = 1.15 },
    { key = "UI_ALRU_Int_4", gap = 0.6, chance = 0.35, size = 1.3 },
}

function E.intensityName(index)
    local row = E.intensity[tonumber(index) or 2]
    return row ~= nil and (Text.tr(row.key) or row.key) or "?"
end

function E.title(def)
    if def == nil then return "?" end
    return Text.tr("UI_ALRU_T_" .. tostring(def.id)) or tostring(def.id)
end

function E.desc(def)
    if def == nil then return "" end
    return Text.tr("UI_ALRU_D_" .. tostring(def.id)) or ""
end

E.defaults = {
    enabled = true,
    intensity = 2,
    news = true,
    radio = true,
    vandalism = true,
    fires = true,
    bodies = true,
    disabled = {},
}

function E.store()
    local data = ModData.getOrCreate("ALifeRUEvents_v2")
    if type(data.settings) ~= "table" then data.settings = {} end
    for key, value in pairs(E.defaults) do
        if data.settings[key] == nil then
            data.settings[key] = type(value) == "table" and {} or value
        end
    end
    if type(data.history) ~= "table" then data.history = {} end
    if type(data.news) ~= "table" then data.news = {} end
    if type(data.cooldowns) ~= "table" then data.cooldowns = {} end
    if type(data.counts) ~= "table" then data.counts = {} end
    return data
end

function E.settings()
    return E.store().settings
end

function E.setSetting(key, value)
    E.store().settings[key] = value
end

function E.setEnabled(id, enabled)
    E.store().settings.disabled[id] = (not enabled) and true or nil
end

function E.isEnabled(id)
    return E.store().settings.disabled[id] ~= true
end

function E.profile()
    local level = tonumber(E.settings().intensity) or 2
    return E.intensity[math.max(1, math.min(#E.intensity, floor(level)))]
end

function E.register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or type(def.run) ~= "function" then return false end
    if E.defs[def.id] == nil then E.order[#E.order + 1] = def.id end
    E.defs[def.id] = def
    return true
end

function E.get(id)
    return E.defs[id]
end

function E.list()
    local out = {}
    for _, id in ipairs(E.order) do out[#out + 1] = E.defs[id] end
    return out
end

function E.player()
    local player
    pcall(function()
        local locator = ProjectALife and ProjectALife.PlayerLocator
        local list = locator and locator.list and locator.list() or nil
        if type(list) == "table" and #list > 0 then player = list[rnd(#list)] end
    end)
    if player == nil then pcall(function() player = getSpecificPlayer(0) end) end
    if player == nil then return nil end
    local ok, usable = pcall(function()
        return not player:isDead() and player:getCurrentSquare() ~= nil
    end)
    if not ok or not usable then return nil end
    return player
end

function E.ready()
    if ProjectALife == nil or ProjectALife.DebugService == nil or ProjectALife.Catalog == nil then
        return false, "alife_missing"
    end
    if ProjectALife.Catalog.current == nil then return false, "catalog_not_loaded" end
    if ProjectALife.EncounterDirector == nil then return false, "director_missing" end
    return true
end

function E.capacity()
    local left = 8
    pcall(function() left = ProjectALife.EncounterDirector.capacityLeft() end)
    return tonumber(left) or 0
end

function E.broadcast(command, payload)
    pcall(function()
        if type(isServer) == "function" and isServer() and type(getOnlinePlayers) == "function" then
            local players = getOnlinePlayers()
            for i = 0, players:size() - 1 do
                sendServerCommand(players:get(i), "ALifeRU", command, payload)
            end
            return
        end
        if ALifeRU.Client ~= nil and type(ALifeRU.Client.handle) == "function" then
            ALifeRU.Client.handle(command, payload)
        end
    end)
end

function E.journal(text, kind)
    local data = E.store()
    data.news[#data.news + 1] = { hour = worldHours(), text = tostring(text), kind = kind or "info" }
    while #data.news > 40 do table.remove(data.news, 1) end
end

function E.news(text, kind, title)
    E.journal(text, kind)
    log("news[" .. tostring(kind or "info") .. "]: " .. tostring(text))
    if E.settings().news ~= true then return false end
    E.broadcast("news", { text = text, kind = kind or "info", title = title })
    return true
end

function E.sound(name, x, y, z, volume)
    E.broadcast("sound", { name = name, x = x, y = y, z = z or 0, volume = volume or 1 })
end

function E.noise(x, y, radius, volume)
    pcall(function() addSound(nil, floor(x), floor(y), 0, floor(radius or 60), floor(volume or 60)) end)
end

function E.radio(speaker, lines, key)
    if E.settings().radio ~= true then return false end
    local aired = false
    pcall(function()
        local radio = ProjectALife and ProjectALife.KnoxRadio
        local channel = radio and radio.channel
        if channel == nil then return end
        local broadcast = RadioBroadCast.new("ALIFERU-" .. tostring(key or "x") .. "-" .. tostring(nowMs()), -1, -1)
        for _, line in ipairs(lines) do
            broadcast:AddRadioLine(RadioLine.new(tostring(speaker) .. ": " .. tostring(line), 1.0, 0.82, 0.62))
        end
        channel:setAiringBroadcast(broadcast)
        aired = true
    end)
    return aired
end

function E.regionAt(x, y)
    local region
    pcall(function()
        local regions = ProjectALife.TownRegions
        local nearest, nearestRegion = regions.distanceToTown({ x = x, y = y })
        if nearestRegion ~= nil and (tonumber(nearest) or 99999) < 900 then region = nearestRegion end
    end)
    return region
end

function E.placeText(x, y, player)
    local region = E.regionAt(x, y)
    local set = Text.townSet(region ~= nil and region.id or "unknown")
    set.region = region
    set.dir, set.Dir, set.meters = "", "", ""
    if player ~= nil then
        pcall(function()
            local px, py = player:getX(), player:getY()
            local index = Text.dirIndex(x - px, y - py)
            set.dir, set.Dir = Text.dir(index, false), Text.dir(index, true)
            set.meters = Text.meters(dist(x, y, px, py))
        end)
    end
    return set
end

function E.nearProtected(x, y, margin)
    margin = margin or 12
    local result = false
    pcall(function()
        local found = SafeHouse.getSafeHouse(floor(x - margin), floor(y - margin), floor(margin * 2), floor(margin * 2))
        if found ~= nil then result = true end
    end)
    return result
end

function E.nearPlayer(x, y, margin)
    local player = E.player()
    if player == nil then return false end
    local near = false
    pcall(function() near = dist(x, y, player:getX(), player:getY()) < margin end)
    return near
end

function E.squareAt(x, y, z)
    local square
    pcall(function() square = getCell():getGridSquare(floor(x), floor(y), floor(z or 0)) end)
    return square
end

function E.hostileProfiles(count, factionId)
    local service = ProjectALife.DebugService
    local ids, why = service.hostileProfileIds(count, nowMs() + rnd(100000), factionId, true)
    return ids, why
end

function E.factionList(filter)
    local current = ProjectALife.Catalog.current
    local rules = ProjectALife.FactionSpawnRules
    local day = worldHours() / 24
    local fit, any = {}, {}
    for _, faction in ipairs(current and current.factionOrder or {}) do
        local bloc = rules and rules.blocOf and rules.blocOf(faction) or nil
        local pass = false
        if type(filter) == "table" then
            if filter.ids ~= nil then
                for _, id in ipairs(filter.ids) do
                    if id == faction.id then pass = true break end
                end
            end
            if filter.blocs ~= nil then
                for _, name in ipairs(filter.blocs) do
                    if name == bloc then pass = true break end
                end
            end
            if pass and filter.hostile == true and rules and rules.hostile and not rules.hostile(faction) then
                pass = false
            end
            if pass and filter.exclude ~= nil then
                for _, id in ipairs(filter.exclude) do
                    if id == faction.id then pass = false break end
                end
            end
        end
        if pass then
            local row = { faction = faction, bloc = bloc }
            any[#any + 1] = row
            local seasonal = true
            pcall(function() seasonal = rules.inSeason(faction, day) == true end)
            if seasonal then fit[#fit + 1] = row end
        end
    end
    if #fit > 0 then return fit, any end
    return any, any
end

function E.pickFaction(filter)
    local rows = E.factionList(filter)
    if #rows == 0 then return nil end
    for _ = 1, 6 do
        local row = rows[rnd(#rows)]
        local ids = E.hostileProfiles(1, row.faction.id)
        if ids ~= nil and #ids > 0 then return row.faction, row.bloc end
    end
    return nil
end

function E.pickRivals(blocs)
    local rows = {}
    for _, bloc in ipairs(blocs) do
        local fit = E.factionList({ blocs = { bloc }, hostile = true })
        local usable = {}
        for _, row in ipairs(fit) do
            local ids = E.hostileProfiles(1, row.faction.id)
            if ids ~= nil and #ids > 0 then usable[#usable + 1] = row end
        end
        if #usable >= 2 then rows[#rows + 1] = usable end
    end
    if #rows == 0 then return nil end
    local usable = rows[rnd(#rows)]
    local first = rnd(#usable)
    local second = rnd(#usable - 1)
    if second >= first then second = second + 1 end
    return usable[first].faction, usable[second].faction, usable[first].bloc
end

function E.placeFor(kind, player, opts)
    local director = ProjectALife.EncounterDirector
    if director == nil or type(director.placeFor) ~= "function" then return nil end
    opts = opts or {}
    local definition
    if kind == "road" then
        definition = { id = "alife_ru_site", locations = { "outside_city", "city" }, placement = "road" }
    elseif kind == "poi" then
        definition = { id = "alife_ru_site", locations = { "city" }, placement = "poi", poi = opts.poi }
    elseif kind == "clearing" then
        definition = { id = "alife_ru_site", locations = { "outside_city" }, placement = "clearing" }
    elseif kind == "building" then
        definition = { id = "alife_ru_site", locations = { "city" }, placement = "building" }
    elseif kind == "outskirts" then
        definition = { id = "alife_ru_site", locations = { "outside_city" }, placement = "town" }
    else
        definition = { id = "alife_ru_site", locations = { "city" }, placement = "town" }
    end
    for _ = 1, 4 do
        local point
        pcall(function() point = director.placeFor(definition, player) end)
        if type(point) == "table" and point.x ~= nil then
            return { x = floor(point.x), y = floor(point.y), z = floor(point.z or 0) }
        end
    end
    return nil
end

function E.groupCenter(handle)
    if handle == nil or #handle.uids == 0 then return nil end
    local sx, sy, n = 0, 0, 0
    for _, uid in ipairs(handle.uids) do
        local x, y
        pcall(function()
            local binding = ProjectALife.Watchdog and ProjectALife.Watchdog.bindings and ProjectALife.Watchdog.bindings[uid]
            local shell = binding and binding.shell
            if shell ~= nil then
                local dead = false
                pcall(function() dead = shell:isDead() == true end)
                if not dead then x, y = shell:getX(), shell:getY() end
            end
        end)
        if x == nil then
            pcall(function()
                local record = ProjectALife.ActorRegistry.peek(uid)
                if record ~= nil and record.lifecycle ~= "dead" and record.worldPosition ~= nil then
                    x, y = record.worldPosition.x, record.worldPosition.y
                end
            end)
        end
        if x ~= nil then
            sx, sy, n = sx + x, sy + y, n + 1
        end
    end
    if n == 0 then return nil end
    return { x = sx / n, y = sy / n, alive = n }
end

E.rnd, E.unit, E.between, E.dist = rnd, unit, between, dist
E.worldHours, E.gameMinutes, E.hourOfDay, E.nowMs = worldHours, gameMinutes, hourOfDay, nowMs

E.fx = {}
local fx = E.fx

local function eachSquare(cx, cy, radius, fn)
    local cell = getCell()
    if cell == nil then return end
    local r = math.max(1, math.floor(radius))
    for dx = -r, r do
        for dy = -r, r do
            local square = cell:getGridSquare(floor(cx) + dx, floor(cy) + dy, 0)
            if square ~= nil then fn(square, dx, dy) end
        end
    end
end

local function guardedSquare(square)
    local protected = false
    pcall(function()
        if SafeHouse.getSafeHouse(square) ~= nil then protected = true end
    end)
    if not protected then
        for _, check in ipairs(E.protectors) do
            local ok, hit = pcall(check, square:getX(), square:getY(), square:getZ())
            if ok and hit == true then
                protected = true
                break
            end
        end
    end
    return not protected
end

local function allowedHere(x, y)
    if E.nearProtected(x, y, 10) then return false end
    return true
end

function fx.scan(cx, cy, radius)
    local found = { windows = {}, doors = {}, containers = {} }
    eachSquare(cx, cy, radius, function(square)
        if not guardedSquare(square) then return end
        for _, object in ipairs(javaList(square:getObjects())) do
            if instanceof(object, "IsoWindow") then
                local broken = false
                pcall(function() broken = object:isSmashed() == true end)
                if not broken then found.windows[#found.windows + 1] = object end
            else
                local isDoor = instanceof(object, "IsoDoor")
                if not isDoor and instanceof(object, "IsoThumpable") then
                    pcall(function() isDoor = object:isDoor() == true end)
                end
                if isDoor then
                    found.doors[#found.doors + 1] = object
                else
                    local count = 0
                    pcall(function() count = object:getContainerCount() end)
                    if count > 0 then found.containers[#found.containers + 1] = object end
                end
            end
        end
    end)
    return found
end

function fx.smash(list, limit)
    shuffle(list)
    local done = 0
    for i = 1, math.min(#list, limit or 2) do
        if pcall(function() list[i]:smashWindow() end) then done = done + 1 end
    end
    return done
end

function fx.breakDoors(list, limit)
    shuffle(list)
    local done = 0
    for i = 1, math.min(#list, limit or 1) do
        local door = list[i]
        local ok = pcall(function()
            if rnd(100) <= 55 then
                door:destroy()
            else
                door:setIsLocked(false)
                pcall(function() door:setLockedByKey(false) end)
                local open = false
                pcall(function() open = door:IsOpen() == true end)
                if not open then door:ToggleDoorSilent() end
            end
        end)
        if ok then done = done + 1 end
    end
    return done
end

function fx.empty(list, limit)
    shuffle(list)
    local done = 0
    for i = 1, math.min(#list, limit or 2) do
        local object = list[i]
        local ok = pcall(function()
            for c = 0, object:getContainerCount() - 1 do
                local container = object:getContainerByIndex(c)
                if container ~= nil then container:removeAllItems() end
            end
        end)
        if ok then done = done + 1 end
    end
    return done
end

function fx.windows(cx, cy, radius, limit)
    return fx.smash(fx.scan(cx, cy, radius).windows, limit)
end

function fx.doors(cx, cy, radius, limit)
    return fx.breakDoors(fx.scan(cx, cy, radius).doors, limit)
end

function fx.loot(cx, cy, radius, limit)
    return fx.empty(fx.scan(cx, cy, radius).containers, limit)
end

function fx.blood(cx, cy, amount)
    local done = 0
    for _ = 1, amount or 4 do
        local square = E.squareAt(cx + rnd(7) - 4, cy + rnd(7) - 4, 0)
        if square ~= nil then
            local ok = pcall(function() addBloodSplat(square, 1 + rnd(3)) end)
            if ok then done = done + 1 end
        end
    end
    return done
end

function fx.corpses(cx, cy, count, outfit)
    local done = 0
    for _ = 1, count or 1 do
        local x, y = floor(cx) + rnd(9) - 5, floor(cy) + rnd(9) - 5
        local square = E.squareAt(x, y, 0)
        if square ~= nil and guardedSquare(square) then
            local ok = false
            if outfit == nil then
                ok = pcall(function() createRandomDeadBody(square, 4 + rnd(4)) end)
            end
            if not ok then
                pcall(function()
                    local list = addZombiesInOutfit(x, y, 0, 1, outfit, 40)
                    if list ~= nil and list:size() > 0 then
                        local zombie = list:get(0)
                        zombie:Kill(nil)
                        ok = true
                    end
                end)
            end
            if ok then
                done = done + 1
                pcall(function() addBloodSplat(square, 2 + rnd(3)) end)
            end
        end
    end
    return done
end

function fx.fire(x, y)
    if E.settings().fires ~= true then return false end
    if not allowedHere(x, y) or E.nearPlayer(x, y, 22) then return false end
    local square = E.squareAt(x, y, 0)
    if square == nil or not guardedSquare(square) then return false end
    return pcall(function() IsoFireManager.StartFire(getCell(), square, true, 100, 500) end)
end

function fx.smoke(x, y)
    local square = E.squareAt(x, y, 0)
    if square == nil then return false end
    return pcall(function() IsoFireManager.StartSmoke(getCell(), square, true, 100, 500) end)
end

function fx.explode(x, y, power)
    if not allowedHere(x, y) or E.nearPlayer(x, y, 28) then return false end
    local square = E.squareAt(x, y, 0)
    if square == nil or not guardedSquare(square) then return false end
    return pcall(function() IsoFireManager.explode(getCell(), square, power or 60) end)
end

function fx.extinguish(cx, cy, radius)
    local done = 0
    eachSquare(cx, cy, radius, function(square)
        local burning = false
        pcall(function() burning = square:haveFire() == true end)
        if burning then
            pcall(function() square:stopFire() end)
            done = done + 1
        end
    end)
    return done
end

function fx.flare(x, y, z)
    local light
    pcall(function()
        light = IsoLightSource.new(floor(x), floor(y), floor(z or 0), 1.0, 0.18, 0.1, 14)
        getCell():addLamppost(light)
    end)
    return light
end

function fx.dropLight(light)
    if light == nil then return end
    pcall(function() getCell():removeLamppost(light) end)
end

function fx.horde(cx, cy, count)
    local made = 0
    for _ = 1, count or 10 do
        local x, y = floor(cx) + rnd(21) - 11, floor(cy) + rnd(21) - 11
        local square = E.squareAt(x, y, 0)
        if square ~= nil and not E.nearPlayer(x, y, 25) then
            local ok, list = pcall(addZombiesInOutfit, x, y, 0, 1, nil, 50)
            if ok and list ~= nil then made = made + list:size() end
        end
    end
    return made
end

function fx.cars(point, scripts, towardX, towardY, worn)
    local made = 0
    local support = ProjectALife and ProjectALife.Support
    if support == nil or type(support.parkCar) ~= "function" then return 0 end
    for _, script in ipairs(scripts or {}) do
        local spot = { x = point.x + rnd(7) - 4, y = point.y + rnd(7) - 4 }
        local ok, placed = pcall(support.parkCar, spot, towardX or point.x, towardY or point.y, script, worn ~= false)
        if ok and placed then made = made + 1 end
    end
    return made
end

function fx.crate(point, sprite, store, draws)
    local builder = ProjectALife and ProjectALife.OutpostBuilder
    if builder == nil or type(builder.placeContainer) ~= "function" then return nil end
    local object
    pcall(function() object = builder.placeContainer(floor(point.x), floor(point.y), floor(point.z or 0), sprite, store, draws or 3) end)
    return object
end

local function ring(point, minR, maxR)
    local angle = unit() * math.pi * 2
    local radius = minR + unit() * (maxR - minR)
    return floor(point.x + math.cos(angle) * radius), floor(point.y + math.sin(angle) * radius)
end

local function validItem(fullType)
    local ok, found = pcall(function() return getScriptManager():FindItem(fullType) end)
    return ok and found ~= nil
end

function fx.wreck(point, script, towardX, towardY)
    local builder = ProjectALife and ProjectALife.OutpostBuilder
    if builder == nil or type(builder.placeVehicle) ~= "function" then return false end
    local bx, by = floor(point.x), floor(point.y)
    local best
    pcall(function()
        local cell = getCell()
        for radius = 0, 6 do
            for dx = -radius, radius do
                for dy = -radius, radius do
                    if best == nil and (math.abs(dx) == radius or math.abs(dy) == radius) then
                        local clear = true
                        for ox = -1, 1 do
                            for oy = -2, 2 do
                                local square = cell:getGridSquare(bx + dx + ox, by + dy + oy, 0)
                                if square == nil or not square:isOutside() or square:isFree(false) ~= true then clear = false end
                            end
                        end
                        if clear then best = { x = bx + dx, y = by + dy } end
                    end
                end
            end
        end
    end)
    if best == nil then return false end
    local dx, dy = (towardX or best.x) - best.x, (towardY or best.y) - best.y
    local facing
    if math.abs(dx) > math.abs(dy) then facing = dx > 0 and "E" or "W" else facing = dy > 0 and "S" or "N" end
    local car
    pcall(function() car = builder.placeVehicle(best.x, best.y, 0, script, facing, 0) end)
    return car ~= nil
end

function fx.cargo(point, store, count, minR, maxR)
    local presets = ProjectALife and ProjectALife.OutpostPresets
    local rows = presets and presets.Stores and presets.Stores[store]
    local builder = ProjectALife and ProjectALife.OutpostBuilder
    if type(rows) ~= "table" or #rows == 0 or builder == nil or type(builder.placeItems) ~= "function" then return 0 end
    local made = 0
    for _ = 1, count do
        local row = rows[rnd(#rows)]
        if row ~= nil and validItem(row[1]) then
            local x, y = ring(point, minR, maxR)
            if builder.placeItems(x, y, floor(point.z or 0), row[1], rnd(3)) then made = made + 1 end
        end
    end
    return made
end

fx.scrap = { "Base.ScrapMetal", "Base.SheetMetal", "Base.SmallSheetMetal", "Base.MetalPipe", "Base.Wire", "Base.ElectronicsScrap" }

function fx.debris(point, count, minR, maxR)
    local builder = ProjectALife and ProjectALife.OutpostBuilder
    if builder == nil or type(builder.placeItems) ~= "function" then return 0 end
    local pool = {}
    for _, name in ipairs(fx.scrap) do
        if validItem(name) then pool[#pool + 1] = name end
    end
    if #pool == 0 then return 0 end
    local made = 0
    for _ = 1, count do
        local x, y = ring(point, minR, maxR)
        if builder.placeItems(x, y, floor(point.z or 0), pool[rnd(#pool)], rnd(2)) then made = made + 1 end
    end
    return made
end

fx.parachuteItem = "EHE.EHE_Parachute"

function fx.parachute(point)
    local builder = ProjectALife and ProjectALife.OutpostBuilder
    if builder == nil or type(builder.placeItems) ~= "function" then return false end
    if not validItem(fx.parachuteItem) then return false end
    local ok, placed = pcall(function()
        return builder.placeItems(floor(point.x), floor(point.y), floor(point.z or 0), fx.parachuteItem, 1)
    end)
    return ok and placed == true
end

fx.crashHulls = { "Base.VanBurnt", "Base.AmbulanceBurnt", "Base.PickUpVanBurnt", "Base.VanSeatsBurnt" }
fx.crashTails = { "Base.PickupBurnt", "Base.PickupSpecialBurnt", "Base.SUVBurnt" }
fx.crashScrap = { "Base.SmallCarBurnt", "Base.CarNormalBurnt", "Base.OffRoadBurnt" }

function fx.crashSite(point)
    local made = { wrecks = 0, crates = 0, cargo = 0, debris = 0 }
    local ahead = { x = point.x + 14, y = point.y + rnd(9) - 5 }
    if fx.wreck(point, fx.crashHulls[rnd(#fx.crashHulls)], ahead.x, ahead.y) then made.wrecks = made.wrecks + 1 end
    if fx.wreck({ x = point.x - 7, y = point.y + rnd(5) - 3 }, fx.crashTails[rnd(#fx.crashTails)], ahead.x, ahead.y) then
        made.wrecks = made.wrecks + 1
    end
    if fx.wreck({ x = point.x + 8, y = point.y + rnd(9) - 5 }, fx.crashScrap[rnd(#fx.crashScrap)], point.x, point.y) then
        made.wrecks = made.wrecks + 1
    end
    for _, kind in ipairs({ "munitions", "medicine", "hardware" }) do
        local x, y = ring(point, 6, 9)
        local crate = fx.crate({ x = x, y = y, z = point.z }, fx.sprites[kind], kind, 5)
        if crate ~= nil then made.crates = made.crates + 1 end
    end
    made.cargo = fx.cargo(point, "munitions", 5, 4, 10) + fx.cargo(point, "medicine", 4, 4, 10)
    made.debris = fx.debris(point, 14, 2, 11)
    return made
end

fx.sprites = {
    munitions = "location_military_generic_01_4",
    rations = "location_shop_greenes_01_35",
    medicine = "location_community_medical_01_37",
    hardware = "location_business_machinery_01_33",
}

function Ctx:log(text)
    log("[" .. tostring(self.id) .. "#" .. tostring(self.serial) .. "] " .. tostring(text))
end

function Ctx:vars(extra)
    local generic = Text.tr("UI_ALRU_B_generic") or ""
    local genericCap = Text.tr("UI_ALRU_BC_generic") or ""
    local place = self.place
    local vars = { town = place.name, loc = place.loc, near = place.near, to = place.to, over = place.over,
        Loc = place.Loc, Near = place.Near, To = place.To, Over = place.Over,
        dir = place.dir, Dir = place.Dir, meters = place.meters,
        who = self.who or generic, Who = self.Who or genericCap,
        crew = self.crew or generic, Crew = self.Crew or genericCap }
    for key, value in pairs(extra or {}) do vars[key] = value end
    return vars
end

function Ctx:say(key, extra)
    return Text.fill(getText(key), self:vars(extra))
end

function Ctx:news(key, kind, extra)
    return E.news(self:say(key, extra), kind, E.title(self.def))
end

function Ctx:radio(speakerKey, lineKeys, extra)
    local out = {}
    for _, key in ipairs(lineKeys) do out[#out + 1] = self:say(key, extra) end
    return E.radio(getText(speakerKey), out, self.id)
end

function Ctx:identify(faction, bloc)
    local row = Text.faction(faction.id, bloc)
    self.who, self.Who, self.crew, self.Crew = row.who, row.Who, row.crew, row.Crew
    return row
end

function Ctx:after(minutes, fn, label)
    self.timers[#self.timers + 1] = { at = gameMinutes() + math.max(0, tonumber(minutes) or 0), fn = fn, label = label }
end

function Ctx:afterMs(ms, fn, label)
    self.timers[#self.timers + 1] = { atMs = nowMs() + math.max(0, tonumber(ms) or 0), fn = fn, label = label }
end

function Ctx:every(minutes, times, fn)
    local step = math.max(0.05, tonumber(minutes) or 1)
    for i = 1, math.max(1, floor(times)) do
        self:after(step * i, function() fn(i) end)
    end
end

function Ctx:site(kind, opts)
    if self.pinned and self.point ~= nil then return self.point end
    local point = E.placeFor(kind, self.player, opts)
    if point == nil then return nil end
    if self.point == nil then self:setPlace(point) end
    return point
end

local kindByPlacement = {
    town = "town", road = "road", poi = "poi", clearing = "clearing", building = "building",
    upper_building = "town",
}

function Ctx:encounter(id, spec)
    spec = spec or {}
    local def = self:encounterDef(id)
    local director = ProjectALife.EncounterDirector
    if def == nil then
        E.serial = E.serial + 1
        local handle = { key = spec.key or ("g" .. tostring(E.serial)), state = "fail", reason = "no_definition", uids = {}, listeners = {} }
        self.groups[handle.key] = handle
        return handle
    end
    local point = spec.point
    if point == nil then
        point = E.placeFor(kindByPlacement[tostring(def.placement or "town")] or "town", self.player, { poi = def.poi })
    end
    if point == nil then
        E.serial = E.serial + 1
        local handle = { key = spec.key or ("g" .. tostring(E.serial)), state = "fail", reason = "no_site", uids = {}, listeners = {} }
        self.groups[handle.key] = handle
        return handle
    end
    if self.point == nil then self:setPlace(point) end
    local route, heading
    pcall(function() route = director.routeFor(def, point) end)
    pcall(function() heading = director.headingFor(def, point) end)
    local merged = {
        key = spec.key, faction = spec.faction, filter = spec.filter,
        count = spec.count or { def.minCount or 2, def.maxCount or 4 },
        mode = def.mode, profile = def.profile, conducts = def.conducts, stance = def.stance, roles = def.roles,
        persistent = def.persistent, modules = def.modules, awareness = def.awareness,
        encounterId = id, point = point, route = route, heading = heading,
        arrival = spec.arrival, hostile = spec.hostile, playerStance = spec.playerStance, radius = spec.radius,
        objective = spec.objective, support = spec.support, keepOut = spec.keepOut,
    }
    return self:spawn(merged)
end

function Ctx:sound(names, x, y, volume)
    local name = type(names) == "table" and names[rnd(#names)] or names
    E.sound(name, x, y, 0, volume)
end

function Ctx:soundFrom(point, distance, names, volume)
    local player = self.player
    local px, py = 0, 0
    pcall(function() px, py = player:getX(), player:getY() end)
    local dx, dy = point.x - px, point.y - py
    local length = math.max(1, math.sqrt(dx * dx + dy * dy))
    local reach = math.min(distance or length, length)
    self:sound(names, px + dx / length * reach, py + dy / length * reach, volume)
end

function Ctx:shots(point, bursts, perBurst, names)
    local bank = names or { "MetaPistol1", "MetaPistol2", "MetaPistol3", "MetaShotgun1", "MetaAssaultRifle1" }
    local at = 0
    for _ = 1, bursts do
        for _ = 1, perBurst do
            at = at + 140 + rnd(260)
            self:afterMs(at, function()
                self:soundFrom(point, 70 + rnd(40), bank, 0.8)
            end)
        end
        at = at + 1200 + rnd(2500)
    end
end

function Ctx:encounterDef(id)
    local encounters = ProjectALife.Encounters
    return encounters and encounters.get and encounters.get(id) or nil
end

function Ctx:spawn(spec)
    local service = ProjectALife.DebugService
    E.serial = E.serial + 1
    local handle = { key = spec.key or ("g" .. tostring(E.serial)), state = "pending", uids = {}, spec = spec,
        listeners = {} }
    self.groups[handle.key] = handle
    local faction = spec.faction
    if type(faction) == "string" then
        faction = ProjectALife.Catalog.faction(faction)
    end
    if faction == nil and spec.filter ~= nil then faction = E.pickFaction(spec.filter) end
    if faction == nil then
        handle.state, handle.reason = "fail", "no_faction"
        E.metrics.refused = E.metrics.refused + 1
        self:log("spawn " .. handle.key .. " refused: no faction")
        return handle
    end
    handle.faction = faction
    local scale = E.profile().size
    local count = spec.count
    if type(count) == "table" then count = between(count[1], count[2]) end
    count = math.max(1, math.min(8, floor((tonumber(count) or 3) * scale + 0.5)))
    count = math.min(count, math.max(1, E.capacity()))
    if E.capacity() < 1 then
        handle.state, handle.reason = "fail", "capacity_full"
        E.metrics.refused = E.metrics.refused + 1
        return handle
    end
    local ids, why = E.hostileProfiles(count, faction.id)
    if ids == nil then
        handle.state, handle.reason = "fail", why or "no_profiles"
        E.metrics.refused = E.metrics.refused + 1
        return handle
    end
    local point = spec.point or self.point
    local requestId = "alife_ru:" .. tostring(self.id) .. ":" .. tostring(self.serial) .. ":" .. handle.key .. ":" .. tostring(nowMs())
    local args = {
        requestId = requestId,
        origin = "director",
        count = #ids,
        profileIds = ids,
        factionId = faction.id,
        x = floor(point.x), y = floor(point.y), z = floor(point.z or 0),
        distance = 0,
        separation = spec.separation or 2,
        radius = spec.radius or 20,
        mode = spec.mode or "roam",
        profile = spec.profile,
        conducts = spec.conducts,
        animation = "normal",
        stance = spec.stance,
        roles = spec.roles,
        route = spec.route,
        heading = spec.heading,
        encounterId = spec.encounterId,
        encounterPersistent = spec.persistent == true,
        anchor = spec.persistent == true,
        arrival = spec.arrival,
        supportPolicy = spec.support or "disabled",
        adminPick = true,
        scavengeArea = spec.scavengeArea,
        moduleOverrides = spec.modules,
        awareness = spec.awareness,
        scene = spec.scene,
    }
    if spec.objective ~= nil then
        args.objectiveX, args.objectiveY = floor(spec.objective.x), floor(spec.objective.y)
    end
    if spec.hostile == true then args.hostileOverride = "hostile" end
    if spec.hostile == false then args.hostileOverride = "friendly" end
    if spec.playerStance ~= nil then args.playerStance = spec.playerStance end
    if spec.keepOut ~= nil then args.playerKeepOut = spec.keepOut end
    handle.requestId = requestId
    handle.startedMs = nowMs()
    handle.point = { x = point.x, y = point.y, z = point.z or 0 }
    local ok, reason, result = false, nil, nil
    local called, err = pcall(function() ok, reason, result = service.spawnEncounter(self.player, args) end)
    if not called then ok, reason = false, tostring(err) end
    if not ok then
        handle.state, handle.reason = "fail", tostring(reason)
        E.metrics.refused = E.metrics.refused + 1
        E.reasons[tostring(reason)] = (E.reasons[tostring(reason)] or 0) + 1
        self:log("spawn " .. handle.key .. " (" .. tostring(faction.id) .. ") refused: " .. tostring(reason))
        return handle
    end
    E.metrics.spawned = E.metrics.spawned + 1
    self:log("spawn " .. handle.key .. " " .. tostring(faction.id) .. " x" .. tostring(#ids) .. " mode=" .. tostring(args.mode)
        .. " at " .. tostring(args.x) .. "," .. tostring(args.y))
    local function settle(outcome)
        local good = type(outcome) == "table" and (tonumber(outcome.active) or 0) > 0
        handle.state = good and "ok" or "fail"
        handle.reason = type(outcome) == "table" and outcome.reason or nil
        handle.uids = type(outcome) == "table" and outcome.actorUids or {}
        if not good then
            E.reasons[tostring(handle.reason)] = (E.reasons[tostring(handle.reason)] or 0) + 1
        end
        for _, listener in ipairs(handle.listeners) do pcall(listener, handle) end
        handle.listeners = {}
    end
    local watched = false
    pcall(function() watched = service.watchGroup(requestId, settle) == true end)
    if not watched then handle.state = "ok" end
    return handle
end

function Ctx:waiting()
    for _, handle in pairs(self.groups) do
        if handle.state == "pending" then
            if nowMs() - (handle.startedMs or 0) > 240000 then
                handle.state, handle.reason = "fail", "timeout"
                for _, listener in ipairs(handle.listeners) do pcall(listener, handle) end
                handle.listeners = {}
            else
                return true
            end
        end
    end
    return false
end

function Ctx:onGroup(handle, fn)
    if handle.state ~= "pending" then
        pcall(fn, handle)
        return
    end
    handle.listeners[#handle.listeners + 1] = fn
end

function Ctx:vandalize(handle, minutes, options)
    if E.settings().vandalism ~= true then return end
    options = options or {}
    local radius = options.radius or 10
    local steps = math.max(1, floor((minutes or 20) / 1))
    self:every(1, steps, function()
        local center = E.groupCenter(handle)
        if center == nil or not allowedHere(center.x, center.y) then return end
        local found = fx.scan(center.x, center.y, radius)
        local done = 0
        if rnd(100) <= (options.windows or 60) then done = done + fx.smash(found.windows, 1 + rnd(2)) end
        if rnd(100) <= (options.doors or 35) then done = done + fx.breakDoors(found.doors, 1) end
        if rnd(100) <= (options.loot or 30) then done = done + fx.empty(found.containers, 1) end
        if rnd(100) <= (options.fire or 0) then
            for _ = 1, 4 do
                if fx.fire(center.x + rnd(13) - 7, center.y + rnd(13) - 7) then break end
            end
        end
        if done > 0 then E.noise(center.x, center.y, 45, 55) end
    end)
end

function Ctx:cars(point, scripts, worn)
    return fx.cars(point or self.point, scripts, self.player and self.player:getX(), self.player and self.player:getY(), worn)
end

function Ctx:start(id, opts)
    opts = opts or {}
    if not E.isEnabled(id) then return nil, "disabled" end
    opts.parent = self
    opts.force = true
    return E.start(id, opts)
end

function Ctx:finish(reason)
    if self.finished then return end
    self.finished = true
    for _, cleanup in ipairs(self.cleanups) do pcall(cleanup) end
    self:log("finished: " .. tostring(reason or "done"))
end

function Ctx:cleanup(fn)
    self.cleanups[#self.cleanups + 1] = fn
end

function E.newContext(def, player, opts)
    E.serial = E.serial + 1
    local ctx = setmetatable({}, Ctx)
    ctx.id = def.id
    ctx.def = def
    ctx.serial = E.serial
    ctx.player = player
    ctx.timers = {}
    ctx.groups = {}
    ctx.cleanups = {}
    ctx.data = {}
    ctx.startedMin = gameMinutes()
    ctx.day = worldHours() / 24
    ctx.hour = hourOfDay()
    ctx.parent = opts and opts.parent or nil
    ctx.foes = opts and opts.foes or nil
    ctx.point = opts and opts.site or nil
    ctx.place = E.placeText(0, 0, nil)
    return ctx
end

function Ctx:setPlace(point)
    self.point = point
    self.place = E.placeText(point.x, point.y, self.player)
end

function E.record(ctx)
    local data = E.store()
    local entry = { id = ctx.id, hour = worldHours(), place = ctx.place and ctx.place.name or "?",
        x = ctx.point and ctx.point.x or nil, y = ctx.point and ctx.point.y or nil }
    data.history[#data.history + 1] = entry
    while #data.history > 30 do table.remove(data.history, 1) end
    data.cooldowns[ctx.id] = worldHours()
    data.counts[ctx.id] = (data.counts[ctx.id] or 0) + 1
    data.lastHour = worldHours()
    E.last = entry
end

function E.start(id, opts)
    opts = opts or {}
    local def = E.defs[id]
    if def == nil then return nil, "unknown_event" end
    local ready, why = E.ready()
    if not ready then return nil, why end
    local player = opts.player or E.player()
    if player == nil then return nil, "no_player" end
    local ctx = E.newContext(def, player, opts)
    if opts.site ~= nil then
        ctx:setPlace(opts.site)
        ctx.pinned = true
    end
    if opts.force ~= true and type(def.can) == "function" then
        local ok, allowed, reason = pcall(def.can, ctx)
        if not ok or allowed == false then
            return nil, ok and (reason or "not_allowed") or tostring(allowed)
        end
    end
    local ok, result = pcall(def.run, ctx)
    if not ok then
        E.metrics.failed = E.metrics.failed + 1
        log("event " .. id .. " crashed: " .. tostring(result))
        ctx:finish("crash")
        return nil, "crash:" .. tostring(result)
    end
    if result ~= nil and result ~= true then
        ctx:finish(tostring(result))
        return nil, tostring(result)
    end
    E.metrics.started = E.metrics.started + 1
    E.active[#E.active + 1] = ctx
    E.record(ctx)
    ctx:log("started at " .. tostring(ctx.point and ctx.point.x) .. "," .. tostring(ctx.point and ctx.point.y))
    return ctx
end

function E.stopAll()
    for _, ctx in ipairs(E.active) do ctx:finish("stopped") end
    E.active = {}
end

function E.tick()
    local now, minutes = nowMs(), gameMinutes()
    local index = 1
    while index <= #E.active do
        local ctx = E.active[index]
        local pending = ctx.timers
        ctx.timers = {}
        for _, timer in ipairs(pending) do
            local due = (timer.at ~= nil and minutes >= timer.at) or (timer.atMs ~= nil and now >= timer.atMs)
            if due then
                local ok, err = pcall(timer.fn)
                if not ok then log("timer " .. tostring(timer.label or "?") .. " in " .. tostring(ctx.id) .. " failed: " .. tostring(err)) end
            else
                ctx.timers[#ctx.timers + 1] = timer
            end
        end
        if ctx.finished or (#ctx.timers == 0 and not ctx:waiting()) then
            ctx:finish("timeline_done")
            table.remove(E.active, index)
        else
            index = index + 1
        end
    end
end

function E.onTick()
    local now = nowMs()
    if now - E.lastTickMs < 400 then return end
    E.lastTickMs = now
    if #E.active == 0 then return end
    local ok, err = pcall(E.tick)
    if not ok then log("tick failed: " .. tostring(err)) end
end

function E.eligible(def, hours, hour)
    local data = E.store()
    if not E.isEnabled(def.id) then return false, "disabled" end
    local day = hours / 24
    if def.minDay ~= nil and day < def.minDay then return false, "too_early" end
    if def.maxDay ~= nil and day > def.maxDay then return false, "too_late" end
    if def.hours ~= nil then
        local from, to = def.hours[1], def.hours[2]
        local inside
        if from <= to then inside = hour >= from and hour < to else inside = hour >= from or hour < to end
        if not inside then return false, "wrong_hour" end
    end
    local last = data.cooldowns[def.id]
    if last ~= nil and hours - last < (def.cooldown or 18) then return false, "cooldown" end
    return true
end

function E.weightFor(def, hours)
    local weight = tonumber(def.weight) or 10
    local decay = def.decay
    if type(decay) == "table" then
        local day = hours / 24
        local from, to = tonumber(decay.start) or 0, tonumber(decay.stop) or 0
        if to > from then
            if day >= to then return 0 end
            if day > from then weight = weight * (to - day) / (to - from) end
        end
    end
    return weight
end

function E.directorTick()
    local settings = E.settings()
    if settings.enabled ~= true then return end
    local ready = E.ready()
    if not ready then return end
    local player = E.player()
    if player == nil then return end
    local hours, hour = worldHours(), hourOfDay()
    local profile = E.profile()
    if #E.active >= 2 then return end
    if hours < 3 then return end
    local data = E.store()
    if hours - (data.lastHour or -1e9) < profile.gap then return end
    if unit() > profile.chance then return end
    local pool, total = {}, 0
    for _, id in ipairs(E.order) do
        local def = E.defs[id]
        local ok = E.eligible(def, hours, hour)
        if ok then
            local weight = E.weightFor(def, hours)
            if weight > 0 then
                pool[#pool + 1] = { def = def, weight = weight }
                total = total + weight
            end
        end
    end
    if total <= 0 then return end
    local point = unit() * total
    local chosen = pool[#pool].def
    for _, row in ipairs(pool) do
        point = point - row.weight
        if point < 0 then chosen = row.def break end
    end
    local ctx, reason = E.start(chosen.id, { player = player })
    if ctx == nil then
        log("director: " .. chosen.id .. " not started (" .. tostring(reason) .. ")")
        data.lastHour = hours - profile.gap + 0.4
    end
end

function E.init()
    if E.initialised then return end
    E.initialised = true
    if Events ~= nil then
        if Events.OnTick ~= nil then Events.OnTick.Add(E.onTick) end
        if Events.EveryTenMinutes ~= nil then Events.EveryTenMinutes.Add(function()
            local ok, err = pcall(E.directorTick)
            if not ok then log("director failed: " .. tostring(err)) end
        end) end
    end
    log("loaded, events: " .. tostring(#E.order))
end

return E
