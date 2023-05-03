function SuperSurvivorPlayerInit(player)
	player:getModData().isHostile = false
	player:getModData().semiHostile = false
	player:getModData().hitByCharacter = false
	player:getModData().ID = 0
	player:setBlockMovement(false)
	player:setNPC(false)
	print("initing player index " .. tostring(player:getPlayerNum()))

	if (player:getPlayerNum() == 0) then
		print("initing player index 0")
		SSM:init()
		MyGroup = SSGM:newGroup()
		MyGroup:addMember(SSM:Get(0), "Leader")
		local spawnBuilding = SSM:Get(0):getBuilding()
		if (spawnBuilding) then -- spawn building is default group base
			print("set building " .. tostring(MyGroup:getID()))
			local def = spawnBuilding:getDef()
			local bounds = { def:getX(), (def:getX() + def:getW()), def:getY(), (def:getY() + def:getH()), 0 }
			MyGroup:setBounds(bounds)
		else
			print("did not spawn in building")
		end

		local wife
		if (player:getModData().WifeID == nil) and (SuperSurvivorGetOptionValue("WifeSpawn") == true) then
			player:getModData().WifeID = 0;

			wife = SSM:spawnSurvivor(not player:isFemale(), player:getCurrentSquare());

			local MData = wife:Get():getModData();

			wife:Get():getModData().InitGreeting = getSpeech("WifeIntro");
			wife:Get():getModData().seenZombie = true;
			MData.MetPlayer = true;
			MData.isHostile = false;

			local GID, Group

			if (SSM:Get(0):getGroupID() == nil) then
				print("SSGM:newGroup() " .. tostring(SSGM:getCount()))
				Group = SSGM:newGroup()
				GID = Group:getID()
				Group:addMember(SSM:Get(0), "Leader")
				print("POST SSGM:newGroup() " .. tostring(SSGM:getCount()))
			else
				GID = SSM:Get(0):getGroupID()
				print("main player has group id detected:" .. tostring(GID))
				Group = SSGM:Get(GID)
			end

			Group:addMember(wife, "Worker")

			local followtask = FollowTask:new(wife, getSpecificPlayer(0))
			local tm = wife:getTaskManager()
			wife:setAIMode("Follow")
			tm:AddToTop(followtask)

			--if(ZombRand(100) < (ChanceToSpawnWithGun)) then
			--	wife:giveWeapon(getWeapon(RangeWeapons[ZombRand(1,#RangeWeapons)]),true) 				
			--elseif(ZombRand(100) < (ChanceToSpawnWithWep)) then
			--	wife:giveWeapon(MeleWeapons[ZombRand(1,#MeleWeapons)],true)
			--end

			GlobalWife = wife
		end

		if (player:getModData().LockNLoad == nil) and (SuperSurvivorGetOptionValue("LockNLoad") == true) then
			local SSME = SSM:Get(0)
			SSME:WearThis("Shoes_ArmyBoots")
			SSME:WearThis("Vest_BulletArmy")
			SSME:WearThis("Trousers_CamoGreen")
			SSME:WearThis("Shirt_CamoGreen")
			SSME:WearThis("Hat_Army")

			if (wife) then
				wife:WearThis("Shoes_ArmyBoots")
				wife:WearThis("Vest_BulletArmy")
				wife:WearThis("Trousers_CamoGreen")
				wife:WearThis("Shirt_CamoGreen")
				wife:WearThis("Hat_Army")
			end

			local bat = player:getInventory():AddItem("Base.BaseballBat");
			local gun = player:getInventory():AddItem("Base.Pistol");
			local mag

			for i = 1, 4 do
				mag = player:getInventory():AddItem(gun:getMagazineType());
				mag:setCurrentAmmoCount(15)
			end

			player:getInventory():AddItem("Base.Bullets9mmBox");
			player:getInventory():AddItem("Base.Bullets9mmBox");
			player:getInventory():AddItem("Base.Bullets9mmBox");
			player:getInventory():AddItem("Base.Bullets9mmBox");

			--gun:setClip(mag)
			if (wife) then
				local pistol = wife:Get():getInventory():AddItem("Base.HuntingRifle");
				wife:Get():getInventory():AddItem("Base.308Clip");
				wife:Get():setPrimaryHandItem(pistol)
				wife:Get():setSecondaryHandItem(pistol)

				for i = 1, 12 do
					wife:Get():getInventory():AddItem("Base.308Bullets");
				end
			end

			for i = 1, 8 do
				player:LevelPerk(Perks.FromString("Aiming"))
			end

			for i = 1, 8 do
				player:LevelPerk(Perks.FromString("Reloading"))
			end

			if (wife) then
				for i = 1, 8 do wife:Get():LevelPerk(Perks.FromString("Aiming")) end
			end

			player:getModData().LockNLoad = true
		end

		local mydesc = getSpecificPlayer(0):getDescriptor();

		if (SSM:Get(0)) then SSM:Get(0):setName(mydesc:getForename()) end
	else
		print("finished initing player index " .. tostring(player:getPlayerNum()))
	end
end

function SuperSurvivorOnDeath(player)
	if (player and player:getModData().ID ~= nil) then
		local SS = SSM:Get(player:getModData().ID);

		if (SS ~= nil) then
			SS:OnDeath();
		end
	end
end

function SuperSurvivorGlobalUpdate(player)
	if (DebugOptions) and player:isLocalPlayer() then
		--DoVision for debug - main player

		local spottedList = player:getCell():getObjectList()
		if (spottedList ~= nil) then
			--print("dovision " .. tostring(spottedList:size()))
			for i = 0, spottedList:size() - 1 do
				local character = spottedList:get(i);
				if (character ~= nil) and (character ~= player) and (instanceof(character, "IsoZombie") or instanceof(character, "IsoPlayer")) then
					player:spotted(character, true)
					character:setAlpha(1)
					character:setTargetAlpha(1)
				end
			end
		end
	end

	if (player and player:getModData().ID ~= nil) then
		local SS = SSM:Get(player:getModData().ID)
		if (SS ~= nil) then SS:PlayerUpdate() end
	end
end

function getCoverValue(obj)
	if (tostring(obj:getType()) == "wall") then
		return 0 -- walls behind player are blocking if on samve sqare
	elseif (obj:getObjectName() == "Tree") then
		return 25
	elseif (obj:getObjectName() == "Window") then
		return 70
	elseif (obj:getObjectName() == "Door") then
		return 80
	elseif (obj:getObjectName() == "Counter") then
		return 80
	elseif (obj:getObjectName() == "IsoObject") then
		return 10 -- drastically lowered because small stuff like garbage was blocking shots
	else
		return 0
	end
end

function getGunShotWoundBP(player)
	if (not instanceof(player, "IsoPlayer")) then
		--print("not a player object was given to getGunshotwoundBP")
		return nil
	end

	local BD = player:getBodyDamage()
	local bps = BD:getBodyParts();
	local foundBP = false
	local list = {};
	if (bps) then
		for i = 1, bps:size() - 1 do
			if (bps:get(i) ~= nil) and (bps:get(i):HasInjury()) and (bps:get(i):getHealth() > 0) then
				table.insert(list, i);
				foundBP = true
			end
		end
	end
	if (not foundBP) then
		--print("no body part with gunshot wound")
		return nil
	end
	local result = ZombRand(1, #list)
	local index = list[result]
	local outBP = bps:get(index)
	--print("body part found was: " .. tostring(outBP))
	return outBP
end

function SuperSurvivorPVPHandle(wielder, victim, weapon, damage)
	local SSW = SSM:Get(wielder:getModData().ID);
	local SSV = SSM:Get(victim:getModData().ID);

	local fakehit = false

	if (SSV == nil) or (SSW == nil) then return false end

	if (victim.setAvoidDamage ~= nil) then
		if (SSW:isInGroup(victim)) then
			fakehit = true;
			victim:setAvoidDamage(true);
		end
	elseif (victim.setNoDamage ~= nil) then
		if (SSW:isInGroup(victim)) then
			fakehit = true;
			victim:setNoDamage(true);
		else
			victim:setNoDamage(false);
		end
	end

	if fakehit then return false end

	local extraDamage;
	local shotPartshotPart = getGunShotWoundBP(victim);

	if (shotPartshotPart ~= nil) and (SSV:getID() ~= 0) then
		extraDamage = 100; --(damage*24)

		shotPartshotPart:AddDamage(extraDamage);
		shotPartshotPart:DamageUpdate();
		victim:getBodyDamage():DamageFromWeapon(weapon);
		victim:update();
	end

	if instanceof(victim, "IsoPlayer") then
		local GroupID = SSV:getGroupID()
		if (GroupID ~= nil) then
			local group = SSGM:Get(GroupID)
			if (group) then
				group:PVPAlert(wielder)
			end
		else
			victim:getModData().hitByCharacter = true
		end

		if (weapon ~= nil) and (not weapon:isAimedFirearm()) and (weapon:getPushBackMod() > 0.3) then
			victim:StopAllActionQueue()
			local dot = victim:getDotWithForwardDirection(wielder:getX(), wielder:getY());
			--print("dot="..tostring(dot))
			if (dot < 0) then
				ISTimedActionQueue.add(ISGetHitFromBehindAction:new(victim, wielder))
			elseif (dot > 0) then
				ISTimedActionQueue.add(ISGetHitFromFrontAction:new(victim, wielder))
			end
		end

		wielder:getModData().semiHostile = true;

		if (victim:getModData().surender) and weapon and weapon:isRanged() then -- defenceless player hit, they die
			victim:getBodyDamage():getBodyPart(BodyPartType.Head):AddDamage(500);
			victim:getBodyDamage():getBodyPart(BodyPartType.Torso_Upper):AddDamage(500);
			victim:getBodyDamage():getBodyPart(BodyPartType.Hand_L):AddDamage(500);
			victim:getBodyDamage():getBodyPart(BodyPartType.UpperLeg_R):AddDamage(500);
			victim:getBodyDamage():Update();

			SSM:PublicExecution(SSW, SSV)
		end

		--if IsNpcDamageBroken and SSV:getID() ~= 0 then
		--	--print("hitConsequences " .. tostring(victim:getBodyDamage():getHealth()) )
		--	--victim:hitConsequences(weapon, wielder, false, damage, false)
		--	local parts = {}
		--	parts[0] = BodyPartType.Head
		--	parts[1] = BodyPartType.Torso_Upper
		--	parts[2] = BodyPartType.Hand_L
		--	parts[3] = BodyPartType.Hand_R
		--	parts[4] = BodyPartType.UpperLeg_L
		--	parts[5] = BodyPartType.UpperLeg_R
		--	victim:getBodyDamage():getBodyPart(parts[ZombRand(#parts)]):AddDamage(damage*100.0);
		--	victim:getBodyDamage():Update();
		--	--print("post post getHealth is " .. tostring(victim:getBodyDamage():getHealth()) )
		--end
		if IsNpcDamageBroken and instanceof(victim, "IsoPlayer") and instanceof(wielder, "IsoPlayer") and not (victim:isLocalPlayer()) then
			if weapon:getType() == "BareHands" then
				return
			end

			local b = true;
			local bindex = ZombRand(BodyPartType.Hand_L:index(), BodyPartType.MAX:index());
			local b2 = false;
			local b3 = false;
			local b4 = false;
			local n;
			if (weapon:getCategories():contains("Blunt") or weapon:getCategories():contains("SmallBlunt")) then
				n = 0;
				b2 = true;
			elseif not (weapon:isAimedFirearm()) then
				n = 1;
				b3 = true;
			else
				b4 = true;
				n = 2;
			end
			local bodydamage = victim:getBodyDamage()
			local bodypart = bodydamage:getBodyPart(BodyPartType.FromIndex(bindex));
			if (ZombRand(0, 100) < victim:getBodyPartClothingDefense(bindex, b3, b4)) then
				b = false;
			end
			if b == false then
				return;
			end
			victim:addHole(BloodBodyPartType.FromIndex(bindex));
			if (b3) then
				if (ZombRand(0, 6) == 6) then
					bodypart:generateDeepWound();
				elseif (ZombRand(0, 3) == 3) then
					bodypart:setCut(true);
				else
					bodypart:setScratched(true, true);
				end
			elseif (b2) then
				if (ZombRand(0, 4) == 4) then
					bodypart:setCut(true);
				else
					bodypart:setScratched(true, true);
				end
			elseif (b4) then
				bodypart:setHaveBullet(true, 0);
			end
			local n2 = ZombRand(weapon:getMinDamage(), weapon:getMaxDamage()) * 15.0;
			if (bindex == BodyPartType.Head:index()) then
				n2 = n2 * 4.0;
			end
			if (bindex == BodyPartType.Neck:index()) then
				n2 = n2 * 4.0;
			end
			if (bindex == BodyPartType.Torso_Upper:index()) then
				n2 = n2 * 2.0;
			end
			bodydamage:AddDamage(bindex, n2);
			local stats = victim:getStats();
			if n == 0 then
				stats:setPain(stats:getPain() + bodydamage:getInitialThumpPain() * BodyPartType.getPainModifyer(bindex));
			elseif n == 1 then
				stats:setPain(stats:getPain() + bodydamage:getInitialScratchPain() * BodyPartType.getPainModifyer(bindex));
			elseif n == 2 then
				stats:setPain(stats:getPain() + bodydamage:getInitialBitePain() * BodyPartType.getPainModifyer(bindex));
			end
			if stats:getPain() > 100 then
				stats:setPain(100)
			end

			SSV:NPCcalculateWalkSpeed();
		end
	end
end

Events.OnWeaponHitCharacter.Add(SuperSurvivorPVPHandle);
Events.OnPlayerUpdate.Add(SuperSurvivorGlobalUpdate);
Events.OnCharacterDeath.Add(SuperSurvivorOnDeath);
