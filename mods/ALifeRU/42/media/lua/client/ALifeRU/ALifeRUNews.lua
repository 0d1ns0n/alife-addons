require "ISUI/ISPanel"

ALifeRU = ALifeRU or {}
local Client = ALifeRU.Client or {}
ALifeRU.Client = Client

Client.toasts = Client.toasts or {}
Client.life = 12000
Client.fade = 700

local KINDS = {
    alert = { 0.95, 0.36, 0.30, "UI_ALRU_K_alert" },
    police = { 0.42, 0.62, 1.00, "UI_ALRU_K_police" },
    aid = { 0.42, 0.86, 0.52, "UI_ALRU_K_aid" },
    military = { 0.74, 0.78, 0.42, "UI_ALRU_K_military" },
    info = { 0.86, 0.86, 0.92, "UI_ALRU_K_info" },
}

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return math.floor(os.time() * 1000)
end

local function wrap(text, width, font)
    local lines = {}
    local manager = getTextManager()
    for paragraph in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
        local line = ""
        for word in string.gmatch(paragraph, "%S+") do
            local attempt = line == "" and word or (line .. " " .. word)
            if line ~= "" and manager:MeasureStringX(font, attempt) > width then
                lines[#lines + 1] = line
                line = word
            else
                line = attempt
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end

NewsToast = ISPanel:derive("NewsToast")

function NewsToast:new(text, kind, title)
    local core = getCore()
    local width = math.min(520, math.floor(core:getScreenWidth() * 0.42))
    local font = UIFont.Small
    local manager = getTextManager()
    local lineHeight = manager:getFontHeight(font)
    local lines = wrap(text, width - 28, font)
    local height = 14 + lineHeight + 4 + #lines * lineHeight + 12
    local x = math.floor(core:getScreenWidth() / 2 - width / 2)
    local o = ISPanel:new(x, 60, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.lines = lines
    o.font = font
    o.lineHeight = lineHeight
    o.kind = KINDS[kind] or KINDS.info
    o.title = title
    o.born = nowMs()
    o.moveWithMouse = false
    return o
end

function NewsToast:alpha()
    local age = nowMs() - self.born
    if age < Client.fade then return age / Client.fade end
    local left = Client.life - age
    if left < Client.fade then return math.max(0, left / Client.fade) end
    return 1
end

function NewsToast:draw()
    local a = self:alpha()
    local color = self.kind
    self:drawRect(0, 0, self.width, self.height, 0.78 * a, 0.04, 0.04, 0.06)
    self:drawRect(0, 0, 5, self.height, a, color[1], color[2], color[3])
    local head = getText(color[4])
    if self.title ~= nil and self.title ~= "" then head = head .. "  -  " .. tostring(self.title) end
    self:drawText(head, 16, 8, color[1], color[2], color[3], a, self.font)
    local y = 8 + self.lineHeight + 4
    for i = 1, #self.lines do
        self:drawText(self.lines[i], 16, y, 0.96, 0.96, 0.96, a, self.font)
        y = y + self.lineHeight
    end
end

function NewsToast:prerender()
    local ok, err = pcall(self.draw, self)
    if not ok then
        Client.broken = true
        print("[ALifeRU] toast draw failed: " .. tostring(err))
        Client.drop(self)
    end
end

function NewsToast:update()
    ISPanel.update(self)
    if nowMs() - self.born > Client.life then Client.drop(self) end
end

function Client.layout()
    local y = 60
    for _, toast in ipairs(Client.toasts) do
        toast:setY(y)
        y = y + toast.height + 6
    end
end

function Client.drop(toast)
    for i = #Client.toasts, 1, -1 do
        if Client.toasts[i] == toast then table.remove(Client.toasts, i) end
    end
    pcall(function() toast:setVisible(false) end)
    pcall(function() toast:removeFromUIManager() end)
    Client.layout()
end

function Client.push(text, kind, title)
    if text == nil or text == "" or Client.broken == true then return false end
    local ok, err = pcall(function()
        local toast = NewsToast:new(text, kind, title)
        toast:initialise()
        toast:addToUIManager()
        toast:setAlwaysOnTop(true)
        toast:setVisible(true)
        Client.toasts[#Client.toasts + 1] = toast
        while #Client.toasts > 4 do Client.drop(Client.toasts[1]) end
        Client.layout()
    end)
    if not ok then print("[ALifeRU] toast failed: " .. tostring(err)) end
    return ok
end

function Client.playAt(name, x, y, z, volume)
    pcall(function()
        local emitter = getWorld():getFreeEmitter(x, y, z or 0)
        if emitter == nil then return end
        local policy = ProjectALife and ProjectALife.AudioPolicy
        if policy ~= nil and type(policy.playLocal) == "function" then
            policy.playLocal(emitter, name, volume or 1)
        else
            emitter:playSound(name)
        end
    end)
end

function Client.handle(command, payload)
    if type(payload) ~= "table" then return false end
    if command == "news" then
        return Client.push(payload.text, payload.kind, payload.title)
    elseif command == "sound" then
        Client.playAt(payload.name, tonumber(payload.x) or 0, tonumber(payload.y) or 0, tonumber(payload.z) or 0, tonumber(payload.volume) or 1)
        return true
    end
    return false
end

local function onServerCommand(module, command, payload)
    if module ~= "ALifeRU" then return end
    Client.handle(command, payload)
end

if Events ~= nil and Events.OnServerCommand ~= nil and not Client.hooked then
    Events.OnServerCommand.Add(onServerCommand)
    Client.hooked = true
end

return Client
