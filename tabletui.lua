local modem = peripheral.wrap("modem")

local progSettings = {
    listenChannel     = 77,
    mobSpawnerChannel = 3467
}
local progState = {
    tab             = "mob",
    repaint         = true,
    unhandledEvents = {}
}

function saveSettings()
    local file = fs.open("settings.json", "w")
    file.write(textutils.serializeJSON(progSettings))
    file.close()
end

function loadSettings()
    local file = fs.open("settings.json", "r")
    if not file then
        saveSettings()
        return
    end
    local readSettings = textutils.unserializeJSON(file.readAll())
    file.close()
    progSettings.listenChannel     = readSettings.listenChannel or progSettings.listenChannel
    progSettings.mobSpawnerChannel = readSettings.mobSpawnerChannel or progSettings.mobSpawnerChannel
end

function pullEvent()
    if #progState.unhandledEvents > 0 then
        return table.remove(progState.unhandledEvents, 1)
    end

    return { os.pullEvent() }
end

loadSettings()
modem.open(progSettings.listenChannel)

local mobSpawner

mobSpawner = {
    settings = {
        playerName = "",
        forced     = false,
        enabled    = false
    },
    state = {
        playerOnline = false,
        enabled      = false
    },

    uiState = {
        requestTimerID    = nil,
        alive             = false,
        inSettings        = false,
        selectedTextField = nil,
        cursorPos         = 0,
        viewPos           = 0,
        curText           = ""
    },

    sendCommand = function(command)
        if not mobSpawner.uiState.alive then
            return nil, nil
        end

        modem.transmit(progSettings.mobSpawnerChannel, progSettings.listenChannel, command)
        local timeoutTimerID = os.createTimer(0.5)
        while true do
            local eventData = { os.pullEvent() }
            if eventData[1] == "modem_message" and eventData[3] == progSettings.listenChannel then
                os.cancelTimer(timeoutTimerID)
                return eventData[4], eventData[5]
            elseif eventData[1] == "timer" and eventData[2] == timeoutTimerID then
                return nil, nil
            end
            table.insert(progState.unhandledEvents, eventData)
        end
    end,
    getState = function()
        local replyChannel, message = mobSpawner.sendCommand("getState")
        local recState = textutils.unserialize(message)
        mobSpawner.state.playerOnline = recState.playerOnline or mobSpawner.state.playerOnline
        mobSpawner.state.enabled      = recState.enabled      or mobSpawner.state.enabled
        return true
    end,
    getSettings = function()
        local replyChannel, message = mobSpawner.sendCommand("getSettings")
        local recSettings = texutils.unserialize(message)
        mobSpawner.settings.playerName = recState.playerName or mobSpawner.settings.playerName
        mobSpawner.settings.forced     = recState.forced     or mobSpawner.settings.forced
        mobSpawner.settings.enabled    = recState.enabled    or mobSpawner.settings.enabled
        return true
    end,
    setPlayerName = function(newPlayerName)
        local replyChannel, message = mobSpawner.sendCommand(string.format("setPlayerName:%s", newPlayerName))
        if message == "changed" then
            mobSpawner.settings.playerName = newPlayerName
            return true
        end
        return false
    end,
    setChannel = function(newChannel)
        local replyChannel, message = mobSpawner.sendCommand(string.format("setChannel:%d", newChannel))
        if message == "changed" then
            progSettings.mobSpawnerChannel = newChannel
            saveSettings()
            return true
        end
        return false
    end,
    forceEnable = function()
        local replyChannel, message = mobSpawner.sendCommand("enable")
        if message == "enabled" then
            mobSpawner.settings.forced  = true
            mobSpawner.settings.enabled = true
            return true
        end
        return false
    end,
    forceDisabled = function()
        local replyChannel, message = mobSpawner.sendCommand("disable")
        if message == "disabled" then
            mobSpawner.settings.forced  = true
            mobSpawner.settings.enabled = false
            return true
        end
        return false
    end,
    unforce = function()
        local replyChannel, message = mobSpawner.sendCommand("unforce")
        if message == "enabled" or message == "disabled" then
            mobSpawner.settings.forced  = false
            mobSpawner.settings.enabled = false
            mobSpawner.state.enabled    = message == "enabled"
            return true
        end
        return false
    end,

    getTextfieldY = function()
        if mobSpawner.uiState.selectedTextField == "playername" then
            return 2
        elseif mobSpawner.uiState.selectedTextField == "channel" then
            return 5
        end
    end,
    drawTextfield = function(y, text, viewPos)
        paintutils.drawLine(1, y, 15, y, colors.gray)
        term.setCursorPos(1, y)
        term.setTextColor(colors.white)
        term.write(string.sub(text, viewPos + 1, viewPos + 15))
    end,
    onStart = function()
        mobSpawner.uiState.requestTimerID = os.startTimer(1)
    end,
    onEnd = function()
        os.cancelTimer(mobSpawner.uiState.requestTimerID)
    end,
    onDraw = function()
        if mobSpawner.uiState.alive then
            paintutils.drawFilledBox(1, 1, 26, 18, colors.black)
        else
            paintutils.drawFilledBox(1, 1, 26, 18, colors.red)
        end

        -- Draw settings button
        paintutils.drawBox(17, 1, 26, 3, colors.white)
        paintutils.drawLine(18, 2, 25, 2, colors.black)
        term.setCursorPos(18, 2)
        if mobSpawner.uiState.inSettings then
            term.setTextColor(colors.orange)
        else
            term.setTextColor(colors.white)
        end
        term.write("Settings")

        if mobSpawner.uiState.inSettings then
            -- Draw Player Name
            term.setCursorPos(1, 1)
            term.setTextColor(colors.white)
            term.write("Player Name:")

            if mobSpawner.uiState.selectedTextField == "playername" then
                mobSpawner.drawTextfield(2, mobSpawner.uiState.curText, mobSpawner.uiState.viewPos)
            else
                mobSpawner.drawTextfield(2, mobSpawner.settings.playerName, 0)
            end

            -- Draw Channel
            term.setCursorPos(1, 4)
            term.setTextColor(colors.white)
            term.write("Channel:")

            if mobSpawner.uiState.selectedTextField == "channel" then
                mobSpawner.drawTextfield(5, mobSpawner.uiState.curText, mobSpawner.uiState.viewPos)
            else
                mobSpawner.drawTextfield(5, tostring(mobSpawner.settings.listenChannel), 0)
            end

            if mobSpawner.uiState.selectedTextField == "playername" then
                term.setCursorBlink(true)
                term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, 2)
            elseif mobSpawner.uiState.selectedTextField == "channel" then
                term.setCursorBlink(true)
                term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, 5)
            else
                term.setCursorBlink(false)
            end
        else
            -- Draw enabled state
            paintutils.drawBox(1, 1, 13, 3, colors.white)
            if mobSpawner.state.enabled then
                paintutils.drawLine(2, 2, 12, 2, colors.lime)
                term.setCursorPos(6, 2)
                term.setTextColor(colors.white)
                term.write("On")
            else
                paintutils.drawLine(2, 2, 12, 2, colors.red)
                term.setCursorPos(5, 2)
                term.setTextColor(colors.white)
                term.write("Off")
            end

            -- Draw forced state
            paintutils.drawBox(1, 5, 13, 7, colors.white)
            if mobSpawner.settings.forced then
                if mobSpawner.settings.enabled then
                    paintutils.drawLine(2, 6, 12, 6, colors.lime)
                    term.setCursorPos(2, 6)
                    term.setTextColor(colors.white)
                    term.write("Forced On")
                else
                    paintutils.drawLine(2, 6, 12, 6, colors.red)
                    term.setCursorPos(2, 6)
                    term.setTextColor(colors.white)
                    term.write("Forced Off")
                end
            else
                paintutils.drawLine(2, 6, 12, 6, colors.lightGray)
                term.setCursorPos(5, 6)
                term.setTextColor(colors.black)
                term.write("Auto")
            end

            -- Draw player state
            paintutils.drawBox(1, 9, 17, 11, colors.white)
            if mobSpawner.state.playerOnline then
                paintutils.drawLine(2, 10, 16, 10, colors.lime)
                term.setCursorPos(2, 10)
                term.setTextColor(colors.white)
                term.write("Player Online")
            else
                paintutils.drawLine(2, 10, 16, 10, colors.red)
                term.setCursorPos(2, 10)
                term.setTextColor(colors.white)
                term.write("Player Offline")
            end
        end
    end,
    onEvent = function(event, eventData)
        if event == "timer" then
            if eventData[2] == mobSpawner.uiState.requestTimerID then
                local isOpen = modem.isOpen(progSettings.mobSpawnerChannel)
                if isOpen then
                    mobSpawnerAlive = true
                    getState()
                    getSettings()
                    progState.repaint = true
                else
                    mobSpawnerAlive   = false
                    progState.repaint = true
                end
                mobSpawner.uiState.requestTimerID = os.startTimer(1)
            end
        elseif event == "mouse_click" then
            if eventData[2] ~= 1 then return end

            -- Settings button
            if eventData[3] >= 17 and eventData[3] <= 26 and eventData[4] >= 1 and eventData[4] <= 3 then
                mobSpawner.uiState.inSettings = ~mobSpawner.uiState.inSettings
                progState.repaint = true
            elseif not mobSpawner.uiState.inSettings then
                if eventData[3] >= 1 and eventData[3] <= 13 and eventData[4] >= 5 and eventData[4] <= 7 then
                    if mobSpawner.settings.forced then
                        if mobSpawner.settings.enabled then
                            mobSpawner.forceDisable()
                        else
                            mobSpawner.unforce()
                        end
                    else
                        mobSpawner.forceEnable()
                    end
                    progState.repaint = true
                end
            else
                if eventData[3] >= 1 and eventData[3] <= 15 then
                    if eventData[4] == 2 then
                        if mobSpawner.uiState.selectedTextField == "playername" then
                            mobSpawner.uiState.cursorPos = mobSpawner.uiState.viewPos + math.max(math.min(eventData[3], #mobSpawner.uiState.curText) - 1, 0)
                        else
                            mobSpawner.uiState.selectedTextField = "playername"
                            mobSpawner.uiState.curText           = mobSpawner.settings.playerName
                            mobSpawner.uiState.cursorPos         = math.max(math.min(eventData[3], #mobSpawner.uiState.curText) - 1, 0)
                            mobSpawner.uiState.viewPos           = 0
                        end
                        term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, 2)
                    elseif eventData[4] == 5 then
                        if mobSpawner.uiState.selectedTextField == "channel" then
                            mobSpawner.uiState.cursorPos = mobSpawner.uiState.viewPos + math.max(math.min(eventData[3], #mobSpawner.uiState.curText) - 1, 0)
                        else
                            mobSpawner.uiState.selectedTextField = "channel"
                            mobSpawner.uiState.curText           = tostring(mobSpawner.settings.listenChannel)
                            mobSpawner.uiState.cursorPos         = math.max(math.min(eventData[3], #mobSpawner.uiState.curText) - 1, 0)
                            mobSpawner.uiState.viewPos           = 0
                        end
                        term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, 5)
                    else
                        submit = mobSpawner.uiState.selectedTextField ~= nil
                    end
                else
                    submit = mobSpawner.uiState.selectedTextField ~= nil
                end

                if submit then
                    if mobSpawner.uiState.selectedTextField == "playername" then
                        mobSpawner.setPlayerName(mobSpawner.uiState.curText)
                    elseif mobSpawner.uiState.selectedTextField == "channel" then
                        mobSpawner.setChannel(tonumber(mobSpawner.uiState.curText))
                    end
                    mobSpawner.uiState.selectedTextField = nil
                    mobSpawner.uiState.curText           = ""
                    mobSpawner.uiState.cursorPos         = 0
                    mobSpawner.uiState.viewPos           = 0
                    progState.repaint                    = true
                end
            end
        elseif event == "char" then
            if not mobSpawner.uiState.inSettings or mobSpawner.uiState.selectedTextField == nil then return end

            if mobSpawner.uiState.selectedTextField == "channel" then
                if eventData[2] < "0" or eventData[2] > "9" then return end
            end

            mobSpawner.uiState.curText = string.sub(mobSpawner.uiState.curText, 1, mobSpawner.uiState.cursorPos) .. eventData[2] .. string.sub(mobSpawner.uiState.curText, 1 + mobSpawner.uiState.cursorPos, -1)
            mobSpawner.uiState.cursorPos = mobSpawner.uiState.cursorPos + 1
            if mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos > 15 then
                mobSpawner.uiState.viewPos = mobSpawner.uiState.cursorPos - 15
            end

            mobSpawner.drawTextfield(mobSpawner.getTextfieldY(), mobSpawner.uiState.curText, mobSpawner.uiState.viewPos)
            term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, mobSpawner.getTextfieldY())
        elseif event == "key" then
            if not mobSpawner.uiState.inSettings or mobSpawner.uiState.selectedTextField == nil then return end

            local redrawTextfield = false

            if eventData[2] == keys.backspace then
                mobSpawner.uiState.curText = string.sub(mobSpawner.uiState.curText, 1, mobSpawner.uiState.cursorPos - 1) .. string.sub(mobSpawner.uiState.curText, 1 + mobSpawner.uiState.cursorPos, -1)
                
                mobSpawner.uiState.cursorPos = mobSpawner.uiState.cursorPos - 1
                if mobSpawner.uiState.cursorPos < mobSpawner.uiState.viewPos then
                    mobSpawner.uiState.viewPos = mobSpawner.uiState.cursorPos
                end
                redrawTextfield = true
            elseif eventData[2] == keys.delete then
                mobSpawner.uiState.curText = string.sub(mobSpawner.uiState.curText, 1, mobSpawner.uiState.cursorPos) .. string.sub(mobSpawner.uiState.curText, 2 + mobSpawner.uiState.cursorPos, -1)
                redrawTextfield = true
            elseif eventData[2] == keys.left then
                mobSpawner.uiState.cursorPos = mobSpawner.uiState.cursorPos - 1
                if mobSpawner.uiState.cursorPos < mobSpawner.uiState.viewPos then
                    mobSpawner.uiState.viewPos = mobSpawner.uiState.cursorPos
                end
                redrawTextfield = true
            elseif eventData[2] == keys.right then
                mobSpawner.uiState.cursorPos = mobSpawner.uiState.cursorPos + 1
                if mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos > 15 then
                    mobSpawner.uiState.viewPos = mobSpawner.uiState.cursorPos - 15
                end
                redrawTextfield = true
            elseif eventData[2] == keys.enter then
                if mobSpawner.uiState.selectedTextField == "playername" then
                    mobSpawner.setPlayerName(mobSpawner.uiState.curText)
                elseif mobSpawner.uiState.selectedTextField == "channel" then
                    mobSpawner.setChannel(tonumber(mobSpawner.uiState.curText))
                end
                mobSpawner.uiState.selectedTextField = nil
                mobSpawner.uiState.curText           = ""
                mobSpawner.uiState.cursorPos         = 0
                mobSpawner.uiState.viewPos           = 0
                progState.repaint                    = true
            elseif eventData[2] == keys.escape then
                mobSpawner.uiState.selectedTextField = nil
                mobSpawner.uiState.curText           = ""
                mobSpawner.uiState.cursorPos         = 0
                mobSpawner.uiState.viewPos           = 0
                progState.repaint                    = true
            end

            if redrawTextfield then
                mobSpawner.drawTextfield(mobSpawner.getTextfieldY(), mobSpawner.uiState.curText, mobSpawner.uiState.viewPos)
                term.setCursorPos(1 + mobSpawner.uiState.cursorPos - mobSpawner.uiState.viewPos, mobSpawner.getTextfieldY())
            end
        end
    end
}

function drawFooter()
    paintutils.drawLine(1, 19, 26, 19, colors.white)
    term.setCursorPos(1, 20)
    term.setBackgroundColor(colors.black)
    term.clearLine()

    if progState.tab == "mob" then
        term.setTextColor(colors.orange)
    else
        term.setTextColor(colors.white)
    end
    term.write(" Mob ")
    paintutils.drawPixel(6, 20, colors.white)
end

term.setBackgroundColor(colors.black)
term.clear()
drawFooter()

if progState.tab == "mob" then
    mobSpawner.onStart()
end

while true do
    if progState.repaint then
        progState.repaint = false
        if progState.tab == nil then
            paintutils.drawFilledBox(1, 1, 26, 18, colors.black)
        elseif progState.tab == "mob" then
            mobSpawner.onDraw()
        end
    end

    local eventData = pullEvent()
    local event     = eventData[1]
    if event == "mouse_click" then
        if eventData[2] == 1 and eventData[4] >= 20 then
            if eventData[3] >= 1 and eventData[3] <= 5 then
                if progState.tab == "mob" then
                    mobSpawner.onEnd()
                    progState.tab = nil
                else
                    progState.tab = "mob"
                    mobSpawner.onStart()
                end
                drawFooter()
                progState.repaint = true
            end
        else
            if progState.tab == "mob" then
                mobSpawner.onEvent(event, eventData)
            end
        end
    else
        if progState.tab == "mob" then
            mobSpawner.onEvent(event, eventData)
        end
    end
end