local Block = require("block")
local GameManager = {
    grid = {
        cols = 8, 
        rows = 10,
        cellSize = 60,
        playArea = {x1 = 1, y1 = 1, x2 = 6, y2 = 8} 
    },
    blocks = {},
    crushers = {}
}

function GameManager.isOccupied(gx, gy, ignoreIdx)
    for i, b in ipairs(GameManager.blocks) do
        if i ~= ignoreIdx then
            for _, s in ipairs(b.segments) do
                if gx == b.gridX + s.x and gy == b.gridY + s.y then return true end
            end
        end
    end
    return false
end

-- NEW: Checks if the WHOLE block can move to a specific coordinate
function GameManager.canBlockFit(blockIdx, testX, testY)
    local b = GameManager.blocks[blockIdx]
    if not b then return false end
    
    for _, s in ipairs(b.segments) do
        if GameManager.isOccupied(testX + s.x, testY + s.y, blockIdx) then
            return false
        end
    end
    return true
end

return GameManager