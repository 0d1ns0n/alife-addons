ProjectALife = ProjectALife or {}
require "ProjectALife/Talk/ALifeSpeech"

local Speech = ProjectALife.Speech
if Speech == nil then return end

local function tr(name, ...)
    return getText("UI_ALRU_Sp_" .. name, ...)
end

Speech.months = setmetatable({}, { __index = function(_, index) return tr("M_" .. tostring(index)) end })
Speech.weekdays = setmetatable({}, { __index = function(_, index) return tr("W_" .. tostring(index)) end })

function Speech.timeText(hour)
    hour = tonumber(hour) or 12
    if hour == 0 then return tr("midnight") end
    if hour == 12 then return tr("noon") end
    if hour < 5 then return tr("night", tostring(hour)) end
    if hour < 12 then return tr("morning", tostring(hour)) end
    if hour < 17 then return tr("day", tostring(hour - 12)) end
    return tr("evening", tostring(hour - 12))
end

local originalRender = Speech.render

function Speech.render(text, vars, shell, localized)
    if type(text) ~= "string" then return nil end
    if localized ~= true then
        local Text = ProjectALife.Text
        if Text ~= nil then
            local template = nil
            if Text.female(shell) then template = Text.lookup(Text.lineKey(text) .. "_f") end
            if template == nil then template = Text.lookup(Text.lineKey(text)) end
            if template ~= nil then text = template end
        end
    end
    vars = type(vars) == "table" and vars or {}
    local clock = nil
    local sx, sy = nil, nil
    if shell ~= nil then pcall(function() sx, sy = shell:getX(), shell:getY() end) end
    local function value(key)
        if vars[key] ~= nil then return tostring(vars[key]) end
        if key == "town" then return Speech.nearestTown(sx, sy) or tr("town") end
        if key == "destination" then return tr("destination") end
        if key == "den" then return tr("den") end
        clock = clock or Speech.clock()
        if key == "day" then return tostring((tonumber(clock.daysSurvived) or 0) + 1) end
        if key == "date" then return tostring(clock.day) .. " " .. (Speech.months[clock.month] or tr("month_default")) end
        if key == "time" then return Speech.timeText(clock.hour) end
        if key == "weekday" then return Speech.weekdays[Speech.weekday(clock.year, clock.month, clock.day) + 1] end
        if key == "weapon" then return tr("weapon") end
        if key == "faction" or key == "group" then return tr("faction") end
        if key == "name" then return Speech.names[ZombRand(#Speech.names) + 1] end
        if key == "street" then return Speech.streets[ZombRand(#Speech.streets) + 1] end
        if key == "address" then return tostring(100 + ZombRand(8900)) .. " " .. Speech.streets[ZombRand(#Speech.streets) + 1] end
        if key == "unit" or key == "callsign" then
            if Speech.military(shell) then return Speech.militaryCallsign() end
            local letters = { "Adam", "Boy", "Charles", "David", "Edward", "Frank", "George", "Henry", "Lincoln", "Mary", "Nora", "Robert", "Sam", "Tom" }
            return tostring(1 + ZombRand(9)) .. "-" .. letters[ZombRand(#letters) + 1] .. "-" .. tostring(10 + ZombRand(80))
        end
        if key == "from" or key == "to" then return tr("road") end
        if key == "count" then return tr("count") end
        return key
    end
    local rendered = string.gsub(text, "{([a-z]+)}", value)

    local first = string.find(rendered, "%a")
    if first ~= nil then
        for index = 1, first - 1 do
            if string.byte(rendered, index) > 127 then first = nil break end
        end
    end
    if first ~= nil then
        rendered = string.sub(rendered, 1, first - 1)
            .. string.upper(string.sub(rendered, first, first)) .. string.sub(rendered, first + 1)
    end
    return rendered
end

Speech.renderOriginal = originalRender
