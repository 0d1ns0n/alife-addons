ALifeCamp = ALifeCamp or {}

function ALifeCamp.T(key, ...)
    local full = "UI_ALC_" .. key
    local Lang = ALifeCamp.Lang
    if Lang ~= nil and Lang.overrideActive() then
        local text = Lang.resolve(full)
        if text == nil then text = getTextOrNull(full) end
        if text == nil or text == full then text = Lang.en(full) end
        if text == nil then text = full end
        return Lang.format(text, ...)
    end
    return getText(full, ...)
end

function ALifeCamp.TN(key)
    local full = "UI_ALC_" .. key
    local Lang = ALifeCamp.Lang
    if Lang ~= nil and Lang.overrideActive() then
        local text = Lang.resolve(full)
        if text == nil then text = getTextOrNull(full) end
        if text == nil or text == full then text = Lang.en(full) end
        if text == full then text = nil end
        return text
    end
    local text = getTextOrNull(full)
    if text == nil or text == full then return nil end
    return text
end

require "ALifeCamp/CampLang"

return ALifeCamp.T
