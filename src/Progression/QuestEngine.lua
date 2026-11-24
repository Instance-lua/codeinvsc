local QuestEngine = {}
QuestEngine.__index = QuestEngine

local function CopyObjectives(Objectives)
    local Result = {}

    for _, Objective in ipairs(Objectives) do
        assert(type(Objective.Id) == "string" and Objective.Id ~= "", "Objective id is required")
        assert(type(Objective.Target) == "number" and Objective.Target > 0, "Objective target must be positive")

        Result[Objective.Id] = {
            Type = Objective.Type,
            Target = Objective.Target,
            Progress = 0,
            Metadata = table.clone(Objective.Metadata or {})
        }
    end

    return Result
end

local function IsComplete(State)
    for _, Objective in pairs(State.Objectives) do
        if Objective.Progress < Objective.Target then
            return false
        end
    end

    return true
end

function QuestEngine.new(Definitions)
    assert(type(Definitions) == "table", "Quest definitions are required")

    local Indexed = {}

    for _, Definition in ipairs(Definitions) do
        assert(type(Definition.Id) == "string" and Definition.Id ~= "", "Quest id is required")
        assert(not Indexed[Definition.Id], "Quest ids must be unique")
        assert(type(Definition.Objectives) == "table" and #Definition.Objectives > 0, "Quest objectives are required")

        Indexed[Definition.Id] = {
            Id = Definition.Id,
            Prerequisites = table.clone(Definition.Prerequisites or {}),
            Objectives = CopyObjectives(Definition.Objectives),
            Rewards = table.clone(Definition.Rewards or {}),
            Repeatable = Definition.Repeatable == true
        }
    end

    return setmetatable({
        Definitions = Indexed,
        States = {},
        Completed = {},
        Revision = 0
    }, QuestEngine)
end

function QuestEngine:CanStart(QuestId)
    local Definition = self.Definitions[QuestId]

    if not Definition then
        return false, "UnknownQuest"
    end

    if self.States[QuestId] then
        return false, "AlreadyActive"
    end

    if self.Completed[QuestId] and not Definition.Repeatable then
        return false, "AlreadyCompleted"
    end

    for _, Prerequisite in ipairs(Definition.Prerequisites) do
        if not self.Completed[Prerequisite] then
            return false, "MissingPrerequisite:" .. Prerequisite
        end
    end

    return true
end

function QuestEngine:Start(QuestId)
    local CanStart, Reason = self:CanStart(QuestId)

    if not CanStart then
        return false, Reason
    end

    local Definition = self.Definitions[QuestId]

    self.States[QuestId] = {
        Status = "Active",
        Objectives = CopyObjectives((function()
            local Result = {}

            for Id, Objective in pairs(Definition.Objectives) do
                table.insert(Result, {
                    Id = Id,
                    Type = Objective.Type,
                    Target = Objective.Target,
                    Metadata = Objective.Metadata
                })
            end

            return Result
        end)()),
        StartedAt = os.time(),
        Revision = self.Revision + 1
    }

    self.Revision += 1

    return true, self:GetState(QuestId)
end

function QuestEngine:ApplyEvent(EventType, Amount, Metadata)
    assert(type(EventType) == "string", "Event type is required")

    Amount = math.max(0, Amount or 1)
    Metadata = Metadata or {}

    local Changed = {}

    for QuestId, State in pairs(self.States) do
        if State.Status == "Active" then
            for ObjectiveId, Objective in pairs(State.Objectives) do
                if Objective.Type == EventType and Objective.Progress < Objective.Target then
                    local Matches = true

                    for Key, Expected in pairs(Objective.Metadata) do
                        if Metadata[Key] ~= Expected then
                            Matches = false
                            break
                        end
                    end

                    if Matches then
                        Objective.Progress = math.min(
                            Objective.Target,
                            Objective.Progress + Amount
                        )

                        table.insert(Changed, {
                            QuestId = QuestId,
                            ObjectiveId = ObjectiveId,
                            Progress = Objective.Progress,
                            Target = Objective.Target
                        })
                    end
                end
            end

            if IsComplete(State) then
                State.Status = "ReadyToClaim"
                State.CompletedAt = os.time()
            end
        end
    end

    if #Changed > 0 then
        self.Revision += 1
    end

    return Changed
end

function QuestEngine:Claim(QuestId)
    local State = self.States[QuestId]
    local Definition = self.Definitions[QuestId]

    if not State or not Definition then
        return false, "UnknownQuest"
    end

    if State.Status ~= "ReadyToClaim" then
        return false, "NotReady"
    end

    State.Status = "Claimed"
    self.Completed[QuestId] = true
    self.States[QuestId] = nil
    self.Revision += 1

    return true, table.clone(Definition.Rewards)
end

function QuestEngine:GetState(QuestId)
    local State = self.States[QuestId]

    if not State then
        return nil
    end

    local Objectives = {}

    for Id, Objective in pairs(State.Objectives) do
        Objectives[Id] = {
            Type = Objective.Type,
            Progress = Objective.Progress,
            Target = Objective.Target
        }
    end

    return {
        Status = State.Status,
        Objectives = Objectives,
        StartedAt = State.StartedAt,
        CompletedAt = State.CompletedAt,
        Revision = State.Revision
    }
end

function QuestEngine:Serialize()
    local States = {}

    for QuestId in pairs(self.States) do
        States[QuestId] = self:GetState(QuestId)
    end

    return {
        States = States,
        Completed = table.clone(self.Completed),
        Revision = self.Revision
    }
end

return QuestEngine
