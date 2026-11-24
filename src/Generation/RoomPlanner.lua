local RoomPlanner = {}

local DefaultRoomCatalog = {
    Entrance = {Weight = 0, MinimumDepth = 0, MaximumPerDungeon = 1, Biomes = {"Any"}},
    Exit = {Weight = 0, MinimumDepth = 1, MaximumPerDungeon = 1, Biomes = {"Any"}},
    Corridor = {Weight = 42, MinimumDepth = 0, MaximumPerDungeon = 80, Biomes = {"Any"}},
    Treasury = {Weight = 12, MinimumDepth = 2, MaximumPerDungeon = 2, Biomes = {"Any"}},
    Shrine = {Weight = 10, MinimumDepth = 1, MaximumPerDungeon = 3, Biomes = {"Any"}},
    Puzzle = {Weight = 11, MinimumDepth = 2, MaximumPerDungeon = 3, Biomes = {"Ancient", "Arcane"}},
    Library = {Weight = 8, MinimumDepth = 2, MaximumPerDungeon = 2, Biomes = {"Ancient", "Arcane"}},
    Sanctum = {Weight = 5, MinimumDepth = 4, MaximumPerDungeon = 1, Biomes = {"Any"}},
    Antechamber = {Weight = 12, MinimumDepth = 1, MaximumPerDungeon = 8, Biomes = {"Any"}}
}

local function SupportsBiome(Definition, Biome)
    for _, Allowed in ipairs(Definition.Biomes) do
        if Allowed == "Any" or Allowed == Biome then
            return true
        end
    end

    return false
end

local function WeightedChoice(Candidates, Random)
    local Total = 0

    for _, Candidate in ipairs(Candidates) do
        Total += Candidate.Definition.Weight
    end

    if Total <= 0 then
        return Candidates[1]
    end

    local Selection = Random:NextNumber(0, Total)

    for _, Candidate in ipairs(Candidates) do
        Selection -= Candidate.Definition.Weight

        if Selection <= 0 then
            return Candidate
        end
    end

    return Candidates[#Candidates]
end

function RoomPlanner.Assign(Graph, Options)
    assert(Graph and Graph.Nodes, "A dungeon graph is required")

    Options = Options or {}

    local Random = assert(Options.Random, "A seeded random generator is required")
    local Catalog = Options.Catalog or DefaultRoomCatalog
    local Biome = Options.Biome or "Ancient"
    local Counts = {}
    local Assignments = {}

    local Nodes = Graph:ToArray()

    table.sort(Nodes, function(A, B)
        if A.Metadata.Depth == B.Metadata.Depth then
            return A.Id < B.Id
        end

        return A.Metadata.Depth < B.Metadata.Depth
    end)

    for _, Node in ipairs(Nodes) do
        local ForcedType = Node.Metadata.Type

        if ForcedType == "Entrance" or ForcedType == "Exit" then
            Assignments[Node.Id] = ForcedType
            Counts[ForcedType] = (Counts[ForcedType] or 0) + 1
        else
            local Candidates = {}

            for Name, Definition in pairs(Catalog) do
                local CurrentCount = Counts[Name] or 0

                if Definition.Weight > 0
                    and Node.Metadata.Depth >= Definition.MinimumDepth
                    and CurrentCount < Definition.MaximumPerDungeon
                    and SupportsBiome(Definition, Biome) then

                    table.insert(Candidates, {
                        Name = Name,
                        Definition = Definition
                    })
                end
            end

            table.sort(Candidates, function(A, B)
                return A.Name < B.Name
            end)

            local Selected = WeightedChoice(Candidates, Random)
            local RoomType = Selected and Selected.Name or "Corridor"

            Assignments[Node.Id] = RoomType
            Counts[RoomType] = (Counts[RoomType] or 0) + 1
        end
    end

    for Id, RoomType in pairs(Assignments) do
        Graph.Nodes[Id].Metadata.Type = RoomType
    end

    return {
        Assignments = Assignments,
        Counts = Counts,
        Biome = Biome
    }
end

return RoomPlanner
