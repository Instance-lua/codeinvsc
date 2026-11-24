local ProfileSchema = {}

ProfileSchema.CurrentVersion = 3

local Defaults = {
    Version = 3,
    Currency = 0,
    Level = 1,
    Experience = 0,
    UnlockedRegions = {"TheForgottenGate"},
    DiscoveredRelics = {},
    RelicInventory = {},
    QuestProgress = {},
    DungeonHistory = {},
    Statistics = {
        RunsStarted = 0,
        RunsCompleted = 0,
        RoomsDiscovered = 0,
        RelicsFound = 0,
        HighestFloor = 0
    },
    Settings = {
        MusicVolume = 0.7,
        EffectsVolume = 0.8,
        ReducedMotion = false
    }
}

local function DeepCopy(Value)
    if type(Value) ~= "table" then
        return Value
    end

    local Result = {}

    for Key, Child in pairs(Value) do
        Result[Key] = DeepCopy(Child)
    end

    return Result
end

local function MergeDefaults(Target, Source)
    for Key, DefaultValue in pairs(Source) do
        if type(DefaultValue) == "table" then
            if type(Target[Key]) ~= "table" then
                Target[Key] = DeepCopy(DefaultValue)
            else
                MergeDefaults(Target[Key], DefaultValue)
            end
        elseif type(Target[Key]) ~= type(DefaultValue) then
            Target[Key] = DefaultValue
        end
    end

    return Target
end

local Migrations = {
    [1] = function(Data)
        Data.Statistics = Data.Statistics or {}
        Data.Statistics.RunsStarted = Data.Statistics.RunsStarted or 0
        Data.Statistics.RunsCompleted = Data.Statistics.RunsCompleted or 0
        Data.Version = 2

        return Data
    end,

    [2] = function(Data)
        Data.Settings = Data.Settings or {}
        Data.Settings.ReducedMotion = Data.Settings.ReducedMotion == true
        Data.DiscoveredRelics = Data.DiscoveredRelics or {}
        Data.Version = 3

        return Data
    end
}

local function ValidateNumber(Data, Key, Minimum, Maximum)
    local Value = Data[Key]

    if type(Value) ~= "number" or Value ~= Value then
        Data[Key] = Minimum
    else
        Data[Key] = math.clamp(Value, Minimum, Maximum)
    end
end

function ProfileSchema.Create()
    return DeepCopy(Defaults)
end

function ProfileSchema.Migrate(Input)
    assert(type(Input) == "table", "Profile must be a table")

    local Data = DeepCopy(Input)
    local Version = math.floor(tonumber(Data.Version) or 1)

    if Version > ProfileSchema.CurrentVersion then
        return nil, "ProfileVersionNewerThanSchema"
    end

    while Version < ProfileSchema.CurrentVersion do
        local Migration = Migrations[Version]

        if not Migration then
            return nil, "MissingMigration:" .. tostring(Version)
        end

        Data = Migration(Data)
        Version = Data.Version
    end

    MergeDefaults(Data, Defaults)

    return Data
end

function ProfileSchema.Validate(Input)
    local Data, ErrorCode = ProfileSchema.Migrate(Input)

    if not Data then
        return nil, ErrorCode
    end

    ValidateNumber(Data, "Currency", 0, 9e15)
    ValidateNumber(Data, "Level", 1, 1000)
    ValidateNumber(Data, "Experience", 0, 9e15)

    Data.Level = math.floor(Data.Level)
    Data.Currency = math.floor(Data.Currency)
    Data.Experience = math.floor(Data.Experience)

    for Key, Volume in pairs({
        MusicVolume = true,
        EffectsVolume = true
    }) do
        if Volume then
            local Value = Data.Settings[Key]

            if type(Value) ~= "number" or Value ~= Value then
                Data.Settings[Key] = 0.7
            else
                Data.Settings[Key] = math.clamp(Value, 0, 1)
            end
        end
    end

    Data.Settings.ReducedMotion = Data.Settings.ReducedMotion == true

    for _, Key in ipairs({
        "RunsStarted",
        "RunsCompleted",
        "RoomsDiscovered",
        "RelicsFound",
        "HighestFloor"
    }) do
        local Value = Data.Statistics[Key]

        if type(Value) ~= "number" or Value ~= Value then
            Data.Statistics[Key] = 0
        else
            Data.Statistics[Key] = math.max(0, math.floor(Value))
        end
    end

    return Data
end

function ProfileSchema.Clone(Input)
    return DeepCopy(Input)
end

return ProfileSchema
