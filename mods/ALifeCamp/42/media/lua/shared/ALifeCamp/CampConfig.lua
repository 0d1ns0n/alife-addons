ALifeCamp = ALifeCamp or {}

local Config = {
    key = "ALifeCamp",
    flagItem = "ALifeCamp.CampFlag",
    flagCount = 4,
    flagSprite = "fencing_01_19",
    crateSprite = "carpentry_01_19",
    minSide = 8,
    maxSide = 100000,
    maxArea = 1000000000,
    logLimit = 80,
    crateCapacity = 1000000,
    nameCount = 12,
    border = { r = 0.95, g = 0.75, b = 0.2 },
    pendingColor = { r = 0.3, g = 0.85, b = 0.95 },
    markerStep = 3,
    markerRange = 45,
    markerLimit = 90,
    windowKey = "KEY_F6",
}

ALifeCamp.Config = Config

function ALifeCamp.isEmpty(t)
    if t == nil then return true end
    for _ in pairs(t) do return false end
    return true
end

return Config
