import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "scores"
import "config"

class('GameState').extends()

local pd <const> = playdate
local gfx <const> = pd.graphics
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
    self.lastCrankPos = nil
    self.isWaitingForCrank = false
    self.millisBetweenRounds = 3000
    self:setupMenuOptions()
    self:startNewRound()
end

function GameState:setupMenuOptions()
    local menu = pd.getSystemMenu()
    
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
    self.isBarFilling = false
    self.fillSpeed = cfg.baseFillSpeed
    self.rounds = self.rounds + 1
    self.roundEndTime = nil
    self.crankUsedInRound = false
    self.lastCrankPos = pd.getCrankPosition()
    self.startingCrankPos = self.lastCrankPos
    self.wasCrankDocked = pd.isCrankDocked()
    
    -- Set a delay before starting to fill
    self.millisBeforeFilling = pd.getCurrentTimeMilliseconds() + 500  -- 500ms delay
    
    -- If crank is undocked, wait for rotation before filling
    self.isWaitingForCrank = not pd.isCrankDocked()
    
    -- Reset crank position
    pd.setCrankSoundsDisabled(true)
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
    if not pd.isCrankDocked() then
        self.roundEndTime = pd.getCurrentTimeMilliseconds() + self.millisBetweenRounds
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
    
    -- Check if it's time to start filling after delay
    if self.millisBeforeFilling and pd.getCurrentTimeMilliseconds() >= self.millisBeforeFilling then
        self.isBarFilling = true
        self.millisBeforeFilling = nil
    end
    
    -- Check if crank was just docked or undocked
    local isCrankDocked = pd.isCrankDocked()
    if isCrankDocked and not self.wasCrankDocked and self.isBarFilling then
        -- Crank was just docked while bar was filling - stop and wait for button press
        self.isWaitingForCrank = false
        self.isBarFilling = false
        self.roundEndTime = nil
    elseif not isCrankDocked and self.wasCrankDocked then
        -- Crank was just undocked
        if self.isBarFilling then
            -- During gameplay - switch to crank mode
            self.lastCrankPos = pd.getCrankPosition()
            self.startingCrankPos = self.lastCrankPos
            self.crankUsedInRound = false
            self.isWaitingForCrank = true
        elseif not self.isGameOver then
            -- At the end of a round - start a new round in crank mode
            self.roundEndTime = nil  -- Cancel any pending auto-start
            self:startNewRound()
        end
    end
    self.wasCrankDocked = isCrankDocked
    
    -- Handle A button press
    if pd.buttonJustPressed(pd.kButtonA) then
        if self.isGameOver then
            switchState(MenuState())
            return
        elseif self.isBarFilling and not self.isWaitingForCrank then
            self:checkScore()
        else
            self:startNewRound()
        end
    end
    
    -- Auto-progress to next round if timer is up
    if self.roundEndTime and not self.isBarFilling and not self.isGameOver then
        if pd.getCurrentTimeMilliseconds() >= self.roundEndTime then
            self:startNewRound()
            return
        end
    end
    
    -- Handle crank input if crank is not docked
    if not pd.isCrankDocked() and self.isBarFilling and not self.isGameOver then
        local currentCrankPos = pd.getCrankPosition()
        
        if self.lastCrankPos == nil then
            self.lastCrankPos = currentCrankPos
        end
        
        -- Calculate rotation direction (accounting for wrap-around)
        local diff = currentCrankPos - self.lastCrankPos
        if diff < -180 then diff = diff + 360 end
        if diff > 180 then diff = diff - 360 end
        
        -- Calculate angular distance from starting position (accounting for wrap-around)
        local distFromStart = currentCrankPos - self.startingCrankPos
        if distFromStart < -180 then distFromStart = distFromStart + 360 end
        if distFromStart > 180 then distFromStart = distFromStart - 360 end
        
        -- Detect significant movement
        if math.abs(diff) > 1 then
            -- Clockwise rotation (positive diff) - fills the bar
            if diff > 0 then
                self.crankUsedInRound = true
                self.isWaitingForCrank = false
                
                -- Speed based on clockwise distance from starting point (0-180 degrees)
                local clockwiseDistance = distFromStart >= 0 and distFromStart or (360 + distFromStart)
                local speedMultiplier = math.min(clockwiseDistance / 180, 1.0) * 2
                self.fillSpeed = cfg.baseFillSpeed * speedMultiplier
                
            -- Counter-clockwise rotation (negative diff) - slows the bar
            elseif diff < 0 and self.crankUsedInRound and not self.isWaitingForCrank then
                -- Reduce speed based on how close we are to starting position
                local clockwiseDistance = distFromStart >= 0 and distFromStart or (360 + distFromStart)
                local speedMultiplier = math.max(0.1, clockwiseDistance / 180)
                self.fillSpeed = cfg.baseFillSpeed * speedMultiplier
                
                -- Check if we've returned to starting position (with some tolerance)
                if math.abs(distFromStart) < 10 then
                    self:checkScore()
                end
            end
        end
        
        -- Update last position for next frame
        self.lastCrankPos = currentCrankPos
    end
    
    if self.isGameOver then
        self:drawGameOver()
    elseif self.isBarFilling then
        -- Only increment if not waiting for crank
        if not self.isWaitingForCrank then
            self.currentPercent = math.min(100, self.currentPercent + self.fillSpeed)
        end
        self:drawUI()
    else
        self:drawUI()
    end
end

function GameState:drawGameOver()
    gfx.drawTextAligned("Game Over!", 200, 80, kTextAlignment.center)
    gfx.drawTextAligned("Score: " .. self.score, 200, 110, kTextAlignment.right)
    gfx.drawTextAligned("Perfect: " .. self.perfectHits, 200, 130, kTextAlignment.center)
    gfx.drawTextAligned("Rounds: " .. self.rounds, 200, 150, kTextAlignment.center)
    
    if self.isNewHighScore then
        gfx.drawTextAligned("New High Score!", 200, 180, kTextAlignment.center)
    end
    
    gfx.drawTextAligned("Press A for menu", 200, 210, kTextAlignment.center)
end

function GameState:drawUI()
    local barWidth = 240
    local barHeight = 20
    local barX = 200 - barWidth/2
    local barY = 135
    local barRadius = 2
    
    -- Draw current percentage only if enabled
    if cfg.showCurrentPercent then
        gfx.drawText("Current: " .. math.floor(self.currentPercent) .. "%", 20, 80)
    end
    gfx.setFont(gfx.font.new("fonts/straight-120-all"))
    gfx.drawTextAligned(self.targetPercent .. "%", 200, 45, kTextAlignment.center)
    gfx.setFont(gfx.font.new("fonts/topaz-11"))
    gfx.drawTextAligned("Score: " .. self.score, 399, 1, kTextAlignment.right)
    
    -- Draw the progress bar
    gfx.drawRoundRect(barX, barY, barWidth, barHeight, barRadius)
    gfx.fillRoundRect(barX, barY, barWidth * (self.currentPercent/100), barHeight, barRadius)
    
    -- Show appropriate instructions based on state
    if not self.isBarFilling and not self.isGameOver then
        if self.millisBeforeFilling then
            -- We're in the delay period before starting
            gfx.drawTextAligned("Get ready...", 200, 200, kTextAlignment.center)
        else
            -- Display the achieved percentage below the progress bar
            local achievedX = barX + (barWidth * (self.currentPercent/100))
            -- Ensure the text stays within screen bounds
            achievedX = math.max(barX + 10, math.min(achievedX, barX + barWidth - 30))
            gfx.drawTextAligned(math.floor(self.currentPercent) .. "%", achievedX, barY + barHeight + 10, kTextAlignment.center)
            
            if not pd.isCrankDocked() then
                -- Show countdown to next round
                if self.roundEndTime then
                    local timeLeft = math.ceil((self.roundEndTime - pd.getCurrentTimeMilliseconds()) / 1000)
                    gfx.drawTextAligned("Next round in " .. timeLeft .. "...", 200, 200, kTextAlignment.center)
                end
            else
                gfx.drawTextAligned("Press A to continue", 200, 200, kTextAlignment.center)
            end
        end
    elseif self.isBarFilling then
        if self.isWaitingForCrank then
            gfx.drawTextAligned("Turn crank clockwise to start", 200, 200, kTextAlignment.center)
        elseif pd.isCrankDocked() then
            gfx.drawTextAligned("Press A to stop", 200, 200, kTextAlignment.center)
        end
    end
    
    -- Draw crank indicator if crank is not docked and bar is filling
    if not pd.isCrankDocked() and self.isBarFilling then
        gfx.drawTextAligned("Turn crank to begin", 200, 175, kTextAlignment.center)
    end
end

function GameState:exit()
    debugPrint("exiting game state")
    -- Clean up menu items when exiting
    pd.getSystemMenu():removeAllMenuItems()
end 