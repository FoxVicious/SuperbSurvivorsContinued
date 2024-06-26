ChopWoodTask = {}
ChopWoodTask.__index = ChopWoodTask

local isLocalLoggingEnabled = false;

function ChopWoodTask:new(superSurvivor)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.parent = superSurvivor
	o.group = superSurvivor:getGroup()
	o.Name = "Chop Wood"
	o.OnGoing = true
	o.Complete = false
	o.Tree = nil
	o.Axe = nil
	o.axetoget = false
	o.WalkedToDesignatedArea = false

	return o
end

function ChopWoodTask:isComplete()
	return self.Complete
end

function ChopWoodTask:isValid()
	if not self.parent then
		return false
	else
		return true
	end
end

function ChopWoodTask:update()
	CreateLogLine("ChopWoodTask", isLocalLoggingEnabled, "ChopWoodTask:update() Called");
	if (not self:isValid()) then return false end

	if (self.parent:isInAction() == false) then
		local choparea = self.group:getGroupArea("ChopTreeArea")
		if (choparea[1] ~= 0) and (not IsSquareInArea(self.parent.player, choparea)) then -- if chop area set but not in it, first go there
			local tempsq = GetRandomAreaSquare(choparea)
			self.parent:walkTo(tempsq)
			self.parent:Wait(1)
		else
			local player = self.parent:Get()
			if (player:getStats():getEndurance() < 0.50) then
				if (self.parent.Reducer % 240 == 0) then
					self.parent:RoleplaySpeak(getActionText("Resting"))
				end
				player:getStats():setEndurance(player:getStats():getEndurance() + 0.01)
				return
			end

			local wep = player:getPrimaryHandItem()
			if (wep ~= nil) and (wep:isBroken()) then
				wep = nil
				player:setPrimaryHandItem(nil)
				player:setSecondaryHandItem(nil)
			end
			if (wep == nil) or (not SuperSurvivorPredicate.chopTree(wep)) then
				self.Axe = self.parent:Get():getInventory():getFirstEvalRecurse(SuperSurvivorPredicate.chopTree)

				if (self.Axe ~= nil) and (player:getPrimaryHandItem() ~= self.Axe) then
					player:setPrimaryHandItem(self.Axe)
				end

			else
				self.Axe = wep
			end

			if (self.Axe == nil) and (self.axetoget == true) then -- tried getting axe with FindThisTask but still no axe so finish
				self.Complete = true
				self.parent:Speak(Get_SS_UIActionText("NoAxeNoChopWood"));
			elseif (self.Axe ~= nil) and (player:getPrimaryHandItem() == self.Axe) then
				--local cell = getSpecificPlayer(0):getCell();
				if (self.Tree == nil or self.Tree:getHealth() <= 0) then
					local range = 25;
					local Square;
					local minx = math.floor(player:getX() - range);
					local maxx = math.floor(player:getX() + range);
					local miny = math.floor(player:getY() - range);
					local maxy = math.floor(player:getY() + range);
					-- local sstring = " around here"; -- WIP - Cows: Commented out, unused variable...

					if (self.group ~= nil) then
						if (choparea[1] ~= 0) then
							minx = choparea[1]
							maxx = choparea[2]
							miny = choparea[3]
							maxy = choparea[4]
							--  WIP - Cows: Commented out, unused variable...
							-- sstring =
							-- " in the designated area" --..tostring(minx)..","..tostring(miny)..":"..tostring(maxx)..","..tostring(maxy) 
							range = 150
						end
					end

					local closestsoFar = range;
					local gamehours = getGameTime():getWorldAgeHours();

					for x = minx, maxx do

						for y = miny, maxy do
							Square = getCell():getGridSquare(x, y, 0);

							if (Square ~= nil) then
								local distance = GetDistanceBetween(Square, player); -- WIP - literally spammed inside the nested for loops...
								local closeobjects = Square:getObjects();

								for i = 0, closeobjects:size() - 1 do
									if ((closeobjects:get(i):getModData().isClaimed == nil)
											or (gamehours > (closeobjects:get(i):getModData().isClaimed + 0.05)))
										and (string.find(tostring(closeobjects:get(i):getType()), "tree")
											and (distance < closestsoFar))
									then
										self.Tree = closeobjects:get(i);
										closestsoFar = distance;
									end
								end
							end
						end
					end

					if (self.Tree ~= nil) and (self.Tree:getSquare() ~= nil) then
						player:StopAllActionQueue();
						self.Tree:getModData().isClaimed = gamehours;
					else
						self.parent:Speak(Get_SS_UIActionText("NoTrees"));
						self.Complete = true
					end
				elseif ((self.Tree ~= nil) and (self.Tree:getSquare() ~= nil)
						and (GetDistanceBetween(self.Tree:getSquare(), player) > 2.0))
				then
					self.parent:walkTo(self.Tree:getSquare());
				elseif (self.Tree ~= nil) then
					player:faceThisObject(self.Tree);
					ISTimedActionQueue.add(ISChopTreeAction:new(player, self.Tree));
					self.Tree = nil
				else
					player:StopAllActionQueue();
					self.Tree = nil;
					self.parent:Speak("?");
				end
			else
				if (not self.axetoget) then
					self.axetoget = true

					self.parent:getTaskManager():AddToTop(FindThisTask:new(self.parent, "Axe", "Type", 1, SuperSurvivorPredicate.chopTree))
				end
			end
		end
	end
	CreateLogLine("ChopWoodTask", isLocalLoggingEnabled, "--- ChopWoodTask:update() End ---");
end
