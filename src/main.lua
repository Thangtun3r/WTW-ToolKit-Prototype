local Editor = require("editor")
local GameManager = require("gameManager")
local Block = require("block")
local Crusher = require("crusher")

local directionImg = love.graphics.newImage("Direction.png")

local dragStart = { x = 0, y = 0, active = false, idx = nil }
local dragDirection = nil 
local margin = { x = 60, y = 60 }

function love.load()
    love.window.setMode(1000, 700)
    Editor.load()
    Editor.offsetX = 650
end

function love.update(dt)
    local mx, my = love.mouse.getPosition()
    local mouseGridX = math.floor((mx - margin.x) / GameManager.grid.cellSize)
    local mouseGridY = math.floor((my - margin.y) / GameManager.grid.cellSize)

    if Editor.isPlacing and Editor.heldBlock then
        Editor.heldBlock.gridX = mouseGridX
        Editor.heldBlock.gridY = mouseGridY
    end

    -- Update and Clean up blocks
    for i = #GameManager.blocks, 1, -1 do
        local b = GameManager.blocks[i]
        local targetX = margin.x + (b.gridX * GameManager.grid.cellSize)
        local targetY = margin.y + (b.gridY * GameManager.grid.cellSize)
        
        -- Smooth visual movement
        b.viewX = b.viewX + (targetX - b.viewX) * b.lerpSpeed * dt
        b.viewY = b.viewY + (targetY - b.viewY) * b.lerpSpeed * dt

        -- Destruction Logic: Check if any segment is in the border zone
        local isOffGrid = false
        for _, s in ipairs(b.segments) do
            local absX = b.gridX + s.x
            local absY = b.gridY + s.y
            if absX <= 0 or absX >= GameManager.grid.cols - 1 or 
               absY <= 0 or absY >= GameManager.grid.rows - 1 then
                isOffGrid = true
                break
            end
        end
        
        local visualDistance = math.abs(targetX - b.viewX) + math.abs(targetY - b.viewY)
        if isOffGrid and visualDistance < 1 then
            table.remove(GameManager.blocks, i)
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- 1. UI CHECK: Check if clicking the Sidebar Editor area
        if x > Editor.offsetX - 20 then
            local result = Editor.mousepressed(x, y)
            if result == "create" then
                local segs = Editor.getCurrentSegments()
                if #segs > 0 then
                    Editor.isPlacing = true
                    Editor.heldBlock = {
                        segments = segs,
                        gridX = 0, gridY = 0,
                        viewX = 0, viewY = 0,
                        color = Editor.getSelectedColor(),
                        moveAxis = Editor.selectedAxis
                    }
                end
            end
            Editor.painting = true
            return
        end

        -- Convert screen coordinates to Grid coordinates
        local gx = math.floor((x - margin.x) / GameManager.grid.cellSize)
        local gy = math.floor((y - margin.y) / GameManager.grid.cellSize)

        -- 2. ERASER CHECK: If eraser is on, we only remove things
        if Editor.eraserMode then
            -- Remove Crushers
            for i = #GameManager.crushers, 1, -1 do
                local c = GameManager.crushers[i]
                if c.gridX == gx and c.gridY == gy then
                    table.remove(GameManager.crushers, i)
                    return
                end
            end
            -- Remove Blocks
            for i = #GameManager.blocks, 1, -1 do
                local b = GameManager.blocks[i]
                for _, s in ipairs(b.segments) do
                    if gx == b.gridX + s.x and gy == b.gridY + s.y then
                        table.remove(GameManager.blocks, i)
                        return
                    end
                end
            end
            return
        end

        -- 3. CRUSHER PLACEMENT: Only if Editor mode is set to crusher
        if Editor.mode == "crusher" then
            -- Only allow placement on the border (X: 0 or 7, Y: 0 or 9)
            local isBorder = (gx == 0 or gx == 7 or gy == 0 or gy == 9)
            if isBorder then
                local exists = false
                for _, c in ipairs(GameManager.crushers) do
                    if c.gridX == gx and c.gridY == gy then
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    if #Editor.selectedColors == 1 then
                        table.insert(GameManager.crushers, Crusher.new(gx, gy, Editor.palette[Editor.selectedColors[1]]))
                    elseif #Editor.selectedColors >= 2 then
                        table.insert(GameManager.crushers, Crusher.new(gx, gy, Editor.palette[Editor.selectedColors[1]], Editor.palette[Editor.selectedColors[2]]))
                    end
                end
            end
            return
        end

        -- 4. BLOCK PLACEMENT: If we are currently holding a block from the editor
        if Editor.isPlacing and Editor.heldBlock then
            -- Manual fit check for the ghost block
            local canFit = true
            for _, s in ipairs(Editor.heldBlock.segments) do
                if GameManager.isOccupied(gx + s.x, gy + s.y) then
                    canFit = false
                    break
                end
            end

            if canFit then
                local b = Editor.heldBlock
                local newBlock = Block.new(gx, gy, b.segments, b.color, b.moveAxis, GameManager.grid.cellSize)
                -- Match visual position to grid immediately for the start of the lerp
                newBlock.viewX = margin.x + gx * GameManager.grid.cellSize
                newBlock.viewY = margin.y + gy * GameManager.grid.cellSize
                table.insert(GameManager.blocks, newBlock)
                Editor.isPlacing = false
                Editor.heldBlock = nil
            end
            return
        end

        -- 5. BLOCK DRAGGING: Logic for moving existing blocks on the board
        for i, b in ipairs(GameManager.blocks) do
            for _, s in ipairs(b.segments) do
                local sx = margin.x + (b.gridX + s.x) * GameManager.grid.cellSize
                local sy = margin.y + (b.gridY + s.y) * GameManager.grid.cellSize
                if x >= sx and x <= sx + GameManager.grid.cellSize and 
                   y >= sy and y <= sy + GameManager.grid.cellSize then
                    dragStart = {x = x, y = y, active = true, idx = i}
                    return
                end
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if Editor.painting then
        Editor.mousemoved(x, y)
        return
    end

    if dragStart.active and dragStart.idx and not dragDirection then
        local diffX = math.abs(x - dragStart.x)
        local diffY = math.abs(y - dragStart.y)
        if diffX > 10 or diffY > 10 then
            if diffX > diffY then
                dragDirection = "horizontal"
            else
                dragDirection = "vertical"
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        if dragStart.active and dragStart.idx and dragDirection then
            local b = GameManager.blocks[dragStart.idx]
            if b then
                local gx, gy = b.gridX, b.gridY
                local step = 0
                
                if dragDirection == "horizontal" and (b.moveAxis == "horizontal" or b.moveAxis == "both") then
                    step = (x > dragStart.x) and 1 or -1
                    while true do
                        local nextX = gx + step
                        -- Corrected call to canBlockFit
                        if not GameManager.canBlockFit(dragStart.idx, nextX, gy) then break end
                        gx = nextX
                        if gx <= 0 or gx >= GameManager.grid.cols - 1 then break end
                    end
                    b.gridX = gx
                elseif dragDirection == "vertical" and (b.moveAxis == "vertical" or b.moveAxis == "both") then
                    step = (y > dragStart.y) and 1 or -1
                    while true do
                        local nextY = gy + step
                        -- Corrected call to canBlockFit
                        if not GameManager.canBlockFit(dragStart.idx, gx, nextY) then break end
                        gy = nextY
                        if gy <= 0 or gy >= GameManager.grid.rows - 1 then break end
                    end
                    b.gridY = gy
                end
            end
        end

        dragStart = { x = 0, y = 0, active = false, idx = nil }
        dragDirection = nil
        
        if Editor.painting then
            Editor.mousereleased()
        end
    end
end

function love.draw()
    local cellSize = GameManager.grid.cellSize

    love.graphics.push()
    love.graphics.translate(margin.x, margin.y)
    for c = 0, GameManager.grid.cols - 1 do
        for r = 0, GameManager.grid.rows - 1 do
            local isPlayZone = (c >= 1 and c <= 6 and r >= 1 and r <= 8)
            love.graphics.setColor(isPlayZone and {0.2, 0.2, 0.2} or {0.1, 0.1, 0.1})
            love.graphics.rectangle("line", c * cellSize, r * cellSize, cellSize, cellSize)
        end
    end
    for _, c in ipairs(GameManager.crushers) do Crusher.draw(c, cellSize) end
    love.graphics.pop()

    for _, b in ipairs(GameManager.blocks) do
        love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
        for _, s in ipairs(b.segments) do
            local drawX, drawY = b.viewX + s.x * cellSize, b.viewY + s.y * cellSize
            love.graphics.rectangle("fill", drawX + 4, drawY + 4, cellSize - 8, cellSize - 8)
        end
        if #b.segments > 0 then
            local s = b.segments[1]
            local drawX, drawY = b.viewX + s.x * cellSize, b.viewY + s.y * cellSize
            local rot = (b.moveAxis == "horizontal") and math.pi/2 or 0
            love.graphics.setColor(1,1,1,0.6)
            local scale = (cellSize - 20) / directionImg:getWidth()
            love.graphics.draw(directionImg, drawX + cellSize/2, drawY + cellSize/2, rot, scale, scale, directionImg:getWidth()/2, directionImg:getHeight()/2)
        end
    end

    if Editor.isPlacing and Editor.heldBlock then
        local b = Editor.heldBlock
        love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.4)
        for _, s in ipairs(b.segments) do
            local drawX = margin.x + (b.gridX + s.x) * cellSize
            local drawY = margin.y + (b.gridY + s.y) * cellSize
            love.graphics.rectangle("fill", drawX + 4, drawY + 4, cellSize - 8, cellSize - 8)
        end
    end

    Editor.draw()
end