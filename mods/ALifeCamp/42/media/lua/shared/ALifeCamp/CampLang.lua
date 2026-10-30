ALifeCamp = ALifeCamp or {}

local Lang = {}
ALifeCamp.Lang = Lang

Lang.AUTO = "AUTO"
Lang.codes = { "AUTO", "EN", "RU", "UA", "DE", "IT" }

local FILE = "ALifeCamp_language.txt"

Lang.choice = nil
Lang.tables = {}

local function restore()
    if Lang.choice ~= nil then return end
    Lang.choice = Lang.AUTO
    pcall(function()
        local reader = getFileReader(FILE, false)
        if reader == nil then return end
        local line = reader:readLine()
        reader:close()
        if line ~= nil then
            line = line:gsub("%s", "")
            if line ~= "" then Lang.choice = line end
        end
    end)
end

function Lang.get()
    restore()
    return Lang.choice
end

function Lang.overrideActive()
    return Lang.get() ~= Lang.AUTO
end

function Lang.table(code)
    if code == nil or code == Lang.AUTO then return nil end
    local cached = Lang.tables[code]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local loaded
    pcall(function() loaded = require("ALifeCamp/Lang/" .. code) end)
    if type(loaded) ~= "table" then loaded = false end
    Lang.tables[code] = loaded
    if loaded == false then return nil end
    return loaded
end

function Lang.resolve(full)
    local t = Lang.table(Lang.get())
    if t == nil then return nil end
    return t[full]
end

function Lang.en(full)
    local t = Lang.table("EN")
    if t == nil then return nil end
    return t[full]
end

function Lang.format(text, ...)
    if text == nil then return nil end
    if select("#", ...) == 0 then return text end
    local args = { ... }
    return (text:gsub("%%(%d+)", function(digits)
        local value = args[tonumber(digits)]
        if value == nil then return "%" .. digits end
        return tostring(value)
    end))
end

function Lang.set(code)
    restore()
    Lang.choice = code or Lang.AUTO
    pcall(function()
        local writer = getFileWriter(FILE, true, false)
        if writer == nil then return end
        writer:write(Lang.choice)
        writer:close()
    end)
    if ALifeCamp.Window ~= nil and ALifeCamp.Window.instance ~= nil then
        pcall(function() ALifeCamp.Window.instance:dropLines() end)
    end
end

function Lang.cycle()
    restore()
    local index = 1
    for i, code in ipairs(Lang.codes) do
        if code == Lang.choice then index = i end
    end
    Lang.set(Lang.codes[index % #Lang.codes + 1])
    return Lang.choice
end

function Lang.label()
    local code = Lang.get()
    if code == Lang.AUTO then
        return (ALifeCamp.TN and ALifeCamp.TN("LangAuto")) or "Auto"
    end
    return (ALifeCamp.TN and ALifeCamp.TN("LangName_" .. code)) or code
end

return Lang
