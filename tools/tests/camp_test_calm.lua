dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local A = ALifeCamp
local Calm, Rel, Store, Camp = A.Calm, A.Relations, A.Store, A.Camp
check("calm and relations loaded", Calm ~= nil and Rel ~= nil)

for x = 20, 140 do for y = 20, 140 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 900
local reg = MOCKALIFE()

local camp = Camp.create({ x1 = 60, y1 = 60, x2 = 99, y2 = 89, z = 0 }, "Calm")
ADDACTOR(reg, "ally", "friendly", 70, 70, nil)
A.Settlers.settle(camp, "ally", "Ally")
ADDACTOR(reg, "stranger", "neutral", 90, 70, nil)
reg.records.ally.memory.camp = camp.id
reg.records.stranger.factionId = "firefighters"
reg.records.ally.factionId = "raiders"

CharacterStat = { PANIC = "PANIC" }
local clock = 100000
getTimestampMs = function() return clock end

local function zombie(uid)
    local z = { class = "IsoZombie", mod = {}, x = 70, y = 70, dead = false }
    if uid ~= nil then z.mod.ProjectALifeOwned = true z.mod.ProjectALifeUID = uid end
    function z:getModData() return self.mod end
    function z:getX() return self.x end
    function z:getY() return self.y end
    function z:isDead() return self.dead end
    return z
end

local function makePlayer(panic, spotted, cellZombies)
    local stats = { panic = panic, visible = #spotted, chasing = 0 }
    function stats:get() return self.panic end
    function stats:set(_, value) self.panic = value end
    function stats:getNumVisibleZombies() return self.visible end
    function stats:getNumChasingZombies() return self.chasing end
    local player = { stats = stats, x = 72, y = 72 }
    function player:getStats() return self.stats end
    function player:getX() return self.x end
    function player:getY() return self.y end
    function player:getSpottedList()
        local list = spotted
        return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
    end
    getCell = function()
        return { getZombieList = function()
            local list = cellZombies or {}
            return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
        end, getGridSquare = function() return nil end }
    end
    return player
end

local player = makePlayer(90, { zombie("ally"), zombie("ally") })
Calm.realAt = -1000000
check("settlers alone do not scare the player", Calm.check(player) == true and player.stats.panic == 0)
check("the cause is logged", PRINTS[#PRINTS]:find("settlers=2", 1, true) ~= nil and PRINTS[#PRINTS]:find("calm", 1, true) ~= nil, PRINTS[#PRINTS])

local stranger = makePlayer(80, { zombie("ally"), zombie("stranger") })
Calm.realAt = -1000000
check("an outside A-Life npc keeps the panic", Calm.check(stranger) == false and stranger.stats.panic == 80)

local scared = makePlayer(80, { zombie("ally"), zombie(nil) })
Calm.realAt = -1000000
check("a real zombie in view keeps the panic", Calm.check(scared) == false and scared.stats.panic == 80)

local hidden = makePlayer(80, {}, { zombie(nil) })
hidden.stats.visible = 0
Calm.realAt = -1000000
ProjectALife.Watchdog.bindings.ally = { shell = zombie("ally") }
check("a real zombie nearby but out of sight keeps the panic", Calm.check(hidden) == false and hidden.stats.panic == 80)

local quiet = makePlayer(80, {}, {})
Calm.realAt = -1000000
check("settlers close by without being spotted still calm the player", Calm.check(quiet) == true and quiet.stats.panic == 0)

local after = makePlayer(80, { zombie("ally") })
Calm.realAt = clock - 5000
check("panic after a real fight is left to fade", Calm.check(after) == false and after.stats.panic == 80)
Calm.realAt = clock - 60000
check("later the panic is cleared", Calm.check(after) == true and after.stats.panic == 0)

local low = makePlayer(2, { zombie("ally") })
check("low panic is left alone", Calm.check(low) == false)

local lonely = makePlayer(70, {})
Calm.realAt = -1000000
ProjectALife.Watchdog.bindings.ally = nil
check("panic with nobody around is not ours to touch", Calm.check(lonely) == false and lonely.stats.panic == 70)

local ticked = makePlayer(90, { zombie("ally") })
Calm.realAt = -1000000
Calm.ticks = 0
for _ = 1, Calm.every do Calm.onUpdate(ticked) end
check("the update hook runs every few ticks", ticked.stats.panic == 0)
Calm.onUpdate(nil)

local ally, stranger2 = reg.records.ally, reg.records.stranger
check("camp membership is read from the camp", Rel.memberOf(ally) ~= nil and Rel.memberOf(stranger2) == nil)

local original = function(source, target) return "hostile" end
ProjectALife.Relations = {
    warfare = true,
    status = original,
    playerStance = function(record) return (record.memory and record.memory.stance) or "neutral" end,
}
Rel.patched = false
check("patch applies", Rel.patch() == true and ProjectALife.Relations.status ~= original)
local status = ProjectALife.Relations.status
check("outsiders that are neutral to the player leave settlers alone", status(stranger2, ally) == "neutral")
reg.records.stranger.memory.stance = "friendly"
check("outsiders friendly to the player are friends of settlers", status(stranger2, ally) == "friendly" and status(ally, stranger2) == "friendly")
reg.records.stranger.memory.stance = "hostile"
check("outsiders hostile to the player attack settlers and are fought back", status(stranger2, ally) == "hostile" and status(ally, stranger2) == "hostile")
reg.records.stranger.memory.stance = "neutral"
ally.memory.hostileToActorKeys = { stranger = true }
check("a grudge of a settler still counts", status(ally, stranger2) == "hostile")
ally.memory.hostileToActorKeys = nil
check("outsiders among themselves keep the original relations", status({ uid = "a", memory = {} }, { uid = "b", memory = {} }) == "hostile")
ADDACTOR(reg, "mate", "friendly", 71, 70, nil)
A.Settlers.settle(camp, "mate", "Mate")
reg.records.mate.memory.camp = camp.id
check("settlers are friendly to each other", status(ally, reg.records.mate) == "friendly")
ProjectALife.Relations.warfare = false
check("no warfare falls back to the original", status(stranger2, ally) == "hostile")
ProjectALife.Relations.warfare = true
check("patching twice changes nothing", Rel.patch() == true and ProjectALife.Relations.status == status)

local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
