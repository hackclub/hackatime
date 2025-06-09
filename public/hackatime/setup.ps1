try {
    # Create config file with API settings
    $configPath = "$env:USERPROFILE\.wakatime.cfg"
    
    @"
[settings]
api_url = $env:HACKATIME_API_URL
api_key = $env:HACKATIME_API_KEY
heartbeat_rate_limit_seconds = 30
"@ | Out-File -FilePath $configPath -Force -Encoding utf8
    
    Write-Host "Config file created at $configPath"

    # Verify config was created successfully
    if (Test-Path $configPath) {
        $config = Get-Content $configPath
        $apiUrl = ($config | Select-String "api_url").ToString().Split('=')[1].Trim()
        $apiKey = ($config | Select-String "api_key").ToString().Split('=')[1].Trim()
        $heartbeatRate = ($config | Select-String "heartbeat_rate_limit_seconds").ToString().Split('=')[1].Trim()
        
        # Display verification info
        Write-Host "API URL: $apiUrl"
        Write-Host ("API Key: " + $apiKey.Substring(0,4) + "..." + $apiKey.Substring($apiKey.Length-4))  # Show first/last 4 chars
        
        # Send test heartbeat
        Write-Host "Sending test heartbeat..."
        $time = [Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat '%s'))
        $heartbeat = @{
            type = 'file'
            time = $time
            entity = 'test.txt'
            language = 'Text'
        }
        
        $response = Invoke-RestMethod -Uri "$apiUrl/users/current/heartbeats" `
            -Method Post `
            -Headers @{Authorization="Bearer $apiKey"} `
            -ContentType 'application/json' `
            -Body "[$($heartbeat | ConvertTo-Json)]"
            
        Write-Host "Test heartbeat sent successfully"
        
        # Display ASCII art on success
        Write-Host "`n" -NoNewline
        Write-Host "  _   _            _         _   _                " -ForegroundColor Cyan
        Write-Host " | | | | __ _  ___| | ____ _| |_(_)_ __ ___   ___ " -ForegroundColor Cyan
        Write-Host " | |_| |/ _` |/ __| |/ / _` | __| | '_ ` _ \ / _ \" -ForegroundColor Cyan
        Write-Host " |  _  | (_| | (__|   < (_| | |_| | | | | | |  __/" -ForegroundColor Cyan
        Write-Host " |_| |_|\__,_|\___|_|\_\__,_|\__|_|_| |_| |_|\___|" -ForegroundColor Cyan
        Write-Host "`n                Ready to track!                 " -ForegroundColor Green
        Write-Host "           https://hackatime.hackclub.com         " -ForegroundColor Yellow
        Write-Host "`n"
    } else {
        throw "Failed to create config file"
    }
} catch {
    Write-Host "----------------------------------------"
    Write-Host "ERROR: An error occurred during setup:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "----------------------------------------"
}
finally {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
