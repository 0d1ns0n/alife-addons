require "ALifeCamp/CampText"
require "ALifeCamp/CampHooks"

ALifeCamp = ALifeCamp or {}

local T = ALifeCamp.T

local Options = {}
ALifeCamp.Options = Options

Options.specs = {}
Options.byKey = {}
Options.groups = { "camp", "people", "life" }
Options.actions = {}

local function resort()
    table.sort(Options.specs, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.order < b.order
    end)
end

function Options.define(spec)
    spec.kind = spec.kind or "toggle"
    spec.group = spec.group or "camp"
    spec.priority = spec.priority or 50
    if spec.default == nil then
        if spec.kind == "toggle" then
            spec.default = true
        else
            spec.default = spec.values ~= nil and spec.values[1] or 0
        end
    end
    local old = Options.byKey[spec.key]
    if old ~= nil then
        for i = #Options.specs, 1, -1 do
            if Options.specs[i] == old then table.remove(Options.specs, i) end
        end
    end
    spec.order = #Options.specs + 1
    Options.byKey[spec.key] = spec
    Options.specs[#Options.specs + 1] = spec
    resort()
    return spec
end

function Options.get(camp, key)
    local spec = Options.byKey[key]
    local value
    if camp ~= nil and camp.options ~= nil then value = camp.options[key] end
    if value == nil and spec ~= nil then return spec.default end
    return value
end

function Options.on(camp, key)
    return Options.get(camp, key) == true
end

function Options.number(camp, key)
    local value = Options.get(camp, key)
    if type(value) == "number" then return value end
    return 0
end

function Options.set(camp, key, value)
    if camp == nil then return end
    if camp.options == nil then camp.options = {} end
    camp.options[key] = value
    local spec = Options.byKey[key]
    if spec ~= nil and type(spec.after) == "function" then pcall(spec.after, camp, value) end
end

function Options.cycle(camp, key)
    local spec = Options.byKey[key]
    if spec == nil then return nil end
    local current = Options.get(camp, key)
    local nextValue
    if spec.kind == "toggle" then
        nextValue = current ~= true
    else
        local values = spec.values or {}
        local index = 0
        for i, value in ipairs(values) do
            if value == current then index = i end
        end
        nextValue = values[index % #values + 1]
    end
    Options.set(camp, key, nextValue)
    return nextValue
end

function Options.valueText(spec, value)
    if spec.kind == "toggle" then
        return T(value == true and "OptOn" or "OptOff")
    end
    local text = ALifeCamp.TN("OptVal_" .. spec.key .. "_" .. tostring(value))
    if text ~= nil then return text end
    return tostring(value)
end

function Options.action(spec)
    spec.priority = spec.priority or 50
    for i = #Options.actions, 1, -1 do
        if Options.actions[i].key == spec.key then table.remove(Options.actions, i) end
    end
    Options.actions[#Options.actions + 1] = spec
    table.sort(Options.actions, function(a, b) return a.priority < b.priority end)
end

function Options.lines(camp)
    local lines = {}
    local grouped = {}
    for _, spec in ipairs(Options.specs) do
        grouped[spec.group] = grouped[spec.group] or {}
        table.insert(grouped[spec.group], spec)
    end
    local order = {}
    for _, group in ipairs(Options.groups) do order[#order + 1] = group end
    for group in pairs(grouped) do
        local known = false
        for _, name in ipairs(Options.groups) do
            if name == group then known = true end
        end
        if not known then order[#order + 1] = group end
    end
    lines[1] = { text = T("OptHelp"), r = 0.7, g = 0.7, b = 0.75 }
    if ALifeCamp.Lang ~= nil then
        lines[#lines + 1] = { text = "" }
        lines[#lines + 1] = { text = T("OptGroup_lang"), r = 0.6, g = 0.85, b = 1 }
        lines[#lines + 1] = {
            text = T("LangRow", ALifeCamp.Lang.label()),
            r = 1, g = 0.9, b = 0.55, hover = true,
            click = function() ALifeCamp.Lang.cycle() end,
        }
        local langHint = ALifeCamp.TN("LangHint")
        if langHint ~= nil then lines[#lines + 1] = { text = langHint, r = 0.62, g = 0.62, b = 0.68, indent = 18 } end
    end
    for _, group in ipairs(order) do
        if grouped[group] ~= nil then
            lines[#lines + 1] = { text = "" }
            lines[#lines + 1] = { text = T("OptGroup_" .. group), r = 0.6, g = 0.85, b = 1 }
            for _, spec in ipairs(grouped[group]) do
                local value = Options.get(camp, spec.key)
                local on = spec.kind == "toggle" and value == true or (spec.kind ~= "toggle" and value ~= 0 and value ~= false)
                local key = spec.key
                lines[#lines + 1] = {
                    text = T("OptRow", T("Opt_" .. key), Options.valueText(spec, value)),
                    r = on and 0.6 or 0.78, g = on and 0.95 or 0.78, b = on and 0.65 or 0.8, hover = true,
                    click = function(c) Options.cycle(c, key) end,
                }
                local hint = ALifeCamp.TN("OptHint_" .. key)
                if hint ~= nil then lines[#lines + 1] = { text = hint, r = 0.62, g = 0.62, b = 0.68, indent = 18 } end
            end
        end
    end
    if #Options.actions > 0 then
        lines[#lines + 1] = { text = "" }
        lines[#lines + 1] = { text = T("OptGroup_actions"), r = 0.6, g = 0.85, b = 1 }
        for _, spec in ipairs(Options.actions) do
            local run = spec.run
            lines[#lines + 1] = { text = T("Act_" .. spec.key), r = 1, g = 0.7, b = 0.5, click = function(c) run(c) end }
            local hint = ALifeCamp.TN("ActHint_" .. spec.key)
            if hint ~= nil then lines[#lines + 1] = { text = hint, r = 0.62, g = 0.62, b = 0.68, indent = 18 } end
        end
    end
    return lines
end

Options.define({ key = "expand", group = "camp", priority = 10, default = true })
Options.define({ key = "raids", group = "camp", priority = 11, default = true })
Options.define({ key = "autoPlan", group = "camp", priority = 12, default = true })
Options.define({ key = "recruit", group = "people", priority = 10, default = true })
Options.define({ key = "vehicles", group = "people", priority = 11, default = true })
Options.define({
    key = "adopt", group = "camp", priority = 13, default = false,
    after = function(camp, value)
        if value == true then
            Options.set(camp, "demolish", false)
            if ALifeCamp.Adopt ~= nil then pcall(ALifeCamp.Adopt.discover, camp) end
        end
    end,
})
Options.define({
    key = "demolish", group = "camp", priority = 14, default = false,
    after = function(camp, value)
        if value == true then
            Options.set(camp, "adopt", false)
            if (camp.phase == nil or camp.phase == "clear") and ALifeCamp.Clear ~= nil and type(ALifeCamp.Clear.state) == "function" then
                local ok, state = pcall(ALifeCamp.Clear.state, camp)
                if ok and type(state) == "table" then
                    state.index = 0
                    state.passDone = false
                    state.lastRemoved = 1
                end
            end
        end
    end,
})
Options.define({
    key = "border", group = "camp", priority = 15, default = true,
    after = function()
        local markers = ALifeCamp.Markers
        if markers ~= nil and type(markers.refresh) == "function" and getPlayer ~= nil then
            pcall(markers.refresh, getPlayer(), true)
        end
    end,
})

return Options
