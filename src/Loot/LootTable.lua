local LootTable = {}
LootTable.__index = LootTable

local function CopyReward(Reward)
    return {
        Id = Reward.Id,
        Weight = Reward.Weight,
        Rarity = Reward.Rarity,
        Quantity = Reward.Quantity or 1,
        Unique = Reward.Unique == true,
        MinimumDepth = Reward.MinimumDepth or 0,
        MaximumDepth = Reward.MaximumDepth or math.huge,
        Tags = table.clone(Reward.Tags or {})
    }
end

function LootTable.new(Entries)
    assert(type(Entries) == "table" and #Entries > 0, "Loot entries are required")

    local Normalized = {}
    local Seen = {}

    for _, Entry in ipairs(Entries) do
        assert(type(Entry.Id) == "string" and Entry.Id ~= "", "Every reward needs an id")
        assert(not Seen[Entry.Id], "Reward ids must be unique")
        assert(type(Entry.Weight) == "number" and Entry.Weight > 0, "Reward weight must be positive")

        Seen[Entry.Id] = true
        table.insert(Normalized, CopyReward(Entry))
    end

    table.sort(Normalized, function(A, B)
        return A.Id < B.Id
    end)

    return setmetatable({
        Entries = Normalized,
        ById = Seen
    }, LootTable)
end

function LootTable:Roll(Random, Context)
    assert(Random and Random.NextNumber, "A seeded random generator is required")

    Context = Context or {}

    local Eligible = {}
    local TotalWeight = 0

    for _, Entry in ipairs(self.Entries) do
        local Depth = Context.Depth or 0
        local IsOwned = Context.Owned and Context.Owned[Entry.Id]

        if Depth >= Entry.MinimumDepth
            and Depth <= Entry.MaximumDepth
            and not (Entry.Unique and IsOwned) then

            local Weight = Entry.Weight * (Context.WeightModifiers and Context.WeightModifiers[Entry.Rarity] or 1)

            if Weight > 0 then
                TotalWeight += Weight
                table.insert(Eligible, {
                    Entry = Entry,
                    Weight = Weight
                })
            end
        end
    end

    if TotalWeight <= 0 then
        return nil, "NoEligibleRewards"
    end

    local Selection = Random:NextNumber(0, TotalWeight)

    for _, Candidate in ipairs(Eligible) do
        Selection -= Candidate.Weight

        if Selection <= 0 then
            return {
                Id = Candidate.Entry.Id,
                Rarity = Candidate.Entry.Rarity,
                Quantity = Candidate.Entry.Quantity,
                Tags = table.clone(Candidate.Entry.Tags),
                Unique = Candidate.Entry.Unique
            }
        end
    end

    return nil, "SelectionFailed"
end

function LootTable:RollMany(Random, Count, Context)
    Count = math.clamp(math.floor(Count), 0, 100)

    local Results = {}

    for Index = 1, Count do
        local Reward, ErrorCode = self:Roll(Random, Context)

        if Reward then
            table.insert(Results, Reward)
        elseif ErrorCode then
            return Results, ErrorCode
        end
    end

    return Results
end

function LootTable:GetEntry(Id)
    for _, Entry in ipairs(self.Entries) do
        if Entry.Id == Id then
            return CopyReward(Entry)
        end
    end
end

return LootTable
