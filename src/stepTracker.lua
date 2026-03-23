-- stepTracker.lua
-- Tracks user actions (steps) for undo/redo and state revert

local StepTracker = {}

StepTracker.active = false
StepTracker.steps = {}
StepTracker.redoStack = {}
StepTracker.stateAtStart = nil
StepTracker.stepCount = 0
StepTracker.snapshotState = nil
StepTracker.snapshotStep = 0

function StepTracker.start(currentState)
    StepTracker.active = true
    StepTracker.steps = {}
    StepTracker.redoStack = {}
    StepTracker.stateAtStart = StepTracker.deepCopy(currentState)
    StepTracker.stepCount = 0
    StepTracker.snapshotState = nil
    StepTracker.snapshotStep = 0
end

function StepTracker.stop()
    StepTracker.active = false
    StepTracker.steps = {}
    StepTracker.redoStack = {}
    StepTracker.stateAtStart = nil
    StepTracker.stepCount = 0
    StepTracker.snapshotState = nil
    StepTracker.snapshotStep = 0
end

function StepTracker.undo(currentState)
    if #StepTracker.steps > 0 then
        local step = table.remove(StepTracker.steps)
        table.insert(StepTracker.redoStack, step)
        StepTracker.stepCount = #StepTracker.steps

        if StepTracker.snapshotState and StepTracker.snapshotStep == #StepTracker.steps then
            return StepTracker.deepCopy(StepTracker.snapshotState)
        end

        return StepTracker.replaySteps(StepTracker.stateAtStart, StepTracker.steps)
    end

    if StepTracker.snapshotState then
        return StepTracker.deepCopy(StepTracker.snapshotState)
    end

    if StepTracker.stateAtStart then
        return StepTracker.deepCopy(StepTracker.stateAtStart)
    end

    return currentState
end

function StepTracker.redo(currentState)
    if #StepTracker.redoStack > 0 then
        local step = table.remove(StepTracker.redoStack)
        table.insert(StepTracker.steps, step)
        StepTracker.stepCount = #StepTracker.steps

        if StepTracker.snapshotState and StepTracker.snapshotStep == #StepTracker.steps then
            return StepTracker.deepCopy(StepTracker.snapshotState)
        end

        return StepTracker.replaySteps(StepTracker.stateAtStart, StepTracker.steps)
    end

    return currentState
end

function StepTracker.recordStep(step)
    if StepTracker.active and step then
        table.insert(StepTracker.steps, step)
        StepTracker.stepCount = #StepTracker.steps
        StepTracker.redoStack = {}
    end
end

function StepTracker.saveSnapshot(currentState)
    StepTracker.snapshotState = StepTracker.deepCopy(currentState)
    StepTracker.snapshotStep = #StepTracker.steps
end

function StepTracker.revert()
    if StepTracker.stateAtStart then
        return StepTracker.deepCopy(StepTracker.stateAtStart)
    end
    return nil
end

function StepTracker.revertToSnapshot()
    if StepTracker.snapshotState then
        StepTracker.steps = {}
        StepTracker.redoStack = {}
        StepTracker.stepCount = 0
        StepTracker.stateAtStart = StepTracker.deepCopy(StepTracker.snapshotState)
        StepTracker.snapshotStep = 0
        return StepTracker.deepCopy(StepTracker.snapshotState)
    end
    return nil
end

function StepTracker.replaySteps(baseState, steps)
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
