#Requires -RunAsAdministrator

param 
(
    $name
)
    
$ErrorActionPreference = "Stop"

$TPM20 = @("1.3.2.8",'7\.2(.*)',"74.8.17568.5511")
$TPM12 = @("5.81")


function Get-Windows-Version {
    param (
        $name
    )

    try{
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-ComputerInfo | Select-Object -ExpandProperty OsName}
    } catch {

        Write-Host "Error: Invoke Command to check Windows version failed." -ForegroundColor Red
        Exit
    }

    $message = "OS Version : " + $return +"`n"

    if ($return -match "11") {
        Write-Host $message -ForegroundColor Green
    } else {
        Write-Host $message -ForegroundColor Red
    }
}

function Get-Bitlocker-Status {
    param(
        $name
    )

    try{
        $return = Invoke-Command -ComputerName $name -ScriptBlock {manage-bde -status}
    } catch {

        Write-Host "Error: Invoke Command to check Bitlocker status failed." -ForegroundColor Red
        Exit
    }

    $status = $return[10].Substring($return[10].Length - 22)

    if ($status -match "Progress")
    {
        $message = "Bitlocker status :" + $status +'`n'
        Write-Host $message 
    } elseif ($status -match "Decrypted") {
        Write-Host "Bitlocker Status : Fully Decrypted`n" -ForegroundColor Red
    } else {
        Write-Host "Bitlocker Status : Fully Encrypted`n" -ForegroundColor Green
    }
}

function Check-Secure-Boot {
    param (
        $name
    )

    
    try{
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Confirm-SecureBootUEFI}
    } catch {

        Write-Host "Error: Invoke Command to check Secure Boot failed." -ForegroundColor Red
        Exit
    }


    if ( $return -eq $true ) {
        Write-Host "Secure Boot : on `n" -ForegroundColor Green
    } else {
        Write-Host "Secure Boot : off `n" -ForegroundColor Red
    }
}

function Check-TPM {
    param (
        $name
    )
    try {
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-Tpm | Select-Object TpmPresent, TpmEnabled, ManufacturerVersion}
    } catch {
         Write-Host "Error: Invoke Command to check TPM 2.0 failed." -ForegroundColor Red
         Exit
    }

    if ($return.TpmPresent -eq $false) {
        Write-Host "TPM not present `n" -ForegroundColor Red
    } elseif ($return.TpmEnabled -eq $false) {
        Write-Host "TPM enabled: no `n" -ForegroundColor Red
    } else {# TPM is present and enabled
        $message = "TPM Manufacturer Version : " + $return.ManufacturerVersion + "`n"

        # if the TPM mfg version is not in the known 2.0 list
        if (($TPM20 | Where-Object {$return.ManufacturerVersion -match $_}) -eq $null) {

            # if the TPM mfg version is in the known 1.2 list
            if (!(($TPM12 | Where-Object {$return.ManufacturerVersion -match $_}) -eq $null)) {
                Write-Host $message -ForegroundColor Red

            } else { # the manufacturer version didn't match either known TPM list
                $message = $message + "Check TPM version. `n"
                Write-Host $message 
            }

        } else { # the TPM mfg version is within the known 2.0 list
            Write-Host $message -ForegroundColor Green
        }
    }
}

function Get-RAID-Status {
    param (
        $name
    )
    try {
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-WmiObject -Class Win32_SCSIController | Where-Object {$_.DriverName -eq "iaStorAC"}}
    } catch {
        Write-Host "Error: Invoke Command to check RAID status failed." -ForegroundColor Red
        Exit
    }

    if (!($return -eq $null)) {
        Write-Host "RAID : on`n" -ForegroundColor Red
    } else {
        Write-Host "RAID : not on`n" -ForegroundColor Green
    }
}

function Get-Asset-Tag {
    param (
        $name
    )
    
    try {
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag}
    } catch {
        Write-Host "Error: Invoke Command to check asset tag failed." -ForegroundColor Red
        Exit
    }

    if ($return -eq "") {
        Write-Host "Asset tag has not been set.`n" -ForegroundColor Red
    } else {

        $tag = $name.Substring($name.Length - 6)

        if ($tag -match '^\d+$') {# computer name has a 6-digit tag at the end
            if ($return -eq $tag) {
                Write-Host "Asset tag and tag from machine name match.`n" -ForegroundColor Green    

            } else { # the asset tag is not null & doesn't match machine name
                $message = "Asset tag descrepency. `nName  :" + $tag + "`nAsset :" + $return + '`n'
                Write-Host $message -ForegroundColor Red
            }
        } else { #computer name does not have 6-digit tag at the end
            $message = "This machine is likely named incorrectly, but the asset tag is " + $return + '`n'
            Write-Host $message
        }
    }
}

function Get-BIOS-Version {
    param (
        $name
    )
  
    try {
        $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-ComputerInfo | Select-Object BiosSMBIOSBIOSVersion, CsModel}
    } catch {
        Write-Host "Error: Invoke Command to check BIOS version failed." -ForegroundColor Red
        Exit
    }

    $message = "BIOS version : " + $return.BiosSMBIOSBIOSVersion + "`n" + "Model : " + $return.CsModel + "`n"
    Write-Host $message
}

# # # # # # # # # # # #   Checking Online Status     # # # # # # # # # # # #

if ($name -eq $null) {
    Write-Host "Script requires a machine name."
    Exit
}

$return = ping $name

# The script will exit if the machine is offline.

if (!($return[2] -match "Reply"))
{
   if ($return[2] -match "Request timed out.") {
        $message = $name + " is offline."
   }
   elseif ($return -match "could not find host") {
        $message = $name + " host could not be found."
   }
   else {
        $message = "Something went wrong."
   }

   Write-Host $message

   Exit
}

# The machine must be online to make it to this point.

$message = $name + " is online. Proceeding to check BIOS settings. `n"
Write-Host $message 


Get-Windows-Version -name $name
Get-BitLocker-Status -name $name 
Check-Secure-Boot -name $name
Check-TPM -name $name
Get-RAID-Status -name $name
Get-Asset-Tag -name $name
Get-BIOS-Version -name $name