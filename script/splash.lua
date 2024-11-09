--only you can prevent vbuck scams

--[[
todo: 
    make this only happen when you load in from the menu, not on restart
    make the three dots to dot stuff
    add more screens
]]

function init()
    played = false
    timer = 0
    random_screen = 0--math.random(0,number of total screens) --CHANGE WHEN ADDING NEW SCREENS

    start_cue = LoadSound("MOD/snd/game_start_cue.ogg")
end

function tick(dt)
    timer = timer + dt

    if not played and timer > 0.3 then
        played = true
        PlaySound(start_cue, GetPlayerTransform().pos, 0.5)
    end
end

function draw()
    if timer < 5 then
        UiMakeInteractive()
        
        UiPush()
            UiColor(0, 0, 0)
            UiRect(UiWidth(), UiHeight())
        UiPop()

        UiPush()
            UiTranslate(UiCenter(), UiMiddle())
	        UiAlign("center middle")
            UiImage("MOD/img/loading_screens/reload"..random_screen..".png")
        UiPop()
    end
end