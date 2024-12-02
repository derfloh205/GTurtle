local Object = require("GCC/Util/classics")
local VUtil = require("GCC/Util/vutil")
local TUtil = require("GCC/Util/tutil")
local f = string.format
local pretty = require("cc.pretty")

---@class GTurtle.TNAV
local TNAV = {}

--- Possible Look Directions (Relative)
---@enum GTurtle.TNAV.HEAD
TNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E" -- East
}
--- Possible Turn Directions
---@enum GTurtle.TNAV.TURN
TNAV.TURN = {
    L = "L", -- Left
    R = "R" -- Right
}

--- Possible Movement Directions
---@enum GTurtle.TNAV.MOVE
TNAV.MOVE = {
    F = "F", -- Forward
    B = "B", -- Back
    U = "U", -- Up
    D = "D" -- Down
}

-- Absolute Vector Diffs based on Heading
TNAV.M_VEC = {
    [TNAV.HEAD.N] = vector.new(0, 1, 0),
    [TNAV.HEAD.S] = vector.new(0, 1, 0),
    [TNAV.HEAD.W] = vector.new(1, 0, 0),
    [TNAV.HEAD.E] = vector.new(1, 0, 0),
    [TNAV.MOVE.U] = vector.new(0, 0, 1),
    [TNAV.MOVE.D] = vector.new(0, 0, 1)
}

---@class GTurtle.TNAV.GridNode.Options
---@field gridMap GTurtle.TNAV.GridMap
---@field pos Vector
---@field blockData table?

---@class GTurtle.TNAV.GridNode : Object
---@overload fun(options: GTurtle.TNAV.GridNode.Options) : GTurtle.TNAV.GridNode
TNAV.GridNode = Object:extend()

---@param options GTurtle.TNAV.GridNode.Options
function TNAV.GridNode:new(options)
    options = options or {}
    self.gridMap = options.gridMap
    self.pos = options.pos
    self.blockData = options.blockData
    -- wether the position ever was scannend
    self.unknown = false
end

---@return boolean isEmpty
function TNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

---@return boolean isUnknown
function TNAV.GridNode:IsUnknown()
    return self.unknown
end

---@return boolean isTurtlePos
function TNAV.GridNode:IsTurtlePos()
    return VUtil:Equal(self.pos, self.gridMap.gridNav.pos)
end

---@class GTurtle.TNAV.GridMap.Options
---@field gridNav GTurtle.TNAV.GridNav

---@class GTurtle.TNAV.GridMap : Object
---@overload fun(options: GTurtle.TNAV.GridMap.Options) : GTurtle.TNAV.GridMap
TNAV.GridMap = Object:extend()

---@param options GTurtle.TNAV.GridMap.Options
function TNAV.GridMap:new(options)
    options = options or {}
    self.gridNav = options.gridNav
    self.boundaries = {
        x = {max = 0, min = 0},
        y = {max = 0, min = 0},
        z = {max = 0, min = 0}
    }
    -- 3D Array
    ---@type table<number, table<number, table<number, GTurtle.TNAV.GridNode>>>
    self.grid = {}
    -- initialize with currentPos (which is seen as empty)
    self:UpdateGridNode(self.gridNav.pos, nil)
    self:UpdateSurroundings()
end

---@param pos Vector
function TNAV.GridMap:UpdateBoundaries(pos)
    self.boundaries.x.min = math.min(self.boundaries.x.min, pos.x)
    self.boundaries.y.min = math.min(self.boundaries.y.min, pos.y)
    self.boundaries.z.min = math.min(self.boundaries.z.min, pos.z)

    self.boundaries.x.max = math.max(self.boundaries.x.max, pos.x)
    self.boundaries.y.max = math.max(self.boundaries.y.max, pos.y)
    self.boundaries.z.max = math.max(self.boundaries.z.max, pos.z)
end

--- initializes or updates a scanned grid node
---@param pos Vector
---@param blockData table?
function TNAV.GridMap:UpdateGridNode(pos, blockData)
    local gridNode = self:GetGridNode(pos)
    gridNode.blockData = blockData or nil
    gridNode.unknown = false

    self:UpdateBoundaries(pos)
end

-- creates a new gridnode at pos or returns an existing one
---@param pos Vector
---@return GTurtle.TNAV.GridNode
function TNAV.GridMap:GetGridNode(pos)
    local x, y, z = pos.x, pos.y, pos.z
    self.grid[x] = self.grid[x] or {}
    self.grid[x][y] = self.grid[x][y] or {}
    local gridNode = self.grid[x][y][z]
    if not gridNode then
        gridNode =
            TNAV.GridNode(
            {
                gridMap = self,
                pos = pos
            }
        )
        gridNode.unknown = true
        self.grid[x][y][z] = gridNode
    end
    return gridNode
end

function TNAV.GridMap:UpdateSurroundings()
    local scanData = self.gridNav.gTurtle:ScanBlocks()
    self.gridNav.gTurtle:Log("Scanning Surroundings..")

    for dir, data in pairs(scanData) do
        self.gridNav.gTurtle:Log(f("%s -> %s", dir, (data and data.name or "Empty")))
        local pos = self.gridNav:GetHeadedPosition(self.gridNav.pos, self.gridNav.head, dir)
        self:UpdateGridNode(pos, data)
    end
end

function TNAV.GridMap:LogGrid()
    self.gridNav.gTurtle:Log(
        "Logging Grid at Z = " .. self.gridNav.pos.z .. "\n" .. self:GetGridString(self.gridNav.pos.z)
    )
end

---@param z number
---@return string
function TNAV.GridMap:GetGridString(z)
    local boundaries = self.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local gridString = ""

    for y = maxY, minY, -1 do
        for x = minX, maxX do
            local gridNode = self:GetGridNode(vector.new(x, y, z))
            local c = " X "
            if gridNode:IsTurtlePos() then
                c = "[T]"
            elseif gridNode:IsEmpty() then
                c = "   "
            elseif gridNode:IsUnknown() then
                c = " ? "
            end
            if x == minX then
                c = "|" .. c
            end
            if x == maxX then
                c = c .. "|"
            end
            gridString = gridString .. c
        end
        gridString = gridString .. "\n"
    end
    return gridString
end

---@class GTurtle.TNAV.GridNav.Options
---@field gTurtle GTurtle.Base
---@field initPos Vector

---@class GTurtle.TNAV.GridNav : Object
---@overload fun(options: GTurtle.TNAV.GridNav.Options) : GTurtle.TNAV.GridNav
TNAV.GridNav = Object:extend()

---@param options GTurtle.TNAV.GridNav.Options
function TNAV.GridNav:new(options)
    options = options or {}
    self.gTurtle = options.gTurtle
    ---@type GTurtle.TNAV.HEAD
    self.head = TNAV.HEAD.N
    self.initPos = options.initPos
    self.pos = self.initPos
    ---@type GTurtle.TNAV.GridNode[]
    self.activePath = {}
    self.gridMap = TNAV.GridMap({gridNav = self})
end

---@param turn GTurtle.TNAV.TURN
function TNAV.GridNav:OnTurn(turn)
    local h = self.head
    if turn == TNAV.TURN.L then
        if h == TNAV.HEAD.N then
            self.head = TNAV.HEAD.W
        elseif h == TNAV.HEAD.W then
            self.head = TNAV.HEAD.S
        elseif h == TNAV.HEAD.S then
            self.head = TNAV.HEAD.E
        elseif h == TNAV.HEAD.E then
            self.head = TNAV.HEAD.N
        end
    elseif turn == TNAV.TURN.R then
        if h == TNAV.HEAD.N then
            self.head = TNAV.HEAD.E
        elseif h == TNAV.HEAD.E then
            self.head = TNAV.HEAD.S
        elseif h == TNAV.HEAD.S then
            self.head = TNAV.HEAD.W
        elseif h == TNAV.HEAD.W then
            self.head = TNAV.HEAD.N
        end
    end

    self.gridMap:UpdateSurroundings()
end

---@param dir GTurtle.TNAV.MOVE
function TNAV.GridNav:OnMove(dir)
    self.pos = self:GetHeadedPosition(self.pos, self.head, dir)
    self.gridMap:UpdateSurroundings()
end

---@return number
function TNAV.GridNav:GetDistanceFromStart()
    return VUtil:ManhattanDistance(self.pos, self.initPos)
end

--- get pos by current pos, current heading and direction to look at
---@param pos Vector
---@param head GTurtle.TNAV.HEAD
---@param dir GTurtle.TNAV.MOVE
function TNAV.GridNav:GetHeadedPosition(pos, head, dir)
    -- use the z diff vector if dir is up or down else use the x/y vector
    local relVec = TNAV.M_VEC[dir] or TNAV.M_VEC[head]

    -- possible movement directions that cause coordination subtraction
    if
        dir == TNAV.MOVE.D or (head == TNAV.HEAD.W and dir == TNAV.MOVE.F) or
            (head == TNAV.HEAD.E and dir == TNAV.MOVE.B) or
            (head == TNAV.HEAD.N and dir == TNAV.MOVE.B) or
            (head == TNAV.HEAD.S and dir == TNAV.MOVE.F)
     then
        relVec = -relVec
    end
    return pos + relVec
end

function TNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.pos), self.head))
end

--- A*

-- Get valid neighbors in 3D space - Used in A*
---@param node GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.GridNode[]
function TNAV.GridNav:GetNeighbors(node)
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GTurtle.TNAV.GridNode[]
    local neighbors = {}
    local directions = {
        {x = 1, y = 0, z = 0}, -- Right
        {x = -1, y = 0, z = 0}, -- Left
        {x = 0, y = 1, z = 0}, -- Up
        {x = 0, y = -1, z = 0}, -- Down
        {x = 0, y = 0, z = 1}, -- Forward
        {x = 0, y = 0, z = -1} -- Backward
    }

    for _, dir in ipairs(directions) do
        local nx, ny, nz = node.pos.x + dir.x, node.pos.y + dir.y, node.pos.z + dir.z
        if nx >= minX and nx <= maxX and ny >= minY and ny <= maxY and nz >= minZ and nz <= maxZ then
            local neighborGridNode = self.gridMap:GetGridNode(vector.new(nx, ny, nz))
            if neighborGridNode and neighborGridNode:IsEmpty() and not neighborGridNode:IsUnknown() then
                table.insert(neighbors, neighborGridNode)
            end
        end
    end

    return neighbors
end

--- Reconstruct the path from start to goal
--- Yes it uses table refs as keys *_*
---@param came_from table<GTurtle.TNAV.GridNode, GTurtle.TNAV.GridNode>
---@param current GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.GridNode[] path
function TNAV.GridNav:ReconstructPath(came_from, current)
    local path = {}
    while current do
        table.insert(path, 1, current)
        current = came_from[current]
    end
    return path
end

--- A* algorithm
---@param startGN GTurtle.TNAV.GridNode
---@param goalGN GTurtle.TNAV.GridNode
function TNAV.GridNav:CalculatePath(startGN, goalGN)
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GTurtle.TNAV.GridNode[]
    local openSet = {startGN}
    local cameFromGN = {}

    -- Initialize cost dictionaries
    local gScore = {}
    local fScore = {}
    for x = minX, maxX do
        gScore[x], fScore[x] = {}, {}
        for y = minY, maxY do
            gScore[x][y], fScore[x][y] = {}, {}
            for z = minZ, maxZ do
                gScore[x][y][z] = math.huge
                fScore[x][y][z] = math.huge
            end
        end
    end

    gScore[startGN.pos.x][startGN.pos.y][startGN.pos.z] = 0
    fScore[startGN.pos.x][startGN.pos.y][startGN.pos.z] = VUtil:ManhattanDistance(startGN.pos, goalGN.pos)

    while #openSet > 0 do
        -- Find node in open_set with the lowest f_score
        table.sort(
            openSet,
            function(aGN, bGN)
                return fScore[aGN.pos.x][aGN.pos.y][aGN.pos.z] < fScore[bGN.pos.x][bGN.pos.y][bGN.pos.z]
            end
        )
        ---@type GTurtle.TNAV.GridNode
        local currentGN = table.remove(openSet, 1)

        -- If goal is reached
        if VUtil:Equal(currentGN.pos, goalGN.pos) then
            return self:ReconstructPath(cameFromGN, currentGN)
        end

        -- Process neighbors
        for _, neighborGN in ipairs(self:GetNeighbors(currentGN)) do
            local tentativeGScore = gScore[currentGN.pos.x][currentGN.pos.y][currentGN.pos.z] + 1
            if tentativeGScore < gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] then
                cameFromGN[neighborGN] = currentGN
                gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] = tentativeGScore
                fScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] =
                    tentativeGScore + VUtil:ManhattanDistance(neighborGN.pos, goalGN.pos)
                if not TUtil:tContains(openSet, neighborGN) then
                    table.insert(openSet, neighborGN)
                end
            end
        end
    end

    return nil -- No path found
end

---@return GTurtle.TNAV.GridNode[] path?
function TNAV.GridNav:CalculatePathToInitialPosition()
    local startGN = self.gridMap:GetGridNode(self.pos)
    local goalGN = self.gridMap:GetGridNode(self.initPos)
    return self:CalculatePath(startGN, goalGN)
end

---@param path GTurtle.TNAV.GridNode[]
function TNAV.GridNav:SetActivePath(path)
    self.activePath = path
end

---@return boolean
function TNAV.GridNav:IsInitialPosition()
    return VUtil:Equal(self.pos, self.initPos)
end

---@return GTurtle.TNAV.MOVE | GTurtle.TNAV.TURN
function TNAV.GridNav:GetNextMoveAlongPath()
    local move
    for i, gridNode in ipairs(self.activePath) do
        if VUtil:Equal(gridNode.pos, self.pos) then
            -- @ gridnode for current path
            local nextGN = self.activePath[i + 1]
            if nextGN then
                local nextPos = nextGN.pos
            --TODO: Determine vector diff and needed turn or move to advance towards next gn
            end
        end
    end

    return move
end

return TNAV
