local TransactionLedger = {}
TransactionLedger.__index = TransactionLedger

local function IsFinite(Value)
    return type(Value) == "number"
        and Value == Value
        and Value ~= math.huge
        and Value ~= -math.huge
end

function TransactionLedger.new(InitialBalance, Options)
    assert(IsFinite(InitialBalance) and InitialBalance >= 0, "Initial balance must be non-negative")

    Options = Options or {}

    return setmetatable({
        Balance = InitialBalance,
        Revision = 0,
        Transactions = {},
        TransactionOrder = {},
        MaximumHistory = math.max(10, math.floor(Options.MaximumHistory or 250)),
        MaximumBalance = Options.MaximumBalance or 9e15
    }, TransactionLedger)
end

function TransactionLedger:Apply(Transaction)
    assert(type(Transaction) == "table", "Transaction is required")

    local Id = assert(Transaction.Id, "Transaction id is required")
    local Amount = Transaction.Amount
    local Reason = Transaction.Reason or "Unspecified"

    assert(type(Id) == "string" and #Id >= 1 and #Id <= 96, "Invalid transaction id")
    assert(IsFinite(Amount) and Amount ~= 0, "Transaction amount must be finite and non-zero")
    assert(type(Reason) == "string" and #Reason <= 128, "Invalid transaction reason")

    local Existing = self.Transactions[Id]

    if Existing then
        return false, "DuplicateTransaction", table.clone(Existing)
    end

    local NewBalance = self.Balance + Amount

    if NewBalance < 0 then
        return false, "InsufficientFunds"
    end

    if NewBalance > self.MaximumBalance then
        return false, "BalanceLimitExceeded"
    end

    self.Revision += 1

    local Receipt = {
        Id = Id,
        Amount = Amount,
        BalanceBefore = self.Balance,
        BalanceAfter = NewBalance,
        Reason = Reason,
        Revision = self.Revision,
        Timestamp = os.time(),
        Metadata = table.clone(Transaction.Metadata or {})
    }

    self.Balance = NewBalance
    self.Transactions[Id] = Receipt
    table.insert(self.TransactionOrder, Id)

    while #self.TransactionOrder > self.MaximumHistory do
        local RemovedId = table.remove(self.TransactionOrder, 1)
        self.Transactions[RemovedId] = nil
    end

    return true, "Applied", table.clone(Receipt)
end

function TransactionLedger:Credit(Id, Amount, Reason, Metadata)
    assert(Amount > 0, "Credit amount must be positive")

    return self:Apply({
        Id = Id,
        Amount = Amount,
        Reason = Reason,
        Metadata = Metadata
    })
end

function TransactionLedger:Debit(Id, Amount, Reason, Metadata)
    assert(Amount > 0, "Debit amount must be positive")

    return self:Apply({
        Id = Id,
        Amount = -Amount,
        Reason = Reason,
        Metadata = Metadata
    })
end

function TransactionLedger:GetBalance()
    return self.Balance
end

function TransactionLedger:GetTransaction(Id)
    local Receipt = self.Transactions[Id]

    return Receipt and table.clone(Receipt)
end

function TransactionLedger:GetHistory(Limit)
    Limit = math.clamp(math.floor(Limit or 25), 1, self.MaximumHistory)

    local Result = {}
    local Start = math.max(1, #self.TransactionOrder - Limit + 1)

    for Index = Start, #self.TransactionOrder do
        local Receipt = self.Transactions[self.TransactionOrder[Index]]

        if Receipt then
            table.insert(Result, table.clone(Receipt))
        end
    end

    return Result
end

function TransactionLedger:Audit()
    local Errors = {}
    local PreviousBalance

    for _, Id in ipairs(self.TransactionOrder) do
        local Receipt = self.Transactions[Id]

        if not Receipt then
            table.insert(Errors, "Missing receipt: " .. Id)
        else
            if PreviousBalance and Receipt.BalanceBefore ~= PreviousBalance then
                table.insert(Errors, "Broken balance chain at: " .. Id)
            end

            if Receipt.BalanceAfter - Receipt.BalanceBefore ~= Receipt.Amount then
                table.insert(Errors, "Invalid arithmetic at: " .. Id)
            end

            PreviousBalance = Receipt.BalanceAfter
        end
    end

    if self.Balance < 0 or self.Balance > self.MaximumBalance then
        table.insert(Errors, "Balance invariant violated")
    end

    return #Errors == 0, Errors
end

function TransactionLedger:Serialize()
    return {
        Balance = self.Balance,
        Revision = self.Revision,
        History = self:GetHistory(self.MaximumHistory)
    }
end

return TransactionLedger
