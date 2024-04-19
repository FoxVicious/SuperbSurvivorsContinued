FarmingTask = {}
FarmingTask.__index = FarmingTask

local isLocalLoggingEnabled = false;

function FarmingTask:new(superSurvivor, BringHere)
    CreateLogLine("FarmingTask", isLocalLoggingEnabled, "function: FarmingTask:new() Called");
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.BringHereSquare = BringHere
    o.parent = superSurvivor
    o.group = superSurvivor:getGroup()
    o.Name = "Farming"
    o.FarmingTaskType = ""
    o.JustHarvested = false
    o.NothingToDoCount = 0

    o.Plant = nil
    o.TargetSquare = nil
    o.Complete = false

    o.Trowel = nil
    o.TrowelToGet = false
    o.Water = nil
    o.WaterToGet = false
    o.SeedCount = -1 --Set to -1 so that it also conducts the seed search on the first cycle.
    o.SeedNotFound = false
    return o
end

function FarmingTask:getShovel()
    local phi = self.parent:Get():getPrimaryHandItem()
    if (not phi) or (not SuperSurvivorPredicate.digPlow(phi)) then
        self.Trowel = self.parent:Get():getInventory():getFirstEvalRecurse(SuperSurvivorPredicate.digPlow)
        ISInventoryPaneContextMenu.transferIfNeeded(self.parent.player, self.Trowel)
        if (self.Trowel == nil) then
            if (self.TrowelToGet == true) then
                self.parent:Speak("No shovel found");
                self.Complete = true;
            else
                self.TrowelToGet = true;
                self.parent:Speak("Looking for a shovel");
                self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "HandShovel", "Type", 1, SuperSurvivorPredicate.digPlow))
            end
        else
            self.parent:Get():setPrimaryHandItem(self.Trowel)
        end
    else
        self.Trowel = phi
    end
end

function FarmingTask:getWater()
    local phi = self.parent:Get():getPrimaryHandItem()
    if (not phi) or (not phi:isWaterSource()) then
        self.Water = self.parent:getWater()
        if (self.Water == nil) then
            if (self.WaterToGet == true) then
                self.parent:Speak("No Water found");
                self.Complete = true;
            else
                self.WaterToGet = true;
                self.parent:Speak("Looking for Water");
                if (self.parent:HasWaterContainer()) then
                    self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Water", "Category"))
                else
                    self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Water", "Category", 1, function(item)
                        return SuperSurvivorPredicate.waterContainer(item) or (item:canStoreWater() and item:isWaterSource() and not item:isBroken() and instanceof(item, "DrainableComboItem"))
                    end))
                end
            end
        end
    else
        self.parent:Get():setPrimaryHandItem(self.Water)
    end
end

function FarmingTask:getSeeds()

    local maxSeedRequired = 1
    local seedTypes = {}
    local lastSeedCount = self.SeedCount
    self.SeedCount = 0
    --check in inventory
    for typeOfPlant, props in pairs(farming_vegetableconf.props) do
        local seedItemType = props.seedName:match("%.([^%.]*)$")
        local seeds = self.parent.player:getInventory():getAllTypeRecurse(seedItemType)
        local seedCount = seeds:size()
        self.SeedCount = self.SeedCount + seedCount

        if (seedCount >= props.seedsRequired) then
            -- some seed found
            return { typeOfPlant = typeOfPlant, items = seeds, count = seedCount, required=props.seedsRequired  }
        end
        if (maxSeedRequired < props.seedsRequired) then
            maxSeedRequired = props.seedsRequired
        end
        table.insert(seedTypes, seedItemType)
    end

    -- If the last search has increased the number of seeds in the inventory, I'll try to find more.
    if (lastSeedCount ~= self.SeedCount) then
        self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Seed", "Type", maxSeedRequired, function(item)
            local itemType = item:getType()
            for _, value in ipairs(seedTypes) do
                if value == itemType then
                    return true;
                end
            end
            return false;
        end))
    else
        self.SeedNotFound = true
    end

    return nil



end

function FarmingTask:isComplete()
    return self.Complete
end

function FarmingTask:isValid()
    if not self.parent then
        return false
    else
        return true
    end
end

function FarmingTask:getPlant(sq)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq)

    if plant then
        return plant
    else
        return nil
    end
end

function FarmingTask:getNumberOf(thisType)
    if (thisType == "Plants") then
        local area = self.group:getGroupArea("FarmingArea")
        local count = 0
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)
                    if (plant) and (plant.state ~= "plow") then
                        count = count + 1
                    end
                end
            end
        end
    elseif (thisType == "Plows") then
        local area = self.group:getGroupArea("FarmingArea")
        local count = 0
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)
                    if (plant) and (plant.state == "plow") then
                        count = count + 1
                    end
                end
            end
        end
    else
        -- either
        local area = self.group:getGroupArea("FarmingArea")
        local count = 0
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)
                    if (plant) then
                        count = count + 1
                    end
                end
            end
        end
    end
end

function FarmingTask:getASquareToPlow()
    local area = self.group:getGroupArea("FarmingArea")

    for x = area[1], area[2] do
        for y = area[3], area[4] do
            local sq = getCell():getGridSquare(x, y, area[5])
            if (sq) and (sq:isFree(false)) and (x % 2 == 0) and (y % 2 ~= 0) then
                local plant = self:getPlant(sq)
                if (plant == nil) then
                    return sq
                end
            end
        end
    end

    return nil
end

function FarmingTask:getAPlantThatNeeds(needs)
    local area = self.group:getGroupArea("FarmingArea")

    if needs == "Watering" then
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)
                    if (plant)
                            and (plant.state == "seeded")
                            and (plant.waterNeeded > 0)
                            and (plant.waterLvl < 100)
                            and (plant.typeOfSeed ~= "Carrots")
                            and (plant.typeOfSeed ~= "RedRadish")
                    then
                        return plant
                    end
                end
            end
        end
    elseif (needs == "Harvesting") and (self.parent:getGroupRole() == Get_SS_JobText("Farmer")) then
        -- only harvest if specifically commanded
    elseif needs == "Plowing" then
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)
                    if (not plant) or (plant and (not plant:isAlive())) then
                        return sq
                    end
                end
            end
        end
    elseif (needs == "Planting") and (self.parent:getGroupRole() == Get_SS_JobText("Farmer")) then
        for x = area[1], area[2] do
            for y = area[3], area[4] do
                local sq = getCell():getGridSquare(x, y, area[5])
                if (sq) then
                    local plant = self:getPlant(sq)

                    if (plant) and (plant.typeOfSeed == "none") then
                        return plant
                    end
                end
            end
        end
    end

    return nil
end

function FarmingTask:AreWeThereYet(plant)
    local distance = GetDistanceBetween(plant, self.parent.player)
    if (distance > 2.0) then
        self.parent:walkTo(plant)
        return false
    else
        return true
    end
end

function FarmingTask:ClearVars()
    self.Plant = nil
    self.TargetSquare = nil
    self.FarmingTaskType = ""
    self.NothingToDoCount = 0
    self.Trowel = nil
    self.TrowelToGet = false
    self.Water = nil
    self.WaterToGet = false
    self.SeedCount = -1
    self.SeedNotFound = false
end

function FarmingTask:update()
    CreateLogLine("FarmingTask", isLocalLoggingEnabled, "function: FarmingTask:update() Called");
    if (not self:isValid()) then
        return false
    end
    if (not self.group) then
        self.group = self.parent:getGroup()
    end

    if (not self.group) then
        return false
    end

    if (self.group:getGroupAreaCenterSquare("FarmingArea") == nil) then
        self.parent:Speak(Get_SS_UIActionText("NoFarmingArea"))
        self.Complete = true
        return nil
    end

    if (self.parent:isInAction() == false) then

        if (self.JustHarvested) then
            -- go store crops
            self.parent:Speak("going to harvested goods")
            local storagecontainer = self.group:getGroupAreaContainer("FoodStorageArea")
            local dest
            if (storagecontainer) then
                dest = storagecontainer
            else
                dest = self.group:getGroupAreaCenterSquare("FoodStorageArea")
                if dest ~= nil then
                    CreateLogLine("FarmingTask", isLocalLoggingEnabled, "Harvest - Found center square");
                end
            end
            if (not dest) then
                dest = self.parent.player:getCurrentSquare()
                CreateLogLine("FarmingTask", isLocalLoggingEnabled, "Harvest - Drop at current");
            end
            self.JustHarvested = false
            --self.parent:Speak("is a container?"..tostring(dest.getContainer ~= nil))
            self.parent:getTaskManager():AddToTop(SortLootTask:new(self.parent, false))
            return true
        end

        if (self.Plant == nil) then
            self.Plant = self:getAPlantThatNeeds("Watering")
            self.FarmingTaskType = "Watering"
        end
        if (self.Plant ~= nil) and (self.FarmingTaskType == "Watering") then
            if (self:AreWeThereYet(self.Plant:getSquare())) then
                if (self.Water == nil) then
                    self:getWater()
                else
                    local plantType = self.Plant.typeOfSeed
                    CreateLogLine("FarmingTask", isLocalLoggingEnabled, "watering: " .. plantType);
                    self.parent:RoleplaySpeak(Get_SS_UIActionText("FarmingActionWatering"))
                    self.parent:StopWalk()
                    ISTimedActionQueue.add(ISWaterPlantAction:new(self.parent:Get(), self.Water, 1, self.Plant:getSquare(), 20))
                    self:ClearVars()
                end
            end
            return true
        end

        if (self.Plant == nil) then
            self.Plant = self:getAPlantThatNeeds("Harvesting")
            self.FarmingTaskType = "Harvesting"
        end
        if (self.Plant ~= nil) and (self.FarmingTaskType == "Harvesting") then
            if (self:AreWeThereYet(self.Plant:getSquare())) then
                local plantType = self.Plant.typeOfSeed
                self.parent:RoleplaySpeak(Get_SS_UIActionText("FarmingActionHarvesting"))
                self.JustHarvested = true
                self.parent:StopWalk()
                ISTimedActionQueue.add(ISHarvestPlantAction:new(self.parent:Get(), self.Plant, 50))
                self:ClearVars()
            end
            return true
        end

        if (self.Plant == nil) then
            self.Plant = self:getAPlantThatNeeds("Plowing")
            self.FarmingTaskType = "Plowing"
        end
        if (self.Plant ~= nil) and (self.FarmingTaskType == "Plowing") then
            self.TargetSquare = self.Plant
            if (self:AreWeThereYet(self.Plant)) then

                self.parent:StopWalk()
                if (self.Trowel == nil) then
                    self:getShovel()
                else
                    ISTimedActionQueue.add(ISPlowAction:new(self.parent:Get(), self.TargetSquare, self.Trowel, 150))
                    self:ClearVars()
                end
            end
            return true
        end

        if (self.Plant == nil) then
            self.Plant = self:getAPlantThatNeeds("Planting")
            self.FarmingTaskType = "Planting"
        end
        if (self.Plant ~= nil) and (self.FarmingTaskType == "Planting") then
            if (self:AreWeThereYet(self.Plant:getSquare())) then
                self.parent:RoleplaySpeak(Get_SS_UIActionText("FarmingActionPlanting"))
                local seeds=self:getSeeds()
                if (seeds == nil) then
                    if (self.SeedNotFound) then
                        self.SeedNotFound = false
                        --No return statement is used, so the variable NothingToDoCount will be incremented
                    else
                        return true
                    end
                else

                    self.parent:StopWalk()
                    ISInventoryPaneContextMenu.transferIfNeeded(self.parent.player, seeds.items)

                    local seedsTable = {}
                    for i = 1, seeds.count do
                        table.insert(seedsTable, seeds.items:get(i - 1))
                    end

                    self.parent:RoleplaySpeak(Get_SS_UIActionText("FarmingActionPlanting"))
                    ISTimedActionQueue.add(ISSeedAction:new(self.parent:Get(), seedsTable, seeds.required, seeds.typeOfPlant, self.Plant, 200))
                    self:ClearVars()
                    return true
                end
            else
                return true
            end
        end

        self.Plant = nil
        self.TargetSquare = nil
        self.FarmingTaskType = ""
        self.NothingToDoCount = self.NothingToDoCount + 1

        if (self.NothingToDoCount > 5) then
            self:ClearVars()
            self.parent:Speak("nothing to do for now...")
            self.Complete = true
            return nil
        end
    end
end
