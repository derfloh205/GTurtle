---@class VUtils
local VUtils = {}

function VUtils:Distance(v1, v2)
    return math.sqrt((v1.x - v2.x) ^ 2 + (v1.y - v2.y) ^ 2 + (v1.z - v2.z) ^ 2)
end

-- THIS IS A TEST

return VUtils
