local DungeonDirector = {}
DungeonDirector.__index = DungeonDirector

local ValidTransitions = {
    Preparing = {Exploring = true, Abandoned = true},
    Exploring = {ChoosingPath = true, Checkpoint = true, Completed = true, Failed = true, Abandoned = true},
    ChoosingPath = {Exploring = true, Abandoned = true},
    Checkpoint = {Exploring = true, Failed = true, Abandoned = true},
    Completed = {},
    Failed = {},
    Abandoned = {}
}

local function CopyChoice(Choice)
    return {
        Id = Choice.Id,
        Label = Choice.Label,
        Destination = Choice.Destination,
        Risk = Choice.Risk,
        RewardMultiplier = Choice.RewardMultiplier or 1,
        Requirements = table.clone(Choice.Requirements or {})
    }
end

function DungeonDirector.new(Configuration)
    assert(type(Configuration) == "table", "Configuration is required")
    assert(type(Configuration.Floors) == "table" and #Configuration.Floors > 0, "At least one floor is required")

    return setmetatable({
        Configuration = Configuration,
        Status = "Preparing",
        FloorIndex = 0,
        VisitedRooms = {},
        Decisions = {},
        Checkpoints = {},
        StartedAt = nil,
        FinishedAt = nil,
        Revision = 0,
        SelectedRoute = nil
    }, DungeonDirector)
end

function DungeonDirector:Transition(NextStatus)
    local Allowed = ValidTransitions[self.Status]

    if not Allowed or not Allowed[NextStatus] then
        return false, "InvalidTransition:" .. self.Status .. ":" .. tostring(NextStatus)
    end

    self.Status = NextStatus
    self.Revision += 1

    if NextStatus == "Exploring" and not self.StartedAt then
        self.StartedAt = os.time()
    end

    if NextStatus == "Completed" or NextStatus == "Failed" or NextStatus == "Abandoned" then
        self.FinishedAt = os.time()
    end

    return true
end

function DungeonDirector:Begin()
    if self.Status ~= "Preparing" then
        return false, "RunAlreadyStarted"
    end

    self.FloorIndex = 1

    return self:Transition("Exploring")
end

function DungeonDirector:GetCurrentFloor()
    return self.Configuration.Floors[self.FloorIndex]
end

function DungeonDirector:VisitRoom(RoomId)
    if self.Status ~= "Exploring" then
        return false, "NotExploring"
    end

    if type(RoomId) ~= "string" or RoomId == "" then
        return false, "InvalidRoom"
    end

    self.VisitedRooms[RoomId] = (self.VisitedRooms[RoomId] or 0) + 1
    self.Revision += 1

    return true
end

function DungeonDirector:OpenRouteChoices(Choices)
    if self.Status ~= "Exploring" then
        return false, "NotExploring"
    end

    if type(Choices) ~= "table" or #Choices < 2 then
        return false, "InsufficientChoices"
    end

    local Normalized = {}
    local Seen = {}

    for _, Choice in ipairs(Choices) do
        assert(type(Choice.Id) == "string" and Choice.Id ~= "", "Choice id is required")
        assert(not Seen[Choice.Id], "Choice ids must be unique")

        Seen[Choice.Id] = true
        table.insert(Normalized, CopyChoice(Choice))
    end

    self.PendingChoices = Normalized

    return self:Transition("ChoosingPath")
end

function DungeonDirector:ChooseRoute(ChoiceId, Context)
    if self.Status ~= "ChoosingPath" then
        return false, "NotChoosing"
    end

    Context = Context or {}

    local Selected

    for _, Choice in ipairs(self.PendingChoices or {}) do
        if Choice.Id == ChoiceId then
            Selected = Choice
            break
        end
    end

    if not Selected then
        return false, "UnknownChoice"
    end

    for Key, Required in pairs(Selected.Requirements) do
        if Context[Key] ~= Required then
            return false, "RequirementFailed:" .. Key
        end
    end

    self.SelectedRoute = Selected
    table.insert(self.Decisions, {
        ChoiceId = Selected.Id,
        Destination = Selected.Destination,
        SelectedAt = os.time()
    })

    self.PendingChoices = nil
    self.Revision += 1

    return self:Transition("Exploring"), CopyChoice(Selected)
end

function DungeonDirector:AdvanceFloor()
    if self.Status ~= "Exploring" then
        return false, "NotExploring"
    end

    if self.FloorIndex >= #self.Configuration.Floors then
        return self:Transition("Completed")
    end

    self.FloorIndex += 1
    self.Revision += 1

    return true, self:GetCurrentFloor()
end

function DungeonDirector:CreateCheckpoint(Data)
    if self.Status ~= "Exploring" then
        return false, "NotExploring"
    end

    local Checkpoint = {
        FloorIndex = self.FloorIndex,
        VisitedRooms = table.clone(self.VisitedRooms),
        Decisions = table.clone(self.Decisions),
        CreatedAt = os.time(),
        Data = table.clone(Data or {})
    }

    table.insert(self.Checkpoints, Checkpoint)

    return self:Transition("Checkpoint"), Checkpoint
end

function DungeonDirector:ResumeCheckpoint(Index)
    if self.Status ~= "Checkpoint" then
        return false, "NoCheckpoint"
    end

    local Checkpoint = self.Checkpoints[Index or #self.Checkpoints]

    if not Checkpoint then
        return false, "CheckpointNotFound"
    end

    self.FloorIndex = Checkpoint.FloorIndex
    self.VisitedRooms = table.clone(Checkpoint.VisitedRooms)
    self.Decisions = table.clone(Checkpoint.Decisions)

    return self:Transition("Exploring")
end

function DungeonDirector:Fail()
    return self:Transition("Failed")
end

function DungeonDirector:Abandon()
    return self:Transition("Abandoned")
end

function DungeonDirector:GetSummary()
    return {
        Status = self.Status,
        FloorIndex = self.FloorIndex,
        FloorCount = #self.Configuration.Floors,
        VisitedRoomCount = (function()
            local Count = 0

            for _ in pairs(self.VisitedRooms) do
                Count += 1
            end

            return Count
        end)(),
        Decisions = table.clone(self.Decisions),
        Duration = self.StartedAt and (self.FinishedAt or os.time()) - self.StartedAt or 0,
        Revision = self.Revision
    }
end

return DungeonDirector
