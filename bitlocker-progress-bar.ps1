# checks & displays Bitlocker encryption progress



do {

    $percent = Get-BitLockerVolume -MountPoint C | Select-Object -ExpandProperty EncryptionPercentage

    $scaled = [int]($percent/2)

    $filledBars = "X" * $scaled
    $emptyBars = "-" * (50 - $scaled)

    $message = "Bitlocker Progress: " + $filledBars + $emptyBars + " (${percent}%)`r"

    Clear-Host
    Write-Host $message -NoNewline

    Start-Sleep -s 2
    
}while ($percent -lt 100)

Clear-Host

Write-Host "Bitlocker encryption is complete."
