require "ALifeRU/ALifeRUText"
require "ALifeRU/ALifeRUEvents"

local E = ALifeRU.Events
local Text = ALifeRU.Text
local fx = E.fx
local rnd, unit = E.rnd, E.unit

local THUGS = { blocs = { "raider", "crime", "gang", "club" }, hostile = true }
local RAIDERS = { blocs = { "raider", "crime" }, hostile = true }
local LAW_IDS = { ids = { "alife_sheriff", "alife_muldraugh_pd", "alife_rosewood_pd", "alife_westpoint_pd",
    "alife_riverside_pd", "alife_county_law_remnants", "alife_trooper_remnants", "alife_ksp_post" } }
local LAW_ANY = { blocs = { "law" } }
local FIRE_IDS = { ids = { "alife_vfd", "alife_fire" } }
local ESCAPEE_IDS = { ids = { "alife_prison_predators", "alife_prison_escape_pair", "alife_lockup_escapees" } }
local GUARD_IDS = { ids = { "alife_guard_remnants", "alife_guard_infantry", "alife_guard", "alife_mp_brigade", "alife_armor_school" } }
local TOLL_IDS = { ids = { "alife_tollmen", "alife_false_checkpoint", "alife_road_militia", "alife_dixie_road", "alife_convoy_predators" } }
local RELIEF_IDS = { ids = { "alife_red_cross", "alife_county_ems", "alife_church_volunteers", "alife_hospital" } }
local REFUGEE_IDS = { ids = { "alife_refugee_walkers", "alife_lone_hitchhiker", "alife_traveller_pair" } }
local CIVIL = { blocs = { "civilian", "worker", "family" } }
local ARSON_IDS = { ids = { "alife_cinder_raiders", "alife_scrapyard_reavers", "alife_bone_raiders" } }

local function variant(list)
    return list[rnd(#list)]
end

local function pickLaw()
    local faction, bloc = E.pickFaction(LAW_IDS)
    if faction == nil then faction, bloc = E.pickFaction(LAW_ANY) end
    return faction, bloc
end

local function poiWord(category)
    local key = "UI_ALRU_Poi_" .. tostring(category or "other")
    return Text.tr(key) or Text.tr("UI_ALRU_Poi_other") or ""
end

local function poiCategory(point)
    local category
    pcall(function() category = ProjectALife.POI.categoryAt(point.x, point.y, point.z or 0) end)
    return category
end

E.register({
    id = "raid_town", kind = "violent", weight = 12, minDay = 2, cooldown = 14,
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(RAIDERS)
        if faction == nil then faction, bloc = E.pickFaction(THUGS) end
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_dispatch", variant({
            { "UI_ALRU_R_raid_1_1", "UI_ALRU_R_raid_1_2" },
            { "UI_ALRU_R_raid_2_1", "UI_ALRU_R_raid_2_2" },
        }))
        ctx:news(variant({ "UI_ALRU_N_raid_a", "UI_ALRU_N_raid_b" }), "alert")
        ctx:after(2.5, function()
            ctx:soundFrom(point, 95, { "PALWorldCarPullup2" }, 1.0)
            ctx:shots(point, 1, 3)
        end, "engines")
        ctx:after(6, function()
            local group = ctx:spawn({ key = "raid", faction = faction, count = { 5, 7 }, mode = "hunt", profile = "seek_destroy",
                conducts = { "leader", "gunner", "gunner" }, arrival = "ground", objective = point, radius = 22,
                hostile = true, point = point })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then
                    ctx:log("raid group did not appear: " .. tostring(h.reason))
                    return
                end
                ctx:cars(point, { "Base.PickUpTruck", "Base.OffRoad" })
                ctx:news("UI_ALRU_N_raid_arrive", "alert")
                ctx:vandalize(h, 40, { windows = 70, doors = 45, loot = 40, fire = 7 })
                ctx:shots(point, 3, 4)
                if E.settings().bodies == true then
                    fx.corpses(point.x, point.y, 3 + rnd(3))
                    fx.blood(point.x, point.y, 8)
                end
                ctx:after(10, function() ctx:news("UI_ALRU_N_raid_smoke", "alert") end, "smoke")
                if unit() < 0.65 then
                    ctx:after(12 + rnd(8), function() ctx:start("sheriff_response", { site = point, foes = faction }) end, "sheriff")
                end
            end)
        end, "arrival")
        return true
    end,
})

E.register({
    id = "gang_war", kind = "violent", weight = 12, minDay = 3, cooldown = 14, hours = { 14, 5 },
    run = function(ctx)
        local first, second, bloc = E.pickRivals({ "gang", "club" })
        if first == nil then return "no_rivals" end
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local a1, b1 = Text.faction(first.id, bloc), Text.faction(second.id, bloc)
        local joiner = Text.tr("UI_ALRU_And") or ""
        ctx.who = a1.who .. " " .. joiner .. " " .. b1.who
        ctx.Who = a1.Who .. " " .. joiner .. " " .. b1.who
        ctx.crew, ctx.Crew = Text.tr("UI_ALRU_B_gang"), Text.tr("UI_ALRU_BC_gang")
        ctx:radio("UI_ALRU_S_police", { "UI_ALRU_R_gang_1", "UI_ALRU_R_gang_2" })
        ctx:news(variant({ "UI_ALRU_N_gang_a", "UI_ALRU_N_gang_b" }), "alert")
        local alongX = rnd(2) == 1
        local a = { x = point.x + (alongX and -13 or 0), y = point.y + (alongX and 0 or -13), z = point.z }
        local b = { x = point.x + (alongX and 13 or 0), y = point.y + (alongX and 0 or 13), z = point.z }
        ctx:after(3, function() ctx:shots(point, 4, 5) end, "shots")
        ctx:after(4, function()
            local ga = ctx:spawn({ key = "A", faction = first, count = { 3, 5 }, mode = "hunt", profile = "seek_destroy",
                conducts = { "leader", "gunner" }, point = a, radius = 12 })
            local gb = ctx:spawn({ key = "B", faction = second, count = { 3, 5 }, mode = "hunt", profile = "seek_destroy",
                conducts = { "leader", "gunner" }, point = b, radius = 12 })
            ctx:onGroup(ga, function(h) if h.state == "ok" then ctx:vandalize(h, 25, { windows = 40, doors = 15, loot = 15 }) end end)
            ctx:onGroup(gb, function(h) if h.state == "ok" then ctx:vandalize(h, 25, { windows = 40, doors = 15, loot = 15 }) end end)
            ctx:after(2, function() E.noise(point.x, point.y, 90, 80) end, "noise")
        end, "groups")
        if unit() < 0.4 then
            ctx:after(16 + rnd(8), function() ctx:start("sheriff_response", { site = point, foes = first }) end, "sheriff")
        end
        ctx:after(20, function() ctx:news("UI_ALRU_N_gang_end", "info") end, "aftermath")
        return true
    end,
})

E.register({
    id = "biker_run", kind = "violent", weight = 8, minDay = 1, cooldown = 18, hours = { 9, 23 },
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction({ blocs = { "club" }, hostile = true })
        if faction == nil then faction, bloc = E.pickFaction(THUGS) end
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:news(variant({ "UI_ALRU_N_biker_a", "UI_ALRU_N_biker_b" }), "alert")
        ctx:after(2, function() ctx:soundFrom(point, 90, { "PALWorldCarPullup2" }, 1.0) end, "engines")
        ctx:after(5, function()
            local group = ctx:encounter("town_patrol", { key = "bikers", faction = faction, count = { 4, 6 }, arrival = "ground",
                point = point, hostile = true })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.PickUpTruck", "Base.CarStationWagon" })
                ctx:news("UI_ALRU_N_biker_patrol", "alert")
                ctx:vandalize(h, 30, { windows = 25, doors = 10, loot = 10 })
            end)
        end, "arrival")
        return true
    end,
})

E.register({
    id = "arson", kind = "violent", weight = 8, minDay = 6, cooldown = 24, hours = { 18, 6 },
    can = function(ctx)
        if E.settings().fires ~= true then return false, "fires_off" end
        return true
    end,
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(ARSON_IDS)
        if faction == nil then faction, bloc = E.pickFaction(THUGS) end
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_dispatch", { "UI_ALRU_R_arson_1", "UI_ALRU_R_arson_2" })
        ctx:news("UI_ALRU_N_arson_a", "alert")
        ctx:after(5, function()
            local group = ctx:spawn({ key = "arsonists", faction = faction, count = { 3, 5 }, mode = "roam", profile = "seek_destroy",
                conducts = { "leader" }, arrival = "ground", point = point, radius = 22, hostile = true })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.StepVan" })
                ctx:vandalize(h, 40, { windows = 55, doors = 30, loot = 10, fire = 45 })
                ctx:after(2, function()
                    for _ = 1, 3 do fx.fire(point.x + rnd(15) - 8, point.y + rnd(15) - 8) end
                    ctx:news("UI_ALRU_N_arson_fire", "alert")
                end, "first fires")
            end)
        end, "arsonists")
        ctx:after(24, function()
            local crewFaction, crewBloc = E.pickFaction(FIRE_IDS)
            if crewFaction == nil then return end
            ctx:identify(crewFaction, crewBloc)
            local group = ctx:spawn({ key = "firemen", faction = crewFaction, count = { 2, 4 }, mode = "guard", profile = "patrol",
                conducts = { "leader" }, arrival = "ground", point = point, radius = 12, hostile = false })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.StepVan", "Base.PickUpTruck" }, false)
                ctx:news("UI_ALRU_N_arson_crew", "aid")
                ctx:every(1, 18, function()
                    local centre = E.groupCenter(h)
                    if centre ~= nil then fx.extinguish(centre.x, centre.y, 9) end
                end)
                ctx:after(20, function() ctx:news("UI_ALRU_N_arson_out", "aid") end, "out")
            end)
        end, "firemen")
        return true
    end,
})

E.register({
    id = "sheriff_response", kind = "law", weight = 9, minDay = 0, maxDay = 40, cooldown = 10,
    run = function(ctx)
        local site = ctx.point
        if site == nil then site = ctx:site("road") or ctx:site("town") end
        if site == nil then return "no_site" end
        local faction, bloc = pickLaw()
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        local hunting = ctx.foes ~= nil
        ctx:radio("UI_ALRU_S_sheriff", hunting and { "UI_ALRU_R_sheriff_h_1", "UI_ALRU_R_sheriff_h_2" }
            or { "UI_ALRU_R_sheriff_p_1", "UI_ALRU_R_sheriff_p_2" })
        ctx:news(hunting and "UI_ALRU_N_sheriff_h" or "UI_ALRU_N_sheriff_p", "police")
        ctx:after(1.5, function() ctx:soundFrom(site, 85, { "PALWorldPoliceSiren" }, 1.0) end, "siren")
        ctx:after(4, function()
            local group = ctx:spawn({ key = "deputies", faction = faction, count = { 2, 4 }, mode = hunting and "hunt" or "patrol",
                profile = hunting and "seek_destroy" or "patrol", conducts = { "leader" }, arrival = "ground", point = site,
                radius = 16 })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(site, { "Base.CarLightsPolice" }, false)
                ctx:news("UI_ALRU_N_sheriff_arrive", "police")
                ctx:after(1, function() ctx:soundFrom(site, 60, { "PALWorldPoliceSiren" }, 0.8) end, "siren2")
            end)
        end, "deputies")
        return true
    end,
})

E.register({
    id = "manhunt", kind = "law", weight = 6, minDay = 2, cooldown = 30, hours = { 18, 7 },
    run = function(ctx)
        local point = ctx:site("outskirts") or ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(ESCAPEE_IDS)
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_sheriff", { "UI_ALRU_R_manhunt_1", "UI_ALRU_R_manhunt_2" })
        ctx:news("UI_ALRU_N_manhunt_a", "police")
        ctx:after(5, function()
            local group = ctx:spawn({ key = "escapees", faction = faction, count = { 2, 4 }, mode = "roam", profile = "seek_destroy",
                point = point, radius = 24, hostile = true })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:news("UI_ALRU_N_manhunt_b", "alert")
            end)
        end, "escapees")
        ctx:after(11, function() ctx:start("sheriff_response", { site = point, foes = faction }) end, "hunt")
        return true
    end,
})

E.register({
    id = "toll_roadblock", kind = "violent", weight = 8, minDay = 5, cooldown = 20,
    run = function(ctx)
        local faction, bloc = E.pickFaction(TOLL_IDS)
        if faction == nil then faction, bloc = E.pickFaction(THUGS) end
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        local group = ctx:encounter("blockade", { key = "toll", faction = faction, hostile = true })
        if group.state == "fail" and group.reason == "no_site" then return "no_site" end
        ctx:news(variant({ "UI_ALRU_N_toll_a", "UI_ALRU_N_toll_b" }), "alert")
        ctx:radio("UI_ALRU_S_trucker", { "UI_ALRU_R_toll_1", "UI_ALRU_R_toll_2" })
        ctx:after(3, function()
            local at = ctx.point or group.point
            if at ~= nil then ctx:soundFrom(at, 80, { "PALWorldShootout" }, 0.7) end
        end, "shots")
        return true
    end,
})

E.register({
    id = "convoy_ambush", kind = "violent", weight = 8, minDay = 4, cooldown = 22,
    run = function(ctx)
        local victims = E.pickFaction(CIVIL)
        local raiders, bloc = E.pickFaction(RAIDERS)
        if victims == nil or raiders == nil then return "no_faction" end
        ctx:identify(raiders, bloc)
        local crash = ctx:encounter("car_crash", { key = "crash", faction = victims })
        if crash.state == "fail" and crash.reason == "no_site" then return "no_site" end
        local at = ctx.point or crash.point
        if at == nil then return "no_site" end
        ctx:after(2, function()
            local ambush = ctx:encounter("highway_ambush", { key = "ambush", faction = raiders, hostile = true,
                point = { x = at.x + 10, y = at.y, z = at.z } })
            ctx:onGroup(ambush, function(h)
                if h.state ~= "ok" then return end
                ctx:soundFrom(at, 80, { "PALWorldCarCrash1", "PALWorldCarCrash2", "PALWorldCarCrash3" }, 1.0)
                ctx:shots(at, 2, 4)
            end)
        end, "ambush")
        ctx:news(variant({ "UI_ALRU_N_convoy_a", "UI_ALRU_N_convoy_b" }), "alert")
        return true
    end,
})

E.register({
    id = "refugees", kind = "aid", weight = 8, minDay = 1, cooldown = 18, hours = { 7, 20 },
    run = function(ctx)
        local point = ctx:site("town") or ctx:site("road")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(REFUGEE_IDS)
        if faction == nil then faction, bloc = E.pickFaction(CIVIL) end
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_volunteer", { "UI_ALRU_R_ref_1", "UI_ALRU_R_ref_2" })
        ctx:news("UI_ALRU_N_ref", "aid")
        ctx:after(3, function()
            local group = ctx:spawn({ key = "refugees", faction = faction, count = { 3, 5 }, mode = "roam", profile = "scavenger",
                point = point, radius = 18, hostile = false, playerStance = "neutral" })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                local px, py = point.x, point.y
                pcall(function() px, py = ctx.player:getX(), ctx.player:getY() end)
                local dx, dy = point.x - px, point.y - py
                local length = math.max(1, math.sqrt(dx * dx + dy * dy))
                local bx, by = point.x + dx / length * 28, point.y + dy / length * 28
                local count = 18 + rnd(18)
                local made = fx.horde(bx, by, count)
                ctx:log("horde behind refugees: " .. tostring(made))
                ctx:every(1.5, 6, function() E.noise(point.x, point.y, 70, 70) end)
            end)
        end, "refugees")
        return true
    end,
})

E.register({
    id = "airdrop", kind = "aid", weight = 6, minDay = 2, maxDay = 45, cooldown = 36, hours = { 8, 20 }, decay = { start = 10, stop = 45 },
    run = function(ctx)
        local point = ctx:site("clearing") or ctx:site("outskirts")
        if point == nil then return "no_site" end
        ctx:radio("UI_ALRU_S_hq", { "UI_ALRU_R_air_1", "UI_ALRU_R_air_2" })
        ctx:news("UI_ALRU_N_air_a", "aid")
        ctx:after(2, function() ctx:soundFrom(point, 120, { "PALWorldJetOverhead" }, 1.0) end, "jet")
        ctx:after(5, function()
            local made = 0
            local kinds = { "munitions", "rations", "medicine" }
            for index, kind in ipairs(kinds) do
                local cx, cy = point.x + index * 2 - 4, point.y + rnd(3) - 2
                local crate = fx.crate({ x = cx, y = cy, z = point.z }, fx.sprites[kind], kind, 3 + rnd(3))
                if crate ~= nil then
                    made = made + 1
                    fx.parachute({ x = cx, y = cy, z = point.z })
                end
            end
            local light = fx.flare(point.x, point.y, point.z)
            fx.smoke(point.x, point.y)
            ctx:cleanup(function() fx.dropLight(light) end)
            ctx:after(40, function() fx.dropLight(light) end, "flare off")
            ctx:soundFrom(point, 70, { "PALWorldWarExplosions" }, 0.6)
            ctx:news("UI_ALRU_N_air_b", "aid")
            ctx:log("airdrop crates: " .. tostring(made))
        end, "drop")
        ctx:after(18, function()
            local faction, bloc = E.pickFaction(THUGS)
            if faction == nil then return end
            ctx:identify(faction, bloc)
            local group = ctx:spawn({ key = "claimers", faction = faction, count = { 3, 5 }, mode = "hunt", profile = "seek_destroy",
                objective = point, point = point, radius = 28, hostile = true, arrival = "ground" })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.PickUpTruck" })
                ctx:news("UI_ALRU_N_air_claim", "alert")
            end)
        end, "claimers")
        return true
    end,
})

E.register({
    id = "heli_crash", kind = "aid", weight = 4, minDay = 3, maxDay = 60, cooldown = 48, decay = { start = 14, stop = 60 },
    run = function(ctx)
        local point = ctx:site("clearing") or ctx:site("outskirts")
        if point == nil then return "no_site" end
        local guards = E.pickFaction(GUARD_IDS)
        ctx:radio("UI_ALRU_S_guardradio", { "UI_ALRU_R_heli_1" })
        ctx:news("UI_ALRU_N_heli_a", "alert")
        ctx:soundFrom(point, 140, { "PALWorldHeliPass1", "PALWorldHeliPass2", "PALWorldHeliPass3" }, 1.0)
        ctx:after(3, function()
            ctx:soundFrom(point, 100, { "PALWorldCarCrash3" }, 1.0)
            ctx:soundFrom(point, 120, { "PALWorldWarExplosions" }, 0.9)
            fx.explode(point.x, point.y, 40)
            fx.smoke(point.x + 1, point.y + 1)
            E.noise(point.x, point.y, 100, 90)
        end, "crash")
        ctx:after(4, function()
            local made = fx.crashSite(point)
            ctx:log("crash site: wrecks " .. tostring(made.wrecks) .. ", crates " .. tostring(made.crates)
                .. ", cargo " .. tostring(made.cargo) .. ", debris " .. tostring(made.debris))
            if E.settings().bodies == true then
                fx.corpses(point.x, point.y, 3, "ArmyCamoGreen")
                fx.blood(point.x, point.y, 8)
            end
            for _ = 1, 3 do fx.fire(point.x + rnd(5) - 3, point.y + rnd(5) - 3) end
        end, "wreckage")
        if guards ~= nil then
            ctx:after(5, function()
                local group = ctx:spawn({ key = "survivors", faction = guards, count = { 1, 3 }, mode = "guard", profile = "patrol",
                    point = point, radius = 10, hostile = false, playerStance = "careful" })
                ctx:onGroup(group, function(h)
                    if h.state == "ok" then ctx:news("UI_ALRU_N_heli_surv", "info") end
                end)
            end, "survivors")
        end
        ctx:after(14, function()
            local faction, thugBloc = E.pickFaction(THUGS)
            if faction == nil then return end
            ctx:identify(faction, thugBloc)
            local group = ctx:spawn({ key = "scavengers", faction = faction, count = { 3, 5 }, mode = "scavenge", profile = "scavenger",
                scavengeArea = { x = point.x, y = point.y, z = 0 }, point = point, radius = 26, hostile = true })
            ctx:onGroup(group, function(h)
                if h.state == "ok" then ctx:news("UI_ALRU_N_heli_scav", "alert") end
            end)
        end, "scavengers")
        return true
    end,
})

E.register({
    id = "relief", kind = "aid", weight = 5, minDay = 1, maxDay = 60, cooldown = 30, hours = { 8, 17 },
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(RELIEF_IDS)
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_volunteer", { "UI_ALRU_R_relief_1", "UI_ALRU_R_relief_2" })
        ctx:news("UI_ALRU_N_relief_a", "aid")
        ctx:after(4, function()
            local group = ctx:spawn({ key = "relief", faction = faction, count = { 3, 4 }, mode = "guard", profile = "patrol",
                conducts = { "leader", "medic" }, arrival = "ground", point = point, radius = 10, hostile = false,
                playerStance = "friendly" })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.StepVan" }, false)
                for index, kind in ipairs({ "rations", "medicine" }) do
                    fx.crate({ x = point.x + index * 2, y = point.y + 3, z = point.z }, fx.sprites[kind], kind, 3)
                end
                ctx:news("UI_ALRU_N_relief_open", "aid")
            end)
        end, "relief")
        return true
    end,
})

E.register({
    id = "looters", kind = "violent", weight = 12, minDay = 1, cooldown = 10, hours = { 7, 22 },
    run = function(ctx)
        local point = ctx:site("poi", { poi = { "medical", "guns", "warehouse", "fire", "police" } })
        if point == nil then point = ctx:site("town") end
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(THUGS)
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        local target = poiWord(poiCategory(point))
        ctx:news(variant({ "UI_ALRU_N_loot_a", "UI_ALRU_N_loot_b" }), "alert", { target = target })
        ctx:after(3, function()
            local group = ctx:spawn({ key = "looters", faction = faction, count = { 3, 5 }, mode = "scavenge", profile = "scavenger",
                scavengeArea = { x = point.x, y = point.y, z = 0 }, point = point, radius = 18, hostile = true })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:vandalize(h, 30, { radius = 12, windows = 80, doors = 55, loot = 70 })
                local scan = fx.scan(point.x, point.y, 14)
                fx.smash(scan.windows, 3)
                fx.breakDoors(scan.doors, 1)
            end)
        end, "looters")
        return true
    end,
})

E.register({
    id = "gas_blast", kind = "violent", weight = 5, minDay = 2, cooldown = 30,
    can = function(ctx)
        if E.settings().fires ~= true then return false, "fires_off" end
        return true
    end,
    run = function(ctx)
        local point = ctx:site("building") or ctx:site("town")
        if point == nil then return "no_site" end
        ctx:news(variant({ "UI_ALRU_N_gas_a", "UI_ALRU_N_gas_b" }), "alert")
        ctx:after(1, function()
            ctx:soundFrom(point, 100, { "PALWorldWarExplosions", "PALWorldArtillery1" }, 1.0)
            fx.explode(point.x, point.y, 70)
            fx.fire(point.x + 1, point.y + 1)
            fx.fire(point.x - 2, point.y)
            fx.smoke(point.x, point.y)
            E.noise(point.x, point.y, 110, 95)
        end, "blast")
        ctx:after(3, function()
            fx.horde(point.x, point.y, 8 + rnd(10))
            ctx:every(1, 5, function() E.noise(point.x, point.y, 90, 70) end)
        end, "crowd")
        return true
    end,
})

E.register({
    id = "horde_march", kind = "violent", weight = 6, minDay = 3, cooldown = 28, hours = { 17, 6 },
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        ctx:radio("UI_ALRU_S_dispatch", { "UI_ALRU_R_horde_1", "UI_ALRU_R_horde_2" })
        ctx:news("UI_ALRU_N_horde", "alert")
        ctx:soundFrom(point, 120, { "PALWorldHeliPass2", "PALWorldHeliPass4" }, 1.0)
        ctx:shots(point, 3, 5)
        ctx:after(2, function()
            local px, py = point.x, point.y
            pcall(function() px, py = ctx.player:getX(), ctx.player:getY() end)
            local dx, dy = point.x - px, point.y - py
            local length = math.max(1, math.sqrt(dx * dx + dy * dy))
            local fx0, fy0 = px + dx / length * 40, py + dy / length * 40
            local total = 0
            for _ = 1, 4 do total = total + fx.horde(fx0, fy0, 12 + rnd(8)) end
            ctx:log("horde size: " .. tostring(total))
            ctx:every(1, 8, function() E.noise(point.x, point.y, 100, 90) end)
        end, "horde")
        return true
    end,
})

E.register({
    id = "military_sweep", kind = "law", weight = 6, minDay = 0, maxDay = 14, cooldown = 20, hours = { 6, 20 },
    run = function(ctx)
        local point = ctx:site("town")
        if point == nil then return "no_site" end
        local faction, bloc = E.pickFaction(GUARD_IDS)
        if faction == nil then return "no_faction" end
        ctx:identify(faction, bloc)
        ctx:radio("UI_ALRU_S_guardcmd", { "UI_ALRU_R_mil_1", "UI_ALRU_R_mil_2" })
        ctx:news("UI_ALRU_N_mil_a", "military")
        ctx:soundFrom(point, 130, { "PALWorldHeliPass1", "PALWorldSirensServices" }, 1.0)
        ctx:after(4, function()
            local group = ctx:encounter("town_patrol", { key = "sweep", faction = faction, count = { 3, 5 }, arrival = "ground",
                point = point, hostile = false, playerStance = "careful" })
            ctx:onGroup(group, function(h)
                if h.state ~= "ok" then return end
                ctx:cars(point, { "Base.PickUpTruck_Camo" }, false)
                ctx:news("UI_ALRU_N_mil_b", "military")
            end)
        end, "patrol")
        return true
    end,
})

E.init()

return E
