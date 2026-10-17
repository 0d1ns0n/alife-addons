ALifeCamp = ALifeCamp or {}

function ALifeCamp.T(key, ...)
    return getText("UI_ALC_" .. key, ...)
end

function ALifeCamp.TN(key)
    local text = getTextOrNull("UI_ALC_" .. key)
    if text == nil or text == "UI_ALC_" .. key then return nil end
    return text
end

return ALifeCamp.T
