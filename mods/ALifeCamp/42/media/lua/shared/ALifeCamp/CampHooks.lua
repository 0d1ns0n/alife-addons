require "ALifeCamp/CampText"

ALifeCamp = ALifeCamp or {}

local Hooks = {}
ALifeCamp.Hooks = Hooks

Hooks.lists = {}
Hooks.tabs = {}
Hooks.reported = {}
Hooks.prof = {}
Hooks.profAt = 0
Hooks.profEvery = 120000
Hooks.profSlow = 4

local function stamp()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return 0
end

local function flush(now)
    local rows = {}
    for key, row in pairs(Hooks.prof) do
        if row.max >= Hooks.profSlow then rows[#rows + 1] = { key = key, row = row } end
    end
    Hooks.prof = {}
    Hooks.profAt = now
    if #rows == 0 then return end
    table.sort(rows, function(a, b) return a.row.total > b.row.total end)
    for i = 1, math.min(#rows, 8) do
        local r = rows[i]
        print("[ALifeCamp:Perf] " .. r.key .. " calls=" .. r.row.n .. " total=" .. math.floor(r.row.total) .. "ms max=" .. math.floor(r.row.max) .. "ms")
    end
end

local function note(key, started)
    local now = stamp()
    local took = now - started
    local row = Hooks.prof[key]
    if row == nil then
        row = { n = 0, total = 0, max = 0 }
        Hooks.prof[key] = row
    end
    row.n = row.n + 1
    row.total = row.total + took
    if took > row.max then row.max = took end
    if now - Hooks.profAt >= Hooks.profEvery then flush(now) end
end

function Hooks.timed(label, fn)
    return function(...)
        local started = stamp()
        local a, b, c = fn(...)
        note(label, started)
        return a, b, c
    end
end

local function call(name, entry, camp, a, b, c)
    local started = stamp()
    local ok, value = pcall(entry.fn, camp, a, b, c)
    note(name .. "#" .. entry.order .. "/p" .. tostring(entry.priority), started)
    return ok, value
end

local function report(name, err)
    if Hooks.reported[name] then return end
    Hooks.reported[name] = true
    print("[ALifeCamp] hook " .. tostring(name) .. " failed: " .. tostring(err))
end

local function insert(list, entry)
    entry.order = #list + 1
    list[#list + 1] = entry
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.order < b.order
    end)
end

function Hooks.add(name, fn, priority)
    local list = Hooks.lists[name]
    if list == nil then
        list = {}
        Hooks.lists[name] = list
    end
    insert(list, { fn = fn, priority = priority or 50 })
end

function Hooks.each(name, camp, a, b)
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, err = call(name, entry, camp, a, b)
        if not ok then report(name, err) end
    end
end

function Hooks.sum(name, camp, a, b)
    local total = 0
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, value = call(name, entry, camp, a, b)
        if not ok then
            report(name, value)
        elseif type(value) == "number" then
            total = total + value
        end
    end
    return total
end

function Hooks.product(name, camp, a, b)
    local total = 1
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, value = call(name, entry, camp, a, b)
        if not ok then
            report(name, value)
        elseif type(value) == "number" then
            total = total * value
        end
    end
    return total
end

function Hooks.first(name, camp, a, b, c)
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, value = call(name, entry, camp, a, b, c)
        if not ok then
            report(name, value)
        elseif value ~= nil then
            return value
        end
    end
    return nil
end

function Hooks.collect(name, camp, a, b)
    local out = {}
    for _, entry in ipairs(Hooks.lists[name] or {}) do
        local ok, part = call(name, entry, camp, a, b)
        if not ok then
            report(name, part)
        elseif type(part) == "table" then
            for _, row in ipairs(part) do out[#out + 1] = row end
        end
    end
    return out
end

function Hooks.line(text, r, g, b, click)
    return { text = text, r = r or 0.88, g = g or 0.88, b = b or 0.9, click = click }
end

function Hooks.tab(id, titleKey, priority)
    for _, tab in ipairs(Hooks.tabs) do
        if tab.id == id then return tab end
    end
    local tab = { id = id, title = titleKey or ("Tab_" .. id), sections = {} }
    tab.priority = priority or 50
    insert(Hooks.tabs, tab)
    return tab
end

function Hooks.section(tabId, titleKey, fn, priority)
    local tab = Hooks.tab(tabId)
    insert(tab.sections, { title = titleKey, fn = fn, priority = priority or 50 })
end

function Hooks.tabLines(tab, camp)
    local lines = {}
    for _, section in ipairs(tab.sections) do
        local ok, part = pcall(section.fn, camp)
        if not ok then
            report("tab:" .. tostring(tab.id), part)
        elseif type(part) == "table" and #part > 0 then
            if section.title ~= nil then
                lines[#lines + 1] = { text = ALifeCamp.T(section.title), r = 0.6, g = 0.85, b = 1 }
            end
            for _, line in ipairs(part) do lines[#lines + 1] = line end
            lines[#lines + 1] = { text = "" }
        end
    end
    return lines
end

function Hooks.overview(camp)
    return Hooks.collect("overview", camp)
end

function Hooks.rand(n)
    if ZombRand ~= nil then return ZombRand(n) + 1 end
    return math.random(n)
end

Hooks.tab("life", "Tab_life", 40)
Hooks.tab("progress", "Tab_progress", 45)

return Hooks
