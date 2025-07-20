#Requires AutoHotkey v2.0
global returntolobby := false
OnError(ErrorHandler)

ErrorHandler(exception, mode) {
    try {
        errorMessage := "Error: " exception.Message "`nFile: " exception.File "`nLine: " exception.Line "`nCode: " exception
            .CallStack
        if (exception.What)
            errorMessage .= "`nWhat: " exception.What
        if (exception.Extra)
            errorMessage .= "`nExtra: " exception.Extra

        logFile := A_ScriptDir "\Logs\error.log"
        FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " - " errorMessage "`n", logFile)

        MsgBox(errorMessage, "Error", "Icon!")

        if IsObject(MainUI) && IsObject(Process)
            UpdateText("Error occurred. Check Logs\error.log for details")

        return true
    } catch {
        return false
    }
}
global roblox := "ahk_exe RobloxPlayerBeta.exe"
global statusHistory := []
global stageStartTime := A_TickCount
global chalCount := 0
global MainUI
global Process
global mode
; Winrate
global totalWins := 0
global totalLosses := 0
global runStartTime := A_TickCount
ActivateRoblox() {
    if !WinExist(roblox) {
        Sleep(1000)
        UpdateText("Roblox is not open or you have Microsoft Store Roblox")
    } else {
        WinGetPos(&X, &Y, &W, &H, MacroUI)
        WinActivate(roblox)
        WinMove(X, Y, 800, 600, roblox)
        return true
    }
}
OcrBetter(x1, y1, x2, y2, scale, debug := false) {
    try {
        WinGetPos(&winX, &winY, , , "ahk_exe RobloxPlayerBeta.exe")
        x1 += winX
        y1 += winY
        x2 += winX
        y2 += winY

        pToken := Gdip_Startup()

        width := x2 - x1
        height := y2 - y1
        pBitmap := Gdip_BitmapFromScreen(x1 "|" y1 "|" width "|" height)

        newWidth := width * scale
        newHeight := height * scale

        pScaled := Gdip_CreateBitmap(newWidth, newHeight)
        g := Gdip_GraphicsFromImage(pScaled)

        Gdip_SetSmoothingMode(g, 4)
        Gdip_SetInterpolationMode(g, 7)
        Gdip_SetPixelOffsetMode(g, 5)

        Gdip_DrawImage(g, pBitmap, 0, 0, newWidth, newHeight, 0, 0, width, height)

        filename := "OCR"
        fullPath := A_ScriptDir "\Images\" filename ".png"

        if FileExist(fullPath)
            FileDelete(fullPath)

        Gdip_SaveBitmapToFile(pScaled, fullPath, 100)

        Sleep 100

        if !FileExist(fullPath) {
            UpdateText("Failed to save OCR image")
            return ""
        }

        result := s.ocr_from_file(fullPath, , true)
        Sleep 100

        Gdip_DeleteGraphics(g)
        Gdip_DisposeImage(pBitmap)
        Gdip_DisposeImage(pScaled)
        Gdip_Shutdown(pToken)

        if FileExist(fullPath)
            FileDelete(fullPath)

        if debug {
            if IsObject(result) && result.Length > 0 {
                text := ""
                for block in result {
                    cleanedText := RegExReplace(block.text, "\s+", "")
                    text .= cleanedText
                }
                if text != ""
                    UpdateText("Found text: " text)
                else
                    UpdateText("No text found in result")
            } else {
                UpdateText("No result returned or result is empty")
            }
        }

        if IsObject(result) && result.Length > 0 {
            finalText := ""
            for block in result {
                cleaned := RegExReplace(block.text, "\s+", "")
                finalText .= cleaned
            }
            return finalText
        }
        return ""
    } catch as err {
        UpdateText("OCR Error: " err.Message)
        return ""
    }
}
ImagesSearch(X1, Y1, X2, Y2, image, tol := 0, &FoundX?, &FoundY?) {
    CoordMode("Pixel", "Window")

    try {
        if ImageSearch(&FoundX, &FoundY, X1, Y1, X2, Y2, "*" tol " " image)
            return true
    } catch {
        return false
    }
    return false
}

ImageSearchLoop(image, X1, Y1, X2, Y2) {
    CoordMode("Pixel", "Window")
    global FoundX, FoundY

    WinActivate(roblox)
    WinGetPos(&X, &Y, &W, &H, roblox)
    while true {
        if (ok := FindText(&x, &y, X1, Y1, X2, Y2, 0, 0, image)) {
            return [x, y]
        } else {
            Sleep 100
        }
    }
}

PixelSearchS(color, x1, y1, x2, y2, variation, v := true) {
    global foundX, foundY
    ActivateRoblox
    if PixelSearch(&foundX, &foundY, x1, y1, x2, y2, color, variation) {
        if v {
            return [foundX, foundY]
        } else {
            return true
        }
    }
    return false
}
PixelSearchLoop(color, x1, y1, x2, y2, variation, click := true) {
    global foundX, foundY
    try {
        loop {
            if PixelSearch(&foundX, &foundY, x1, y1, x2, y2, color, variation) {
                if click {
                    MoveXY()
                }
                return [foundX, foundY]
            } else {
                Sleep 100
            }
        }
    } catch Error as e {
        return false
    }
}
Pixel(color, x1, y1, addx1, addy1, variation) {
    global foundX, foundY
    try {
        if PixelSearch(&foundX, &foundY, x1, y1, x1 + addx1, y1 + addy1, color, variation) {
            return [foundX, foundY] AND true
        }
        return false
    } catch Error as e {
        MsgBox("Error in Pixel: " e.Message)
        return false
    }
}
PixelSearchLoop2(color, x1, y1, x2, y2, variation, attempts) {
    global foundX, foundY
    attempts2 := 0
    try {
        loop {
            if attempts2 >= attempts {
                return false
            }
            if PixelSearch(&foundX, &foundY, x1, y1, x2, y2, color, variation) {
                MoveXY()
                return [foundX, foundY]
            } else {
                attempts2++
                Sleep 100
                continue
            }
        }
    } catch Error as e {
        return false
    }
}

Scroll(times, direction, delay) {
    if (times < 1) {
        MsgBox("Invalid number of times")
        return
    }
    if (direction != "WheelUp" and direction != "WheelDown") {
        MsgBox("Invalid direction")
        return
    }
    if (delay < 0) {
        MsgBox("Invalid delay")
        return
    }
    loop times {
        Send("{" direction "}")
        Sleep(delay)
    }
}

wiggle() {
    MouseMove(1, 1, 5, "R")
    Sleep(30)
    MouseMove(-1, -1, 5, "R")
}
Wigglehuge() {
    MouseMove(5, 5, 5, "R")
    Sleep(30)
    MouseMove(-5, -5, 5, "R")
}
MoveXY() {
    MouseMove(FoundX, FoundY)
    MouseMove(1, 0, , "R")
    Sleep(50)
    wiggle()
    Click()
}

ClickV3(x, y) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(50)
    Wigglehuge()
    Click("Right")
}
ClickV2(x, y) {
    ActivateRoblox()
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(50)
    wiggle()
    Click()
}
Clickv5(x, y) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(50)
    Wigglehuge()
    Click()
}
Click2(x, y) {

    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(50)
    MouseMove(1, 1, 5, "R")
    Sleep(30)
    MouseMove(-1, -1, 5, "R")
    Click()
}

ClickV4(x, y, delay) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(delay)
    wiggle()
    Click()
}

Clicks() {
    MouseMove(1, 0, , "R")
    Sleep(50)
    wiggle()
    Click()
    Click()
    Click()
    Sleep(50)
    Click()
    MouseMove(-1, 0, , "R")
}
ZoomTech(start := true) {
    GetMode()
    Send "{Tab}"
    MouseMove(408, 247, 5)
    MouseClick("Right", , , 1, 0, "D")
    MouseMove(0, 1, 0, "R")
    Sleep(500)
    MouseClick("Right", , , 1, 0, "U")
    if start {
        ClickV2(361, 542)
    }
}

GetElapsedTime(startTime) {
    elapsedMs := A_TickCount - startTime
    hours := Floor(elapsedMs / (1000 * 60 * 60))
    minutes := Floor(Mod(elapsedMs / (1000 * 60), 60))
    seconds := Floor(Mod(elapsedMs / 1000, 60))

    if (hours > 0)
        return Format("{:02d}:{:02d}:{:02d}", hours, minutes, seconds)
    else
        return Format("{:02d}:{:02d}", minutes, seconds)
}
WebhookScreenshot(title, description) {
    ActivateRoblox()

    if !MainUI["EnableWebhook"].Value
        return
    mode := ModeSelect.Text
    UpdateText("Webhook Enabled")

    color := 0x00aeff
    if InStr(title, "Win")
        color := 0x4BB543
    else if InStr(title, "Loss")
        color := 0xFF3333

    submitted := MainUI.Submit(false)
    currentMode := submitted.SelectedMode
    discordId := MainUI["DiscordIdEdit"].Value
    WebhookURL := MainUI["MyEdit"].Value

    if !(WebhookURL ~=
        "i)^https:\/\/((?:ptb|canary)\.)?discord(?:app)?\.com\/api\/webhooks\/\d{17,23}\/[A-Za-z0-9_\-\.]{60,100}$") {
        MsgBox("Invalid Discord webhook URL", "Webhook Error", "Icon!")
        return
    }

    global totalWins, totalLosses, chalCount
    if !IsSet(totalWins)
        totalWins := 0
    if !IsSet(totalLosses)
        totalLosses := 0
    if !IsSet(chalCount)
        chalCount := 0
    pToken := Gdip_Startup()
    if !pToken {
        UpdateText("Failed to initialize GDI+")
        return
    }

    MonitorGet(MonitorGetPrimary(), &Left, &Top, &Right, &Bottom)
    pBitmap := Gdip_BitmapFromScreen(Left "|" Top "|" (Right - Left) "|" (Bottom - Top))
    if !pBitmap {
        UpdateText("Failed to capture the screen")
        Gdip_Shutdown(pToken)
        return
    }

    WinGetClientPos(&x, &y, &w, &h, roblox)
    pCroppedBitmap := Gdip_CloneBitmapArea(pBitmap, x, y + 5, w - 12, h - 10)
    if !pCroppedBitmap {
        UpdateText("Failed to crop the bitmap")
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
        return
    }

    webhook := WebhookBuilder(WebhookURL)
    attachment := AttachmentBuilder(pCroppedBitmap)
    myEmbed := EmbedBuilder()

    myEmbed.setTitle(title . " - " . currentMode . " #" . chalCount)

    avgRunTime := "N/A"
    if (chalCount > 0) {
        avgRunTimeMs := (A_TickCount - runStartTime) / chalCount
        avgRunTimeMin := Floor(avgRunTimeMs / (1000 * 60))
        avgRunTimeSec := Floor(Mod(avgRunTimeMs / 1000, 60))
        avgRunTime := avgRunTimeMin "m " avgRunTimeSec "s"
    }
    winrate := GetWinrate()
    enhancedDesc := description
    enhancedDesc .= "`n• 🔢 | Run #: " . chalCount
    enhancedDesc .= "`n• 🔢 | Avg Run: " . avgRunTime
    enhancedDesc .= "`n• 🏆 | Total Wins: " . totalWins
    enhancedDesc .= "`n• 😔 | Total Losses: " . totalLosses
    enhancedDesc .= "`n• 💯 | Winrate: " . winrate

    myEmbed.setDescription(enhancedDesc)
    myEmbed.setColor(color)
    myEmbed.setImage(attachment)

    elapsedTime := GetElapsedTime(stageStartTime)
    totalTime := GetElapsedTime(runStartTime)
    currentTime := FormatTime(A_Now, "h:mm tt")

    myEmbed.setFooter({
        text: "Cys AFS Macro " Version " | Run: " elapsedTime " | Total: " totalTime " | " currentTime
    })

    webhook.send({
        content: discordId ? "<@" discordId ">" : "",
        embeds: [myEmbed],
        files: [attachment]
    })

    Gdip_DisposeImage(pCroppedBitmap)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    UpdateText("Webhook sent: " . title)
}

WebhookScreenshot2(color := 0x00aeff, status := "") {
    ActivateRoblox()
    if MainUI["EnableWebhook"].Value {
        UpdateText("Webhook Enabled")

        submitted := MainUI.Submit(false)
        currentMode := submitted.SelectedMode

        title := "Test Screenshot"
        description := "Test Screenshot"

        discordId := MainUI["DiscordIDEdit"].Value
        WebhookURL := MainUI["MyEdit"].Value
        webhook := WebhookBuilder(WebhookURL)

        if !(WebhookURL ~=
            "i)^https:\/\/((?:ptb|canary)\.)?discord(?:app)?\.com\/api\/webhooks\/\d{17,23}\/[A-Za-z0-9_\-\.]{60,100}$"
        ) {
            MsgBox(
                "Invalid Discord webhook URL. Please enter a valid URL in the format:`nhttps://discord.com/api/webhooks/ID/TOKEN",
                "Webhook Error", "Icon!")
            return
        }

        pToken := Gdip_Startup()
        if !pToken {
            MsgBox("Failed to initialize GDI+")
            return
        }

        MonitorGet(MonitorGetPrimary(), &Left, &Top, &Right, &Bottom)
        pBitmap := Gdip_BitmapFromScreen(Left "|" Top "|" (Right - Left) "|" (Bottom - Top))
        if !pBitmap {
            MsgBox("Failed to capture screen")
            Gdip_Shutdown(pToken)
            return
        }

        WinGetClientPos(&x, &y, &w, &h, roblox)
        pCroppedBitmap := Gdip_CloneBitmapArea(pBitmap, x, y + 5, w - 10, h - 10)
        if !pCroppedBitmap {
            MsgBox("Failed to crop bitmap")
            Gdip_DisposeImage(pBitmap)
            Gdip_Shutdown(pToken)
            return
        }

        global totalWins, totalLosses, chalCount
        elapsedTime := GetElapsedTime(stageStartTime)
        totalTime := GetElapsedTime(runStartTime)
        winrateText := GetWinrate()

        avgRunTime := "N/A"
        if (chalCount > 0) {
            avgRunTimeMs := (A_TickCount - runStartTime) / chalCount
            avgRunTimeMin := Floor(avgRunTimeMs / (1000 * 60))
            avgRunTimeSec := Floor(Mod(avgRunTimeMs / 1000, 60))
            avgRunTime := avgRunTimeMin "m " avgRunTimeSec "s"
        }

        attachment := AttachmentBuilder(pCroppedBitmap)
        myEmbed := EmbedBuilder()

        if (currentMode != "")
            title .= " - " . currentMode

        myEmbed.setTitle(title)

        if (status != "")
            description := status
        else if (currentMode != "")
            description := "**Manual Screenshot**`n• Mode: " . currentMode
                . "`n• Run #: " . chalCount
                . "`n• Winrate: " . winrateText

        myEmbed.setDescription(description)
        myEmbed.setColor(color)
        myEmbed.setImage(attachment)

        currentTime := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        myEmbed.setFooter({ text: "Cys AFS X Macro " Version "  | Run: " elapsedTime " | Total: " totalTime " | " currentTime })

        webhook.send({
            content: discordId ? "<@" discordId ">" : "",
            embeds: [myEmbed],
            files: [attachment]
        })

        Gdip_DisposeImage(pCroppedBitmap)
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
        UpdateText("Test webhook sent successfully")
    }
}

CheckIfUnitPlaced() {
    if Pixel(0x2C5CC2, 81, 405, 4, 4, 2) {
        return true
    } else {
        return false
    }
}

Retrycheckloop() {
    while true {
        ClickV2(700, 567)
        if Retrycheck() {
            return true
        }
        if !DisconnectCheck() {
            return true
        }
        Sleep 500
    }
}

PlaceInOrder() {
    CoordMode("Mouse", "Client")
    submitted := MainUI.Submit(false)
    mode := submitted.SelectedMode
    selectedCustom := submitted.SelectedCustomMode
    settingsFile := ""
    if (mode = "Custom") {
        settingsFile := A_ScriptDir "\Settings\Customs\" selectedCustom ".txt"
    }
    else {
        settingsFile := A_ScriptDir "\Settings\" mode ".txt"
    }

    UpdateText("Loading settings from: " settingsFile)

    if !FileExist(settingsFile) {
        UpdateText("No settings file found for mode: " mode)
        return false
    }

    try {
        fileContent := FileRead(settingsFile)
        lines := StrSplit(fileContent, "`n")
    } catch Error as e {
        MsgBox("Error reading settings file: " e.Message)
        return false
    }

    for index, line in lines {
        if (line = "")
            continue

        if (InStr(line, "Index=")) {
            index := SubStr(line, 7)
            x := ""
            y := ""
            unit := ""
            upgrade := ""
            continue
        }
        if (InStr(line, "Unit=")) {
            unit := SubStr(line, 6)
            continue
        }
        if (InStr(line, "Upgrade=")) {
            upgrade := SubStr(line, 9)
            continue
        }
        if (InStr(line, "X=")) {
            x := SubStr(line, 3)
            continue
        }
        if (InStr(line, "Y=")) {
            y := SubStr(line, 3)
            if (x = "" || y = "") {
                continue
            }
            if (x != "" && y != "" && unit != "") {
                CoordMode("Mouse", "Client")

                try {
                    x := Integer(x)
                    y := Integer(y)
                } catch Error as e {
                    UpdateText("ERROR: Invalid coordinates - X: " x ", Y: " y)
                    continue
                }

                UpdateText("Attempting to place unit " unit " at X: " x ", Y: " y " (Upgrade: " upgrade ")")

                if !PlaceUnit(x, y, unit) {
                    return false
                }

                Sleep 100
                if !UpgradeUnit(x, y, upgrade, 50) {
                    return false
                }
            }
        }
    }
    if Retrycheckloop() {
        return false
    }

}



UpgradeUnit(x, y, Upgrade, delay, unitslot := "") {
    if (Upgrade = 0) {
        return true
    }

    UpdateText("Upgrading until " Upgrade)
    upgradeImages := [Upgrade1, Upgrade2, Upgrade3, Upgrade4, Upgrade5, Upgrade6, Upgrade7, Upgrade8, Upgrade9,
        Upgrade10, Upgrade11]
    mode := GetMode()
    if (Upgrade = "MAX") {
        while true {
            if Retrycheck() {
                return False
            }
            if !DisconnectCheck() {
                return False
            }
            if (!CheckIfUnitPlaced()) {
                CoordMode("Mouse", "Client")
                ClickV4(x, y, 1)
                Sleep(10)
            }
            ActivateRoblox()
            Send "{e}"

            Sleep(delay)
            if (ok := FindText(&foundX, &foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, MaxUnit)) {
                UpdateText("Max Unit Level Reached")
                Sleep(100)
                return true
            }
        }
    }

    upgradePattern := upgradeImages[Integer(Upgrade)]
    while true {
        if Retrycheck() {
            return False
        }
        if (!CheckIfUnitPlaced()) {
            CoordMode("Mouse", "Client")
            ClickV4(x, y, 1)
            Sleep(10)
        }
        if !DisconnectCheck() {
            return False
        }
        ActivateRoblox()
        Send "{e}"

        Sleep(delay)

        if (ok := FindText(&foundX, &foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, upgradePattern)) {
            UpdateText("Upgrade " Upgrade " Complete")
            Sleep(100)
            return true
        }
    }
}
PlaceUnit(x, y, unitslot) {
    static placementdelay := ""
    if (placementdelay == "") {
        try {
            placementDelayFile := FileRead(A_ScriptDir "\Settings\PlacementDelay.txt")
            placementdelay := StrSplit(placementDelayFile, "=")[2]
        } catch {
            placementdelay := 150
        }
    }
    if (unitslot == "0") {
        ClickV2(x, y)
        return true
    }

    if (InStr(unitslot, "w") || InStr(unitslot, "W")) {
        waittime1 := StrSplit(unitslot, 2)
        waittime := waittime1[2] * 1000
        UpdateText("Waiting " waittime "ms")
        Sleep(waittime)
        return true
    }

    if (InStr(unitslot, "u") || InStr(unitslot, "U")) {
        CoordMode("Mouse", "Window")
        slotKey := StrLower(unitslot)

        if (slotKey == "u1") {
            ClickV2(680, 230)
            return true
        } else if (slotKey == "u2") {
            ClickV2(754, 232)
            return true
        } else if (slotKey == "u3") {
            ClickV2(677, 349)
            return true
        } else if (slotKey == "u4") {
            ClickV2(756, 350)
            return true
        } else if (slotKey == "u5") {
            ClickV2(679, 470)
            return true
        } else if (slotKey == "u6") {
            ClickV2(756, 468)
            return true
        }
    }

    if (unitslot == "r" || unitslot == "R") {
        ActivateRoblox()
        ClickV3(x, y)
        Sleep(7500)
        return true
    }

    if (unitslot == "f" || unitslot == "F") {
        Send "{F}"
        return true
    }
    loop {
        if (Retrycheck()) {
            return false
        }

        if (!DisconnectCheck()) {
            return false
        }

        Send(unitslot)
        Sleep(placementdelay)
        CoordMode("Mouse", "Client")

        ClickV2(x, y)
        Sleep(450)
        ClickV2(x, y)
        if (CheckIfUnitPlaced() && unitslot != "0") {
            UpdateText("Unit Placed Successfully")
            Sleep(200)
            return true
        }
        Sleep 250
        ClickV2(x, y)
        if (CheckIfUnitPlaced() && unitslot != "0") {
            UpdateText("Unit Placed Successfully")
            Sleep(200)

            return true
        }
    }
}
Retrycheck() {
    global chalCount
    CoordMode("Mouse", "Window")
    CoordMode("Pixel", "Window")
    loss := Pixel(0xFF4D4D, 291, 342, 3, 3, 3)
    win := Pixel(0x7AD732, 283, 343, 3, 3, 3)
    retry := Pixel(0x9136F0, 381, 226, 3, 3, 3)
    rareReward := (ok := FindText(&X, &Y, 663 - 150000, 585 - 150000, 663 + 150000, 585 + 150000, 0, 0, Rare))
    mythicReward := (ok:=FindText(&X, &Y, 744-150000, 597-150000, 744+150000, 597+150000, 0, 0, mythicReward))
    if (retry) {
        ClickV2(400, 300)
    }
    if (rareReward) || (mythicReward){
        loop 10 {
            ClickV2(400, 300)
        }
    }
    if (loss) {
        chalCount++
        return RetryFunctionLoss()
    } else if (win) {
        chalCount++
        return Retryfunctionwin()
    }
    return false
}

Retryfunctionwin() {
    global totalWins, FoundX, FoundY, nextmap
    mode := GetMode()
    submitted := MainUI.Submit(false)
    retryColor := 0xEFCB4E
    totalWins++
    winrate := GetWinrate()
    ClickV2(400, 300)
    WebhookScreenshot("Map Win", "")
    CoordMode("Mouse", "Window")
    UpdateText("Retry Detected [Win] - Winrate: " winrate)
    if PixelSearchLoop(retryColor, 374, 441, 437, 469, 5) {
        FoundX := FoundX + 3
        MoveXY()
        Clicks()
        Clicks()
        Clicks()
    }
    nextmap++
    return true
}
RetryFunctionLoss() {
    global totalLosses, FoundX, FoundY, nextmap
    mode := GetMode()
    submitted := MainUI.Submit(false)
    retryColor := 0xEFCB4E
    totalLosses++
    winrate := GetWinrate()
    ClickV2(400, 300)
    WebhookScreenshot("Map Loss", "Current Winrate: " winrate)

    CoordMode("Mouse", "Window")
    UpdateText("Retry Detected [Loss] - Winrate: " winrate)
    if PixelSearchLoop(retryColor, 374, 441, 437, 469, 5) {
        FoundX := FoundX + 3
        MoveXY()
        Clicks()
        Clicks()
        Clicks()
    }
    nextmap++
    return true
}

GetWinrate() {
    global totalWins, totalLosses

    totalRuns := totalWins + totalLosses
    if (totalRuns > 0) {
        winratePercent := Round((totalWins / totalRuns) * 100, 2)
        return winratePercent "% (" totalWins "W/" totalLosses "L)"
    }

    return "0% (0W/0L)"
}

FindRaid() {
    if (!WinExist(roblox)) {
        return
    }
    modetext := ModeSelect.Text
    switch modetext {
        case "Custom":
            Custom()
    }
}

Custom() {
    PlaceInOrder()
}

Clicktomove(x1, y1, delay, x2 := "", y2 := "") {
    UISettings := A_ScriptDir "\Settings\UISettings.txt"
    UISettings := FileRead(UISettings) = 1 ? 1 : 0
    ActivateRoblox()
    send "{Escape}"
    Sleep 750
    ClickV2(253, 124)
    Sleep 750
    if (UISettings = 1) {
        UpdateText("Click to Move: New UI")
        ClickV2(341, 395)
    } else {
        UpdateText("Click to Move: Normal UI")
        ClickV2(341, 290)
    }
    send "{Escape}"
    sleep 2000
    ClickV3(x1, y1)
    Sleep delay
    if (x2 != "" && y2 != "") {
        ClickV3(x2, y2)
        Sleep delay
    }

    Send "{Escape}"
    Sleep 750
    ClickV2(253, 124)
    Sleep 750
    if (UISettings = 1) {
        ClickV2(778, 395)
        send "{Escape}"
    } else {
        ClickV2(783, 288)
        send "{Escape}"
        Sleep 2000
        ClickV2(381, 160)
    }
}

HasInternet() {
    return DllCall("Wininet.dll\InternetGetConnectedState", "int*", 0, "int", 0)
}

Reconnect() {
    static placeId := 17687504411
    privateServerLink := ""
    privateServerFile := A_ScriptDir "\Settings\PrivateServer.txt"

    if FileExist(privateServerFile) {
        try privateServerLink := Trim(FileRead(privateServerFile))
        catch Error as e
            return UpdateText("Error reading private server link: " e.Message)
    }

    for _ in [1, 2] {
        if WinExist("ahk_exe RobloxPlayerBeta.exe") {
            WinClose("ahk_exe RobloxPlayerBeta.exe")
            Sleep(500)
        }
    }

    loop {
        if HasInternet() {
            UpdateText("Internet connection detected, attempting to reconnect...")

            if (privateServerLink != "") {
                serverCode := GetPrivateServerCode(privateServerLink)
                if (serverCode != "") {
                    deepLink := "roblox://experiences/start?placeId=" placeId "&linkCode=" serverCode
                    Run(deepLink)
                    UpdateText("Attempting to join private server...")
                } else {
                    UpdateText("Invalid private server link format.")
                    return false
                }
            } else {
                Run("roblox://placeID=" placeId)
                UpdateText("Attempting to join public server...")
            }

            if WinWait("ahk_exe RobloxPlayerBeta.exe", , 17)
                break
            else {
                UpdateText("Roblox not detected, retrying...")
                Sleep(1000)
            }
        } else {
            UpdateText("No internet connection detected, retrying in 3 seconds...")
            Sleep(3000)
        }
    }

    ActivateRoblox()
    Sleep(3000)

    if LookForLobby() {
        UpdateText("Successfully reconnected.")
        return true
    }

    UpdateText("Failed to reconnect.")
    return false
}

GetPrivateServerCode(link) {
    if RegExMatch(link, "\?privateServerLinkCode=([\w-]+)", &m)
        return m[1]
    return ""
}

LookForLobby() {
    while !Pixel(0x44D56D, 37, 305, 3, 3, 3) {
    }
    UpdateText("Lobby Found")
    return true
}
DisconnectCheck() {
    if Pixel(0x393B3D, 498, 357, 3, 3, 0) {
        global ReconnectA := true
        UpdateText("Disconnected... [Trying to reconnect]")
        return false
    }
    CoordMode("Mouse", "Window")
    return true
}
