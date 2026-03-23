local Block = {}

function Block.new(gx, gy, segments, color, moveAxis, cellSize)
    return {
        gridX = gx,
        gridY = gy,
        segments = segments, -- List of {x, y}
        color = color,
        moveAxis = moveAxis or "both", -- "horizontal", "vertical", "both"
        viewX = gx * cellSize,
        viewY = gy * cellSize,
        lerpSpeed = 18,
        isCrushed = false
    }
end

function Block.getSegments(b)
    local absolute = {}
    for _, s in ipairs(b.segments) do
        table.insert(absolute, {x = b.gridX + s.x, y = b.gridY + s.y})
    end
    return absolute
end

return Block