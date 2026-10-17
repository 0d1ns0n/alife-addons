require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampOptions"

ALifeCamp = ALifeCamp or {}

local T = ALifeCamp.T
local Store = ALifeCamp.Store

local Features = {}
ALifeCamp.Features = Features

Features.specs = {}
Features.byKey = {}

local function bucket()
    local data = Store.data()
    if type(data.features) ~= "table" then data.features = {} end
    return data.features
end
Features.bucket = bucket

local function resort()
    table.sort(Features.specs, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.order < b.order
    end)
end

function Features.define(spec)
    if type(spec) ~= "table" or spec.key == nil then return nil end
    spec.key = tostring(spec.key)
    spec.default = spec.default == true
    spec.name = spec.name or ("Feat_" .. spec.key)
    spec.desc = spec.desc or ("FeatHint_" .. spec.key)
    spec.priority = spec.priority or 50
    local old = Features.byKey[spec.key]
    if old ~= nil then
        for i = #Features.specs, 1, -1 do
            if Features.specs[i] == old then table.remove(Features.specs, i) end
        end
    end
    spec.order = #Features.specs + 1
    Features.byKey[spec.key] = spec
    Features.specs[#Features.specs + 1] = spec
    resort()
    return spec
end

function Features.get(key)
    local value
    local ok, b = pcall(bucket)
    if ok and type(b) == "table" then value = b[key] end
    if value == nil then
        local spec = Features.byKey[key]
        return spec ~= nil and spec.default == true
    end
    return value == true
end

function Features.on(key)
    return Features.get(key) == true
end

function Features.set(key, value)
    if key == nil then return false end
    value = value == true
    local changed = Features.get(key) ~= value
    local ok, b = pcall(bucket)
    if ok and type(b) == "table" then b[key] = value end
    if changed then print("[ALifeCamp:Features] " .. tostring(key) .. "=" .. tostring(value)) end
    local spec = Features.byKey[key]
    if spec ~= nil and type(spec.after) == "function" then pcall(spec.after, value) end
    return value
end

function Features.toggle(key)
    return Features.set(key, not Features.on(key))
end

function Features.list()
    local out = {}
    for _, spec in ipairs(Features.specs) do
        out[#out + 1] = { key = spec.key, name = spec.name, desc = spec.desc, on = Features.on(spec.key), default = spec.default == true, priority = spec.priority }
    end
    return out
end

function Features.lines()
    local lines = {}
    if #Features.specs == 0 then return lines end
    lines[#lines + 1] = { text = "" }
    lines[#lines + 1] = { text = T("FeatSection"), r = 0.6, g = 0.85, b = 1 }
    local help = ALifeCamp.TN("FeatHelp")
    if help ~= nil then lines[#lines + 1] = { text = help, r = 0.7, g = 0.7, b = 0.75 } end
    for _, spec in ipairs(Features.specs) do
        local key = spec.key
        local on = Features.on(key)
        lines[#lines + 1] = {
            text = T("OptRow", T(spec.name), T(on and "OptOn" or "OptOff")),
            r = on and 0.6 or 0.78, g = on and 0.95 or 0.78, b = on and 0.65 or 0.8, hover = true,
            click = function() Features.toggle(key) end,
        }
        local hint = ALifeCamp.TN(spec.desc)
        if hint ~= nil then lines[#lines + 1] = { text = hint, r = 0.62, g = 0.62, b = 0.68, indent = 18 } end
    end
    return lines
end

local Options = ALifeCamp.Options
if Options ~= nil and type(Options.lines) == "function" and Options.alcFeaturesWrapped ~= true then
    Options.alcFeaturesWrapped = true
    local base = Options.lines
    Options.lines = function(camp)
        local lines = base(camp)
        if type(lines) ~= "table" then lines = {} end
        local ok, extra = pcall(Features.lines)
        if ok and type(extra) == "table" then
            for _, line in ipairs(extra) do lines[#lines + 1] = line end
        end
        return lines
    end
end

Features.define({
    key = "outposts",
    name = "Feat_outposts",
    desc = "FeatHint_outposts",
    default = false,
    priority = 10,
    after = function(value)
        if value == true then
            local Outposts = ALifeCamp.Outposts
            if Outposts ~= nil and type(Outposts.enable) == "function" then pcall(Outposts.enable) end
        end
    end,
})

return Features
