import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "scores"
import "config"

class('GameState').extends()

local gfx <const> = playdate.graphics
local Config <const> = Config
local cfg <const> = Config

function GameState:init()
    debugPrint("initializing game state")
    self.score = 0
    self.perfectHits = 0
    self.rounds = 0
    self.gameMode = "classic"
    self.roundEndTime = nil
    self.crankUsedInRound = false
    self:setupMenuOptions()
    self:startNewRound()
end

function GameState:setupMenuOptions()
    local menu = playdate.getSystemMenu()
    
    -- Add game mode menu
    local modes = {"Classic", "Precision"}
    menu:addOptionsMenuItem("Mode", modes, function(value)
        if value == "Classic" then
            self.gameMode = "classic"
        else
            self.gameMode = "precision"
        end
        self:startNewRound()
    end)
    
    -- Add show percentage toggle
    menu:addCheckmarkMenuItem("Show %", cfg.showCurrentPercent, function(value)
        cfg.showCurrentPercent = value
    end)
end

function GameState:startNewRound()
    debugPrint("starting new round")
    self.targetPercent = math.random(10, 90)
    self.currentPercent = 0
    self.isBarFilling = true
    self.fillSpeed = cfg.baseFillSpeed
    self.rounds = self.rounds + 1
    self.roundEndTime = nil
    self.crankUsedInRound = false
    
    -- Reset crank position
    playdate.setCrankSoundsDisabled(true)
end

function GameState:checkScore()
    debugPrint("checking score")
    self.isBarFilling = false
    local difference = math.abs(self.currentPercent - self.targetPercent)
    
    debugPrint("Current:", self.currentPercent, "Target:", self.targetPercent, "Difference:", difference)
    
    if difference == 0 then
        debugPrint("Perfect hit!")
        self.score = self.score + 10
        self.perfectHits = self.perfectHits + 1
    elseif difference <= 2 then
        debugPrint("Great hit!")
        self.score = self.score + 4
    elseif difference <= 5 then
        debugPrint("Good hit!")
        self.score = self.score + 1
    else
        debugPrint("Miss!")
        -- Game over if we're in instant death mode
        local gameMode = cfg.gameModes[self.gameMode]
        if gameMode and gameMode.instantDeath then
            self:gameOver()
            return
        end
    end
    
    -- Set timer for auto-progression if crank is undocked
    if not playdate.isCrankDocked() then
        self.roundEndTime = playdate.getCurrentTimeMilliseconds() + 1500 -- 1.5 second pause
    end
    
    debugPrint("Score is now:", self.score)
end

function GameState:gameOver()
    -- Check and save high score
    debugPrint("game over")
    local isNewHighScore = Scores.checkAndSaveHighScore(
        self.gameMode,
        self.score,
        self.perfectHits,
        self.rounds
    )
    
    -- Show game over screen
    self.isGameOver = true
    self.isNewHighScore = isNewHighScore
end

function GameState:update()
    gfx.clear()
    
    -- Handle A button press
    if playdate.buttonJustPressed(playdate.kButtonA) then
        if self.isGameOver then
            switchState(MenuState())
            return
        elseif self.isBarFilling then
            self:checkScore()
        else
            self:startNewRound()
        end
    end
    
    -- Auto-progress to next round if timer is up
    if self.roundEndTime and not self.isBarFilling and not self.isGameOver then
        if playdate.getCurrentTimeMilliseconds() >= self.roundEndTime then
            self:startNewRound()
            return
        end
    end
    
    -- Handle crank input if crank is not docked
    if not playdate.isCrankDocked() and self.isBarFilling and not self.isGameOver then
        local crankPos = playdate.getCrankPosition()
        local crankChange = playdate.getCrankChange()
        
        -- Mark that crank has been used in this round if there's significant movement
        if math.abs(crankChange) > 1 then
            self.crankUsedInRound = true
        end
        
        -- Only check for stopping at 0 degrees if the crank has been used in this round
        if self.crankUsedInRound and crankPos <= 5 then
            -- Near 0 degrees, stop the bar
            self:checkScore()
        else
            -- Otherwise adjust fill speed based on crank position
            -- Map 0-180 degrees to 0-2x base speed
            local speedMultiplier = math.min(crankPos / 180, 1.0) * 2
            self.fillSpeed = cfg.baseFillSpeed * speedMultiplier
        end
    end
    
    if self.isGameOver then
        self:drawGameOver()
    elseif self.isBarFilling then
        self.currentPercent = math.min(100, self.currentPercent + self.fillSpeed)
        self:drawUI()
    else
        self:drawUI()
    end
end

function GameState:drawGameOver()
    gfx.drawTextAligned("Game Over!", 200, 80, kTextAlignment.center)
    gfx.drawTextAligned("Score: " .. self.score, 200, 110, kTextAlignment.center)
    gfx.drawTextAligned("Perfect: " .. self.perfectHits, 200, 130, kTextAlignment.center)
    gfx.drawTextAligned("Rounds: " .. self.rounds, 200, 150, kTextAlignment.center)
    
    if self.isNewHighScore then
        gfx.drawTextAligned("New High Score!", 200, 180, kTextAlignment.center)
    end
    
    gfx.drawTextAligned("Press A for menu", 200, 210, kTextAlignment.center)
end

function GameState:drawUI()
    local barWidth = 200
    local barHeight = 20
    local barX = 200 - barWidth/2
    local barY = 120
    
    -- Draw current percentage only if enabled
    if cfg.showCurrentPercent then
        gfx.drawText("Current: " .. math.floor(self.currentPercent) .. "%", 20, 80)
    end
    gfx.drawText("Target: " .. self.targetPercent .. "%", 20, 20)
    gfx.drawText("Score: " .. self.score, 20, 40)
    gfx.drawText("Perfect: " .. self.perfectHits, 20, 60)
    
    -- Draw the progress bar
    gfx.drawRect(barX, barY, barWidth, barHeight)
    gfx.fillRect(barX, barY, barWidth * (self.currentPercent/100), barHeight)
    
    -- Show appropriate instructions based on state
    if not self.isBarFilling and not self.isGameOver then
        if not playdate.isCrankDocked() then
            -- Show countdown to next round
            if self.roundEndTime then
                local timeLeft = math.ceil((self.roundEndTime - playdate.getCurrentTimeMilliseconds()) / 1000)
                gfx.drawTextAligned("Next round in " .. timeLeft .. "...", 200, 180, kTextAlignment.center)
            end
        else
            gfx.drawTextAligned("Press A to continue", 200, 180, kTextAlignment.center)
        end
    end
    
    -- Draw crank indicator if crank is not docked and bar is filling
    if not playdate.isCrankDocked() and self.isBarFilling then
        if not self.crankUsedInRound then
            gfx.drawTextAligned("Turn crank to begin", 200, 160, kTextAlignment.center)
        else
            gfx.drawTextAligned("Crank to adjust speed", 200, 160, kTextAlignment.center)
            gfx.drawTextAligned("Return to 0° to stop", 200, 180, kTextAlignment.center)
        end
    end
end

function GameState:exit()
    debugPrint("exiting game state")
    -- Clean up menu items when exiting
    playdate.getSystemMenu():removeAllMenuItems()
end 