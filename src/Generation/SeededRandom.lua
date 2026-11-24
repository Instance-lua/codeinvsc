local SeededRandom = {}
SeededRandom.__index = SeededRandom

local Modulus = 2147483647
local Multiplier = 48271

function SeededRandom.new(Seed)
    assert(type(Seed) == "number" and Seed == Seed, "Seed must be a finite number")

    local Normalized = math.floor(math.abs(Seed)) % (Modulus - 1) + 1

    return setmetatable({
        State = Normalized,
        DrawCount = 0
    }, SeededRandom)
end

function SeededRandom:NextNumber(Minimum, Maximum)
    Minimum = Minimum or 0
    Maximum = Maximum or 1

    assert(Minimum <= Maximum, "Minimum cannot exceed Maximum")

    self.State = (self.State * Multiplier) % Modulus
    self.DrawCount += 1

    local Unit = (self.State - 1) / (Modulus - 1)

    return Minimum + (Maximum - Minimum) * Unit
end

function SeededRandom:NextInteger(Minimum, Maximum)
    assert(Minimum <= Maximum, "Minimum cannot exceed Maximum")

    return math.floor(self:NextNumber(Minimum, Maximum + 1))
end

function SeededRandom:Chance(Probability)
    return self:NextNumber() < math.clamp(Probability, 0, 1)
end

function SeededRandom:Choose(Values)
    assert(type(Values) == "table" and #Values > 0, "Values must be a non-empty array")

    return Values[self:NextInteger(1, #Values)]
end

function SeededRandom:Fork(Salt)
    assert(type(Salt) == "number", "Salt must be numeric")

    local Mixed = (self.State + math.floor(math.abs(Salt)) * 104729) % (Modulus - 1) + 1

    return SeededRandom.new(Mixed)
end

function SeededRandom:GetState()
    return {
        State = self.State,
        DrawCount = self.DrawCount
    }
end

function SeededRandom:Restore(State)
    assert(type(State) == "table", "State must be a table")
    assert(type(State.State) == "number", "State.State must be numeric")
    assert(type(State.DrawCount) == "number", "State.DrawCount must be numeric")

    self.State = math.clamp(math.floor(State.State), 1, Modulus - 1)
    self.DrawCount = math.max(0, math.floor(State.DrawCount))

    return self
end

return SeededRandom
