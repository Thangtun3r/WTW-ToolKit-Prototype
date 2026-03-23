# Quick Reference: Per-Segment Dynamite System

## Visual Editor Example

### Before (painting a 3-block shape):

```
Dynamite Mode: OFF          Dynamite Mode: ON

[  ][  ][  ]               [  ][  ][  ]
[■ ][■ ][■ ]      →        [🧨][🧨][🧨]
[  ][  ][  ]               [  ][  ][  ]

All normal green           All explosive orange
```

### After (mixed explosives):

```
Dynamite Mode: OFF (toggle it)

[  ][  ][  ]
[■ ][🧨][■ ]     ← Middle cube is explosive only!
[  ][  ][  ]

Result: Block with dynamite on CENTER segment only
```

---

## Data Structure

### Old System:
```lua
Block {
  segments = {{x=0, y=1}, {x=1, y=1}, {x=2, y=1}},
  isExplosive = true  -- ALL segments explosive or NONE
}
```

### New System:
```lua
Block {
  segments = {
    {x=0, y=1, isExplosive = false},   -- Normal
    {x=1, y=1, isExplosive = true},    -- Explosive ← Can mix!
    {x=2, y=1, isExplosive = false}    -- Normal
  }
}
```

---

## Controls

| Action | Key/Click |
|--------|-----------|
| Toggle Dynamite Mode | `O` or click DYNAMITE button |
| Paint Normal Cell | Click grid cell with Dynamite OFF |
| Paint Explosive Cell | Click grid cell with Dynamite ON |
| Erase Cell | Click cell again (clears status) |
| View Mode | Dynamite Mode ON: grid shows ORANGE cells as explosive |
| Create Block | Click CREATE OBJECT button |

---

## How It Looks In-Game

### On Placed Blocks:
```
Block on board:

[Green]  [Green]  [Green]
           ↓ dynamite icon here
[Green] [Dynamite] [Green]
```

### When Triggered:
Click a trigger crusher → Block detonates if ANY segment is explosive

---

## Code Locations

| File | Change |
|------|--------|
| **editor.lua** | Line 5: Added `explosiveGrid = {}` |
| **editor.lua** | Line 28: Init both grids in `Editor.load()` |
| **editor.lua** | Line 50-56: Mark segments explosive in mousemoved |
| **editor.lua** | Line 75-82: Mark segments explosive in mousepressed |
| **editor.lua** | Line 165-170: Different color for explosive cells (orange vs green) |
| **editor.lua** | Line 225-229: Return both segments AND explosive metadata |
| **block.lua** | Line 8-12: Store isExplosive on each segment |
| **main.lua** | Line 240: Get both arrays from Editor.getCurrentSegments() |
| **main.lua** | Line 243-244: Pass explosiveSegments to Block.new() |
| **main.lua** | Line 270-278: Check ANY segment for detonation (not block-level) |
| **main.lua** | Line 610-613: Draw dynamite icon per-segment in rendering |

---

## Migration from Old Code

If you have existing code using `block.isExplosive`:

**Old:**
```lua
if block.isExplosive then
  -- do something
end
```

**New:**
```lua
local hasExplosive = false
for _, seg in ipairs(block.segments) do
  if seg.isExplosive then
    hasExplosive = true
    break
  end
end
if hasExplosive then
  -- do something
end
```

---

## Testing Checklist

- [ ] Paint a block with some cells in Dynamite mode, some not
- [ ] Create the block — verify dynamite icon appears only on orange cells
- [ ] Drag the block around — icon should stay with the right cells
- [ ] Undo/Redo — explosive status should persist
- [ ] Trigger crusher with mixed-explosive blocks
- [ ] Save snapshot → revert → check explosives still there
- [ ] Try multi-color blocks with explosives mixed in
