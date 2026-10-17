require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ALifeCamp/CampConfig"
require "ALifeCamp/CampText"
require "ALifeCamp/CampGeo"
require "ALifeCamp/CampStore"
require "ALifeCamp/CampBlueprints"
require "ALifeCamp/CampBuild"
require "ALifeCamp/CampPlan"
require "ALifeCamp/CampAdopt"

ALifeCamp = ALifeCamp or {}

local Geo = ALifeCamp.Geo
local Store = ALifeCamp.Store
local Bp = ALifeCamp.Blueprints
local Build = ALifeCamp.Build
local Plan = ALifeCamp.Plan
local T = ALifeCamp.T

local FONT = UIFont.Small

local function fh()
    return getTextManager():getFontHeight(FONT)
end

local function textWidth(text)
    return getTextManager():MeasureStringX(FONT, text)
end

local Canvas = ISPanel:derive("ALCPlanCanvas")
Canvas.__index = Canvas

Canvas.stateColors = {
    [Plan.FREE] = { 0.16, 0.28, 0.14 },
    [Plan.BLOCKED] = { 0.42, 0.3, 0.16 },
    [Plan.BUILDING] = { 0.46, 0.46, 0.5 },
    [Plan.WATER] = { 0.15, 0.3, 0.55 },
    [Plan.BUILT] = { 0.62, 0.62, 0.66 },
    [Plan.UNKNOWN] = { 0.12, 0.12, 0.13 },
    [Plan.ADOPTED] = { 0.3, 0.42, 0.52 },
}

Canvas.adoptColors = {
    queued = { 0.55, 0.62, 0.8 }, salvage = { 0.95, 0.7, 0.3 }, fortify = { 0.9, 0.45, 0.35 },
    fitout = { 0.45, 0.8, 0.55 }, done = { 0.25, 0.75, 0.85 },
}

function Canvas.districtColor(kind)
    local districts = ALifeCamp.Districts
    local value = districts ~= nil and type(districts.colors) == "table" and districts.colors[kind] or nil
    if type(value) ~= "table" then return { 1, 1, 1 } end
    if value.r ~= nil then return { value.r, value.g or value.r, value.b or value.r } end
    return { value[1] or 1, value[2] or value[1] or 1, value[3] or value[1] or 1 }
end

Canvas.kindColors = {
    house_s = { 0.95, 0.6, 0.2 }, house_m = { 0.95, 0.5, 0.15 }, house_l = { 0.9, 0.4, 0.1 },
    shed = { 0.95, 0.85, 0.25 }, campfire = { 0.9, 0.25, 0.2 }, farm = { 0.55, 0.9, 0.3 },
    tower = { 0.7, 0.45, 0.95 }, fence = { 0.95, 0.95, 0.95 },
}

function Canvas:new(x, y, w, h, owner)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    o.owner = owner
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.06, a = 1 }
    o.borderColor = { r = 0.5, g = 0.5, b = 0.55, a = 1 }
    return o
end

Canvas.minSize = 2
Canvas.maxSize = 40

function Canvas:geometry()
    local camp = self.owner:camp()
    if camp == nil then return nil end
    local w, h = Geo.width(camp), Geo.height(camp)
    local stamp = tostring(camp.id) .. ":" .. w .. "x" .. h
    if self.stamp ~= stamp or self.size == nil then
        self.stamp = stamp
        local fit = math.floor(math.min((self.width - 8) / w, (self.height - 8) / h))
        self.size = math.max(Canvas.minSize, math.min(Canvas.maxSize, fit))
        self.cx, self.cy = w / 2, h / 2
    end
    local size = self.size
    local ox = math.floor(self.width / 2 - self.cx * size)
    local oy = math.floor(self.height / 2 - self.cy * size)
    return camp, size, ox, oy, w, h
end

function Canvas:cellAt(px, py)
    local camp, size, ox, oy, w, h = self:geometry()
    if camp == nil then return nil end
    local cx = math.floor((px - ox) / size)
    local cy = math.floor((py - oy) / size)
    if cx < 0 or cy < 0 or cx >= w or cy >= h then return nil end
    return camp.x1 + cx, camp.y1 + cy
end

function Canvas:projectAt(x, y)
    local camp = self.owner:camp()
    if camp == nil then return nil end
    local best
    for _, project in ipairs(Build.list(camp)) do
        local rect = Bp.footprint(project)
        if project.kind ~= "fence" and project.kind ~= "court" and x >= rect.x1 and x <= rect.x2 and y >= rect.y1 and y <= rect.y2 then best = project end
    end
    return best
end

function Canvas:adoptAt(x, y)
    local camp = self.owner:camp()
    if camp == nil then return nil end
    for _, rec in ipairs(ALifeCamp.Adopt.list(camp)) do
        local r = rec.rect
        if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then return rec end
    end
    return nil
end

function Canvas:prerender()
    ISPanel.prerender(self)
    local camp, size, ox, oy, w, h = self:geometry()
    if camp == nil then return end
    local grid = self.owner.grid
    self:setStencilRect(0, 0, self.width, self.height)
    self:drawRect(ox, oy, w * size, h * size, 1, 0.1, 0.16, 0.09)
    if grid ~= nil then
        local firstX = math.max(0, math.floor(-ox / size))
        local lastX = math.min(w - 1, math.floor((self.width - ox) / size))
        local firstY = math.max(0, math.floor(-oy / size))
        local lastY = math.min(h - 1, math.floor((self.height - oy) / size))
        for cy = firstY, lastY do
            local row = cy * w
            for cx = firstX, lastX do
                local state = grid.cells[row + cx + 1]
                if state ~= nil and state ~= Plan.FREE then
                    local color = Canvas.stateColors[state]
                    self:drawRect(ox + cx * size, oy + cy * size, size, size, 1, color[1], color[2], color[3])
                end
            end
        end
    end
    for _, project in ipairs(Build.list(camp)) do
      if project.kind ~= "court" then
        local color = Canvas.kindColors[project.kind] or Canvas.districtColor(project.kind)
        if project.kind == "fence" then
            local rx, ry = ox + (project.x - camp.x1) * size, oy + (project.y - camp.y1) * size
            self:drawRectBorder(rx, ry, project.w * size, project.h * size, 0.9, color[1], color[2], color[3])
        else
            local rect = Bp.footprint(project)
            local rx, ry = ox + (rect.x1 - camp.x1) * size, oy + (rect.y1 - camp.y1) * size
            local rw, rh = (rect.x2 - rect.x1 + 1) * size, (rect.y2 - rect.y1 + 1) * size
            local alpha = project.status == "done" and 0.95 or 0.55
            self:drawRect(rx, ry, rw, rh, alpha, color[1], color[2], color[3])
            local progress = Build.progress(project)
            if project.status ~= "done" and progress > 0 then
                self:drawRect(rx, ry + rh - 3, math.floor(rw * progress), 3, 1, 0.2, 1, 0.3)
            end
            local selected = self.owner.selected == project.id
            self:drawRectBorder(rx, ry, rw, rh, 1, selected and 1 or 0.1, selected and 1 or 0.1, selected and 0.3 or 0.1)
        end
      end
    end
    local Adopt = ALifeCamp.Adopt
    for _, rec in ipairs(Adopt.list(camp)) do
        local color = Canvas.adoptColors[rec.status] or { 1, 1, 1 }
        local r = rec.rect
        local rx, ry = ox + (r.x1 - camp.x1) * size, oy + (r.y1 - camp.y1) * size
        local rw, rh = (r.x2 - r.x1 + 1) * size, (r.y2 - r.y1 + 1) * size
        self:drawRect(rx, ry, rw, rh, rec.status == "done" and 0.9 or 0.65, color[1], color[2], color[3])
        local progress = Adopt.overall(rec)
        if rec.status ~= "done" and progress > 0 then
            self:drawRect(rx, ry + rh - 3, math.floor(rw * progress), 3, 1, 0.2, 1, 0.3)
        end
        local selected = self.owner.selectedAdopt == rec.id
        self:drawRectBorder(rx, ry, rw, rh, 1, selected and 1 or 0.9, selected and 1 or 0.9, selected and 0.3 or 0.95)
    end
    local tool = self.owner.tool
    if tool ~= nil and self.hoverX ~= nil and tool ~= "fence" then
        local def = Bp.kinds[tool]
        local probe = { kind = tool, x = self.hoverX, y = self.hoverY, w = def.w, h = def.h }
        local rect = Bp.footprint(probe)
        local ok = Build.fits(camp, tool, self.hoverX, self.hoverY, def.w, def.h, nil, self.owner.door)
        local rx, ry = ox + (rect.x1 - camp.x1) * size, oy + (rect.y1 - camp.y1) * size
        local rw, rh = (rect.x2 - rect.x1 + 1) * size, (rect.y2 - rect.y1 + 1) * size
        if ok then
            self:drawRect(rx, ry, rw, rh, 0.45, 0.2, 1, 0.3)
        else
            self:drawRect(rx, ry, rw, rh, 0.45, 1, 0.2, 0.2)
        end
    end
    self:drawRectBorder(ox, oy, w * size, h * size, 1, 0.9, 0.75, 0.2)
    self:clearStencilRect()
end

function Canvas:onMouseMove(dx, dy)
    local drag = self.drag
    if drag ~= nil and Mouse.isLeftDown() then
        local mx, my = self:getMouseX(), self:getMouseY()
        if math.abs(mx - drag.px) + math.abs(my - drag.py) > 6 then drag.moved = true end
        if drag.moved then
            self.cx = drag.cx - (mx - drag.px) / self.size
            self.cy = drag.cy - (my - drag.py) / self.size
        end
        return true
    end
    local x, y = self:cellAt(self:getMouseX(), self:getMouseY())
    self.hoverX, self.hoverY = x, y
    return true
end

function Canvas:onMouseMoveOutside(dx, dy)
    self.hoverX, self.hoverY = nil, nil
    self:onMouseMove(dx, dy)
end

function Canvas:onMouseDown(px, py)
    self:geometry()
    self.drag = { px = px, py = py, cx = self.cx, cy = self.cy, moved = false }
    return true
end

function Canvas:onMouseUp(px, py)
    local drag = self.drag
    self.drag = nil
    if drag == nil or drag.moved then return true end
    local x, y = self:cellAt(px, py)
    if x ~= nil then self.owner:onCell(x, y) end
    return true
end

function Canvas:onMouseUpOutside(px, py)
    self.drag = nil
end

function Canvas:onMouseWheel(del)
    local camp, size, ox, oy, w, h = self:geometry()
    if camp == nil then return true end
    local mx, my = self:getMouseX(), self:getMouseY()
    local cellX = (mx - ox) / size
    local cellY = (my - oy) / size
    local grown = math.max(Canvas.minSize, math.min(Canvas.maxSize, size + (del < 0 and 1 or -1)))
    if grown ~= size then
        self.size = grown
        self.cx = cellX - (mx - self.width / 2) / grown
        self.cy = cellY - (my - self.height / 2) / grown
    end
    return true
end

function Canvas:onRightMouseDown(px, py)
    self.owner:onRotate()
    return true
end

local Planner = ISCollapsableWindow:derive("ALCPlanner")
Planner.__index = Planner
Planner.instance = nil
Planner.doors = { "S", "W", "N", "E" }
ALifeCamp.Planner = Planner

function Planner:camp()
    return Store.get(self.campId)
end

function Planner:button(label, fn)
    local b = ISButton:new(0, 0, 10, 10, label, self, fn)
    b:initialise()
    b:instantiate()
    b.borderColor = { r = 0.6, g = 0.6, b = 0.66, a = 0.8 }
    b.backgroundColor = { r = 0.13, g = 0.13, b = 0.16, a = 1 }
    b.backgroundColorMouseOver = { r = 0.3, g = 0.3, b = 0.36, a = 1 }
    self:addChild(b)
    return b
end

function Planner:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.tools = {}
    for _, kind in ipairs(Bp.order) do
        self.tools[kind] = self:button(T("Kind_" .. kind), function() self:selectTool(kind) end)
    end
    self.actions = {
        cursor = self:button(T("PlCursor"), function() self:selectTool(nil) end),
        generate = self:button(T("PlGenerate"), function() self:onGenerate() end),
        clear = self:button(T("PlClear"), function() self:onClearPlan() end),
        remove = self:button(T("PlRemove"), function() self:onRemove() end),
        rotate = self:button(T("PlRotate"), function() self:onRotate() end),
        close = self:button(T("PlClose"), function() self:close() end),
    }
    self.canvas = Canvas:new(0, 0, 10, 10, self)
    self.canvas:initialise()
    self.canvas:instantiate()
    self:addChild(self.canvas)
    self:layoutAll()
end

function Planner:layoutAll()
    self.laidW, self.laidH = self.width, self.height
    local th = self:titleBarHeight()
    local bh = fh() + 8
    local pad = 6
    local left = 0
    local ids = {}
    for _, kind in ipairs(Bp.order) do ids[#ids + 1] = self.tools[kind] end
    for _, id in ipairs({ "cursor", "generate", "clear", "remove", "rotate", "close" }) do ids[#ids + 1] = self.actions[id] end
    for _, b in ipairs(ids) do left = math.max(left, textWidth(b.title) + 24) end
    local y = th + pad
    for _, b in ipairs(ids) do
        b:setX(pad)
        b:setY(y)
        b:setWidth(left)
        b:setHeight(bh)
        y = y + bh + 3
    end
    self.infoY = self.height - self:resizeWidgetHeight() - (fh() + 4) * 4 - pad
    self.canvas:setX(left + pad * 2)
    self.canvas:setY(th + pad)
    self.canvas:setWidth(self.width - left - pad * 3)
    self.canvas:setHeight(math.max(60, self.infoY - th - pad * 2))
end

function Planner:selectTool(kind)
    self.tool = kind
    for id, b in pairs(self.tools) do
        if id == kind then
            b.backgroundColor = { r = 0.2, g = 0.5, b = 0.26, a = 1 }
        else
            b.backgroundColor = { r = 0.13, g = 0.13, b = 0.16, a = 1 }
        end
    end
    if kind ~= nil then
        self.selected = nil
        self.selectedAdopt = nil
    end
end

function Planner:onRotate()
    local index = 1
    for i, side in ipairs(Planner.doors) do
        if side == self.door then index = i end
    end
    self.door = Planner.doors[index % #Planner.doors + 1]
end

function Planner:note(key, ...)
    self.message = T(key, ...)
    self.messageAt = getTimestampMs()
end

function Planner:onCell(x, y)
    local camp = self:camp()
    if camp == nil then return end
    local tool = self.tool
    if tool == nil then
        local project = self.canvas:projectAt(x, y)
        local rec = project == nil and self.canvas:adoptAt(x, y) or nil
        self.selected = project ~= nil and project.id or nil
        self.selectedAdopt = rec ~= nil and rec.id or nil
        return
    end
    if tool == "fence" then
        for _, project in ipairs(Build.list(camp)) do
            if project.kind == "fence" then
                project.gate = self.door
                if (project.stage or 1) <= 1 and ALifeCamp.isEmpty(project.done) then
                    project.gates = ALifeCamp.Gates.layout(project.w, project.h, self.door)
                end
                self:note("PlGateSet", self.door)
                return
            end
        end
        local project, why = Build.add(camp, "fence", camp.x1, camp.y1, { w = Geo.width(camp), h = Geo.height(camp), gate = self.door })
        if project == nil then
            self:note("PlNo_" .. tostring(why))
        else
            project.gates = ALifeCamp.Gates.layout(project.w, project.h, self.door)
            self:note("PlAdded")
        end
        return
    end
    local project, why = Build.add(camp, tool, x, y, { door = self.door })
    if project == nil then
        self:note("PlNo_" .. tostring(why))
    else
        self.selected = project.id
        self:note("PlAdded")
        if camp.phase == "plan" then Store.log(camp, "planned", project.kind) end
    end
end

function Planner:onGenerate()
    local camp = self:camp()
    if camp == nil then return end
    local added = Plan.generate(camp)
    self:note("PlGenerated", tostring(added))
    Store.log(camp, "autoplan", added)
end

function Planner:onClearPlan()
    local camp = self:camp()
    if camp == nil then return end
    self:note("PlCleared", tostring(Plan.clearPlanned(camp)))
    self.selected = nil
end

function Planner:onRemove()
    local camp = self:camp()
    if camp == nil or self.selected == nil then return end
    Build.remove(camp, self.selected)
    self.selected = nil
    self:note("PlRemoved")
end

function Planner:update()
    ISCollapsableWindow.update(self)
    if self.laidW ~= self.width or self.laidH ~= self.height then self:layoutAll() end
    local camp = self:camp()
    if camp == nil then return end
    if self.grid == nil or self.grid.w ~= Geo.width(camp) or self.grid.h ~= Geo.height(camp) then
        self.grid = Plan.newGrid(camp)
    end
    Plan.scanStep(camp, self.grid, 300)
end

function Planner:infoLines(camp)
    local lines = {}
    local project = self.selected ~= nil and Build.get(camp, self.selected) or nil
    local rec = self.selectedAdopt ~= nil and ALifeCamp.Adopt.get(camp, self.selectedAdopt) or nil
    if rec ~= nil then
        local s = ALifeCamp.Adopt.summary(camp, rec)
        local beds = s.capacity > 0 and s.capacity or s.expected
        lines[#lines + 1] = T("PlAdoptInfo", tostring(s.id), T("AdSt_" .. s.status), tostring(math.floor(s.progress * 100)), tostring(beds))
        if s.waiting ~= nil then
            local text = ALifeCamp.Window ~= nil and ALifeCamp.Window.adoptWaiting(nil, s.waiting) or ""
            if text ~= "" then lines[#lines + 1] = T("AdWait", text) end
        end
    elseif project ~= nil then
        local stage, total = Build.currentStage(project)
        local name = T("Kind_" .. project.kind)
        if project.status == "done" then
            lines[#lines + 1] = T("PlInfoDone", name, tostring(project.x), tostring(project.y))
        else
            local stageName = stage ~= nil and T("Stage_" .. stage.id) or "-"
            lines[#lines + 1] = T("PlInfo", name, tostring(project.stage), tostring(total), stageName, tostring(math.floor(Build.progress(project) * 100)))
            local missing, cost = Build.needs(camp, project)
            local parts = {}
            for _, kind in ipairs({ "planks", "nails", "logs", "metal", "rope" }) do
                if cost ~= nil and cost[kind] ~= nil then
                    parts[#parts + 1] = T("Need_" .. kind, tostring(math.floor((camp.stock or {})[kind] or 0)), tostring(cost[kind]))
                end
            end
            lines[#lines + 1] = T("PlNeeds", table.concat(parts, ", "))
        end
    else
        lines[#lines + 1] = T("PlHint")
    end
    local tool = self.tool
    if tool ~= nil then
        lines[#lines + 1] = T("PlTool", T("Kind_" .. tool), T("Side_" .. tostring(self.door)))
    end
    if self.message ~= nil and getTimestampMs() - (self.messageAt or 0) < 6000 then
        lines[#lines + 1] = self.message
    end
    return lines
end

function Planner:prerender()
    ISCollapsableWindow.prerender(self)
    local camp = self:camp()
    if camp == nil then return end
    local y = self.infoY or (self.height - 80)
    local line = fh() + 3
    for _, text in ipairs(self:infoLines(camp)) do
        self:drawText(text, 10, y, 0.9, 0.9, 0.92, 1, FONT)
        y = y + line
    end
end

function Planner:close()
    self:setVisible(false)
    self:removeFromUIManager()
    Planner.instance = nil
end

function Planner.open(camp)
    if camp == nil then return nil end
    local existing = Planner.instance
    if existing ~= nil then
        existing.campId = camp.id
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end
    local core = getCore()
    local w = math.min(core:getScreenWidth() - 60, 900)
    local h = math.min(core:getScreenHeight() - 60, 700)
    local win = ISCollapsableWindow:new(core:getScreenWidth() / 2 - w / 2, core:getScreenHeight() / 2 - h / 2, w, h)
    setmetatable(win, Planner)
    win.title = T("PlTitle")
    win.resizable = true
    win.campId = camp.id
    win.door = "S"
    win:initialise()
    win:addToUIManager()
    win:setVisible(true)
    win:bringToTop()
    Planner.instance = win
    return win
end

return Planner
