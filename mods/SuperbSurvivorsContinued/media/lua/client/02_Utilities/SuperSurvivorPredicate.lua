
SuperSurvivorPredicate ={}
SuperSurvivorPredicate.__index = SuperSurvivorPredicate

function SuperSurvivorPredicate.waterContainer(item)
    -- our item can store water, but doesn't have water right now
    if item:canStoreWater() and not item:isWaterSource() and not item:isBroken() then
        return true
    end

    -- or our item can store water and is not full
    if item:canStoreWater() and item:isWaterSource() and not item:isBroken() and instanceof(item, "DrainableComboItem") and item:getUsedDelta() < 1 then
        return true
    end

    return false
end

--- See ISWorldObjectContextMenu.predicateChopTree
function SuperSurvivorPredicate.chopTree(item)
    return not item:isBroken() and item:hasTag("ChopTree")
end

-- See ISFarmingMenu.predicateDigPlow
function SuperSurvivorPredicate.digPlow(item)
    return not item:isBroken() and item:hasTag("DigPlow")
end

function SuperSurvivorPredicate.hammer(item)
    return not item:isBroken() and item:hasTag("Hammer")
end
