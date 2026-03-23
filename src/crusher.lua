local Crusher = {}

function Crusher.new(gx, gy, color, dualColor)
    return {
        gridX = gx,
        gridY = gy,
        color = color,
        dualColor = dualColor or nil,  -- Optional second color for dual-color crushers
        isMulti = dualColor ~= nil
    }
end

function Crusher.draw(c, cellSize)
    if c.isMulti and c.dualColor then
        -- Split the cell in half for dual-color crushers
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], 1)
        love.graphics.rectangle("fill", c.gridX * cellSize + 2, c.gridY * cellSize + 2, (cellSize - 4) / 2, cellSize - 4)
        
        love.graphics.setColor(c.dualColor[1], c.dualColor[2], c.dualColor[3], 1)
        love.graphics.rectangle("fill", c.gridX * cellSize + 2 + (cellSize - 4) / 2, c.gridY * cellSize + 2, (cellSize - 4) / 2, cellSize - 4)
    else
        -- Single color crusher
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], 1)
        love.graphics.rectangle("fill", c.gridX * cellSize + 2, c.gridY * cellSize + 2, cellSize - 4, cellSize - 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", c.gridX * cellSize, c.gridY * cellSize, cellSize, cellSize)
end

return Crusher
