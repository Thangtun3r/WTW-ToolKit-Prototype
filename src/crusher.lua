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
    -- Helper to desaturate color (simple lerp to gray)
    local function desaturate(color, factor)
        local gray = 0.3 * color[1] + 0.59 * color[2] + 0.11 * color[3]
        return {
            color[1] + (gray - color[1]) * factor,
            color[2] + (gray - color[2]) * factor,
            color[3] + (gray - color[3]) * factor
        }
    end
    local sat = 0.1 -- 0 = full gray, 1 = original color
    local alpha = 0.8
    if c.isMulti and c.dualColor then
        -- Diagonal split for dual-color crushers
        local x = c.gridX * cellSize + 2
        local y = c.gridY * cellSize + 2
        local size = cellSize - 4
        -- First triangle (top-left to bottom-right)
        local col1 = desaturate(c.color, sat)
        love.graphics.setColor(col1[1], col1[2], col1[3], alpha)
        love.graphics.polygon("fill", x, y, x + size, y, x + size, y + size)
        -- Second triangle (bottom-right to top-left)
        local col2 = desaturate(c.dualColor, sat)
        love.graphics.setColor(col2[1], col2[2], col2[3], alpha)
        love.graphics.polygon("fill", x, y, x, y + size, x + size, y + size)
    else
        -- Single color crusher
        local col = desaturate(c.color, sat)
        love.graphics.setColor(col[1], col[2], col[3], alpha)
        love.graphics.rectangle("fill", c.gridX * cellSize + 2, c.gridY * cellSize + 2, cellSize - 4, cellSize - 4)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", c.gridX * cellSize, c.gridY * cellSize, cellSize, cellSize)
end

return Crusher
