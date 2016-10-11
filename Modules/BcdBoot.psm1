<#
This code is written and maintained by Darren R. Starr from Nocturnal Holdings AS Norway.

License :

Copyright (c) 2016 Nocturnal Holdings AS Norway

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software 
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

<#
    .SYNOPSIS
        An API to wrap %SYSTEM32$\bcdboot.exe for making UEFI VHDs bootable

    .DESCRIPTION
        Provides and API specifically designed to make a VHD file UEFI bootable.
        To use this class, a path to the root of the Windows partition of the VHD
        as well as the root of the System partition of the VHD must be present.

    .NOTES
        BcdBoot resolves the location of the BcdBoot.exe executable and
        executes it from where it's found.

    .LINK
        https://technet.microsoft.com/en-us/library/dd744347(v=ws.10).aspx

    .EXAMPLE
        Import-Module BcdBoot.psm1
        [BcdBoot]::ConfigureUEFIBoot('x:', 'y:')
#>
class BcdBoot
{
    hidden [string] $BcdBootPath
    hidden [string] $WindowsPath
    hidden [string] $SystemDrive

    <#
        .SYNOPSIS 
            Constructor
    #>
    BcdBoot()
    {
        $this.ResolveBcdBoot()
    }

    <#
        .SYNOPSIS 
            Constructor

        .PARAMETER WindowsDrive
            The path of the root of the Windows drive.

            This is not the windows directory of the Windows drive.
        
        .PARAMETER SystemDrive
            The path of the root of the System drive. 
    #>
    BcdBoot([string]$WindowsDrive, [string]$SystemDrive)
    {
        $this.ResolveBcdBoot()
        $this.SetSystemDrive($SystemDrive)
        $this.SetWindowsDrive($WindowsDrive)
    }

    hidden [void]ResolveBcdBoot()
    {
        $this.BcdBootPath = Join-Path ([Environment]::SystemDirectory) 'BcdBoot.exe'
        If (-not (Test-Path $this.BcdBootPath)) {
            throw 'Cannot find BcdBoot.exe in ' + $this.BcdBootPath
        }
    }

    <#
        .SYNOPSIS  
            Configures the location of the Windows directory to boot from
        
        .PARAMETER WindowsPath
            The part of the Windows directory to boot from
    #>
    [void] SetWindowsPath([string]$WindowsPath)
    {
        If(-not (Test-Path $WindowsPath)) {
            throw 'Provided Windows directory does not exist -> ' + $WindowsPath
        }

        $this.WindowsPath = $WindowsPath
    }

    <#
        .SYNOPSIS
            Sets the root of the Windows drive to boot from
        
        .PARAMETER WindowsDrive
            The root of the Windows drive to boot from

        .NOTES
            This function attempts to resolve ($WindowsDrive)\Windows if it does
            not exist, this class will not function properly.
    #>
    [void] SetWindowsDrive([string]$WindowsDrive)
    {
        If(-not (Test-Path $WindowsDrive)) {
            throw 'Provided Windows drive does not exist -> ' + $WindowsDrive
        }

        $windowsDirectory = Join-Path $WindowsDrive 'Windows'
        $this.SetWindowsPath($windowsDirectory)
    }

    <#
        .SYNOPSIS 
            Sets the root path of the System drive where the UEFI bootloader is to be installed

        .PARAMETER SystemDrive
            Sets the path of the root of the System partition
    #>
    [void] SetSystemDrive([string]$SystemDrive)
    {
        If(-not (Test-Path $SystemDrive)) {
            throw 'Provided system drive does not exist -> ' + $SystemDrive
        }
        $this.SystemDrive = $SystemDrive
    }

    <#
        .SYNOPSIS
            Applies the changes to the configured drives.
    #>
    [void] Apply()
    {
        $bootArgs = @(
            $this.WindowsPath,
            '/s',
            $this.SystemDrive,
            '/v',
            '/f UEFI'
        )

        $returnCode = Start-Process `
            -FilePath $this.BcdBootPath `
            -ArgumentList $bootArgs `
            -NoNewWindow `
            -Wait `
            -PassThru

        If ($returnCode.ExitCode -ne 0) {
            throw 'Failed to execute BcdBoot.exe'
        }
    }

    <#
        .SYNOPSIS 
            Static function to make the UEFI boot configuration a single line of code.
        
        .PARAMETER WindowsDrive
            The path of the root of the Windows drive.

            This is not the windows directory of the Windows drive.
        
        .PARAMETER SystemDrive
            The path of the root of the System drive. 
    #>
    static [void]ConfigureUEFIBoot([string]$WindowsDrive, [string]$SystemDrive) 
    {
        $instance = [BcdBoot]::new($WindowsDrive, $SystemDrive)
        $instance.Apply()
    }
}

