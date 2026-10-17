require "ALifeCamp/CampConfig"
require "ALifeCamp/CampStore"

ALifeCamp = ALifeCamp or {}

local Store = ALifeCamp.Store

local Skills = {}
ALifeCamp.Skills = Skills

Skills.list = { "build", "farm", "guard", "scavenge", "medic", "mech", "clean" }
Skills.primary = {
    builder = "build", farmer = "farm", guard = "guard", scavenger = "scavenge", worker = "scavenge",
    medic = "medic", mechanic = "mech", sanitary = "clean",
}
Skills.maxLevel = 10
Skills.xpUnit = 30
Skills.workRate = 0.8
Skills.sideRate = 0.2
Skills.rangeBoost = 3
Skills.perLevel = 0.06

function Skills.levelOf(xp)
    local level = math.floor(math.sqrt(math.max(0, xp or 0) / Skills.xpUnit))
    return math.min(Skills.maxLevel, level)
end

function Skills.xpFor(level)
    return level * level * Skills.xpUnit
end

function Skills.data(settler)
    if type(settler.skills) ~= "table" then settler.skills = {} end
    return settler.skills
end

function Skills.level(settler, skill)
    return Skills.levelOf(Skills.data(settler)[skill])
end

function Skills.totalLevel(settler)
    local total = 0
    for _, skill in ipairs(Skills.list) do total = total + Skills.level(settler, skill) end
    return total
end

function Skills.best(settler)
    local best, bestLevel = nil, 0
    for _, skill in ipairs(Skills.list) do
        local level = Skills.level(settler, skill)
        if level > bestLevel then best, bestLevel = skill, level end
    end
    return best, bestLevel
end

function Skills.gain(camp, uid, skill, xp)
    local settler = camp.settlers[uid]
    if settler == nil or xp <= 0 then return false end
    local data = Skills.data(settler)
    local before = Skills.levelOf(data[skill])
    data[skill] = (data[skill] or 0) + xp
    local after = Skills.levelOf(data[skill])
    if after > before then
        local label = ALifeCamp.T ~= nil and ALifeCamp.T("Skill_" .. skill) or skill
        Store.log(camp, "skill", settler.name, label .. " " .. after)
        return true
    end
    return false
end

function Skills.factor(camp, skill)
    local total, count = 0, 0
    for _, settler in pairs(camp.settlers) do
        local role = settler.role or "worker"
        if Skills.primary[role] == skill then
            total = total + Skills.level(settler, skill)
            count = count + 1
        end
    end
    if count == 0 then return 1 end
    return 1 + Skills.perLevel * (total / count)
end

function Skills.hasRange(camp)
    local Build = ALifeCamp.Build
    if Build == nil then return false end
    for _, project in pairs(Build.plan(camp).items) do
        if project.kind == "range" and project.status == "done" and not project.retired then return true end
    end
    return false
end

function Skills.step(camp, minutes)
    local boost = Skills.hasRange(camp) and Skills.rangeBoost or 1
    local list = Skills.list
    local levelUps = 0
    for uid, settler in pairs(camp.settlers) do
        local role = settler.role or "worker"
        local main = Skills.primary[role] or "scavenge"
        if Skills.gain(camp, uid, main, Skills.workRate * minutes * boost) then levelUps = levelUps + 1 end
        settler.sideIndex = ((settler.sideIndex or 0) + math.floor(minutes + 0.5)) % (#list * 4)
        local side = list[math.floor(settler.sideIndex / 4) + 1]
        if side ~= main and Skills.gain(camp, uid, side, Skills.sideRate * minutes * boost) then levelUps = levelUps + 1 end
    end
    return levelUps
end

function Skills.maxAll(camp)
    for _, settler in pairs(camp.settlers) do
        local data = Skills.data(settler)
        for _, skill in ipairs(Skills.list) do data[skill] = Skills.xpFor(Skills.maxLevel) end
    end
end

function Skills.summary(settler)
    local best, level = Skills.best(settler)
    return best, level, Skills.totalLevel(settler)
end

return Skills
