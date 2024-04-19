BarricadeBuildingTask = {}
BarricadeBuildingTask.__index = BarricadeBuildingTask

local isLocalLoggingEnabled = false;

function BarricadeBuildingTask:getHammer()
	local phi = self.parent:Get():getPrimaryHandItem()
	if (not phi) or (not SuperSurvivorPredicate.hammer(phi)) then
		self.Hammer = self.parent:Get():getInventory():getFirstEvalRecurse(SuperSurvivorPredicate.hammer)
		if (self.Hammer == nil) then
			if (self.HammerToGet == true) then
				self.parent:Speak("No hammer found");
				self.Complete = true;
			else
				self.HammerToGet = true;
				self.parent:Speak("Looking for a hammer");
				self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "hammer", "Type",1,SuperSurvivorPredicate.hammer))
			end
		else
			ISInventoryPaneContextMenu.transferIfNeeded(self.parent.player, self.Hammer)
			self.parent:Get():setPrimaryHandItem(self.Hammer)
		end
	else
		self.Hammer = phi
	end
end

function BarricadeBuildingTask:getPlank()
	local phi = self.parent:Get():getPrimaryHandItem()
	if (not phi) or (phi:getType() ~= "Plank") then
		self.Plank = self.parent:Get():getInventory():getFirstTypeRecurse("Plank")
		if (self.Plank == nil) then
			if (self.PlankToGet == true) then
				self.parent:Speak("No plank found");
				self.Complete = true;
			else
				self.PlankToGet = true;
				self.parent:Speak("Looking for a plank");
				self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Plank", "Type"))
			end
		else
			ISInventoryPaneContextMenu.transferIfNeeded(self.parent.player, self.Plank)
		end
	else
		self.Plank = phi
	end
end

function BarricadeBuildingTask:getNails()
		local lastNailsCount =self.NailsCount
		local nails=self.parent:Get():getInventory():getSomeTypeRecurse("Nails",2)
		if (nails:size()<2) then
			self.NailsCount = nails:size()
			if (self.NailsToGet == true and lastNailsCount ~= nil and lastNailsCount == self.NailsCount) then
				self.parent:Speak("No nails found");
				self.Complete = true;
			else
				self.NailsToGet = true;
				self.parent:Speak("Looking for nails");
				self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Nails", "Type",2))
			end
		else
			ISInventoryPaneContextMenu.transferIfNeeded(self.parent.player, nails)
			self.NailsCount = nails:size()
		end
end

function BarricadeBuildingTask:new(superSurvivor)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.parent = superSurvivor
	o.Name = "Barricade Building"
	o.OnGoing = true
	o.TargetBuilding = nil
	o.TargetSquare = nil
	o.Window = nil
	o.PreviousSquare = nil
	o.Complete = false
	o.parent:setLastWeapon()

	CreateLogLine("BarricadeBuildingTask", isLocalLoggingEnabled, "function: BarricadeBuildingTask:new() called");

	o.Hammer = nil
	o.HammerToGet=false
	o.Plank = nil
	o.PlankToGet=false
	o.NailsCount=nil
	o.NailsToGet=false
	return o
end

function BarricadeBuildingTask:ForceComplete()
	self:OnComplete()
	self.Complete = true
end

function BarricadeBuildingTask:OnComplete()
	self.parent:reEquipLastWeapon()
end

function BarricadeBuildingTask:isComplete()
	if (self.Complete) then
		self:ForceComplete()
	end
	return self.Complete
end

function BarricadeBuildingTask:isValid()
	if not self.parent then
		return false
	else
		return true
	end
end

function BarricadeBuildingTask:update()
	CreateLogLine("BarricadeBuildingTask", isLocalLoggingEnabled, "function: BarricadeBuildingTask:update() called");
	if (not self:isValid()) then return false end

	-- Since there are multiple calls to the FindThisTask task, we need to wait until GoFindThisCounter returns to 0
	if (self.parent.GoFindThisCounter > 0) then
		return false
	end

	if (self.parent:isInAction() == false) then
		local building = self.parent:getBuilding();
		if (building ~= nil) then
			if (self.Window == nil) then self.Window = self.parent:getUnBarricadedWindow(building) end
			if (not self.Window) then
				CreateLogLine("BarricadeBuildingTask", isLocalLoggingEnabled, "No window found...");
				self.Complete = true
				return false
			end
		else
			self.Complete = true
			return false
		end
		if(self.Hammer==nil)then
			self:getHammer()
			return false
		end
		if(self.Plank==nil)then
			self:getPlank()
			return false
		end
		if(self.NailsCount==nil or self.NailsCount<2)then
			self:getNails()
			return false
		end

		local barricade = self.Window:getBarricadeForCharacter(self.parent.player)
		local distance = GetDistanceBetween(self.parent.player, self.Window:getIndoorSquare());
		if (distance > 2) or (self.parent.player:getZ() ~= self.Window:getZ()) then
			local attempts = self.parent:getWalkToAttempt(self.Window:getIndoorSquare())
			self.parent:walkTo(self.Window:getIndoorSquare())

			if (attempts > 8) then
				self.Complete = true
				return false
			end
		elseif barricade == nil or (barricade:canAddPlank()) then
			self.parent.player:setPrimaryHandItem(self.Hammer)
			self.parent.player:setSecondaryHandItem(self.Plank)

			self.parent:StopWalk()
			ISTimedActionQueue.add(ISBarricadeAction:new(self.parent.player, self.Window, false, false, 100));


			self.Window = nil
			self.Plank=nil
			self.PlankToGet=false
			self.NailsCount=nil
			self.NailsToGet=false
		else
			self.Window = nil
		end
	else
		CreateLogLine("BarricadeBuildingTask", isLocalLoggingEnabled, "waiting for non action");
	end
end
