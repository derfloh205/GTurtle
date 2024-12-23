local GBox = require("GCC/GUI/gbox")
local GNAV = require("GCC/GNav/gnav")
local GVector = require("GCC/GNav/gvector")
local f = string.format

---@class GGrid.Options : GBox.Options
---@field gridMap GNAV.GridMap
---@field colorMapFunc fun(gridNode: GNAV.GridNode) : number

---@class GGrid : GBox
---@overload fun(options: GGrid.Options) : GGrid
local GGrid = GBox:extend()

---@param options GGrid.Options
function GGrid:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GGrid.super.new(self, options)

    self.gridMap = options.gridMap
    self.colorMapFunc = options.colorMapFunc
end

---@param centerPosition GVector
function GGrid:Update(centerPosition)
    local halfX = (self.box.width - (self.box.width % 2)) / 2
    local halfY = (self.box.height - (self.box.height % 2)) / 2
    local minX = centerPosition.x - halfX
    local maxX = centerPosition.x + halfX
    local minY = centerPosition.y - halfY
    local maxY = centerPosition.y + halfY
    local z = centerPosition.z

    ---@type GBox.Pixel[]
    local pixels = {}

    for x = minX, maxX do
        for y = minY, maxY do
            local gridNode = self.gridMap:GetGridNode(GVector(x, y, z))
            local color = self.colorMapFunc(gridNode)
            local pixelX = x - minX
            local pixelY = y - minY
            table.insert(pixels, {x = pixelX, y = pixelY, c = color})
        end
    end

    self:Draw(pixels)
end

return GGrid
