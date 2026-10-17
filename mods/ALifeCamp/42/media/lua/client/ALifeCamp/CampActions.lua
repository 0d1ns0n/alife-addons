require "TimedActions/ISBaseTimedAction"

ISALCPlaceFlag = ISBaseTimedAction:derive("ISALCPlaceFlag")

function ISALCPlaceFlag:isValid()
    return ALifeCamp.Flags.have(self.character) > 0
end

function ISALCPlaceFlag:update()
    self.character:faceLocation(self.x + 0.5, self.y + 0.5)
end

function ISALCPlaceFlag:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISALCPlaceFlag:stop()
    ISBaseTimedAction.stop(self)
end

function ISALCPlaceFlag:perform()
    ISBaseTimedAction.perform(self)
end

function ISALCPlaceFlag:complete()
    ALifeCamp.Flags.commitPlace(self.character, self.x, self.y, self.z)
    return true
end

function ISALCPlaceFlag:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 70
end

function ISALCPlaceFlag:new(character, x, y, z)
    local o = ISBaseTimedAction.new(self, character)
    o.x = x
    o.y = y
    o.z = z
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

ISALCTakeFlag = ISBaseTimedAction:derive("ISALCTakeFlag")

function ISALCTakeFlag:isValid()
    return self.object ~= nil and self.object:getSquare() ~= nil
end

function ISALCTakeFlag:update()
    self.character:faceThisObject(self.object)
end

function ISALCTakeFlag:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISALCTakeFlag:stop()
    ISBaseTimedAction.stop(self)
end

function ISALCTakeFlag:perform()
    ISBaseTimedAction.perform(self)
end

function ISALCTakeFlag:complete()
    ALifeCamp.Flags.commitTake(self.character, self.object)
    return true
end

function ISALCTakeFlag:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function ISALCTakeFlag:new(character, object)
    local o = ISBaseTimedAction.new(self, character)
    o.object = object
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
