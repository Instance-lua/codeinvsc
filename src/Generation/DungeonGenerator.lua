local DungeonGraph = require(script.Parent.DungeonGraph)
local SeededRandom = require(script.Parent.SeededRandom)

local DungeonGenerator = {}

local function ManhattanDistance(First, Second)
    return math.abs(First.X - Second.X) + math.abs(First.Y - Second.Y)
end

local function GetAvailableCells(Graph, Node, MaximumRadius)
    local Available = {}

    for _, Direction in ipairs({
        {X = 0, Y = -1},
        {X = 1, Y = 0},
        {X = 0, Y = 1},
        {X = -1, Y = 0}
    }) do
        local X = Node.X + Direction.X
        local Y = Node.Y + Direction.Y
        local Occupied = false

        for _, Existing in pairs(Graph.Nodes) do
            if Existing.X == X and Existing.Y == Y then
                Occupied = true
                break
            end
        end

        if not Occupied and math.abs(X) + math.abs(Y) <= MaximumRadius then
            table.insert(Available, {X = X, Y = Y})
        end
    end

    return Available
end

local function CountOpenSides(Graph, X, Y)
    local Count = 0

    for _, Direction in ipairs({
        {X = 0, Y = -1},
        {X = 1, Y = 0},
        {X = 0, Y = 1},
        {X = -1, Y = 0}
    }) do
        local Found = false

        for _, Node in pairs(Graph.Nodes) do
            if Node.X == X + Direction.X and Node.Y == Y + Direction.Y then
                Found = true
                break
            end
        end

        if not Found then
            Count += 1
        end
    end

    return Count
end

local function GetDirection(First, Second)
    local DeltaX = Second.X - First.X
    local DeltaY = Second.Y - First.Y

    if DeltaY == -1 then
        return "North"
    elseif DeltaX == 1 then
        return "East"
    elseif DeltaY == 1 then
        return "South"
    elseif DeltaX == -1 then
        return "West"
    end
end

function DungeonGenerator.Generate(Options)
    assert(type(Options) == "table", "Options are required")

    local Seed = assert(Options.Seed, "Seed is required")
    local RoomCount = math.clamp(math.floor(Options.RoomCount or 12), 3, 80)
    local MaximumRadius = math.max(2, math.floor(Options.MaximumRadius or 9))
    local LoopChance = math.clamp(Options.LoopChance or 0.18, 0, 0.6)

    local Random = SeededRandom.new(Seed)
    local Graph = DungeonGraph.new()

    local Start = Graph:AddNode("Room_001", 0, 0, {
        Type = "Entrance",
        Depth = 0
    })

    local Frontier = {Start}
    local Created = 1

    while Created < RoomCount and #Frontier > 0 do
        local FrontierIndex = Random:NextInteger(1, #Frontier)
        local Parent = Frontier[FrontierIndex]
        local Available = GetAvailableCells(Graph, Parent, MaximumRadius)

        if #Available == 0 then
            table.remove(Frontier, FrontierIndex)
        else
            table.sort(Available, function(A, B)
                local ScoreA = CountOpenSides(Graph, A.X, A.Y)
                local ScoreB = CountOpenSides(Graph, B.X, B.Y)

                return ScoreA > ScoreB
            end)

            local CandidatePool = math.min(#Available, 3)
            local Position = Available[Random:NextInteger(1, CandidatePool)]
            local Id = string.format("Room_%03d", Created + 1)
            local Depth = Parent.Metadata.Depth + 1

            local Node = Graph:AddNode(Id, Position.X, Position.Y, {
                Type = "Unassigned",
                Depth = Depth,
                Parent = Parent.Id
            })

            Graph:Connect(Parent.Id, Node.Id, GetDirection(Parent, Node))

            table.insert(Frontier, Node)
            Created += 1

            if Random:Chance(0.28) then
                table.remove(Frontier, FrontierIndex)
            end
        end
    end

    local Nodes = Graph:ToArray()

    for _, Node in ipairs(Nodes) do
        for _, Candidate in ipairs(Nodes) do
            if Node.Id < Candidate.Id
                and ManhattanDistance(Node, Candidate) == 1
                and not Graph.Edges[Node.Id .. "|" .. Candidate.Id]
                and Random:Chance(LoopChance) then

                Graph:Connect(
                    Node.Id,
                    Candidate.Id,
                    GetDirection(Node, Candidate)
                )
            end
        end
    end

    local Farthest = Start
    local MaximumDepth = -1

    for _, Node in pairs(Graph.Nodes) do
        if Node.Metadata.Depth > MaximumDepth then
            MaximumDepth = Node.Metadata.Depth
            Farthest = Node
        end
    end

    Start.Metadata.Type = "Entrance"
    Farthest.Metadata.Type = "Exit"

    local Valid, Errors = Graph:Validate(Start.Id, Farthest.Id)

    if not Valid then
        return nil, Errors
    end

    return {
        Seed = Seed,
        Graph = Graph,
        Entrance = Start.Id,
        Exit = Farthest.Id,
        RoomCount = Graph.NodeCount,
        RandomState = Random:GetState()
    }
end

return DungeonGenerator
