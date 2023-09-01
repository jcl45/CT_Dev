'Clear currently applied machine policy
Set oWMI = GetObject("winmgmts://./root/ccm")
set oClient = oWMI.Get("SMS_Client")
oClient.ResetPolicy(0)

'Request machine policy from SCCM MP
Set cpApplet = CreateObject("CPAPPLET.CPAppletMgr")
Set oCommands = cpApplet.GetClientActions 
For Each oAction In oCommands
    If UCase(oAction.name) = UCase("Request & Evaluate Machine Policy") then
        oAction.PerformAction
    End If
Next