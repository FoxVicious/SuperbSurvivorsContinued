AttackTask = {}
AttackTask.__index = AttackTask

function AttackTask:new(superSurvivor)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.parent = superSurvivor
	o.Name = "Attack"

	o.OnGoing = false
	o.parent:Speak("starting attack")
	o.parent:DebugSay(tostring(o.parent:getCurrentTask()) .. " Started!")
	o.parent:Set_AtkTicks(0) -- should not have to wait/delay on first attack, only after the first swing/shot

	return o
end

function AttackTask:isComplete()
	local theDistance = getDistanceBetween(self.Target, self.parent.player)

	--self.parent.player:Say( tostring(self.parent:needToFollow()) ..",".. tostring(self.parent:getDangerSeenCount() > 0) ..",".. tostring(self.parent.LastEnemeySeen) ..",".. tostring(not self.parent.LastEnemeySeen:isDead()) ..",".. tostring(self.parent:HasInjury() == false) )
	if (not self.parent:needToFollow()) and ((self.parent:getDangerSeenCount() > 0) or (self.parent:isEnemyInRange(self.parent.LastEnemeySeen) and self.parent:hasWeapon())) and (self.parent.LastEnemeySeen) and not self.parent.LastEnemeySeen:isDead() and (self.parent:HasInjury() == false) then
		return false
	else
		if theDistance < 1 then
			self.parent:StopWalk()
		end

		return true
	end
end

function AttackTask:isValid()
	if (not self.parent) or (not self.parent.LastEnemeySeen) or (not self.parent:isInSameRoom(self.parent.LastEnemeySeen)) or (self.parent.LastEnemeySeen:isDead()) then
		return false
	else
		return true
	end
end

function AttackTask:update()
	if (not self:isValid()) or (self:isComplete()) then return false end

	if (self.parent:isWalkingPermitted()) then
		self.parent:NPC_MovementManagement() -- For melee movement management

		-- Controls the Range of how far / close the NPC should be
		if self.parent:hasGun() then -- Despite the name, it means 'has gun in the npc's hand'
			-- WIP - When and where was "weapon" assigned a value? This is still unassigned...
			if (self.parent:needToReadyGun(weapon)) then
				self.parent:ReadyGun(weapon)
			else
				self.parent:NPC_MovementManagement_Guns() -- To move around, it checks for in attack range too
			end
		end
	end


	local theDistance = getDistanceBetween(self.parent.LastEnemeySeen, self.parent.player)
	local minrange = self.parent:getMinWeaponRange()
	local NPC_AttackRange = self.parent:isEnemyInRange(self.parent.LastEnemeySeen)

	-- Controls if the NPC is litreally running or walking state.
	self.parent:NPC_ShouldRunOrWalk()

	--	if (NPC_AttackRange) or (theDistance <= minrange) or (theDistance < 0.65) then
	if (NPC_AttackRange) or (theDistance < 0.65) then
		local weapon = self.parent.player:getPrimaryHandItem()

		if (not weapon or (not self.parent:usingGun()) or ISReloadWeaponAction.canShoot(weapon)) then
			if (self.parent:hasGun()) then -- Gun related conditions
				if (self.parent:needToReadyGun(weapon)) then
					self.parent:ReadyGun(weapon)
				else
					if (self.parent:Is_AtkTicksZero()) then
						self.parent:Attack(self.parent.LastEnemeySeen)
					else
						self.parent:AtkTicks_Countdown()
					end
				end
			else -- Melee related conditions
				if (self.parent:Is_AtkTicksZero()) then
					self.parent:NPC_Attack(self.parent.LastEnemeySeen)
				else
					self.parent:AtkTicks_Countdown()
				end
			end

			if (instanceof(self.parent.LastEnemeySeen, "IsoPlayer")) then
				self.parent:Wait(5)
			end -- nerf attack speed of player vs player attacking
		elseif (self.parent:usingGun()) then
			if (self.parent:ReadyGun(weapon) == false) then self.parent:reEquipMele() end
			--print(self.parent:getName().. " trying to ready gun" )
			self.parent:Wait(1)
		end
		--if(self.parent:usingGun()) then self.parent.Reducer = 0 end -- force delay when using gun
	elseif (self.parent:isWalkingPermitted()) then
		self.parent:NPC_ManageLockedDoors() -- To prevent getting stuck in doors
	else
		self.parent:DebugSay("ATTACK TASK - something is wrong")
	end
	return true
end
