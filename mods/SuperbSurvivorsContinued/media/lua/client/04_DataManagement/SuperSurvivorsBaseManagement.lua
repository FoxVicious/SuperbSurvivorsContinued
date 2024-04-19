SuperSurvivorsBaseSelector = {
    selectingArea = false,
    startX = nil,
    startY = nil,
    currentX = nil,
    currentY = nil,
    selectionStarted = false,
    needSetStartPoint = true,
    toggleCallbacks={}
}

local function onRenderTick()
    SuperSurvivorsBaseSelector:update()
end

local function isMouseOverUI()
    local uis = UIManager.getUI()
    for i = 1, uis:size() do
        local ui = uis:get(i - 1)
        if ui:isMouseOver() then
            return true
        end
    end
    return false
end

local function triggerToggleCallback()
    for _,v in pairs(SuperSurvivorsBaseSelector.toggleCallbacks) do
        if(v~=nil) then
            v.func(v.param)
        end
    end
end


function SuperSurvivorsBaseSelector:AddToggleCallback(key,func,param)
    SuperSurvivorsBaseSelector.toggleCallbacks[key]= {func=func,param=param}
end

function SuperSurvivorsBaseSelector:RemoveToggleCallback(key)
    SuperSurvivorsBaseSelector.toggleCallbacks[key] = nil
end

function SuperSurvivorsBaseSelector:update()
    if not self.selectingArea  then
        return
    end
    if (Mouse.isLeftDown()) then

        -- in this way we can avoid using the initial delay of 15 ticks, but we can't select an area under the UI.
        if (not isMouseOverUI()) then
            self.selectionStarted = true
            self:updatePosition()
        end
    else
        self.needSetStartPoint = true;
    end

    if (self.selectionStarted) then
        self:renderSelection()
    end

end

function SuperSurvivorsBaseSelector:updatePosition()
    local tile = UIManager:getPickedTile()
    self.currentX = tile:getX()
    self.currentY = tile:getY()
    if (self.needSetStartPoint) then
        self.needSetStartPoint = false
        self.startX = self.currentX
        self.startY = self.currentY
    end

end

function SuperSurvivorsBaseSelector:renderSelection()

    local x1 = math.min(self.startX, self.currentX)
    local x2 = math.max(self.startX, self.currentX)
    local y1 = math.min(self.startY, self.currentY)
    local y2 = math.max(self.startY, self.currentY)

    for xx = x1, x2 do
        for yy = y1, y2 do
            local sq = getCell():getGridSquare(xx, yy, getSpecificPlayer(0):getZ());
            if (sq) and (sq:getFloor()) then
                sq:getFloor():setHighlighted(true);
            end
        end
    end
end

function SuperSurvivorsBaseSelector:StartSelectingArea(test, area)
    if(not self.selectingArea) then
        Events.OnRenderTick.Add(onRenderTick);
    end
    self:ClearVariables()
    self.selectingArea = true
    triggerToggleCallback()
end

function SuperSurvivorsBaseSelector:StopSelectingArea(test, area, value)
    -- value 0 means cancel, -1 is clear, 1 is set
    if (value ~= 0) then
        if (value == -1) then
            self:ClearVariables()
        end
        local mySS = SSM:Get(0)
        local gid = mySS:getGroupID()
        if (not gid) then
            return false
        end
        local group = SSGM:GetGroupById(gid)
        if (not group) then
            return false
        end
        if (area == "BaseArea") then
            local baseBounds = {
                math.floor(self.startX),
                math.floor(self.currentX),
                math.floor(self.startY),
                math.floor(self.currentY),
                math.floor(getSpecificPlayer(0):getZ())
            }
            group:setBounds(baseBounds);
        else
            group:setGroupArea(area, math.floor(self.startX), math.floor(self.currentX), math.floor(self.startY),
                    math.floor(self.currentY), getSpecificPlayer(0):getZ())
        end
    end
    Events.OnRenderTick.Remove(onRenderTick);
    self:ClearVariables()
    triggerToggleCallback()
end

function SuperSurvivorsBaseSelector:ClearVariables()
    self.selectingArea = false
    self.startX = nil
    self.startY = nil
    self.currentX = nil
    self.currentY = nil
    self.selectionStarted = false
    self.needSetStartPoint = true
end
