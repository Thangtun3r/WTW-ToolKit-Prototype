-- stepTracker.lua
-- Tracks user actions (steps) for undo/redo and state revert

local StepTracker = {}

StepTracker.active = false
StepTracker.steps = {}
StepTracker.stateAtStart = nil
StepTracker.stepCount = 0

function StepTracker.start(currentState)
    StepTracker.active = true
StepTracker.redoStack = {}
    StepTracker.steps = {}
    -- Deep copy the state at start
    StepTracker.stateAtStart = StepTracker.deepCopy(currentState)
    StepTracker.stepCount = 0
    StepTracker.redoStack = {}
end

function StepTracker.stop()
    StepTracker.active = false
    StepTracker.steps = {}
    StepTracker.stateAtStart = nil
    StepTracker.stepCount = 0
end
    StepTracker.redoStack = {}

function StepTracker.undo(currentState)
    if #StepTracker.steps > 0 then
        table.remove(StepTracker.steps)
        -- Replay all steps from the initial state
        return StepTracker.replaySteps(StepTracker.stateAtStart, StepTracker.steps)
    end
        table.insert(StepTracker.redoStack, step)
        -- Do not increase stepCount for undo/redo
        StepTracker.stepCount = #StepTracker.steps
    return currentState
end

function StepTracker.recordStep(step)

function StepTracker.redo(currentState)
    if #StepTracker.redoStack > 0 then
        local step = table.remove(StepTracker.redoStack)
        table.insert(StepTracker.steps, step)
        -- Do not increase stepCount for undo/redo
        StepTracker.stepCount = #StepTracker.steps
        return StepTracker.replaySteps(StepTracker.stateAtStart, StepTracker.steps)
    end
    return currentState
end
    if StepTracker.active then
        table.insert(StepTracker.steps, step)
        StepTracker.stepCount = #StepTracker.steps
    end
        StepTracker.redoStack = {} -- Clear redo stack on new action
end

function StepTracker.revert()
    if StepTracker.stateAtStart then
        return StepTracker.deepCopy(StepTracker.stateAtStart)
    end
    return nil
end

function StepTracker.replaySteps(baseState, steps)
    -- Replay all steps from baseState
    local state = StepTracker.deepCopy(baseState)
    for _, step in ipairs(steps) do
        if step.apply then
            step.apply(state)
        elseif step.type == "move_block" then
            local block = state.blocks[step.blockIdx]
            if block then
                block.gridX = step.toX
                block.gridY = step.toY
            end
        end
    end
    return state
end

function StepTracker.deepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = StepTracker.deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

return StepTracker
