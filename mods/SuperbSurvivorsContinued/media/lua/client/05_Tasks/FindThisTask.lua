require "03_Core/SuperSurvivor";

FindThisTask = {}
FindThisTask.__index = FindThisTask

local isLocalLoggingEnabled = false;

function FindThisTask:new(superSurvivor, itemType, CategoryOrType, thisQuantity, predicate)
	CreateLogLine("FindThisTask", isLocalLoggingEnabled, "function: FindThisTask:new() Called");
	local o = {}
	setmetatable(o, self)
	self.__index = self

	if (superSurvivor == nil) then return nil end

	o.FoundCount = 0
	if (thisQuantity ~= nil) then
		o.Quantity = thisQuantity
	else
		o.Quantity = 1
	end
	o.parent = superSurvivor
	o.Name = "Find This"
	o.OnGoing = false
	o.COT = CategoryOrType
	o.itemtype = itemType

	if (itemType == "Water") then
		o.BagToPutIn = superSurvivor:Get():getInventory()
	else
		o.BagToPutIn = superSurvivor:getBag()
	end

	if (not superSurvivor.player:getCurrentSquare()) then
		o.Complete = true
		return nil
	end
	o.TargetItem = nil
	o.Complete = false
	o.WasSuccessful = false

	o.Predicate=predicate

	superSurvivor:RoleplaySpeak(Get_SS_UIActionText("LookForItem_Before") .. itemType .. Get_SS_UIActionText("LookForItem_After"))
	return o
end

function FindThisTask:isComplete()
	if (self.Complete) then
		if (self.ItemType == "Weapon") then
			local weapon = FindAndReturnBestWeapon(self.BagToPutIn)
			if (weapon ~= nil) and (self.parent:Get():getPrimaryHandItem() == nil or self.parent:Get():getPrimaryHandItem():getMaxDamage() < weapon:getMaxDamage()) then
				self.parent:Get():setPrimaryHandItem(weapon)
			end
		end
	end
	return self.Complete
end

function FindThisTask:isValid()
	return true
end

function FindThisTask:getWasSuccessful()
	return self.WasSuccessful
end

function FindThisTask:update()
	CreateLogLine("FindThisTask", isLocalLoggingEnabled, "FindThisTask:update() Called");
	if (getSpecificPlayer(0):isAsleep()) then return false end
	if (not self:isValid()) or self.parent:getDangerSeenCount() > 0 then
		self.Complete = true
		return false
	end

	if (self.parent:isInAction()) then
		return false
	end


	if (self.TargetItem == nil) then

		if (self.Predicate ~= nil) then
			self.TargetItem = self.parent:FindThisNearByPredicate(self.Predicate)
		else
			self.TargetItem = self.parent:FindThisNearBy(self.itemtype, self.COT)
		end
	end

	if (self.TargetItem == nil) then
		self.Complete = true

		if (self.WasSuccessful == false) then
			self.parent:RoleplaySpeak(Get_SS_UIActionText("NoFindItem_Before") ..
				self.itemtype .. Get_SS_UIActionText("NoFindItem_After"))
		end

		if self.itemtype == "Food" then
			self.parent:setNoFoodNearBy(true)
		elseif self.itemtype == "Water" then
			self.parent:setNoWaterNearBy(true)
		end

		return false
	end


	local distance, targetSquare
	if (instanceof(self.TargetItem, "InventoryItem")) and (self.TargetItem:getWorldItem() ~= nil) then
		targetSquare = self.TargetItem:getWorldItem():getSquare()
	elseif (instanceof(self.TargetItem, "IsoObject")) and (self.TargetItem:getSquare() ~= nil) then
		targetSquare = self.TargetItem:getSquare()
	elseif (instanceof(self.TargetItem, "InventoryItem")) and (self.TargetItem:getContainer() ~= nil) then
		targetSquare = self.TargetItem:getContainer():getSourceGrid()
	end

	if (not targetSquare) then
		self.TargetItem = nil
		return false
	else
		distance = GetDistanceBetween(targetSquare, self.parent:Get())

		if (distance > 2.0) or (targetSquare:getZ() ~= self.parent:Get():getZ()) then
			self.parent:walkTo(targetSquare)
		else
			if (instanceof(self.TargetItem, "InventoryItem")) and (self.parent:getBag():hasRoomFor(self.parent:Get(), self.TargetItem) == false) then
				self.parent:getTaskManager():AddToTop(CleanInvTask:new(self.parent, self.parent:Get():getCurrentSquare(),
					false))
			elseif (instanceof(self.TargetItem, "IsoWorldInventoryObject")) and (self.parent:getBag():hasRoomFor(self.parent:Get(), self.TargetItem:getItem()) == false) then
				self.parent:getTaskManager():AddToTop(CleanInvTask:new(self.parent, self.parent:Get():getCurrentSquare(),
					false))
			end

			if (instanceof(self.TargetItem, "IsoObject")) then
				if (self.parent:HasWaterContainer()) then

					self:fillWaterContainers()
					self.Complete = true
					self.WasSuccessful = true

				else
					self.parent:DrinkFromObject(self.TargetItem)
					self.Complete = true
					self.WasSuccessful = true
				end
			else
				if (self.BagToPutIn:contains(self.TargetItem) == false) then
					local targetWorldItem=self.TargetItem:getWorldItem()
					if ( targetWorldItem~= nil) then
						local targetItemSquare = targetWorldItem:getSquare() -- IsoGridSquare
						local targetItemSquareModData=targetItemSquare:getModData()
						if (targetItemSquare ~= nil) and (targetItemSquareModData.Group ~= nil) and (targetItemSquareModData.Group ~= self.parent:getGroupID()) then
							SSGM:GetGroupById(targetItemSquareModData.Group):stealingDetected(self.parent.player)
						end
						local itemsToPickUp={self.TargetItem}
						local itemsOnSquare= targetItemSquare:getWorldObjects()
						local i=0
						self.FoundCount = self.FoundCount + 1

						while (self.FoundCount < self.Quantity and i<itemsOnSquare:size())do
							local itemWorld=itemsOnSquare:get(i) --IsoWorldInventoryObject
							if(itemWorld ~= nil) then
								local item=itemWorld:getItem() --InventoryItem
								if(item ~= nil) then
									if (item:getType() == self.TargetItem:getType()) or (self.COT=="Category" and item:getCategory() == self.itemtype) then
										table.insert(itemsToPickUp,item)
										self.FoundCount = self.FoundCount + 1
									end
								end
							end
							i=i+1
						end
						self.parent:RoleplaySpeak(Get_SS_UIActionText("TakesFromGround_Before") ..self.TargetItem:getDisplayName() .. Get_SS_UIActionText("TakesFromGround_After"))
						local time = ISWorldObjectContextMenu.grabItemTime(self.parent.player, targetWorldItem);
						self.parent:StopWalk()
						for _, itemObj in ipairs(itemsToPickUp) do
							if self:isValid() and itemObj and itemObj:getWorldItem() then
								if self.BagToPutIn:isItemAllowed(itemObj) then
									ISTimedActionQueue.add(ISInventoryTransferAction:new(self.parent.player, itemObj,
											itemObj:getContainer(), self.BagToPutIn, time))
								end
							end
						end
					else
						self.parent:StopWalk()
						ISTimedActionQueue.add(ISInventoryTransferAction:new(self.parent.player, self.TargetItem,
							self.TargetItem:getContainer(), self.BagToPutIn, 20))
						self.parent:RoleplaySpeak(Get_SS_UIActionText("TakesFromCont_Before") ..
							self.TargetItem:getDisplayName() .. Get_SS_UIActionText("TakesFromCont_After"))
						self.FoundCount = self.FoundCount + 1
					end
				else
					self.FoundCount = self.FoundCount + 1
					self.TargetItem = nil
				end
			end
		end
	end

	if self.FoundCount >= self.Quantity then
		self.Complete = true
		self.WasSuccessful = true
	end
end

---See ISWorldObjectContextMenu.doFillWaterMenu and ISWorldObjectContextMenu.onTakeWater
function FindThisTask:fillWaterContainers()
	local playerObj = self.parent.player
	local playerInv = playerObj:getInventory()
	local waterContainerList = {}
	local pourInto = playerInv:getAllEvalRecurse(SuperSurvivorPredicate.waterContainer)

	if pourInto:isEmpty() then
		return
	end

	--make a table of all containers
	for i = 0, pourInto:size() - 1 do
		local container = pourInto:get(i)
		table.insert(waterContainerList, container)
	end
	local waterObject = self.TargetItem
	local waterAvailable = waterObject:getWaterAmount()

	local didWalk = false

	for i, item in ipairs(waterContainerList) do
		-- first case, fill an empty bottle
		if item:canStoreWater() and not item:isWaterSource() then
			if not didWalk and (not waterObject:getSquare() or not luautils.walkAdj(playerObj, waterObject:getSquare(), true)) then
				return
			end
			didWalk = true
			-- we create the item which contain our water
			local newItemType = item:getReplaceType("WaterSource");
			local newItem = InventoryItemFactory.CreateItem(newItemType, 0);
			newItem:setCondition(item:getCondition());
			newItem:setFavorite(item:isFavorite());
			local returnToContainer = item:getContainer():isInCharacterInventory(playerObj) and item:getContainer()
			ISWorldObjectContextMenu.transferIfNeeded(playerObj, item)
			local destCapacity = 1 / newItem:getUseDelta()
			local waterConsumed = math.min(math.floor(destCapacity + 0.001), waterAvailable)
			ISTimedActionQueue.add(ISTakeWaterAction:new(playerObj, newItem, waterConsumed, waterObject, waterConsumed * 10, item));
			if returnToContainer and (returnToContainer ~= playerInv) then
				ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, newItem, playerInv, returnToContainer))
			end
		elseif item:canStoreWater() and item:isWaterSource() then
			-- second case, a bottle contain some water, we just fill it
			if not didWalk and (not waterObject:getSquare() or not luautils.walkAdj(playerObj, waterObject:getSquare(), true)) then
				return
			end
			didWalk = true
			local returnToContainer = item:getContainer():isInCharacterInventory(playerObj) and item:getContainer()
			if playerObj:getPrimaryHandItem() ~= item and playerObj:getSecondaryHandItem() ~= item then
			end
			ISWorldObjectContextMenu.transferIfNeeded(playerObj, item)
			local destCapacity = (1 - item:getUsedDelta()) / item:getUseDelta()
			local waterConsumed = math.min(math.floor(destCapacity + 0.001), waterAvailable)
			ISTimedActionQueue.add(ISTakeWaterAction:new(playerObj, item, waterConsumed, waterObject, waterConsumed * 10, nil));
			if returnToContainer then
				ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, playerInv, returnToContainer))
			end
		end
	end

end

