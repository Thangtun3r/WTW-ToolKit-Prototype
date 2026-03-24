local Crusher = {}

function Crusher.new(gx, gy, color, dualColor, isTrigger)
    return {
        gridX = gx,
        gridY = gy,
        color = color,
        dualColor = dualColor or nil,  -- Optional second color for dual-color crushers
        isMulti = dualColor ~= nil,
        isTrigger = isTrigger or false
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
    -- Shrink by 10% and center
    local shrink = 0.10
    local size = (cellSize - 4) * (1 - shrink)
    local offset = ((cellSize - 4) - size) / 2
    local x = c.gridX * cellSize + 2 + offset
    local y = c.gridY * cellSize + 2 + offset
    local centerX = c.gridX * cellSize + cellSize/2
    local centerY = c.gridY * cellSize + cellSize/2
    local radius = size/2

    if c.isMulti and c.dualColor then
        -- Two-color crusher: top half one color, bottom half second color
        local col1 = desaturate(c.color, sat)
        love.graphics.setColor(col1[1], col1[2], col1[3], alpha)
        love.graphics.arc("fill", centerX, centerY, radius, -math.pi, 0)

        local col2 = desaturate(c.dualColor, sat)
        love.graphics.setColor(col2[1], col2[2], col2[3], alpha)
        love.graphics.arc("fill", centerX, centerY, radius, 0, math.pi)
    else
        -- Single color crusher as circle
        local col = desaturate(c.color, sat)
        love.graphics.setColor(col[1], col[2], col[3], alpha)
        love.graphics.circle("fill", centerX, centerY, radius)
    end

    -- Draw small centered triangle inside the circle, direction based on nearest block needed
    local triSize = radius * 0.5

    local function getNearestBlockDirection()
        local minDist = math.huge
        local bestDir = "down"
        local dirs = {
            {dx = 1, dy = 0, name = "right"},
            {dx = -1, dy = 0, name = "left"},
            {dx = 0, dy = 1, name = "down"},
            {dx = 0, dy = -1, name = "up"},
        }

        local maxSteps = math.max(GameManager.grid.cols, GameManager.grid.rows)
        for _, d in ipairs(dirs) do
            for step = 1, maxSteps do
                local px = c.gridX + d.dx * step
                local py = c.gridY + d.dy * step
                if px < 0 or px >= GameManager.grid.cols or py < 0 or py >= GameManager.grid.rows then
                    break
                end

                for _, b in ipairs(GameManager.blocks) do
                    for _, s in ipairs(b.segments) do
                        local sx = b.gridX + s.x
                        local sy = b.gridY + s.y
                        if sx == px and sy == py then
                            if step < minDist then
                                minDist = step
                                bestDir = d.name
                            end
                            break
                        end
                    end
                    if minDist == step and bestDir == d.name then
                        break
                    end
                end
                if minDist == step and bestDir == d.name then
                    break
                end
            end
        end

        return bestDir
    end

    local dir = getNearestBlockDirection()
    local t1x, t1y, t2x, t2y, t3x, t3y

    if dir == "right" then
        t1x = centerX + triSize * 0.6; t1y = centerY
        t2x = centerX - triSize * 0.3; t2y = centerY - triSize * 0.4
        t3x = centerX - triSize * 0.3; t3y = centerY + triSize * 0.4
    elseif dir == "left" then
        t1x = centerX - triSize * 0.6; t1y = centerY
        t2x = centerX + triSize * 0.3; t2y = centerY - triSize * 0.4
        t3x = centerX + triSize * 0.3; t3y = centerY + triSize * 0.4
    elseif dir == "up" then
        t1x = centerX; t1y = centerY - triSize * 0.6
        t2x = centerX - triSize * 0.4; t2y = centerY + triSize * 0.3
        t3x = centerX + triSize * 0.4; t3y = centerY + triSize * 0.3
    else
        t1x = centerX; t1y = centerY + triSize * 0.6
        t2x = centerX - triSize * 0.4; t2y = centerY - triSize * 0.3
        t3x = centerX + triSize * 0.4; t3y = centerY - triSize * 0.3
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.polygon("fill", t1x, t1y, t2x, t2y, t3x, t3y)
    -- keep blend mode normal for rest

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("line", centerX, centerY, radius)
end

return Crusher
