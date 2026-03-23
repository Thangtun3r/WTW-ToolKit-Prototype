local Editor = {
    drawGrid = {},
    active = true,
    cellSize = 40,
    offsetX = 650,
    offsetY = 20,
    selectedAxis = "vertical",
    mode = "block",
    palette = {
        {1, 0.3, 0.3}, {0.3, 1, 0.3}, {0.3, 0.6, 1}, 
        {1, 1, 0.3}, {1, 0.3, 1}, {0.3, 1, 1}
    },
    selectedColors = {1},
    isPlacing = false,
    heldBlock = nil,
    painting = false,
    paintMode = true, -- true = draw, false = erase
    directionOptions = {"horizontal", "vertical", "static"},
    selectedDirectionIdx = 2,
    directionDropdownOpen = false,
    eraserMode = false,
    uiY = 20,
    hitboxes = {} 
}

function Editor.load()
    for x = 0, 2 do
        Editor.drawGrid[x] = {}
        for y = 0, 2 do Editor.drawGrid[x][y] = false end
    end
end

function Editor.mousemoved(x, y)
    if not Editor.painting then return end
    local hb = Editor.hitboxes.grid
    if hb and x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
        local gx = math.floor((x - hb.x) / Editor.cellSize)
        local gy = math.floor((y - hb.y) / Editor.cellSize)
        if gx >= 0 and gx <= 2 and gy >= 0 and gy <= 2 then
            Editor.drawGrid[gx][gy] = Editor.paintMode -- Follow the mode set on first click
        end
    end
end

function Editor.mousepressed(x, y)
    -- 1. Grid Interaction (Painting)
    local hb = Editor.hitboxes.grid
    if hb and x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
        local gx = math.floor((x - hb.x) / Editor.cellSize)
        local gy = math.floor((y - hb.y) / Editor.cellSize)
        
        Editor.paintMode = not Editor.drawGrid[gx][gy] -- If clicking empty, draw. If clicking filled, erase.
        Editor.drawGrid[gx][gy] = Editor.paintMode
        Editor.painting = true
        return true
    end

    -- 2. Dropdown
    local dd = Editor.hitboxes.dropdown
    if dd and x >= dd.x and x <= dd.x + dd.w and y >= dd.y and y <= dd.y + dd.h then
        Editor.directionDropdownOpen = not Editor.directionDropdownOpen
        return true
    end

    -- 3. Dropdown Options
    if Editor.directionDropdownOpen and Editor.hitboxes.options then
        for i, optHb in ipairs(Editor.hitboxes.options) do
            if x >= optHb.x and x <= optHb.x + optHb.w and y >= optHb.y and y <= optHb.y + optHb.h then
                Editor.selectedDirectionIdx = i
                Editor.selectedAxis = Editor.directionOptions[i]
                Editor.directionDropdownOpen = false
                return true
            end
        end
    end

    -- 4. Palette
    if Editor.hitboxes.palette then
        for i, phb in ipairs(Editor.hitboxes.palette) do
            if x >= phb.x and x <= phb.x + phb.w and y >= phb.y and y <= phb.y + phb.h then
                local found = false
                for j, selIdx in ipairs(Editor.selectedColors) do
                    if selIdx == i then table.remove(Editor.selectedColors, j) found = true break end
                end
                if not found then table.insert(Editor.selectedColors, i) end
                if #Editor.selectedColors == 0 then Editor.selectedColors = {i} end
                return true
            end
        end
    end

    -- 5. Modes
    local mb = Editor.hitboxes.modes
    if mb and y >= mb.y and y <= mb.y + mb.h then
        if x >= mb.x and x <= mb.x + 80 then
            Editor.mode = "block"; Editor.eraserMode = false; return true
        elseif x >= mb.x + 90 and x <= mb.x + 170 then
            Editor.mode = "crusher"; Editor.eraserMode = false; return true
        end
    end

    -- 6. Eraser
    local er = Editor.hitboxes.eraser
    if er and x >= er.x and x <= er.x + er.w and y >= er.y and y <= er.y + er.h then
        Editor.eraserMode = not Editor.eraserMode
        return true
    end

    -- 7. Create Button
    local cb = Editor.hitboxes.create
    if cb and x >= cb.x and x <= cb.x + cb.w and y >= cb.y and y <= cb.y + cb.h then
        return "create"
    end

    return false
end

function Editor.mousereleased()
    Editor.painting = false
end

function Editor.draw()
    if not Editor.active then return end
    local currentY = Editor.uiY
    local spacing = 25
    Editor.hitboxes = {}

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("EDITOR PANEL", Editor.offsetX, currentY)
    currentY = currentY + spacing

    -- 3x3 Grid
    Editor.hitboxes.grid = {x = Editor.offsetX, y = currentY, w = Editor.cellSize * 3, h = Editor.cellSize * 3}
    for gx = 0, 2 do
        for gy = 0, 2 do
            local bx = Editor.offsetX + (gx * Editor.cellSize)
            local by = currentY + (gy * Editor.cellSize)
            love.graphics.setColor(Editor.drawGrid[gx][gy] and {0.4, 1, 0.4} or {0.2, 0.2, 0.2})
            love.graphics.rectangle("fill", bx, by, Editor.cellSize-2, Editor.cellSize-2)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", bx, by, Editor.cellSize-2, Editor.cellSize-2)
        end
    end
    currentY = currentY + (Editor.cellSize * 3) + spacing

    -- Direction
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Direction:", Editor.offsetX, currentY)
    currentY = currentY + 20
    Editor.hitboxes.dropdown = {x = Editor.offsetX, y = currentY, w = 140, h = 30}
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", Editor.offsetX, currentY, 140, 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(Editor.directionOptions[Editor.selectedDirectionIdx], Editor.offsetX + 10, currentY + 8)
    local dropdownAnchorY = currentY
    currentY = currentY + 30 + spacing

    -- Palette
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Palette:", Editor.offsetX, currentY)
    currentY = currentY + 20
    Editor.hitboxes.palette = {}
    for i, color in ipairs(Editor.palette) do
        local px = Editor.offsetX + (i-1) * 35
        Editor.hitboxes.palette[i] = {x = px, y = currentY, w = 30, h = 30}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", px, currentY, 30, 30)
        for _, selIdx in ipairs(Editor.selectedColors) do
            if selIdx == i then
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", px-2, currentY-2, 34, 34)
            end
        end
    end
    currentY = currentY + 35 + spacing

    -- Modes
    Editor.hitboxes.modes = {x = Editor.offsetX, y = currentY, w = 260, h = 30}
    love.graphics.setColor(Editor.mode == "block" and {0.2, 0.8, 0.2} or {0.4, 0.4, 0.4})
    love.graphics.rectangle("fill", Editor.offsetX, currentY, 80, 30)
    love.graphics.setColor(Editor.mode == "crusher" and {0.8, 0.2, 0.2} or {0.4, 0.4, 0.4})
    love.graphics.rectangle("fill", Editor.offsetX + 90, currentY, 80, 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("BLOCK", Editor.offsetX + 15, currentY + 8)
    love.graphics.print("CRUSHER", Editor.offsetX + 100, currentY + 8)
    currentY = currentY + 30 + spacing

    -- Eraser
    Editor.hitboxes.eraser = {x = Editor.offsetX, y = currentY, w = 170, h = 30}
    love.graphics.setColor(Editor.eraserMode and {1, 1, 0} or {0.4, 0.4, 0.4})
    love.graphics.rectangle("fill", Editor.offsetX, currentY, 170, 30)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("ERASER: " .. (Editor.eraserMode and "ON" or "OFF"), Editor.offsetX + 40, currentY + 8)
    currentY = currentY + 30 + spacing

    -- Create Button
    Editor.hitboxes.create = {x = Editor.offsetX, y = currentY, w = 170, h = 40}
    love.graphics.setColor(0.2, 0.5, 1)
    love.graphics.rectangle("fill", Editor.offsetX, currentY, 170, 40)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("CREATE OBJECT", Editor.offsetX + 35, currentY + 12)

    -- Dropdown Overlay
    if Editor.directionDropdownOpen then
        Editor.hitboxes.options = {}
        for i, opt in ipairs(Editor.directionOptions) do
            local oy = dropdownAnchorY + (i * 30)
            Editor.hitboxes.options[i] = {x = Editor.offsetX, y = oy, w = 140, h = 30}
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", Editor.offsetX, oy, 140, 30)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", Editor.offsetX, oy, 140, 30)
            love.graphics.print(opt, Editor.offsetX + 10, oy + 8)
        end
    end
end

function Editor.getCurrentSegments()
    local segments = {}
    for x = 0, 2 do
        for y = 0, 2 do
            if Editor.drawGrid[x][y] then table.insert(segments, {x = x, y = y}) end
        end
    end
    return segments
end

function Editor.getSelectedColor()
    return Editor.palette[Editor.selectedColors[1]] or Editor.palette[1]
end

return Editor