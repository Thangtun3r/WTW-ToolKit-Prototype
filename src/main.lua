
local Editor = require("editor")
local GameManager = require("gameManager")
_G.GameManager = GameManager
local Block = require("block")
local Crusher = require("crusher")
local StepTracker = require("stepTracker")

local directionImg = love.graphics.newImage("Direction.png")

local dynamiteImg, triggerImg
pcall(function()
    dynamiteImg = love.graphics.newImage("dynamite.png")
end)
pcall(function()
    triggerImg = love.graphics.newImage("trigger.png")
end)

local function triggerCrusherAt(c)
    -- Only trigger once
    if not c.isTrigger or c.triggered then return false end
    c.triggered = true
    c.isTrigger = false -- disable trigger visual afterward

    local gx, gy = c.gridX, c.gridY
    -- Determine ray direction based on border position
    local dx, dy = 0, 0
    if gx == 0 then dx = 1 elseif gx == GameManager.grid.cols - 1 then dx = -1
    elseif gy == 0 then dy = 1 elseif gy == GameManager.grid.rows - 1 then dy = -1 end

    if dx == 0 and dy == 0 then return false end

    local destroyed = false

    -- No raycast: find first block with dynamite and clear all its dynamite cubes.
    for bi = #GameManager.blocks, 1, -1 do
        local b = GameManager.blocks[bi]
        local hasDynamite = false
        for _, s in ipairs(b.segments) do
            if s.isDynamite then
                hasDynamite = true
                break
            end
        end

        if hasDynamite then
            for si = #b.segments, 1, -1 do
                if b.segments[si].isDynamite then
                    table.remove(b.segments, si)
                    destroyed = true
                end
            end
            if #b.segments == 0 then
                table.remove(GameManager.blocks, bi)
            end
            break -- only one block per trigger click
        end
    end

    if destroyed then
        print("Trigger crusher activated at (" .. gx .. ", " .. gy .. "): destroyed dynamite cubes")
    else
        print("Trigger crusher activated at (" .. gx .. ", " .. gy .. "): no dynamite in path")
    end
end

-- Level save/load helpers
local LevelManager = {
    files = {},
    selectedIndex = 1,
}

local LevelSelectUI = {
    x = 10,
    y = 50,
    w = 400,
    rowHeight = 20,
    maxRows = 8,
    isOpen = false,
    buttonHeight = 26,
    buttonWidth = 420,
    deleteButtonHeight = 26,
    deleteButtonWidth = 100,
}

local function serializeValue(value, indent)
    indent = indent or ""
    local t = type(value)
    if t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "table" then
        local isArray = true
        local maxIndex = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        local parts = {}
        local nextIndent = indent .. "  "
        if isArray then
            for i = 1, maxIndex do
                table.insert(parts, nextIndent .. serializeValue(value[i], nextIndent))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        else
            for k, v in pairs(value) do
                local keypart = (type(k) == "string" and k:match("^%a[%w_]*$") and k or "[" .. serializeValue(k) .. "]")
                table.insert(parts, nextIndent .. keypart .. " = " .. serializeValue(v, nextIndent))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
    else
        return "nil"
    end
end

local function updateWindowTitleWithLevel()
    local selectedFile = "(none)"
    if #LevelManager.files > 0 and LevelManager.selectedIndex >= 1 and LevelManager.selectedIndex <= #LevelManager.files then
        selectedFile = LevelManager.files[LevelManager.selectedIndex]
    end
    love.window.setTitle("Color Bloks 2D - " .. selectedFile)
end

local function refreshLevelFiles()
    local items = love.filesystem.getDirectoryItems("")
    LevelManager.files = {}
    for _, file in ipairs(items) do
        if file:match("^level_.*%.lvl$") then
            table.insert(LevelManager.files, file)
        end
    end
    table.sort(LevelManager.files)
    if #LevelManager.files == 0 then
        LevelManager.selectedIndex = 1
    else
        LevelManager.selectedIndex = math.min(LevelManager.selectedIndex, #LevelManager.files)
    end
    updateWindowTitleWithLevel()
end

local function updateWindowTitleWithLevel()
    local selectedFile = "(none)"
    if #LevelManager.files > 0 and LevelManager.selectedIndex >= 1 and LevelManager.selectedIndex <= #LevelManager.files then
        selectedFile = LevelManager.files[LevelManager.selectedIndex]
    end
    love.window.setTitle("Color Bloks 2D - " .. selectedFile)
end

local function getNextLevelNumber()
    local maxNum = 0
    for _, file in ipairs(LevelManager.files) do
        local num = tonumber(file:match("^level_(%d+)%.lvl$"))
        if num and num > maxNum then
            maxNum = num
        end
    end
    return maxNum + 1
end

local function saveLevelAs(fileName)
    local snapshot = {
        grid = GameManager.grid,
        crushers = GameManager.crushers,
        blocks = GameManager.blocks,
    }
    local content = "return " .. serializeValue(snapshot)
    local ok, err = love.filesystem.write(fileName, content)
    if not ok then
        print("[Save] Failed to save level to " .. fileName .. ": " .. tostring(err))
        return false
    end
    print("[Save] Level saved to " .. fileName)
    refreshLevelFiles()
    return true
end

local function saveLevel()
    refreshLevelFiles()
    local nextNum = getNextLevelNumber()
    local fileName = string.format("level_%d.lvl", nextNum)
    return saveLevelAs(fileName)
end

local function applyLoadedLevel(levelData)
    if not levelData or type(levelData) ~= "table" then
        print("[Load] invalid level data")
        return false
    end
    if levelData.grid then
        GameManager.grid = levelData.grid
    end

    GameManager.crushers = {}
    for _, c in ipairs(levelData.crushers or {}) do
        table.insert(GameManager.crushers, Crusher.new(c.gridX or 0, c.gridY or 0, c.color or {1,1,1}, c.dualColor, c.isTrigger))
    end

    GameManager.blocks = {}
    for _, b in ipairs(levelData.blocks or {}) do
        local block = Block.new(b.gridX or 0, b.gridY or 0, b.segments or {}, b.color or {1,1,1}, b.moveAxis or "both", GameManager.grid.cellSize, b.isStatic)
        block.viewX = (b.viewX or (margin.x + (b.gridX or 0) * GameManager.grid.cellSize))
        block.viewY = (b.viewY or (margin.y + (b.gridY or 0) * GameManager.grid.cellSize))
        table.insert(GameManager.blocks, block)
    end

    print("[Load] Level loaded")
    return true
end

local function loadLevel(fileName)
    if not love.filesystem.getInfo(fileName) then
        print("[Load] level file not found: " .. tostring(fileName))
        return false
    end
    local content, err = love.filesystem.read(fileName)
    if not content then
        print("[Load] can't read level file: " .. tostring(err))
        return false
    end
    local chunk, err2 = loadstring(content)
    if not chunk then
        print("[Load] invalid level file format: " .. tostring(err2))
        return false
    end
    local ok, data = pcall(chunk)
    if not ok then
        print("[Load] error executing level file: " .. tostring(data))
        return false
    end
    return applyLoadedLevel(data)
end

local function selectNextLevel()
    if #LevelManager.files == 0 then
        print("[Load] no saved levels available")
        return
    end
    LevelManager.selectedIndex = LevelManager.selectedIndex % #LevelManager.files + 1
    print("[Load] selected level " .. LevelManager.selectedIndex .. ": " .. LevelManager.files[LevelManager.selectedIndex])
    updateWindowTitleWithLevel()
end

local function loadSelectedLevel()
    if #LevelManager.files == 0 then
        print("[Load] no saved levels available")
        return
    end
    local fileName = LevelManager.files[LevelManager.selectedIndex]
    loadLevel(fileName)
end

local dragStart = { x = 0, y = 0, active = false, idx = nil }
local dragDirection = nil
local dragMode = nil
local margin = { x = 60, y = 60 }
local focusMode = false
local normalWindow = { w = 1000, h = 700 }


function love.load()
    love.window.setMode(1000, 700)
    love.window.setTitle("Color Bloks 2D")
    Editor.load()
    Editor.offsetX = 650

    -- Load saved level list from disk
    refreshLevelFiles()
    updateWindowTitleWithLevel()

    -- Start tracking operations automatically so Ctrl+Z/Ctrl+Y will undo/redo edits directly.
    StepTracker.start({
        blocks = GameManager.blocks,
        crushers = GameManager.crushers,
        editor = Editor,
    })
end




local previousEditorMode = "block"
local pressedColorKeys = {}
local lastStepKey = ""

function love.keypressed(key, scancode, isrepeat)
    -- Track last step key for indicator
    if key == 'f5' then lastStepKey = 'F5 (Start Tracking)' end
    if key == 'f6' then lastStepKey = 'F6 (Revert Snapshot)' end
    if key == 'f7' then lastStepKey = 'F7 (Save Snapshot)' end
    if key == 'f8' then lastStepKey = 'F8 (Save Level)' end
    if key == 'f9' then lastStepKey = 'F9 (Select Next Saved Level)' end
    if key == 'f10' then lastStepKey = 'F10 (Load Selected Level)' end
    if key == 'l' then lastStepKey = 'L (Refresh Level List)' end
    if key == 's' and love.keyboard.isDown('lctrl','rctrl') then lastStepKey = 'Ctrl+S (Save Selected Level)' end
    if key == 'z' and love.keyboard.isDown('lctrl','rctrl') then lastStepKey = 'Ctrl+Z (Undo)' end
    if key == 'y' and love.keyboard.isDown('lctrl','rctrl') then lastStepKey = 'Ctrl+Y (Redo)' end
    -- StepTracker controls
    if key == 'f5' then -- Start tracking
        StepTracker.start({
            blocks = GameManager.blocks,
            crushers = GameManager.crushers,
            editor = Editor,
        })
        print("Step tracking started")
        return
    elseif key == 'f6' then -- Revert to snapshot
        local state = StepTracker.revertToSnapshot() or StepTracker.revert()
        if state then
            GameManager.blocks = StepTracker.deepCopy(state.blocks)
            GameManager.crushers = StepTracker.deepCopy(state.crushers)
            -- Optionally restore editor state if needed
        end
        print("Reverted to saved snapshot")
        return
    elseif key == 'f7' then -- Save snapshot
        StepTracker.saveSnapshot({
            blocks = GameManager.blocks,
            crushers = GameManager.crushers,
            editor = Editor,
        })
        print("Snapshot saved")
        return
    elseif key == 'f8' then -- Save level to file
        saveLevel()
        return
    elseif key == 'f9' then -- Select next saved level file
        selectNextLevel()
        return
    elseif key == 'f10' then -- Load selected saved level file
        loadSelectedLevel()
        return
    elseif key == 'f12' then -- Focus mode toggle
        focusMode = not focusMode
        if focusMode then
            LevelSelectUI.isOpen = false
            local gw = GameManager.grid.cols * GameManager.grid.cellSize + margin.x * 2
            local gh = GameManager.grid.rows * GameManager.grid.cellSize + margin.y * 2
            love.window.setMode(gw, gh)
        else
            love.window.setMode(normalWindow.w, normalWindow.h)
        end
        print("Focus mode: " .. tostring(focusMode))
        return
    elseif key == 'l' then -- Refresh saved level list
        refreshLevelFiles()
        print("[Load] available saved levels:")
        for i, fileName in ipairs(LevelManager.files) do
            local selected = (i == LevelManager.selectedIndex) and "*" or " "
            print(string.format("%s %d. %s", selected, i, fileName))
        end
        return
    elseif key == 's' and love.keyboard.isDown('lctrl','rctrl') then -- Save selected level (or new)
        local selectedName = LevelManager.files[LevelManager.selectedIndex]
        if selectedName then
            saveLevelAs(selectedName)
        else
            saveLevel()
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
    elseif key == 'y' and love.keyboard.isDown('lctrl','rctrl') then -- Redo
        if StepTracker.active then
            local state = StepTracker.redo({
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
    -- Toggle explosion / dynamite paint mode
    if key == 'o' then
        Editor.explosionMode = not Editor.explosionMode
        print("Explosion mode: " .. tostring(Editor.explosionMode))
        return
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
        -- If holding a block, update its color to the new selection
        if Editor.isPlacing and Editor.heldBlock then
            Editor.heldBlock.color = Editor.getSelectedColor()
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
    -- 0. Saved-level dropdown
    if focusMode then
        LevelSelectUI.isOpen = false
    else
        local renderX = love.graphics.getWidth() - LevelSelectUI.buttonWidth - 10
        local renderY = love.graphics.getHeight() - 140
        local buttonX1, buttonY1 = renderX, renderY
        local buttonX2, buttonY2 = renderX + LevelSelectUI.buttonWidth, renderY + LevelSelectUI.buttonHeight

        if button == 1 and x >= buttonX1 and x <= buttonX2 and y >= buttonY1 and y <= buttonY2 then
            LevelSelectUI.isOpen = not LevelSelectUI.isOpen
            return
        end

        if LevelSelectUI.isOpen then
            local rows = math.min(#LevelManager.files, LevelSelectUI.maxRows)
            local listTop = renderY + LevelSelectUI.buttonHeight
            local listBottom = listTop + rows * LevelSelectUI.rowHeight

        if button == 1 and x >= renderX and x <= renderX + LevelSelectUI.buttonWidth and y >= listTop and y <= listBottom then
            local clickedRow = math.floor((y - listTop) / LevelSelectUI.rowHeight) + 1
            if clickedRow >= 1 and clickedRow <= #LevelManager.files then
                LevelManager.selectedIndex = clickedRow
                updateWindowTitleWithLevel()
                print("[Load] selected level " .. clickedRow .. ": " .. LevelManager.files[clickedRow])
            end
            LevelSelectUI.isOpen = false
            return
        end

        -- right click delete is disabled in level dropdown; use Delete button
        -- (keep this block removed to avoid accidental delete via right mouse button)


        if button == 1 then
            local deleteX = renderX + LevelSelectUI.buttonWidth - LevelSelectUI.deleteButtonWidth - 8
            local deleteY = renderY + LevelSelectUI.buttonHeight + (math.min(#LevelManager.files, LevelSelectUI.maxRows) * LevelSelectUI.rowHeight) + 8
            if x >= deleteX and x <= deleteX + LevelSelectUI.deleteButtonWidth and y >= deleteY and y <= deleteY + LevelSelectUI.deleteButtonHeight then
                if #LevelManager.files > 0 then
                    local fileToDelete = LevelManager.files[LevelManager.selectedIndex]
                    if love.filesystem.getInfo(fileToDelete) then
                        love.filesystem.remove(fileToDelete)
                    end
                    table.remove(LevelManager.files, LevelManager.selectedIndex)
                    if LevelManager.selectedIndex > #LevelManager.files then
                        LevelManager.selectedIndex = math.max(1, #LevelManager.files)
                    end
                    if #LevelManager.files == 0 then
                        LevelManager.selectedIndex = 1
                    end
                    updateWindowTitleWithLevel()
                    print("[Load] deleted selected level " .. tostring(fileToDelete))
                end
                LevelSelectUI.isOpen = false
                return
            end
        end

        -- Click outside to close
        if button == 1 and not (x >= renderX and x <= renderX + LevelSelectUI.buttonWidth and y >= renderY and y <= listBottom + LevelSelectUI.deleteButtonHeight + 8) then
            LevelSelectUI.isOpen = false
            -- continue to game UI interactions
        end
    end
    end

    -- 1. UI CHECK: Check if clicking the Sidebar Editor area
    if button == 1 and x > Editor.offsetX - 20 then
        local result = Editor.mousepressed(x, y)
        if result == "create" then
            local segs = Editor.getCurrentSegments()
            if #segs > 0 then
                Editor.isPlacing = true
                local isStatic = (Editor.selectedAxis == "static")
                Editor.heldBlock = {
                    segments = segs,
                    gridX = 0, gridY = 0,
                    viewX = 0, viewY = 0,
                    color = isStatic and {1,1,1} or Editor.getSelectedColor(),
                    moveAxis = isStatic and "none" or Editor.selectedAxis,
                    isStatic = isStatic
                }
            end
        end
        Editor.painting = true
        return
    end

    -- Convert screen coordinates to Grid coordinates
    local gx = math.floor((x - margin.x) / GameManager.grid.cellSize)
    local gy = math.floor((y - margin.y) / GameManager.grid.cellSize)

    -- Right mouse button (2) for erasing blocks and crushers
    if button == 2 then
        -- Do NOT set Editor.painting for right click
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

        -- 2.5. Trigger existing crusher if clicked (only triggers if isTrigger=true and not already triggered)
        for _, c in ipairs(GameManager.crushers) do
            if c.gridX == gx and c.gridY == gy and c.isTrigger and not c.triggered then
                triggerCrusherAt(c)
                return
            end
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
                        local isTrigger = Editor.explosionMode
                        StepTracker.recordStep({
                            type = "add_crusher",
                            gx = gx, gy = gy, color1 = color1, color2 = color2, isTrigger = isTrigger,
                            apply = function(state)
                                if color2 then
                                    table.insert(state.crushers, Crusher.new(gx, gy, Editor.palette[color1], Editor.palette[color2], isTrigger))
                                else
                                    table.insert(state.crushers, Crusher.new(gx, gy, Editor.palette[color1], nil, isTrigger))
                                end
                            end
                        })
                    end
                    local isTrigger = Editor.explosionMode
                    if #Editor.selectedColors == 1 then
                        table.insert(GameManager.crushers, Crusher.new(gx, gy, Editor.palette[Editor.selectedColors[1]], nil, isTrigger))
                    elseif #Editor.selectedColors >= 2 then
                        table.insert(GameManager.crushers, Crusher.new(gx, gy, Editor.palette[Editor.selectedColors[1]], Editor.palette[Editor.selectedColors[2]], isTrigger))
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
                        gx = gx, gy = gy, segments = b.segments, color = b.color, moveAxis = b.moveAxis, isStatic = b.isStatic,
                        apply = function(state)
                            local block = Block.new(gx, gy, b.segments, b.color, b.moveAxis, GameManager.grid.cellSize, b.isStatic)
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
            if not b.isStatic then
                for _, s in ipairs(b.segments) do
                    local sx = margin.x + (b.gridX + s.x) * GameManager.grid.cellSize
                    local sy = margin.y + (b.gridY + s.y) * GameManager.grid.cellSize
                    if x >= sx and x <= sx + GameManager.grid.cellSize and 
                       y >= sy and y <= sy + GameManager.grid.cellSize then
                        dragStart = {x = x, y = y, active = true, idx = i, startGridX = b.gridX, startGridY = b.gridY, pressTime = love.timer.getTime()}
                        dragMode = "undetermined"
                        dragDirection = nil
                        return
                    end
                end
            end
        end
    end
function love.mousemoved(x, y, dx, dy)
    -- Paint erase while dragging with right mouse button (button 2), even if not in painting mode
    if love.mouse.isDown(2) then
        local gx = math.floor((x - margin.x) / GameManager.grid.cellSize)
        local gy = math.floor((y - margin.y) / GameManager.grid.cellSize)
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
                break
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
                    break
                end
            end
        end
        return
    end
    if Editor.painting then
        if Editor.mode == "crusher" then
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

    if dragStart.active and dragStart.idx then
        local diffX = math.abs(x - dragStart.x)
        local diffY = math.abs(y - dragStart.y)
        local elapsed = love.timer.getTime() - (dragStart.pressTime or 0)

        if dragMode == "undetermined" and (diffX > 10 or diffY > 10) then
            if elapsed >= 0.15 then
                dragMode = "free"
            else
                dragMode = "slide"
            end
        end

        if dragMode == "free" then
            local b = GameManager.blocks[dragStart.idx]
            if b then
                local mouseGridX = math.floor((x - margin.x) / GameManager.grid.cellSize)
                local mouseGridY = math.floor((y - margin.y) / GameManager.grid.cellSize)
                -- Keep inside bounds
                mouseGridX = math.max(0, math.min(GameManager.grid.cols - 1, mouseGridX))
                mouseGridY = math.max(0, math.min(GameManager.grid.rows - 1, mouseGridY))
                -- Optional collision check:
                if GameManager.canBlockFit(dragStart.idx, mouseGridX, mouseGridY) then
                    b.gridX = mouseGridX
                    b.gridY = mouseGridY
                end
            end
            return
        end

        if dragMode ~= "free" and not dragDirection then
            if diffX > 10 or diffY > 10 then
                if diffX > diffY then
                    dragDirection = "horizontal"
                else
                    dragDirection = "vertical"
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        if dragStart.active and dragStart.idx then
            local b = GameManager.blocks[dragStart.idx]
            if b then
                local oldX, oldY = dragStart.startGridX, dragStart.startGridY
                local toX, toY = b.gridX, b.gridY
                local moved = (toX ~= oldX or toY ~= oldY)

                if dragMode ~= "free" and dragDirection and b then
                    local gx, gy = b.gridX, b.gridY
                    local step = 0
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
                    toX, toY = b.gridX, b.gridY
                end

                -- Track block move as a step
                if moved and StepTracker.active then
                    local idx = dragStart.idx
                    StepTracker.recordStep({
                        type = "move_block",
                        blockIdx = idx,
                        fromX = oldX, fromY = oldY,
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
        dragMode = nil
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
    -- Tracking indicator and step count with color
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    if not focusMode then
        if StepTracker.active then
            love.graphics.setColor(0, 1, 0, 1) -- Green for tracking
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for not tracking
        end
        local trackingText = StepTracker.active and ("[TRACKING]  Steps: " .. tostring(StepTracker.stepCount or 0)) or "[NOT TRACKING]"
        love.graphics.print(trackingText, 10, 10)
        love.graphics.setColor(1, 1, 1, 1)
        if lastStepKey ~= "" then
            love.graphics.print("Last Step Key: " .. lastStepKey, 10, 30)
        end

        -- Shortcut help HUD in bottom-right
        local helpY = winH - 60
        love.graphics.printf("F5: Start Tracking  F6: Revert Snapshot  F7: Save Snapshot", 0, helpY, winW - 10, "right")
        love.graphics.printf("F8: Save Level  F9: Next Level  F10: Load Level  F12: Toggle Focus", 0, helpY + 18, winW - 10, "right")
        love.graphics.printf("Ctrl+S: Save Selected  Ctrl+Z: Undo  Ctrl+Y: Redo", 0, helpY + 36, winW - 10, "right")
    else
        -- focus mode: minimal display (no dropdown/UI)
        -- just keep grid+blocks drawing below
        love.graphics.setColor(1, 1, 1, 1)
        -- optionally could draw a small subtitle for mode but requirement says hide
        -- love.graphics.printf("[FOCUS MODE]", 10, 10, winW - 20, "left")
    end

    -- drop the old footer "Selected Level" text to reduce left-corner clutter

    if focusMode then
        -- hide level dropdown UI in focus mode
        LevelSelectUI.isOpen = false
    else
        -- Saved Level dropdown-style menu only in normal mode
        LevelSelectUI.x = winW - LevelSelectUI.buttonWidth - 10
        LevelSelectUI.y = winH - 140

        -- Button line
        local selectedFile = (#LevelManager.files > 0) and (LevelManager.files[LevelManager.selectedIndex] or "(none)") or "(none)"
        love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
        love.graphics.rectangle("fill", LevelSelectUI.x, LevelSelectUI.y, LevelSelectUI.buttonWidth, LevelSelectUI.buttonHeight)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", LevelSelectUI.x, LevelSelectUI.y, LevelSelectUI.buttonWidth, LevelSelectUI.buttonHeight)
        love.graphics.print("Level: " .. selectedFile, LevelSelectUI.x + 8, LevelSelectUI.y + 6)
        love.graphics.print(LevelSelectUI.isOpen and "▲" or "▼", LevelSelectUI.x + LevelSelectUI.buttonWidth - 20, LevelSelectUI.y + 6)

        -- Dropdown entries
        if LevelSelectUI.isOpen then
            local rows = math.min(#LevelManager.files, LevelSelectUI.maxRows)
            local totalH = (rows * LevelSelectUI.rowHeight)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", LevelSelectUI.x, LevelSelectUI.y + LevelSelectUI.buttonHeight, LevelSelectUI.buttonWidth, totalH)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", LevelSelectUI.x, LevelSelectUI.y + LevelSelectUI.buttonHeight, LevelSelectUI.buttonWidth, totalH)

            for i = 1, rows do
                local fileName = LevelManager.files[i]
                local cellY = LevelSelectUI.y + LevelSelectUI.buttonHeight + (i - 1) * LevelSelectUI.rowHeight
                if i == LevelManager.selectedIndex then
                    love.graphics.setColor(0.9, 0.9, 0.2)
                else
                    love.graphics.setColor(1, 1, 1)
                end
                love.graphics.print(string.format("%d. %s", i, fileName), LevelSelectUI.x + 8, cellY + 2)
            end

            if #LevelManager.files == 0 then
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("No saved levels yet (press F8)", LevelSelectUI.x + 8, LevelSelectUI.y + LevelSelectUI.buttonHeight + 2)
            else
                local deleteX = LevelSelectUI.x + LevelSelectUI.buttonWidth - LevelSelectUI.deleteButtonWidth - 8
                local deleteY = LevelSelectUI.y + LevelSelectUI.buttonHeight + totalH + 8
                love.graphics.setColor(0.65, 0.15, 0.15, 0.9)
                love.graphics.rectangle("fill", deleteX, deleteY, LevelSelectUI.deleteButtonWidth, LevelSelectUI.deleteButtonHeight)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", deleteX, deleteY, LevelSelectUI.deleteButtonWidth, LevelSelectUI.deleteButtonHeight)
                love.graphics.print("Delete", deleteX + 12, deleteY + 6)
            end
        end
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
    for _, c in ipairs(GameManager.crushers) do
        Crusher.draw(c, cellSize)
        if c.isTrigger then
            local cx = c.gridX * cellSize
            local cy = c.gridY * cellSize
            if triggerImg then
                local scale = (cellSize * 0.55) / math.max(triggerImg:getWidth(), triggerImg:getHeight())
                local shadowScale = scale * 1.15
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.draw(triggerImg, cx + cellSize/2, cy + cellSize/2 + 1, 0, shadowScale, shadowScale, triggerImg:getWidth()/2, triggerImg:getHeight()/2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(triggerImg, cx + cellSize/2, cy + cellSize/2, 0, scale, scale, triggerImg:getWidth()/2, triggerImg:getHeight()/2)
            else
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", cx + 2, cy + 2, cellSize - 4, cellSize - 4)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 0.4, 0.4, 0.85)
                love.graphics.circle("fill", cx + cellSize/2, cy + cellSize/2, cellSize*0.2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf("T", cx, cy + cellSize*0.35, cellSize, "center")
            end
        end
    end
    love.graphics.pop()

    for _, b in ipairs(GameManager.blocks) do
        local alpha = b.isStatic and 0.8 or 1
        love.graphics.setColor(b.color[1], b.color[2], b.color[3], alpha)
        for _, s in ipairs(b.segments) do
            local drawX, drawY = b.viewX + s.x * cellSize, b.viewY + s.y * cellSize
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], alpha)
            love.graphics.rectangle("fill", drawX + 4, drawY + 4, cellSize - 8, cellSize - 8)
            if s.isDynamite then
                if dynamiteImg then
                    local scale = (cellSize * 0.55) / math.max(dynamiteImg:getWidth(), dynamiteImg:getHeight())
                    local shadowScale = scale * 1.15
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(dynamiteImg, drawX + cellSize/2, drawY + cellSize/2 + 1, 0, shadowScale, shadowScale, dynamiteImg:getWidth()/2, dynamiteImg:getHeight()/2)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(dynamiteImg, drawX + cellSize/2, drawY + cellSize/2, 0, scale, scale, dynamiteImg:getWidth()/2, dynamiteImg:getHeight()/2)
                else
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", drawX + 1, drawY + 1, cellSize - 2, cellSize - 2)
                    love.graphics.setLineWidth(1)
                    love.graphics.setColor(1, 0.4, 0, 1)
                    love.graphics.rectangle("fill", drawX + cellSize*0.25, drawY + cellSize*0.25, cellSize*0.5, cellSize*0.5)
                    love.graphics.setColor(1,1,1,1)
                    love.graphics.printf("D", drawX, drawY + cellSize*0.3, cellSize, "center")
                end
            end
            if b.isStatic then
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.setLineWidth(2)
                love.graphics.line(drawX + 6, drawY + 6, drawX + cellSize - 6, drawY + cellSize - 6)
                love.graphics.line(drawX + 6, drawY + cellSize - 6, drawX + cellSize - 6, drawY + 6)
                love.graphics.setLineWidth(1)
            end
        end

        if not b.isStatic and #b.segments > 0 then
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