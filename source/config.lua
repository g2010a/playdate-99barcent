Config = {
    baseFillSpeed = 1,
    showCurrentPercent = false,
    startingPoints = 5,
    closeThreshold = 1,
    
    -- Future game modes can be added here
    gameModes = {
        classic = {
            name = "Classic",
            fillSpeed = 0.5,
            usesCrank = false,
            instantDeath = false
        },
        endless = {
            name = "Endless",
            fillSpeed = 0.5,
            usesCrank = true,
            instantDeath = false
        }
        -- Add more modes here
    }
}

-- Debug logging configuration
DEBUG = playdate.isSimulator

function debugPrint(...)
    if DEBUG then
        print(...)
    end
end

function debugTable(t, label)
    if DEBUG then
        print(label or "Table contents:")
        for k, v in pairs(t) do
            print(string.format("  %s: %s", k, tostring(v)))
        end
    end
end

return Config 