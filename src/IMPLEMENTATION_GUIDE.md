# Dynamite System Implementation - Per-Segment Explosives

## Overview
Changed the dynamite/explosive system from a **block-wide boolean flag** to **per-segment marking**, so individual cubes within a multi-segment block can be marked as explosive, not the entire block.

---

## Key Changes

### 1. **Editor.lua** - Separate Grid Tracking
```lua
explosiveGrid = {}  -- NEW: Tracks which cells in the 3x3 editor grid are explosive
```

**Behavior:**
- When **Dynamite Mode is ON** and you paint a cell green in the editor, it becomes **ORANGE** (indicating explosive)
- When **Dynamite Mode is OFF**, painted cells are green (normal)
- When erasing, the explosive status is cleared too
- You can now mix explosive and non-explosive cells in the same block!

**Visual Feedback:**
- Orange cells in editor = explosive segments
- Green cells in editor = normal segments

**Updated function:**
```lua
function Editor.getCurrentSegments()
    local segments = {}
    local explosiveSegments = {}  -- Returns BOTH segments AND which are explosive
    -- ... returns segments, explosiveSegments
end
```

---

### 2. **Block.lua** - Segment-Level Properties
Changed from:
```lua
isExplosive = isExplosive or false  -- Single boolean for whole block
```

To:
```lua
local segmentsWithExplosive = {}
for i, seg in ipairs(segments) do
    segmentsWithExplosive[i] = {
        x = seg.x,
        y = seg.y,
        isExplosive = explosiveSegments and explosiveSegments[i] or false
    }
end
```

**Each segment now has its own `isExplosive` flag.**

---

### 3. **Main.lua** - Rendering & Trigger Logic

#### Drawing:
```lua
if s.isExplosive then
    -- Draw dynamite icon ONLY on explosive segments
    love.graphics.draw(dynamiteImg, ...)
end
```
Now the dynamite icon appears only on the specific cubes you marked as explosive.

#### Trigger Detonation:
```lua
local hasExplosive = false
for _, seg in ipairs(b.segments) do
    if seg.isExplosive then
        hasExplosive = true
        break
    end
end
if hasExplosive then
    -- Block can be detonated
end
```

A block is detonated if **ANY** of its segments are explosive.

---

## Workflow

### Creating a Multi-Segment Block with Mixed Explosives:

1. **Toggle Dynamite Mode** (Press `O` or click the DYNAMITE button)
   - Dynamite Mode ON (button turns orange)

2. **Paint in the Editor Grid**
   - Paint cell (0,0) → Green (normal)
   - Paint cell (1,0) → Orange (explosive!) because Dynamite Mode is ON
   - Paint cell (2,0) → Orange (explosive!)
   - Toggle Dynamite OFF
   - Paint cell (1,1) → Green (normal)

3. **Click CREATE OBJECT**
   - Editor grid shows your mixed block design

4. **Place on Board**
   - Block appears with dynamite icons ONLY on the orange cells from step 2

5. **Trigger with Crusher**
   - Click a trigger crusher
   - Block detonates because it has explosive segments

---

## File Comparison

| Aspect | Old System | New System |
|--------|-----------|-----------|
| **Explosive Flag** | `block.isExplosive` (boolean) | `segment.isExplosive` (per-segment) |
| **Editor Tracking** | None (only toggle mode) | `Editor.explosiveGrid[x][y]` |
| **Visual** | Icon on all segments if block explosive | Icon only on explosive segments |
| **Trigger Logic** | Check block.isExplosive | Check if ANY segment is explosive |

---

## Important Notes

- **Eraser clears both** normal and explosive flags
- **One-shot mode is removed** — the old system would auto-toggle Dynamite OFF after placement. Now you control when it's on/off.
- **Backwards compatible segment structure** — all blocks still have segments; explosives just have an additional property
- **Undo/Redo tracks** explosive segments per block properly

---

## Testing

1. Paint a 2x2 block with mixed colors and explosives
2. Verify dynamite icons appear only where expected
3. Use trigger crusher to detonate
4. Undo and check explosives restored correctly
5. Try multi-color + explosive combinations
