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

-- Save scores to datastore
function Scores.saveScores()
    playdate.datastore.write(Scores.data)
end

-- Initialize the scores data structure if it doesn't exist
if not Scores.data then
    Scores.data = {}
end

-- Make sure Scores.maxScores is defined
if not Scores.maxScores then
    Scores.maxScores = 10  -- Default to 10 high scores
end

-- Save new high score if better than current
function Scores.checkAndSaveHighScore(mode, score, perfectHits, rounds)
    debugPrint("Checking high score for mode:", mode, "Score:", score)
    
    -- Ensure data table exists
    if not Scores.data then
        Scores.data = {}
    end
    
    -- Initialize scores for this mode if they don't exist yet
    if not Scores.data[mode] then
        Scores.data[mode] = {}
    end
    
    -- Make sure maxScores is defined
    if not Scores.maxScores then
        Scores.maxScores = 10  -- Default to 10 high scores
    end
    
    local modeScores = Scores.data[mode]
    local isNewHighScore = false
    
    -- Get current date in a simple format
    local currentTime = playdate.getTime()
    local dateString = string.format("%d-%02d-%02d", currentTime.year, currentTime.month, currentTime.day)
    
    -- Create new score entry with mode-specific data
    local newScore = {
        score = score or 0,  -- Ensure score is never nil
        perfectHits = perfectHits or 0,
        date = dateString
    }
    
    -- Add mode-specific data
    if mode == "classic" then
        newScore.rounds = rounds or 0
        newScore.points = score or 0  -- In classic mode, score is points
    elseif mode == "endless" then
        -- For endless mode, we only care about perfect hits
        newScore.perfectHits = perfectHits or 0
    else
        -- For other modes, include rounds
        newScore.rounds = rounds or 0
    end
    
    -- Always add the score first
    table.insert(modeScores, newScore)
    
    -- Define a safe comparison function
    local function safeCompare(a, b)
        local scoreA = a and a.score or 0
        local scoreB = b and b.score or 0
        return scoreA > scoreB
    end
    
    -- Sort scores (highest first) using the safe comparison
    table.sort(modeScores, safeCompare)
    
    -- Check if this is a new high score (it's in the top maxScores)
    local maxScores = Scores.maxScores or 10  -- Use default if nil
    for i = 1, math.min(maxScores, #modeScores) do
        if modeScores[i] == newScore then
            isNewHighScore = true
            break
        end
    end
    
    -- Trim to max scores
    while #modeScores > (Scores.maxScores or 10) do
        table.remove(modeScores)
    end
    
    -- Save scores to disk
    Scores.saveScores()
    
    return isNewHighScore
end

-- Get high scores for a specific mode
function Scores.getHighScore(mode)
    local scores = Scores.load()
    return scores[mode]
end

-- Update the display function to show mode-specific information
function Scores.drawScoreList(mode)
    local scores = Scores.data[mode] or {}
    local y = 60
    
    -- Draw header based on mode
    if mode == "classic" then
        gfx.drawTextAligned("Rank", 50, 40, kTextAlignment.center)
        gfx.drawTextAligned("Points", 150, 40, kTextAlignment.center)
        gfx.drawTextAligned("Rounds", 250, 40, kTextAlignment.center)
        gfx.drawTextAligned("Perfect", 350, 40, kTextAlignment.center)
    elseif mode == "endless" then
        gfx.drawTextAligned("Rank", 50, 40, kTextAlignment.center)
        gfx.drawTextAligned("Accuracy", 150, 40, kTextAlignment.center)
        gfx.drawTextAligned("Perfect", 250, 40, kTextAlignment.center)
        gfx.drawTextAligned("Rounds", 350, 40, kTextAlignment.center)
    else
        gfx.drawTextAligned("Rank", 50, 40, kTextAlignment.center)
        gfx.drawTextAligned("Score", 150, 40, kTextAlignment.center)
        gfx.drawTextAligned("Rounds", 250, 40, kTextAlignment.center)
        gfx.drawTextAligned("Date", 350, 40, kTextAlignment.center)
    end
    
    -- Draw divider line
    gfx.drawLine(20, 55, 380, 55)
    
    -- Draw scores
    for i, score in ipairs(scores) do
        if mode == "classic" then
            gfx.drawTextAligned("#" .. i, 50, y, kTextAlignment.center)
            gfx.drawTextAligned(score.score, 150, y, kTextAlignment.center)
            gfx.drawTextAligned(score.rounds or "-", 250, y, kTextAlignment.center)
            gfx.drawTextAligned(score.perfectHits or "-", 350, y, kTextAlignment.center)
        elseif mode == "endless" then
            gfx.drawTextAligned("#" .. i, 50, y, kTextAlignment.center)
            gfx.drawTextAligned(score.score .. "%", 150, y, kTextAlignment.center)
            gfx.drawTextAligned(score.perfectHits or "-", 250, y, kTextAlignment.center)
            gfx.drawTextAligned(score.rounds or "-", 350, y, kTextAlignment.center)
        else
            gfx.drawTextAligned("#" .. i, 50, y, kTextAlignment.center)
            gfx.drawTextAligned(score.score, 150, y, kTextAlignment.center)
            gfx.drawTextAligned(score.rounds or "-", 250, y, kTextAlignment.center)
            gfx.drawTextAligned(score.date or "-", 350, y, kTextAlignment.center)
        end
        y = y + 20
    end
    
    -- If no scores yet
    if #scores == 0 then
        gfx.drawTextAligned("No scores yet!", 200, 100, kTextAlignment.center)
    end
end

return Scores
