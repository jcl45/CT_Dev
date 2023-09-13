
$Map = (Get-ChildItem Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall -Recurse | Where-Object DisplayName -eq "Configuration Manager Client")
$Map | ForEach-Object {
    Add-content "$CacheFldr\Registry\HKLM_Software_BskyB.log" -value "`r`n -------------------------------------- `r`n"
    Get-ItemProperty Registry::$_ | Out-File -Append -FilePath "$CacheFldr\Registry\HKLM_Software_BskyB.log"
} 