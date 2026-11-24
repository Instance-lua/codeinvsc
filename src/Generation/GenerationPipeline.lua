local DungeonGenerator = require(script.Parent.DungeonGenerator)
local RoomPlanner = require(script.Parent.RoomPlanner)
local SeededRandom = require(script.Parent.SeededRandom)

local GenerationPipeline = {}

function GenerationPipeline.Build(Options)
    assert(type(Options) == "table", "Generation options are required")

    local Seed = assert(Options.Seed, "Seed is required")
    local RootRandom = SeededRandom.new(Seed)

    local LayoutRandom = RootRandom:Fork(101)
    local AssignmentRandom = RootRandom:Fork(211)

    local Layout, Errors = DungeonGenerator.Generate({
        Seed = LayoutRandom:NextInteger(1, 2147483646),
        RoomCount = Options.RoomCount,
        MaximumRadius = Options.MaximumRadius,
        LoopChance = Options.LoopChance
    })

    if not Layout then
        return nil, {
            Stage = "Layout",
            Errors = Errors
        }
    end

    local Plan = RoomPlanner.Assign(Layout.Graph, {
        Random = AssignmentRandom,
        Catalog = Options.Catalog,
        Biome = Options.Biome
    })

    local Valid, ValidationErrors = Layout.Graph:Validate(
        Layout.Entrance,
        Layout.Exit
    )

    if not Valid then
        return nil, {
            Stage = "Validation",
            Errors = ValidationErrors
        }
    end

    return {
        Seed = Seed,
        Entrance = Layout.Entrance,
        Exit = Layout.Exit,
        RoomCount = Layout.RoomCount,
        Biome = Plan.Biome,
        Rooms = Layout.Graph:ToArray(),
        RoomCounts = Plan.Counts,
        PathToExit = Layout.Graph:FindPath(Layout.Entrance, Layout.Exit),
        RandomState = RootRandom:GetState()
    }
end

return GenerationPipeline
