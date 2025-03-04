import "CoreLibs/object"
import "CoreLibs/graphics"
import "scores"

class('MenuState').extends()

local gfx <const> = playdate.graphics

function MenuState:init()
    debugPrint("initializing menu state")
    self.titleFont = gfx.font.new("fonts/topaz-11")
    self.highScores = Scores.getHighScore("classic")
end

function MenuState:enter()
    debugPrint("entering menu state")
    gfx.sprite.removeAll()
end

function MenuState:update()
    gfx.clear()
    
    if playdate.buttonJustPressed(playdate.kButtonA) then
        switchState(GameState())
        return
    end
    
    gfx.pushContext()
    gfx.setFont(self.titleFont)
    gfx.drawTextAligned("=== B A R C E N T ===", 200, 80, kTextAlignment.center)
    gfx.popContext()
    
    gfx.drawTextAligned("Match the percentage", 200, 140, kTextAlignment.center)
    
    -- Display high scores
    gfx.drawTextAligned("High Score: " .. self.highScores.points, 200, 160, kTextAlignment.center)
    gfx.drawTextAligned("Perfect Hits: " .. self.highScores.perfectHits, 200, 175, kTextAlignment.center)
    gfx.drawTextAligned("Rounds: " .. self.highScores.rounds, 200, 190, kTextAlignment.center)
    
    gfx.drawTextAligned("Press A to start", 200, 220, kTextAlignment.center)
end

function MenuState:exit()
    debugPrint("exiting menu state")
end 