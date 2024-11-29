local Object = require("GTurtle/classics")
local VUtils = require("GTurtle/vutils")
local TUtils = require("GTurtle/tutils")
local pretty = require("cc.pretty")

---@class Vector
---@field x number
---@field y number
---@field z number

---@class GNAV
local GNAV = {}

--- Possible Look Directions (Relative)
---@enum GNAV.HEAD
GNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E" -- East
}
--- Possible Turn Directions
---@enum GNAV.TURN
GNAV.TURN = {
    L = "L", -- Left
    R = "R" -- Right
}

--- Possible Movement Directions
---@enum GNAV.MOVE
GNAV.MOVE = {
    F = "F", -- Forward
    B = "B", -- Back
    U = "U", -- Up
    D = "D" -- Down
}

-- Absolute Vector Diffs based on Heading
GNAV.M_VEC = {
    [GNAV.HEAD.N] = vector.new(0, 1, 0),
    [GNAV.HEAD.S] = vector.new(0, 1, 0),
    [GNAV.HEAD.W] = vector.new(1, 0, 0),
    [GNAV.HEAD.E] = vector.new(1, 0, 0),
    [GNAV.MOVE.U] = vector.new(0, 0, 1),
    [GNAV.MOVE.D] = vector.new(0, 0, 1)
}

---@class GNAV.GridNode.Options
---@field gridMap GNAV.GridMap
---@field pos Vector
---@field blockData table?

---@class GNAV.GridNode : Object
---@overload fun(options: GNAV.GridNode.Options) : GNAV.GridNode
GNAV.GridNode = Object:extend()

---@param options GNAV.GridNode.Options
function GNAV.GridNode:new(options)
    options = options or {}
    self.gridMap = options.gridMap
    self.pos = options.pos
    self.blockData = options.blockData
    -- wether the position ever was scannend
    self.unknown = false
end

---@return boolean isEmpty
function GNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

---@return boolean isUnknown
function GNAV.GridNode:IsUnknown()
    return self.unknown
end

---@return boolean isTurtlePos
function GNAV.GridNode:IsTurtlePos()
    return VUtils:Equal(self.pos, self.gridMap.gridNav.pos)
end

---@class GNAV.GridMap.Options
---@field gridNav GNAV.GridNav

---@class GNAV.GridMap : Object
---@overload fun(options: GNAV.GridMap.Options) : GNAV.GridMap
GNAV.GridMap = Object:extend()

---@param options GNAV.GridMap.Options
function GNAV.GridMap:new(options)
    options = options or {}
    self.gridNav = options.gridNav
    self.boundaries = {
        x = {max = 0, min = 0},
        y = {max = 0, min = 0},
        z = {max = 0, min = 0}
    }
    -- 3D Array
    ---@type table<number, table<number, table<number, GNAV.GridNode>>>
    self.grid = {}
    -- initialize with currentPos (which is seen as empty)
    self:UpdateGridNode(self.gridNav.pos, nil)
    self:UpdateSurroundings()
end

---@param pos Vector
function GNAV.GridMap:UpdateBoundaries(pos)
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
function GNAV.GridMap:UpdateGridNode(pos, blockData)
    local gridNode = self:GetGridNode(pos)
    gridNode.blockData = blockData or nil
    gridNode.unknown = false

    self:UpdateBoundaries(pos)
end

-- creates a new gridnode at pos or returns an existing one
---@param pos Vector
---@return GNAV.GridNode
function GNAV.GridMap:GetGridNode(pos)
    local x, y, z = pos.x, pos.y, pos.z
    self.grid[x] = self.grid[x] or {}
    self.grid[x][y] = self.grid[x][y] or {}
    local gridNode = self.grid[x][y][z]
    if not gridNode then
        gridNode =
            GNAV.GridNode(
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

function GNAV.GridMap:UpdateSurroundings()
    local scanData = self.gridNav.gTurtle:ScanBlocks()
    self.gridNav.gTurtle:Log("Scanned Surroundings:")
    self.gridNav:LogPos()

    for dir, data in pairs(scanData) do
        self.gridNav.gTurtle:Log("Dir: " .. dir .. " -> " .. (data and data.name or "Empty"))
        local pos = self.gridNav:GetHeadedPosition(self.gridNav.pos, self.gridNav.head, dir)
        self.gridNav.gTurtle:Log("-> Pos: " .. tostring(pos))
        self:UpdateGridNode(pos, data)
    end
end

function GNAV.GridMap:LogGrid()
    self.gridNav.gTurtle:Log(
        "Logging Grid at Z = " .. self.gridNav.pos.z .. "\n" .. self:GetGridString(self.gridNav.pos.z)
    )
end

---@param z number
---@return string
function GNAV.GridMap:GetGridString(z)
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

---@class GNAV.PathNode.Options
---@field pos Vector
---@field lNode GNAV.PathNode?

---@class GNAV.PathNode : Object
---@overload fun(options: GNAV.PathNode.Options) : GNAV.PathNode
GNAV.PathNode = Object:extend()

function GNAV.PathNode:new(options)
    options = options or {}
    self.pos = options.pos
    self.lNode = options.lNode
    self.nNode = nil
end

---@class GNAV.GridNav.Options
---@field gTurtle GTurtle.Base
---@field initPos Vector

---@class GNAV.GridNav : Object
---@overload fun(options: GNAV.GridNav.Options) : GNAV.GridNav
GNAV.GridNav = Object:extend()

---@param options GNAV.GridNav.Options
function GNAV.GridNav:new(options)
    options = options or {}
    self.gTurtle = options.gTurtle
    ---@type GNAV.HEAD
    self.head = GNAV.HEAD.N
    self.initPos = options.initPos
    self.pos = self.initPos
    self.path = {}
    self.gridMap = GNAV.GridMap({gridNav = self})
    self:UpdatePath()
end

function GNAV.GridNav:UpdatePath()
    local lastNode = self.path[#self.path]

    local newNode = GNAV.PathNode({pos = self.pos, lNode = lastNode})
    if lastNode then
        lastNode.nNode = newNode
    end
end

---@param turn GNAV.TURN
function GNAV.GridNav:OnTurn(turn)
    local h = self.head
    if turn == GNAV.TURN.L then
        if h == GNAV.HEAD.N then
            self.head = GNAV.HEAD.W
        elseif h == GNAV.HEAD.W then
            self.head = GNAV.HEAD.S
        elseif h == GNAV.HEAD.S then
            self.head = GNAV.HEAD.E
        elseif h == GNAV.HEAD.E then
            self.head = GNAV.HEAD.N
        end
    elseif turn == GNAV.TURN.R then
        if h == GNAV.HEAD.N then
            self.head = GNAV.HEAD.E
        elseif h == GNAV.HEAD.E then
            self.head = GNAV.HEAD.S
        elseif h == GNAV.HEAD.S then
            self.head = GNAV.HEAD.W
        elseif h == GNAV.HEAD.W then
            self.head = GNAV.HEAD.N
        end
    end

    self.gridMap:UpdateSurroundings()
end

---@param dir GNAV.MOVE
function GNAV.GridNav:OnMove(dir)
    self.gTurtle:Log(string.format("Record Movement - @{%s}: %s -> %s", tostring(self.pos), self.head, dir))
    self.pos = self:GetHeadedPosition(self.pos, self.head, dir)
    self.gTurtle:Log("-> " .. tostring(self.pos))
    self:UpdatePath()
    self.gridMap:UpdateSurroundings()
end

---@return number
function GNAV.GridNav:GetDistanceFromStart()
    return VUtils:ManhattanDistance(self.pos, self.initPos)
end

--- get pos by current pos, current heading and direction to look at
---@param pos Vector
---@param head GNAV.HEAD
---@param dir GNAV.MOVE
function GNAV.GridNav:GetHeadedPosition(pos, head, dir)
    -- use the z diff vector if dir is up or down else use the x/y vector
    local relVec = GNAV.M_VEC[dir] or GNAV.M_VEC[head]

    -- possible movement directions that cause coordination subtraction
    if
        dir == GNAV.MOVE.D or (head == GNAV.HEAD.W and dir == GNAV.MOVE.F) or
            (head == GNAV.HEAD.E and dir == GNAV.MOVE.B) or
            (head == GNAV.HEAD.N and dir == GNAV.MOVE.B) or
            (head == GNAV.HEAD.S and dir == GNAV.MOVE.F)
     then
        relVec = -relVec
    end
    return pos + relVec
end

function GNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.pos), self.head))
end

--- A*

-- Get valid neighbors in 3D space - Used in A*
---@param node GNAV.GridNode
---@return GNAV.GridNode[]
function GNAV.GridNav:GetNeighbors(node)
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GNAV.GridNode[]
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
---@param came_from table<GNAV.GridNode, GNAV.GridNode>
---@param current GNAV.GridNode
---@return GNAV.GridNode[] path
function GNAV.GridNav:ReconstructPath(came_from, current)
    local path = {}
    while current do
        table.insert(path, 1, current)
        current = came_from[current]
    end
    return path
end

--- A* algorithm
---@param startGN GNAV.GridNode
---@param goalGN GNAV.GridNode
function GNAV.GridNav:CalculatePath(startGN, goalGN)
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GNAV.GridNode[]
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
    fScore[startGN.pos.x][startGN.pos.y][startGN.pos.z] = VUtils:ManhattanDistance(startGN.pos, goalGN.pos)

    while #openSet > 0 do
        -- Find node in open_set with the lowest f_score
        table.sort(
            openSet,
            function(aGN, bGN)
                return fScore[aGN.pos.x][aGN.pos.y][aGN.pos.z] < fScore[bGN.pos.x][bGN.pos.y][bGN.pos.z]
            end
        )
        ---@type GNAV.GridNode
        local currentGN = table.remove(openSet, 1)

        -- If goal is reached
        if VUtils:Equal(currentGN.pos, goalGN.pos) then
            return self:ReconstructPath(cameFromGN, currentGN)
        end

        -- Process neighbors
        for _, neighborGN in ipairs(self:GetNeighbors(currentGN)) do
            local tentativeGScore = gScore[currentGN.pos.x][currentGN.pos.y][currentGN.pos.z] + 1
            if tentativeGScore < gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] then
                cameFromGN[neighborGN] = currentGN
                gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] = tentativeGScore
                fScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] =
                    tentativeGScore + VUtils:ManhattanDistance(neighborGN.pos, goalGN.pos)
                if not TUtils:tContains(openSet, neighborGN) then
                    table.insert(openSet, neighborGN)
                end
            end
        end
    end

    return nil -- No path found
end

function GNAV.GridNav:CalculatePathToStart()
    local startGN = self.gridMap:GetGridNode(self.pos)
    local goalGN = self.gridMap:GetGridNode(self.initPos)
    return self:CalculatePath(startGN, goalGN)
end

-- Example usage
-- local max_x, max_y, max_z = 5, 5, 5
-- local grid = {}
-- for x = 1, max_x do
--     grid[x] = {}
--     for y = 1, max_y do
--         grid[x][y] = {}
--         for z = 1, max_z do
--             grid[x][y][z] = {x = x, y = y, z = z, is_obstacle = false}
--         end
--     end
-- end

-- -- Define obstacles
-- grid[3][3][3].is_obstacle = true

-- -- Start and goal nodes
-- local start = grid[1][1][1]
-- local goal = grid[5][5][5]

-- -- Find the path
-- local path = astar(grid, start, goal, max_x, max_y, max_z)
-- if path then
--     for _, p in ipairs(path) do
--         print("Step: x=" .. p.x .. ", y=" .. p.y .. ", z=" .. p.z)
--     end
-- else
--     print("No path found.")
-- end

---

return GNAV
