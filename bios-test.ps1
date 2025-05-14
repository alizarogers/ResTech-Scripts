### TO DO ###
<# -firgure out raid/ahci commands
- output asset tag
- test
#>

#Requires -RunAsAdministrator

param 
(
    $name
)
    
$TPM20 = @("1.3.2.8",'7\.2(.*)')
$TPM12 = @(

$ErrorActionPreference = "Stop"


# # # # # # # # # # # #     Validation     # # # # # # # # # # # #
 

$return = ping $name

# Ensuring that the machine is online first. Script will exit if it is not. 

if (!($return[2] -match "Reply"))
{
   if ($return[2] -match "Request timed out.")
   {
        $message = $name + " is offline."
   }
   elseif ($return -match "could not find host")
   {
        $message = $name + " host could not be found."
   }
   else
   {
        $message = "Something went wrong."
   }

   Write-Host $message

   Exit
}

# The machine must be onling to make it to this point.

$message = $name + " is online. Proceeding to check BIOS settings. `n"
Write-Host $message 


# # # # # # # # # # # #     BIOS Settings     # # # # # # # # # # # #


# Secure Boot

try{
    $return = Invoke-Command -ComputerName $name -ScriptBlock {Confirm-SecureBootUEFI}
} catch {

    Write-Host "Error: Invoke Command to check Secure Boot failed." -ForegroundColor Red
    Exit
}


if ( $return -eq $true )
{
    Write-Host "Secure Boot: on `n" -ForegroundColor Green
}
else 
{
    Write-Host "Secure Boot: off `n" -ForegroundColor DarkRed
}

# TPM 2.0 

try {
    $return = Invoke-Command -ComputerName $name -ScriptBlock {Get-Tpm | Select-Object TpmPresent, TpmEnabled, ManufacturerVersion}
} catch {
    Write-Host "Error: Invoke Command to check TPM 2.0 failed." -ForegroundColor Red
    Exit
}

if ($return.TpmPresent -eq $false)
{
    Write-Host "TPM not present `n" -ForegroundColor DarkRed
}
elseif ($return.TpmEnabled -eq $false)
{
    Write-Host "TPM enabled: no `n" -ForegroundColor DarkRed
}
else # TPM is present and enabled
{
    $message = "TPM Manufacturer Version: " + $return.ManufacturerVersion + '`n'

    # if the TPM mfg version is not in the known 2.0 list
    if (($TPM20 | Where-Object {$return.ManufacturerVersion -match $_}) -eq $null)
    {
        # if the TPM mfg version is in the known 1.2 list
        if (!(($TPM12 | Where-Object {$return.ManufacturerVersion -match $_}) -eq $null))
        {
            Write-Host $message -ForegroundColor DarkRed
        }
        # the manufacturer version didn't match either known TPM list
        else 
        {
            $message = $message + "Check TPM version. `n"
            Write-Host $message 
        }
    }
    # the TPM mfg version is within the known 2.0 list
    else
    {
        Write-Host $message -ForegroundColor Green
    }
}

# RAID check

try {
$retrn = Invoke-Command -ComputerName $name -ScriptBlock {Get-PhysicalDisk | Select-Object FriendlyName, BusType}
} catch {
    Write-Host "Error: Invoke Command to check RAID status failed." -ForegroundColor Red
    Exit
}

Exit