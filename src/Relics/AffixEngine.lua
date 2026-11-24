local AffixEngine = {}

local AllowedSlots = {
    Weapon = {Power = true, Fortune = true, Haste = true},
    Armor = {Vitality = true, Fortune = true, Ward = true},
    Charm = {Fortune = true, Haste = true, Ward = true}
}

local DiminishingStats = {
    Fortune = 0.72,
    Haste = 0.65,
    Ward = 0.8
}

local function ValidateAffix(Affix)
    assert(type(Affix.Id) == "string" and Affix.Id ~= "", "Affix id is required")
    assert(type(Affix.Stat) == "string", "Affix stat is required")
    assert(type(Affix.Value) == "number" and Affix.Value > 0, "Affix value must be positive")
    assert(type(Affix.Tier) == "number" and Affix.Tier >= 1, "Affix tier is invalid")
end

function AffixEngine.Generate(Item, Pool, Random, Options)
    assert(type(Item) == "table" and type(Item.Slot) == "string", "Item slot is required")
    assert(type(Pool) == "table" and #Pool > 0, "Affix pool is required")
    assert(Random and Random.NextInteger, "A seeded random generator is required")

    Options = Options or {}

    local Allowed = assert(AllowedSlots[Item.Slot], "Unsupported item slot")
    local Minimum = math.max(0, math.floor(Options.MinimumAffixes or 1))
    local Maximum = math.max(Minimum, math.floor(Options.MaximumAffixes or 3))
    local Count = Random:NextInteger(Minimum, Maximum)
    local Candidates = {}

    for _, Affix in ipairs(Pool) do
        ValidateAffix(Affix)

        if Allowed[Affix.Stat] then
            table.insert(Candidates, Affix)
        end
    end

    local Selected = {}
    local UsedStats = {}

    for _ = 1, math.min(Count, #Candidates) do
        local Available = {}

        for _, Candidate in ipairs(Candidates) do
            if not UsedStats[Candidate.Stat] then
                table.insert(Available, Candidate)
            end
        end

        if #Available == 0 then
            break
        end

        local Choice = Available[Random:NextInteger(1, #Available)]
        UsedStats[Choice.Stat] = true

        table.insert(Selected, {
            Id = Choice.Id,
            Stat = Choice.Stat,
            Value = Choice.Value,
            Tier = Choice.Tier
        })
    end

    return Selected
end

function AffixEngine.Aggregate(BaseStats, Affixes, Options)
    assert(type(BaseStats) == "table" and type(Affixes) == "table", "Stats and affixes are required")

    Options = Options or {}

    local Result = table.clone(BaseStats)
    local Totals = {}

    for _, Affix in ipairs(Affixes) do
        ValidateAffix(Affix)

        local Current = Totals[Affix.Stat] or 0
        local Factor = DiminishingStats[Affix.Stat] or 1
        local Contribution = Affix.Value * Factor ^ math.floor(Current / 100)

        Totals[Affix.Stat] = Current + Contribution
    end

    for Stat, Value in pairs(Totals) do
        Result[Stat] = (Result[Stat] or 0) + Value
    end

    if Options.Maximums then
        for Stat, Maximum in pairs(Options.Maximums) do
            if Result[Stat] then
                Result[Stat] = math.min(Result[Stat], Maximum)
            end
        end
    end

    return Result
end

function AffixEngine.Compare(FirstStats, SecondStats)
    local Differences = {}
    local Keys = {}

    for Key in pairs(FirstStats) do
        Keys[Key] = true
    end

    for Key in pairs(SecondStats) do
        Keys[Key] = true
    end

    for Key in pairs(Keys) do
        local First = FirstStats[Key] or 0
        local Second = SecondStats[Key] or 0

        Differences[Key] = {
            Current = First,
            Candidate = Second,
            Delta = Second - First
        }
    end

    return Differences
end

return AffixEngine
