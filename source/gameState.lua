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

function GameState:init(mode)
    debugPrint("initializing game state")
    self.gameMode = mode or "classic"
    self.points = cfg.startingPoints or 5  -- Default to 5 if not configured
    self.score = 0
    self.perfectHits = 0
    self.totalStops = 0  -- Add counter for total stops
    self.rounds = 0
    self.roundEndTime = nil
    self.crankUsedInRound = false
    self.lastCrankPos = nil
    self.isWaitingForCrank = false
    self.millisBetweenRounds = 3000
    self.showConfirmation = false
    self.confirmationSelection = 1  -- 1 = No, 2 = Yes
    self:startNewRound()
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
    debugPrint("Current game mode:", self.gameMode)  -- Add this debug line
    
    -- Increment total stops counter for all modes
    self.totalStops = self.totalStops + 1
    
    if self.gameMode == "classic" then
        -- Classic mode scoring
        if difference == 0 then
            debugPrint("Perfect hit!")
            self.points = self.points + 2
            self.perfectHits = self.perfectHits + 1
        elseif difference <= (cfg.closeThreshold or 1) then
            debugPrint("Close hit!")
            self.points = self.points + 1
        else
            debugPrint("Miss!")
            self.points = self.points - 1
        end
        
        -- Check if player ran out of points
        if self.points <= 0 then
            self:gameOver()
            return
        end
    else
        -- Endless mode scoring (percentage accuracy)
        debugPrint("Using endless mode scoring")
        if difference == 0 then
            debugPrint("Perfect hit!")
            self.perfectHits = self.perfectHits + 1
        end
        
        -- Calculate percentage accuracy
        self.score = math.floor((self.perfectHits / self.totalStops) * 10000) / 100
        debugPrint("Accuracy:", self.score, "%")
    end
    
    -- Set timer for next round if crank is not docked
    if not pd.isCrankDocked() then
        self.roundEndTime = pd.getCurrentTimeMilliseconds() + 3000  -- 3 seconds
    end
    
    debugPrint("Score is now:", self.score)
    debugPrint("Points are now:", self.points)
end

function GameState:gameOver()
    -- Check and save high score
    debugPrint("game over")
    debugPrint("Game over in mode:", self.gameMode)
    
    -- For classic mode, use points as the score
    local finalScore
    if self.gameMode == "classic" then
        finalScore = self.points
    else
        finalScore = self.score  -- For endless, this is the percentage accuracy
    end
    
    local isNewHighScore = Scores.checkAndSaveHighScore(
        self.gameMode,
        finalScore,
        self.perfectHits,
        self.rounds
    )
    
    -- Show game over screen
    self.isGameOver = true
    self.isNewHighScore = isNewHighScore
end

function GameState:showModeChangeConfirmation()
    -- Set up confirmation dialog for mode change
    self.showConfirmation = true
    self.confirmationSelection = 1  -- Default to No
    self.confirmationType = "modeChange"
    self.confirmationMessage = "Change game mode? Current progress will be lost."
end

function GameState:update()
    gfx.clear()
    
    -- Handle confirmation overlay if active
    if self.showConfirmation then
        if pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight) then
            -- Toggle between Yes and No
            self.confirmationSelection = self.confirmationSelection == 1 and 2 or 1
        elseif pd.buttonJustPressed(pd.kButtonA) then
            if self.confirmationSelection == 2 then  -- Yes selected
                if self.confirmationType == "modeChange" and MenuState.pendingModeChange then
                    debugPrint("Changing mode to:", MenuState.pendingModeChange)
                    
                    -- Save high score for current mode before changing
                    local finalScore
                    if self.gameMode == "classic" then
                        finalScore = self.points
                    else
                        finalScore = self.score
                    end
                    
                    Scores.checkAndSaveHighScore(
                        self.gameMode,
                        finalScore,
                        self.perfectHits,
                        self.rounds
                    )
                    
                    -- Update the selected mode
                    MenuState.selectedMode = MenuState.pendingModeChange
                    
                    -- Clear pending mode change
                    MenuState.pendingModeChange = nil
                    
                    -- Return to menu with new mode selected
                    switchState(MenuState())
                    return
                else
                    -- Regular exit confirmation
                    switchState(MenuState())
                    return
                end
            end
            -- Hide confirmation dialog
            self.showConfirmation = false
        elseif pd.buttonJustPressed(pd.kButtonB) then
            -- Cancel confirmation
            self.showConfirmation = false
            -- Reset menu selection if this was a mode change
            if self.confirmationType == "modeChange" then
                local menu = pd.getSystemMenu()
                local currentModeIndex
                if self.gameMode == "classic" then
                    currentModeIndex = 1
                else
                    currentModeIndex = 2
                end
                menu:setOptionsMenuItem("Mode", currentModeIndex)
                MenuState.pendingModeChange = nil
            end
        end
        
        self:drawConfirmationOverlay()
        return
    end
    
    -- Check if B button is pressed to show confirmation
    if pd.buttonJustPressed(pd.kButtonB) then
        self.showConfirmation = true
        self.confirmationSelection = 1  -- Default to "No"
        return
    end
    
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
        -- Don't allow starting a new round during the millisBeforeFilling period
        if self.millisBeforeFilling then
            return
        end
        
        if self.isGameOver then
            switchState(MenuState())
            return
        elseif not self.isBarFilling then
            -- Start a new round if we're not already filling
            if not pd.isCrankDocked() and self.roundEndTime and pd.getCurrentTimeMilliseconds() < self.roundEndTime then
                -- Don't start a new round if we're still in the countdown period
                return
            end
            self:startNewRound()
        elseif pd.isCrankDocked() then
            -- Stop the bar if A is pressed and crank is docked
            self:checkScore()
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

function GameState:drawGame()
    -- Move all drawing code here from update
    -- ... existing drawing code ...
    self:drawUI()
    -- ... existing drawing code ...
end

function GameState:drawGameOver()
    gfx.drawTextAligned("Game Over!", 200, 80, kTextAlignment.center)
    
    if self.gameMode == "classic" then
        gfx.drawTextAligned("Final Points: " .. self.points, 200, 110, kTextAlignment.center)
    else
        gfx.drawTextAligned("Accuracy: " .. self.score .. "%", 200, 110, kTextAlignment.center)
    end
    
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
        gfx.drawText("Current: " .. math.floor(self.currentPercent) .. "%", 1, 1)
    end
    
    -- Draw target percentage
    gfx.setFont(gfx.font.new("fonts/straight-120-all"))
    gfx.drawTextAligned(self.targetPercent .. "%", 200, 45, kTextAlignment.center)
    gfx.setFont(gfx.font.new("fonts/topaz-11"))
    
    -- Draw score or points based on game mode
    if self.gameMode == "classic" then
        gfx.drawTextAligned("Points: " .. self.points, 399, 1, kTextAlignment.right)
        gfx.drawTextAligned("Rounds: " .. self.rounds, 399, 15, kTextAlignment.right)
    else
        gfx.drawTextAligned("Accuracy: " .. self.score .. "%", 399, 1, kTextAlignment.right)
        gfx.drawTextAligned("Perfect: " .. self.perfectHits .. "/" .. self.totalStops, 399, 15, kTextAlignment.right)
    end
    
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
        else
            -- In crank mode, don't show "Press A to stop"
            gfx.drawTextAligned("Return crank to stop", 200, 200, kTextAlignment.center)
        end
    end
    
    -- Draw crank indicator if crank is not docked and bar is filling
    if not pd.isCrankDocked() and self.isBarFilling then
        gfx.drawTextAligned("Turn crank to begin", 200, 175, kTextAlignment.center)
    end
end

function GameState:drawConfirmationOverlay()
    -- Dim the background
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5)
    gfx.fillRect(0, 0, 400, 240)
    
    -- Draw confirmation box
    gfx.setColor(gfx.kColorWhite)
    local boxWidth = 240
    local boxHeight = 100
    local boxX = 200 - boxWidth/2
    local boxY = 120 - boxHeight/2
    gfx.fillRoundRect(boxX, boxY, boxWidth, boxHeight, 4)
    
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(boxX, boxY, boxWidth, boxHeight, 4)
    
    -- Show appropriate message based on confirmation type
    local message
    if self.confirmationType == "modeChange" then
        message = self.confirmationMessage
    else
        message = "You a chicken, McFly?"
    end
    
    gfx.drawTextAligned(message, 200, boxY + 20, kTextAlignment.center)
    
    -- Draw options
    local noX = boxX + 60
    local yesX = boxX + boxWidth - 60
    local optionsY = boxY + boxHeight - 40
    
    -- Highlight selected option
    if self.confirmationSelection == 1 then
        -- No is selected
        gfx.fillRoundRect(noX - 30, optionsY - 10, 60, 30, 3)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawTextAligned("No", noX, optionsY, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.drawTextAligned("Yes", yesX, optionsY, kTextAlignment.center)
    else
        -- Yes is selected
        gfx.fillRoundRect(yesX - 30, optionsY - 10, 60, 30, 3)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.drawTextAligned("No", noX, optionsY, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawTextAligned("Yes", yesX, optionsY, kTextAlignment.center)
    end
    
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GameState:exit()
    debugPrint("exiting game state")
    -- Don't remove menu items here, let MenuState handle it
    -- pd.getSystemMenu():removeAllMenuItems()
end
