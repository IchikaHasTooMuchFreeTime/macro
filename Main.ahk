   #Include Other\Images.ahk
   #Include Other\UI.ahk
   #Include Other\AHKv2-Gdip-master\FindText.ahk
   #Include Other\Discord-Webhook-master\lib\WEBHOOK.ahk
   #Include Other\AHKv2-Gdip-master\Gdip_All.ahk
   #Include Other\RapidOcr\RapidOcr.ahk
   #Include Other\Func.ahk
   #SingleInstance Force
   dllPath := A_ScriptDir '\\Other\\RapidOcr\\' (A_PtrSize * 8) 'bit\\RapidOcrOnnx.dll'
   global s := RapidOcr({ models: A_ScriptDir "\\Other\\RapidOcr\\models" }, dllPath)
   global nextmap := 0
   global stageStartTime := A_TickCount
   global chalCount := 0
   global roblox := "ahk_exe RobloxPlayerBeta.exe"
   CoordMode("Mouse", "Window")
   CoordMode("Pixel", "Window")
   ActivateRoblox()
   global chalactive := false
   global ReconnectA := false


   MainGameLoop() {
       global nextmap, ReconnectA, returntolobby
       while true {
           if (ReconnectA) {
               UpdateText("Reconnecting...")
               if Reconnect() {
                   global ReconnectA := false
                   UpdateText("Reconnected successfully!")
                   Sleep 2000
                   FindRaid()
                   continue
               } else {
                   UpdateText("Reconnection failed, retrying...")
                   Sleep 2000
                   continue
               }
           }

           if (nextmap) {
               nextmap := 0
               if !PlaceInOrder() {
                   if ReconnectA {
                       continue
                   }
               }
           }
           Sleep 1000
       }
   }

   LOADWEBHOOKK()
   StartMacro(*) {
       if !WinExist(roblox) {
           UpdateText("Roblox window not found")
           return
       }

       SaveSettings()
       ActivateRoblox()
       mode := GetMode()

       if (!mode) {
           UpdateText("Please select a mode before starting")
           return
       }

       global startTime := A_TickCount
       global chalCount := 0
       global totalWins := 0
       global runStartTime := A_TickCount
       global totalLosses := 0
       global nextmap := 0
       global ReconnectA := false
       mode := modeselect.text
       UpdateText("Starting " mode)
       FindRaid()
       MainGameLoop()
   }
