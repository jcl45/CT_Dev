(Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall).Name | ForEach-Object {
    if ( (Get-ItemProperty Registry::$_).DisplayName -eq  "Configuration Manager Client") {
        Write-Host "True"
        exit 0
    }
}
