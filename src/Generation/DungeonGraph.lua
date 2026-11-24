local DungeonGraph = {}
DungeonGraph.__index = DungeonGraph

local Directions = {
    {Name = "North", X = 0, Y = -1, Opposite = "South"},
    {Name = "East", X = 1, Y = 0, Opposite = "West"},
    {Name = "South", X = 0, Y = 1, Opposite = "North"},
    {Name = "West", X = -1, Y = 0, Opposite = "East"}
}

local DirectionByName = {}

for _, Direction in ipairs(Directions) do
    DirectionByName[Direction.Name] = Direction
end

local function CoordinateKey(X, Y)
    return tostring(X) .. ":" .. tostring(Y)
end

function DungeonGraph.new()
    return setmetatable({
        Nodes = {},
        Edges = {},
        NodeCount = 0
    }, DungeonGraph)
end

function DungeonGraph:AddNode(Id, X, Y, Metadata)
    assert(type(Id) == "string" and Id ~= "", "Node id is required")
    assert(not self.Nodes[Id], "Node already exists")
    assert(type(X) == "number" and type(Y) == "number", "Coordinates must be numeric")

    local Node = {
        Id = Id,
        X = X,
        Y = Y,
        Metadata = Metadata or {},
        Connections = {}
    }

    self.Nodes[Id] = Node
    self.NodeCount += 1

    return Node
end

function DungeonGraph:GetNode(Id)
    return self.Nodes[Id]
end

function DungeonGraph:GetAt(X, Y)
    for _, Node in pairs(self.Nodes) do
        if Node.X == X and Node.Y == Y then
            return Node
        end
    end
end

function DungeonGraph:Connect(FirstId, SecondId, Direction)
    local First = assert(self.Nodes[FirstId], "First node does not exist")
    local Second = assert(self.Nodes[SecondId], "Second node does not exist")

    assert(FirstId ~= SecondId, "A node cannot connect to itself")

    local DeltaX = Second.X - First.X
    local DeltaY = Second.Y - First.Y
    local Resolved

    for _, Candidate in ipairs(Directions) do
        if Candidate.X == DeltaX and Candidate.Y == DeltaY then
            Resolved = Candidate
            break
        end
    end

    assert(Resolved, "Connections must be between adjacent grid cells")

    if Direction then
        assert(Direction == Resolved.Name, "Direction does not match coordinates")
    end

    First.Connections[Resolved.Name] = SecondId
    Second.Connections[Resolved.Opposite] = FirstId

    self.Edges[FirstId .. "|" .. SecondId] = true
    self.Edges[SecondId .. "|" .. FirstId] = true

    return true
end

function DungeonGraph:GetNeighbors(Id)
    local Node = assert(self.Nodes[Id], "Node does not exist")
    local Result = {}

    for _, Direction in ipairs(Directions) do
        local NeighborId = Node.Connections[Direction.Name]

        if NeighborId then
            table.insert(Result, {
                Direction = Direction.Name,
                Node = self.Nodes[NeighborId]
            })
        end
    end

    return Result
end

function DungeonGraph:GetDegree(Id)
    local Node = assert(self.Nodes[Id], "Node does not exist")
    local Count = 0

    for _ in pairs(Node.Connections) do
        Count += 1
    end

    return Count
end

function DungeonGraph:FindPath(StartId, GoalId)
    if not self.Nodes[StartId] or not self.Nodes[GoalId] then
        return nil
    end

    local Queue = {StartId}
    local Head = 1
    local Previous = {[StartId] = false}

    while Head <= #Queue do
        local CurrentId = Queue[Head]
        Head += 1

        if CurrentId == GoalId then
            local Path = {}
            local Cursor = GoalId

            while Cursor do
                table.insert(Path, 1, Cursor)
                Cursor = Previous[Cursor]
            end

            return Path
        end

        for _, Neighbor in ipairs(self:GetNeighbors(CurrentId)) do
            local NeighborId = Neighbor.Node.Id

            if Previous[NeighborId] == nil then
                Previous[NeighborId] = CurrentId
                table.insert(Queue, NeighborId)
            end
        end
    end

    return nil
end

function DungeonGraph:GetReachable(StartId)
    assert(self.Nodes[StartId], "Start node does not exist")

    local Visited = {[StartId] = true}
    local Queue = {StartId}
    local Head = 1

    while Head <= #Queue do
        local CurrentId = Queue[Head]
        Head += 1

        for _, Neighbor in ipairs(self:GetNeighbors(CurrentId)) do
            local NeighborId = Neighbor.Node.Id

            if not Visited[NeighborId] then
                Visited[NeighborId] = true
                table.insert(Queue, NeighborId)
            end
        end
    end

    return Visited
end

function DungeonGraph:Validate(StartId, GoalId)
    local Errors = {}
    local Coordinates = {}

    for Id, Node in pairs(self.Nodes) do
        local Key = CoordinateKey(Node.X, Node.Y)

        if Coordinates[Key] then
            table.insert(Errors, "Coordinate collision between " .. Id .. " and " .. Coordinates[Key])
        else
            Coordinates[Key] = Id
        end

        for DirectionName, NeighborId in pairs(Node.Connections) do
            local Direction = DirectionByName[DirectionName]
            local Neighbor = self.Nodes[NeighborId]

            if not Direction or not Neighbor then
                table.insert(Errors, "Invalid connection on " .. Id)
            elseif Neighbor.Connections[Direction.Opposite] ~= Id then
                table.insert(Errors, "Asymmetric connection between " .. Id .. " and " .. NeighborId)
            elseif Neighbor.X ~= Node.X + Direction.X or Neighbor.Y ~= Node.Y + Direction.Y then
                table.insert(Errors, "Non-adjacent connection between " .. Id .. " and " .. NeighborId)
            end
        end
    end

    if StartId and GoalId then
        if not self:FindPath(StartId, GoalId) then
            table.insert(Errors, "Exit is unreachable from entrance")
        end
    end

    local Reachable = StartId and self:GetReachable(StartId)

    if Reachable then
        for Id in pairs(self.Nodes) do
            if not Reachable[Id] then
                table.insert(Errors, "Unreachable node: " .. Id)
            end
        end
    end

    return #Errors == 0, Errors
end

function DungeonGraph:ToArray()
    local Result = {}

    for _, Node in pairs(self.Nodes) do
        table.insert(Result, {
            Id = Node.Id,
            X = Node.X,
            Y = Node.Y,
            Metadata = Node.Metadata,
            Connections = table.clone(Node.Connections)
        })
    end

    table.sort(Result, function(A, B)
        return A.Id < B.Id
    end)

    return Result
end

return DungeonGraph
