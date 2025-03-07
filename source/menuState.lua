import "CoreLibs/object"
import "CoreLibs/graphics"
import "scores"
import "config"

class('MenuState').extends()

local pd <const> = playdate
local gfx <const> = pd.graphics
local cfg <const> = Config

-- Add a static flag to track if menu has been set up
MenuState.menuInitialized = false

function MenuState:init()
    debugPrint("initializing menu state")
    self.titleFont = gfx.font.new("fonts/straight-120-all")
    self.selectedMode = "classic" -- Default mode
    self:setupMenuOptions()
    self:refreshHighScores()
end

function MenuState:setupMenuOptions()
    -- Only set up menu once across all instances
    if not MenuState.menuInitialized then
        debugPrint("Setting up menu options")
        local menu = pd.getSystemMenu()
        
        -- Clear any existing menu items
        menu:removeAllMenuItems()
        
        -- Add game mode menu
        local modes = {"Classic", "Endless"}
        menu:addOptionsMenuItem("Mode", modes, function(value)
            local newMode = value == "Classic" and "classic" or "endless"
            debugPrint("Mode selected from menu:", newMode)
            
            -- If we're in a game state (not menu state)
            if currentState and currentState.gameMode then
                -- Always show confirmation when changing modes during gameplay
                MenuState.pendingModeChange = newMode
                debugPrint("Showing mode change confirmation for:", newMode)
                
                -- Show confirmation dialog
                currentState.showConfirmation = true
                currentState.confirmationSelection = 1  -- Default to No
                currentState.confirmationType = "modeChange"
                currentState.confirmationMessage = "Change game mode? Current progress will be lost."
                return
            end
            
            -- If we're in the menu, apply the change immediately
            MenuState.selectedMode = newMode
            debugPrint("Applied mode change immediately:", newMode)
            
            -- Update the current instance if it exists
            if self and self.selectedMode then
                self.selectedMode = newMode
                self:refreshHighScores()
                
                -- Force a refresh of the menu state by recreating it
                if currentState and currentState == self then
                    switchState(MenuState())
                end
            end
            
            debugPrint("Selected mode:", MenuState.selectedMode)
        end)
        
        -- Add show percentage toggle
        menu:addCheckmarkMenuItem("Show %", cfg.showCurrentPercent, function(value)
            cfg.showCurrentPercent = value
        end)
        
        MenuState.menuInitialized = true
    end
    
    -- Update instance variable from static if needed
    if MenuState.selectedMode and self.selectedMode ~= MenuState.selectedMode then
        self.selectedMode = MenuState.selectedMode
    end
end

function MenuState:refreshHighScores()
    -- Refresh high scores for the selected mode
    debugPrint("Refreshing high scores for mode:", self.selectedMode)
    self.highScores = Scores.getHighScore(self.selectedMode) or {points = 0, perfectHits = 0, rounds = 0}
end

function MenuState:enter()
    debugPrint("entering menu state")
    gfx.sprite.removeAll()
    
    -- Refresh high scores when entering the menu
    self:refreshHighScores()
    
    -- Make sure menu options are set up
    self:setupMenuOptions()
end

function MenuState:update()
    gfx.clear()
    
    if pd.buttonJustPressed(pd.kButtonA) then
        -- Pass the selected mode to the game state
        switchState(GameState(self.selectedMode))
        return
    end
    
    gfx.pushContext()
    gfx.setFont(self.titleFont)
    gfx.drawTextAligned("99%", 200, 45, kTextAlignment.center)
    gfx.popContext()
    
    -- Show current mode
    local modeName = self.selectedMode == "classic" and "Classic Mode" or "Endless Mode"
    gfx.drawTextAligned(modeName, 200, 120, kTextAlignment.center)
    gfx.drawTextAligned("Stop the bar at the right percentage", 200, 140, kTextAlignment.center)
    
    -- Display high scores with nil checks
    local points = self.highScores.points or 0
    local perfectHits = self.highScores.perfectHits or 0
    local rounds = self.highScores.rounds or 0
    
    -- Show appropriate stats based on mode
    if self.selectedMode == "classic" then
        gfx.drawTextAligned("High Score: " .. points, 200, 160, kTextAlignment.center)
    else
        gfx.drawTextAligned("Best Accuracy: " .. points .. "%", 200, 160, kTextAlignment.center)
    end
    
    gfx.drawTextAligned("Perfect Hits: " .. perfectHits, 200, 175, kTextAlignment.center)
    gfx.drawTextAligned("Rounds: " .. rounds, 200, 190, kTextAlignment.center)
    
    gfx.drawTextAligned("Press A to start", 200, 220, kTextAlignment.center)
end

function MenuState:exit()
    debugPrint("exiting menu state")
    -- We'll keep the menu items when exiting
end 