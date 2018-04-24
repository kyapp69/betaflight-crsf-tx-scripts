CRSF_FRAMETYPE_DISPLAYPORT_UPDATE   = 0x7D
CRSF_FRAMETYPE_DISPLAYPORT_CLEAR    = 0x7E
CRSF_FRAMETYPE_DISPLAYPORT_CMD      = 0x7F
CRSF_DISPLAYPORT_SUBCMD_OPEN        = 0x01
CRSF_DISPLAYPORT_SUBCMD_CLOSE       = 0x02
CRSF_DISPLAYPORT_SUBCMD_POLL        = 0x03
CRSF_ADDRESS_BETAFLIGHT             = 0xC8
CRSF_ADDRESS_TRANSMITTER            = 0xEA

cmsMenuOpen = false
lastMenuEventTime = 0

screenBuffer = {
    rows = 8,
    cols = 32,
    buffer = {},
    resetRow = function(row)
        screenBuffer.buffer[row] = string.rep(" ", screenBuffer.cols)
    end,
    reset = function()
        for i=1, screenBuffer.rows do
            screenBuffer.resetRow(i)
        end
    end,
    update = function(row,col,str) 
        if row > screenBuffer.rows or col > screenBuffer.cols then
            return nil
        end
        local bufferLeft = string.sub(screenBuffer.buffer[row],1,col-1)
        local bufferRightStart = string.len(bufferLeft) + string.len(str) + 1
        local bufferRight = string.sub(screenBuffer.buffer[row],bufferRightStart, screenBuffer.cols)
        screenBuffer.buffer[row] = string.sub(string.format("%s%s%s", bufferLeft, str, bufferRight),1,screenBuffer.cols)
    end,
    draw = function()
        lcd.clear()
        local pixelsPerRow = 8
        local pixelsPerChar = 6
        -- draw buffer monospaced, as font characters vary in width.
        for row=1,screenBuffer.rows do
            for col=1,screenBuffer.cols do
                char = string.sub(screenBuffer.buffer[row], col, col)
                xPos = ((col-1)*pixelsPerChar)+1
                yPos = ((row-1)*pixelsPerRow)+1
                lcd.drawText(xPos, yPos, char, SMLSIZE) 
            end
        end
        lcd.drawText(165, 2, "Refresh >>" , SMLSIZE) 
    end
}

local function subrange(t, first, last)
    local sub = {}
    for i=first,last do
        sub[#sub + 1] = t[i]
    end
    return sub
end

local function arrayToString(arr)
    local str = ""
    for i=1,#arr do
        str = string.format("%s%c",str,arr[i])
    end
    return str
end

local function displayPortCmd(cmd)
    local payloadOut = { CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_TRANSMITTER, cmd }
    crossfireTelemetryPush(CRSF_FRAMETYPE_DISPLAYPORT_CMD, payloadOut) 
end

local function init()
    screenBuffer.reset()
end

local function run(event)
    lastMenuEventTime = getTime()
    local command, data = crossfireTelemetryPop()
    if data ~= nil then
        if data[1] == CRSF_ADDRESS_TRANSMITTER and data[2] == CRSF_ADDRESS_BETAFLIGHT then
            if command == CRSF_FRAMETYPE_DISPLAYPORT_CLEAR then
                screenBuffer.reset()
            elseif command == CRSF_FRAMETYPE_DISPLAYPORT_UPDATE then
                local row = data[3] + 1
                screenBuffer.update(row,1,arrayToString(subrange(data,4,#data-1)))
                cmsMenuOpen = true
            end
        end
    end
    screenBuffer.draw()
    if cmsMenuOpen == false then
        displayPortCmd(CRSF_DISPLAYPORT_SUBCMD_OPEN)
    end
    if (event == EVT_PLUS_BREAK) then
        displayPortCmd(CRSF_DISPLAYPORT_SUBCMD_POLL)
    end
end

local function background()
    if cmsMenuOpen == true and lastMenuEventTime + 100 < getTime() then
        displayPortCmd(CRSF_DISPLAYPORT_SUBCMD_CLOSE)
        cmsMenuOpen = false
    end
end

return { init=init, run=run, background=background }