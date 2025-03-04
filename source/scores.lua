import "CoreLibs/object"

Scores = {}

-- Initialize default high scores for each game mode
local function getDefaultScores()
    return {
        classic = {
            points = 0,
            perfectHits = 0,
            rounds = 0
        }
        -- Add more game modes here as needed
    }
end

-- Load scores from datastore or create default if none exist
function Scores.load()
    local scores = playdate.datastore.read()
    if not scores then
        scores = getDefaultScores()
        playdate.datastore.write(scores)
    end
    return scores
end

-- Save new high score if better than current
function Scores.checkAndSaveHighScore(mode, points, perfectHits, rounds)
    local scores = Scores.load()
    local modeScores = scores[mode]
    
    -- Update if points are higher
    if points > modeScores.points then
        modeScores.points = points
        modeScores.perfectHits = perfectHits
        modeScores.rounds = rounds
        playdate.datastore.write(scores)
        return true
    end
    
    return false
end

-- Get high scores for a specific mode
function Scores.getHighScore(mode)
    local scores = Scores.load()
    return scores[mode]
end

return Scores 