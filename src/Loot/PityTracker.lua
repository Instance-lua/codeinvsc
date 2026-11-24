local PityTracker = {}
PityTracker.__index = PityTracker

function PityTracker.new(Rules)
    assert(type(Rules) == "table", "Pity rules are required")

    local Normalized = {}

    for Rarity, Rule in pairs(Rules) do
        assert(type(Rule.Threshold) == "number" and Rule.Threshold >= 1, "Invalid pity threshold")
        assert(type(Rule.Boost) == "number" and Rule.Boost >= 0, "Invalid pity boost")

        Normalized[Rarity] = {
            Threshold = math.floor(Rule.Threshold),
            Boost = Rule.Boost,
            MaximumBoost = Rule.MaximumBoost or Rule.Boost * Rule.Threshold
        }
    end

    return setmetatable({
        Rules = Normalized,
        Counters = {}
    }, PityTracker)
end

function PityTracker:GetModifier(Rarity)
    local Rule = self.Rules[Rarity]

    if not Rule then
        return 1
    end

    local Count = self.Counters[Rarity] or 0
    local Boost = math.min(Count * Rule.Boost, Rule.MaximumBoost)

    return 1 + Boost
end

function PityTracker:Record(Rarity, RewardedRarity)
    local Rule = self.Rules[Rarity]

    if not Rule then
        return
    end

    if RewardedRarity == Rarity then
        self.Counters[Rarity] = 0
    else
        self.Counters[Rarity] = math.min(
            (self.Counters[Rarity] or 0) + 1,
            Rule.Threshold
        )
    end
end

function PityTracker:GetGuaranteed(Rarity)
    local Rule = self.Rules[Rarity]

    if not Rule then
        return false
    end

    return (self.Counters[Rarity] or 0) >= Rule.Threshold
end

function PityTracker:Serialize()
    return table.clone(self.Counters)
end

function PityTracker:Restore(State)
    assert(type(State) == "table", "Pity state must be a table")

    for Rarity, Rule in pairs(self.Rules) do
        local Value = State[Rarity] or 0
        self.Counters[Rarity] = math.clamp(math.floor(Value), 0, Rule.Threshold)
    end

    return self
end

return PityTracker
