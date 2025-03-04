import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "gameState"
import "menuState"
import "config"

local pd <const> = playdate
local gfx <const> = pd.graphics

local currentState = nil

-- Load font at startup
function pd.update()
    if not currentState then
        pd.init()
        return
    end
    
    pd.timer.updateTimers()
    gfx.sprite.update()
    
    if currentState and currentState.update then
        currentState:update()
    end
end

function switchState(newState)
    debugPrint("switching state to", newState)
    if currentState and currentState.exit then
        currentState:exit()
    end
    
    currentState = newState
    
    if currentState and currentState.enter then
        currentState:enter()
    end
end

function pd.init()
    debugPrint("initializing")
    gfx.setFont(gfx.font.new("fonts/topaz-serif-8"))
    gfx.setBackgroundColor(gfx.kColorWhite)
    switchState(MenuState())
end