
local Editor = require("editor")
local GameManager = require("gameManager")
local Block = require("block")
local Crusher = require("crusher")
local StepTracker = require("stepTracker")

local directionImg = love.graphics.newImage("Direction.png")

local dragStart = { x = 0, y = 0, active = false, idx = nil }
local dragDirection = nil 
local margin = { x = 60, y = 60 }


function love.load()
    love.window.setMode(1000, 700)
    Editor.load()
    Editor.offsetX = 650
end




local previousEditorMode = "block"
local pressedColorKeys = {}
local lastStepKey = ""
local originalState = nil

function love.keypressed(key, scancode, isrepeat)
    -- Track last step key for indicator
    if key == 'f5' then lastStepKey = 'F5 (Start Tracking)' end
    if key == 'f6' then lastStepKey = 'F6 (Stop/Revert)' end
    if key == 'f7' then lastStepKey = 'F7 (Restore Original)' end
    if key == 'z' and love.keyboard.isDown('lctrl','rctrl') then lastStepKey = 'Ctrl+Z (Undo)' end
    -- StepTracker controls
    if key == 'f5' then -- Start tracking
        -- Save original state for F7 restore
        originalState = {
            blocks = StepTracker.deepCopy(GameManager.blocks),
            crushers = StepTracker.deepCopy(GameManager.crushers),
            -- Optionally add editor state if needed
        }
        StepTracker.start({
            blocks = GameManager.blocks,
            crushers = GameManager.crushers,
            editor = Editor,
        })
        print("Step tracking started")
        return
    elseif key == 'f6' then -- Stop tracking and revert
        local state = StepTracker.revert()
        if state then
            GameManager.blocks = StepTracker.deepCopy(state.blocks)
            GameManager.crushers = StepTracker.deepCopy(state.crushers)
            -- Optionally restore editor state if needed
        end
        StepTracker.stop()
        print("Step tracking stopped and reverted")
        return
    elseif key == 'f7' then -- Restore original state after tracking
        if originalState then
            GameManager.blocks = StepTracker.deepCopy(originalState.blocks)
            GameManager.crushers = StepTracker.deepCopy(originalState.crushers)
            print("Restored to original state before tracking")
        end
        return
    elseif key == 'z' and love.keyboard.isDown('lctrl','rctrl') then -- Undo
        if StepTracker.active then
            local state = StepTracker.undo({
                blocks = GameManager.blocks,
                crushers = GameManager.crushers,
                editor = Editor,
            })
            if state then
                GameManager.blocks = StepTracker.deepCopy(state.blocks)
                GameManager.crushers = StepTracker.deepCopy(state.crushers)
            end
        end
        return
    end
    -- Toggle eraser mode with 'e'
    if key == 'e' then
        Editor.eraserMode = not Editor.eraserMode
        if Editor.eraserMode then
            previousEditorMode = Editor.mode or previousEditorMode
            Editor.mode = nil
        else
            Editor.mode = previousEditorMode or "block"
        end
    end
    -- Toggle crusher mode with 'c'
    if key == 'c' then
        Editor.mode = "crusher"
        previousEditorMode = "crusher"
        Editor.eraserMode = false
    end
    -- Toggle block mode with 'b'
    if key == 'b' then
        Editor.mode = "block"
        previousEditorMode = "block"
        Editor.eraserMode = false
    end
    -- Number keys for color selection (1-6):
    local num = tonumber(key)
    if num and num >= 1 and num <= #Editor.palette then
        pressedColorKeys[num] = true
        -- Count how many color keys are currently pressed
        local count = 0
        for i = 1, #Editor.palette do
            if pressedColorKeys[i] then count = count + 1 end
        end
        if count == 1 then
            -- Only one key pressed: single color mode
            Editor.selectedColors = {num}
        else
            -- Multi-key: add all currently pressed keys
            Editor.selectedColors = {}
            for i = 1, #Editor.palette do
                if pressedColorKeys[i] then table.insert(Editor.selectedColors, i) end
            end
        end
        return
    end
end



function love.keyreleased(key, scancode)
    local num = tonumber(key)
    if num and num >= 1 and num <= #Editor.palette then
        pressedColorKeys[num] = nil
        -- Count how many color keys are currently pressed
        local count = 0
        for i = 1, #Editor.palette do
            if pressedColorKeys[i] then count = count + 1 end
        end
        if count == 1 then
            -- Only one left: single color mode
            for i = 1, #Editor.palette do
                if pressedColorKeys[i] then Editor.selectedColors = {i} end
            end
        elseif count > 1 then
            -- Multi-key: add all currently pressed keys
            Editor.selectedColors = {}
            for i = 1, #Editor.palette do
                if pressedColorKeys[i] then table.insert(Editor.selectedColors, i) end
            end
        else
            -- None left: keep last released as selected
            Editor.selectedColors = {num}
        end
    end
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
            Editor.painting = true
            -- Remove Crushers
            for i = #GameManager.crushers, 1, -1 do
                local c = GameManager.crushers[i]
                if c.gridX == gx and c.gridY == gy then
                    if StepTracker.active then
                        StepTracker.recordStep({
                            type = "remove_crusher",
                            gx = gx, gy = gy,
                            apply = function(state)
                                for j = #state.crushers, 1, -1 do
                                    local cc = state.crushers[j]
                                    if cc.gridX == gx and cc.gridY == gy then
                                        table.remove(state.crushers, j)
                                        break
                                    end
                                end
                            end
                        })
                    end
                    table.remove(GameManager.crushers, i)
                    return
                end
            end
            -- Remove Blocks
            for i = #GameManager.blocks, 1, -1 do
                local b = GameManager.blocks[i]
                for _, s in ipairs(b.segments) do
                    if gx == b.gridX + s.x and gy == b.gridY + s.y then
                        if StepTracker.active then
                            StepTracker.recordStep({
                                type = "remove_block",
                                blockIdx = i,
                                apply = function(state)
                                    table.remove(state.blocks, i)
                                end
                            })
                        end
                        table.remove(GameManager.blocks, i)
                        return
                    end
                end
            end
            return
        end

        -- 3. CRUSHER PAINTING: If Editor mode is set to crusher, enable painting
        if Editor.mode == "crusher" then
            Editor.painting = true
            -- Place crusher at initial click
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
                    if StepTracker.active then
                        local color1 = Editor.selectedColors[1]
                        local color2 = Editor.selectedColors[2]
                        StepTracker.recordStep({
                            type = "add_crusher",
                            gx = gx, gy = gy, color1 = color1, color2 = color2,
                            apply = function(state)
                                if color2 then
                                    table.insert(state.crushers, Crusher.new(gx, gy, Editor.palette[color1], Editor.palette[color2]))
                                else
                                    table.insert(state.crushers, Crusher.new(gx, gy, Editor.palette[color1]))
                                end
                            end
                        })
                    end
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
                if StepTracker.active then
                    StepTracker.recordStep({
                        type = "add_block",
                        gx = gx, gy = gy, segments = b.segments, color = b.color, moveAxis = b.moveAxis,
                        apply = function(state)
                            local block = Block.new(gx, gy, b.segments, b.color, b.moveAxis, GameManager.grid.cellSize)
                            block.viewX = margin.x + gx * GameManager.grid.cellSize
                            block.viewY = margin.y + gy * GameManager.grid.cellSize
                            table.insert(state.blocks, block)
                        end
                    })
                end
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
        if Editor.eraserMode then
            -- Paint erase while dragging
            local gx = math.floor((x - margin.x) / GameManager.grid.cellSize)
            local gy = math.floor((y - margin.y) / GameManager.grid.cellSize)
            -- Remove Crushers
            for i = #GameManager.crushers, 1, -1 do
                local c = GameManager.crushers[i]
                if c.gridX == gx and c.gridY == gy then
                    table.remove(GameManager.crushers, i)
                    break
                end
            end
            -- Remove Blocks
            for i = #GameManager.blocks, 1, -1 do
                local b = GameManager.blocks[i]
                for _, s in ipairs(b.segments) do
                    if gx == b.gridX + s.x and gy == b.gridY + s.y then
                        table.remove(GameManager.blocks, i)
                        break
                    end
                end
            end
        elseif Editor.mode == "crusher" then
            -- Paint crushers while dragging
            local gx = math.floor((x - margin.x) / GameManager.grid.cellSize)
            local gy = math.floor((y - margin.y) / GameManager.grid.cellSize)
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
        else
            Editor.mousemoved(x, y)
        end
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
                local oldX, oldY = b.gridX, b.gridY
                local gx, gy = b.gridX, b.gridY
                local step = 0
                local moved = false
                if dragDirection == "horizontal" and (b.moveAxis == "horizontal" or b.moveAxis == "both") then
                    step = (x > dragStart.x) and 1 or -1
                    while true do
                        local nextX = gx + step
                        if not GameManager.canBlockFit(dragStart.idx, nextX, gy) then break end
                        gx = nextX
                        if gx <= 0 or gx >= GameManager.grid.cols - 1 then break end
                    end
                    if gx ~= oldX then moved = true end
                    b.gridX = gx
                elseif dragDirection == "vertical" and (b.moveAxis == "vertical" or b.moveAxis == "both") then
                    step = (y > dragStart.y) and 1 or -1
                    while true do
                        local nextY = gy + step
                        if not GameManager.canBlockFit(dragStart.idx, gx, nextY) then break end
                        gy = nextY
                        if gy <= 0 or gy >= GameManager.grid.rows - 1 then break end
                    end
                    if gy ~= oldY then moved = true end
                    b.gridY = gy
                end
                -- Track block move as a step
                if moved and StepTracker.active then
                    local idx = dragStart.idx
                    local fromX, fromY = oldX, oldY
                    local toX, toY = b.gridX, b.gridY
                    StepTracker.recordStep({
                        type = "move_block",
                        blockIdx = idx,
                        fromX = fromX, fromY = fromY,
                        toX = toX, toY = toY,
                        apply = function(state)
                            local block = state.blocks[idx]
                            if block then
                                block.gridX = toX
                                block.gridY = toY
                            end
                        end
                    })
                end
            end
        end

        dragStart = { x = 0, y = 0, active = false, idx = nil }
        dragDirection = nil

        if Editor.painting then
            Editor.painting = false
            if Editor.mode == "crusher" then
                -- Do nothing extra for crusher painting
            else
                Editor.mousereleased()
            end
        end
    end
end

function love.draw()
    -- Tracking indicator and step count
    love.graphics.setColor(1, 1, 1, 1)
    local trackingText = StepTracker.active and ("[TRACKING]  Steps: " .. tostring(StepTracker.stepCount or 0)) or "[NOT TRACKING]"
    love.graphics.print(trackingText, 10, 10)
    if lastStepKey ~= "" then
        love.graphics.print("Last Step Key: " .. lastStepKey, 10, 30)
    end
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
            love.graphics.setBlendMode("subtract")
            love.graphics.draw(directionImg, drawX + cellSize/2, drawY + cellSize/2, rot, scale, scale, directionImg:getWidth()/2, directionImg:getHeight()/2)
            love.graphics.setBlendMode("alpha")
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