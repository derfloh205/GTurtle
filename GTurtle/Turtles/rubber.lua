local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local VUtil = require("GCC/Util/vutil")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle.TurtleData.Rubber.Data
---@field resourceChestPos Vector
---@field produceChestPos Vector
---@field treePositions Vector[]
---@field fenceCorners Vector[]

---@class GTurtle.TurtleData.Rubber : GTurtle.TurtleData
---@field data GTurtle.TurtleData.Rubber.Data

---@class GTurtle.RubberTurtle.Options : GTurtle.Base.Options

---@class GTurtle.RubberTurtle : GTurtle.Base
---@overload fun(options: GTurtle.RubberTurtle.Options) : GTurtle.RubberTurtle
local RubberTurtle = GTurtle.Base:extend()

---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    EXPLORE_TREE_POSITIONS = "EXPLORE_TREE_POSITIONS",
    FETCH_SAPLINGS = "FETCH_SAPLINGS",
    SEARCH_TREE = "",
    DECIDE_ACTION = "DECIDE_ACTION"
}
TUtil:Inject(RubberTurtle.STATE, GState.STATE)

RubberTurtle.INVENTORY_WHITELIST = {
    CONST.ITEMS.RUBBER_SAPLINGS,
    CONST.ITEMS.RUBBER_WOOD
}

RubberTurtle.FUEL_BLACKLIST = {
    CONST.ITEMS.RUBBER_SAPLINGS,
    CONST.ITEMS.RUBBER_WOOD
}

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
    options.fuelBlacklist = self.FUEL_BLACKLIST
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
    ---@type GTurtle.TurtleData.Rubber
    self.turtleData = self.turtleData
    self.treeCount = 1
end

---@return GTurtle.TurtleData.Rubber.Data
function RubberTurtle:GetRTData()
    return self.turtleData.data
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    local rtData = self:GetRTData()

    if not rtData.resourceChestPos then
        rtData.resourceChestPos = TermUtil:ReadVector("Resource Chest Position?")
    end
    if not rtData.produceChestPos then
        rtData.produceChestPos = TermUtil:ReadVector("Produce Chest Position?")
    end
    -- if not rtData.treePositions or #rtData.treePositions == 0 then
    --     self.treeCount = TermUtil:ReadNumber("Tree Count?")
    --     rtData.treePositions = {}
    --     for i = 1, self.treeCount do
    --         table.insert(rtData.treePositions, TermUtil:ReadVector(f("#%s Tree Pos?", i)))
    --     end
    -- end

    if not rtData.fenceCorners then
        rtData.fenceCorners = rtData.fenceCorners or {}
        rtData.fenceCorners[1] = TermUtil:ReadVector("Fence #1")
        rtData.fenceCorners[2] = TermUtil:ReadVector("Fence #2")
        rtData.fenceCorners[3] = TermUtil:ReadVector("Fence #3")
    end

    rtData.treePositions = rtData.treePositions or {}

    self:WriteTurtleData()

    self.tnav:SetGeoFence(rtData.fenceCorners)

    self.resourceGN = self.tnav.gridMap:GetGridNode(VUtil:Deserialize(rtData.resourceChestPos))
    self.resourceGN.unknown = false
    self.produceGN = self.tnav.gridMap:GetGridNode(VUtil:Deserialize(rtData.produceChestPos))
    self.produceGN.unknown = false
    self.treeGNs =
        TUtil:Map(
        rtData.treePositions,
        function(serializedPos)
            return self.tnav.gridMap:GetGridNode(VUtil:Deserialize(serializedPos))
        end
    )

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

function RubberTurtle:FETCH_SAPLINGS()
    self:NavigateToPosition(self.resourceGN.pos)
    -- search for chest
    local chests =
        self.tnav:GetNeighbors(
        true,
        function(gn)
            return gn:IsChest()
        end
    )

    self:Log("Chest found? " .. tostring(#chests))

    if #chests == 0 then
        -- dance once to scan surroundings
        self:ExecuteMovement("RRRR")
        self:Log("Danced")
        chests =
            self.tnav:GetNeighbors(
            true,
            function(gn)
                return gn:IsChest()
            end
        )
    end

    local chestGN = chests[1]

    -- if still nothing here then user lied to us!
    if not chestGN then
        self:Log("Error: Resource Chest not found!")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    -- otherwise fetch saplings..
    self:Log("Turn to Chest")
    local relativeHead = self.tnav.currentGN:GetRelativeHeading(chestGN)
    self:TurnToHead(relativeHead)
    self:Log("Get Saplings..")
    self:SuckFromChest(CONST.ITEMS.RUBBER_SAPLINGS)
    self:DropExcept(self.INVENTORY_WHITELIST)

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

---@return GTurtle.TNAV.GridNode? candidateGN
---@return GTurtle.TNAV.GridArea? candidateArea
function RubberTurtle:GetTreePositionCandidate()
    local requiredRadius = 1
    local z = self.tnav.currentGN.pos.z
    local maxGridSize = 15
    self.invalidTreeGNs = self.invalidTreeGNs or {}

    local candidateGN, candidateArea

    for x, xData in pairs(self.tnav.gridMap.grid) do
        for y, _ in pairs(xData) do
            local gridNode = self.tnav.gridMap:GetGridNode(vector.new(x, y, z))
            local inFence = self.tnav.geoFence and self.tnav.geoFence:IsWithin(gridNode)
            if inFence and not TUtil:tContains(self.invalidTreeGNs, gridNode) then
                self:FLog("Tree Pos? %s", gridNode)
                local area = self.tnav.gridMap:GetAreaAround(gridNode, requiredRadius)

                if area:IsEmpty() then
                    return gridNode, area
                else
                    table.insert(self.invalidTreeGNs, gridNode)
                end
                self:FLog("Non Empty Area: %s", gridNode)
            end
        end
        --sleep(0)
    end

    --self:Log("Could not find empty area, Increasing Grid")
    --self.tnav.gridMap:IncreaseGridSize(1, 1, 0)

    local gridX, gridY = self.tnav.gridMap:GetGridSize()
    --candidateGN --or (gridX > maxGridSize and gridY > maxGridSize)

    if not candidateGN then
        self:FLog("Could not find candidate for tree position (Grid Size: %d %d)", gridX, gridY)
    end
end

function RubberTurtle:EXPLORE_TREE_POSITIONS()
    local candidateGN, candidateArea = self:GetTreePositionCandidate()

    if candidateGN and candidateArea then
        self:FLog("HUH?? %d %d %d", candidateGN.pos.x, candidateGN.pos.y, candidateGN.pos.z)
        self:FLog("Tree Candidate Position %s", tostring(candidateGN and candidateGN.pos))
        local success = self:NavigateToPosition(candidateGN.pos, true)
        if not success then
            self:Log("Not able to navigate to tree pos")
            table.insert(self.invalidTreeGNs, candidateGN)
            return
        end
        local areaCorners = candidateArea:GetCorners(candidateGN.pos.z)
        -- navigate to area corners to inspect
        for _, cornerGN in ipairs(areaCorners) do
            local success = self:NavigateToPosition(cornerGN.pos, true)
            if not success then
                self:Log("Not able to inspect tree area")
                table.insert(self.invalidTreeGNs, candidateGN)
                return
            end
        end
        if candidateArea:IsEmpty() then
            self:FLog("Viable Tree Position Found: %s", candidateGN)
            table.insert(self.treeGNs, candidateGN)
            local rtData = self:GetRTData()
            table.insert(rtData.treePositions, candidateGN.pos)
            self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
        end
    else
        self:Log("No available tree pos candidate")
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

function RubberTurtle:DECIDE_ACTION()
    -- if no rubber sapling in inventory - fetch from resource chest
    if false then --not self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        self:SetState(RubberTurtle.STATE.FETCH_SAPLINGS)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.EXPLORE_TREE_POSITIONS)
    else
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

return RubberTurtle
