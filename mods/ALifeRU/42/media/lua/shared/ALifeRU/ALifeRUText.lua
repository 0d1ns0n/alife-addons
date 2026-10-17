ALifeRU = ALifeRU or {}

local Text = {}
ALifeRU.Text = Text

Text.townForms = { "loc", "near", "to", "over", "Loc", "Near", "To", "Over" }

function Text.tr(key, ...)
    local value = getText(key, ...)
    if value == nil or value == key then return nil end
    return value
end

function Text.dirIndex(dx, dy)
    local angle
    if math.atan2 then
        angle = math.atan2(dy, dx)
    else
        angle = math.atan(dy / (dx == 0 and 0.0001 or dx))
        if dx < 0 then angle = angle + math.pi end
    end
    local index = math.floor(angle / (math.pi / 4) + 0.5)
    return index - 8 * math.floor(index / 8)
end

function Text.dir(index, capital)
    return Text.tr("UI_ALRU_Dir_" .. tostring(index) .. (capital and "_c" or "")) or ""
end

function Text.meters(tiles)
    tiles = tonumber(tiles) or 0
    if tiles < 30 then return Text.tr("UI_ALRU_Meters_near") or "" end
    return Text.tr("UI_ALRU_Meters", tostring(math.max(10, math.floor(tiles / 10 + 0.5) * 10))) or ""
end

function Text.town(id, form)
    local key = "UI_ALRU_Town_" .. tostring(id) .. "_" .. tostring(form)
    return Text.tr(key)
end

function Text.townSet(id)
    local known = Text.tr("UI_ALRU_Town_" .. tostring(id) .. "_nom")
    local set = {}
    if known == nil then
        id = "unknown"
        known = Text.tr("UI_ALRU_Town_unknown_nom") or ""
    end
    set.name = known
    for _, form in ipairs(Text.townForms) do
        set[form] = Text.town(id, form) or ""
    end
    return set
end

function Text.faction(id, bloc)
    id = tostring(id or "")
    local row = {
        who = Text.tr("UI_ALRU_F_" .. id),
        Who = Text.tr("UI_ALRU_FC_" .. id),
        crew = Text.tr("UI_ALRU_C_" .. id),
        Crew = Text.tr("UI_ALRU_CC_" .. id),
    }
    if row.who == nil or row.crew == nil then
        local key = tostring(bloc or "")
        local generic = Text.tr("UI_ALRU_B_" .. key) or Text.tr("UI_ALRU_B_generic") or ""
        local capital = Text.tr("UI_ALRU_BC_" .. key) or Text.tr("UI_ALRU_BC_generic") or ""
        row = { who = generic, Who = capital, crew = generic, Crew = capital }
    end
    return row
end

function Text.fill(template, vars)
    local text = tostring(template or "")
    for key, value in pairs(vars or {}) do
        text = string.gsub(text, "{" .. key .. "}", function() return tostring(value) end)
    end
    return text
end

return Text
