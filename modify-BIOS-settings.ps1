function Confirm-Module {
    param ( $moduleName = "DellBIOSProvider" )

    # if the module is not installed, install it
    if (-not $(Get-Module -Name $moduleName -ListAvailable)){ 
        try {
            Install-Module -Name $moduleName
        } catch {
            Write-Error "There was an error while installing $moduleName. (Check admin privileges.)"
            Return $false
        }
    }
    Import-Module DellBIOSProvider
    Return $true
}

function Set-AssetTag {
    param ( [Parameter(Mandatory=$true)] $assetTag )

    if (Confirm-Module) {
        try {
            Set-Item DellSmbios:\SystemInformation\Asset $assetTag
        } catch {
            Write-Error "There was an error while trying to set the asset tag."
            Return
        }
    }
}

function Set-SecureBoot {
    
    if (Confirm-Module) {
        # confirm that legacy option ROMs option is disabled (necesarry to turn secure boot on)
        Set-Location DellSmbios:\AdvancedBootOptions\
       if ((Get-Item .\LegacyOrom).CurrentValue -eq "Enabled")
       {
            Set-Item DellSmbios:\AdvancedBootOptions\LegacyOrom "Disabled"
       }

    }
}