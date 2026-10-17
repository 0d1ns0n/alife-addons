dofile(MOCK)
for _, name in ipairs({ "Sanitary", "Health", "Life", "Progress", "Council", "Houses", "Fortress" }) do
    SKIPMOD["shared/ALifeCamp/Camp" .. name .. ".lua"] = true
    SKIPMOD["@addon/shared/ALifeCampCheats/Cheats" .. name .. ".lua"] = true
end
LOADMOD(ROOT)

local Motor = ALifeCamp.Motor
check("motor module loaded", Motor ~= nil)

local fleet = { { id = 1 }, { id = 2 }, { id = 3 } }
local function setLike()
    return {
        size = function() return #fleet end,
        iterator = function()
            local index = 0
            return {
                hasNext = function() return index < #fleet end,
                next = function() index = index + 1 return fleet[index] end,
            }
        end,
    }
end
local realCell = getCell
getCell = function() return { getVehicles = setLike, getGridSquare = function() return nil end } end
local seen = 0
Motor.each(function() seen = seen + 1 end)
check("a java Set without get is walked by its iterator", seen == 3, seen)

getCell = function()
    return { getVehicles = function()
        return { size = function() return #fleet end, get = function(_, i) return fleet[i + 1] end }
    end }
end
seen = 0
Motor.each(function() seen = seen + 1 end)
check("a list with get is still walked", seen == 3, seen)

getCell = function() return { getVehicles = function() return {} end } end
seen = 0
Motor.each(function() seen = seen + 1 end)
check("an empty unknown list is harmless", seen == 0)
check("no errors were swallowed along the way", #SILENT == 0, #SILENT)

getCell = realCell
local missingKeys = {}
for k in pairs(MISSING) do missingKeys[#missingKeys + 1] = k end
table.sort(missingKeys)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = missingKeys }
