ProjectALife = ProjectALife or {}
ALifeRU = ALifeRU or {}

local Voice = { passes = 0, translated = 0, limit = 400000 }
ALifeRU.Voice = Voice

Voice.roots = { "FactionVoiceStyles", "ReactionLibrary", "Gossip", "VoiceCatalog" }
Voice.skip = { adapters = true, metrics = true, shell = true, cache = true }

local function translated(text)
    if string.len(text) < 6 or string.find(text, " ", 1, true) == nil then return nil end
    local Text = ProjectALife.Text
    if Text == nil or type(Text.hash) ~= "function" or type(getTextOrNull) ~= "function" then return nil end
    local key = "RD_ALifeLine_" .. Text.hash(text)
    local ok, value = pcall(getTextOrNull, key)
    if ok and type(value) == "string" and value ~= "" and value ~= key then return value end
    return nil
end

local function walk(root, seen, budget)
    local stack = { root }
    local changed = 0
    while #stack > 0 do
        local node = table.remove(stack)
        local updates = nil
        for key, value in pairs(node) do
            local kind = type(value)
            if kind == "string" then
                local ru = translated(value)
                if ru ~= nil then
                    updates = updates or {}
                    updates[#updates + 1] = { key, ru }
                end
            elseif kind == "table" and not seen[value] and not Voice.skip[key] then
                seen[value] = true
                budget.n = budget.n + 1
                if budget.n < Voice.limit then stack[#stack + 1] = value end
            end
        end
        if updates ~= nil then
            for _, pair in ipairs(updates) do node[pair[1]] = pair[2] end
            changed = changed + #updates
        end
    end
    return changed
end

function Voice.run()
    local seen = {}
    seen[ProjectALife] = true
    if ProjectALife.Text ~= nil then seen[ProjectALife.Text] = true end
    local budget = { n = 0 }
    local total = 0
    for _, name in ipairs(Voice.roots) do
        local root = ProjectALife[name]
        if type(root) == "table" and not seen[root] then
            seen[root] = true
            total = total + walk(root, seen, budget)
        end
    end
    Voice.passes = Voice.passes + 1
    Voice.translated = Voice.translated + total
    if total > 0 then print("[ALifeRU-Voice] pass " .. tostring(Voice.passes) .. ": " .. tostring(total) .. " lines") end
    return total
end

local function safeRun()
    pcall(Voice.run)
end

safeRun()

if Events ~= nil then
    if Events.OnGameStart ~= nil then Events.OnGameStart.Add(safeRun) end
    if Events.OnGameTimeLoaded ~= nil then Events.OnGameTimeLoaded.Add(safeRun) end
    if Events.EveryOneMinute ~= nil then
        local ticks = 0
        local function late()
            ticks = ticks + 1
            safeRun()
            if ticks >= 3 then Events.EveryOneMinute.Remove(late) end
        end
        Events.EveryOneMinute.Add(late)
    end
end

return Voice
