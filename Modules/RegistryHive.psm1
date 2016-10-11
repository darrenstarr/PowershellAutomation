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

enum HKEY {
    LOCAL_MACHINE = 1
    CURRENT_USER = 2
}

<#
    .SYNOPSIS
        An API which mounts a registry hive and provides access functions for settings values

    .DESCRIPTION
        RegistryHive is a class to mount a given registry hive file (typically from a mounted
        VHD) to be configured.

    .NOTES
        This is implemented extremely inefficiently by using reg.exe. I have been experimenting
        with using the Windows API RegLoadKey() via reflection. I have been struggling though
        as I don't have experience with elevating privleges AdjustTokenPrivileges(). Currently
        reg.exe appears to work. Once I get further along, I'll implement the correct reflection
        APIs by using PSReflect.

    .LINK
        https://github.com/mattifestation/PSReflect

    .EXAMPLE
        using module 'RegistryHive.psm1'
        
        $hive = [RegistryHive]::new()
        $hive.MountHive('F:\Windows\System32\config\SYSTEM')
        $hive.SetItemProperty('\ControlSet001\Control\Terminal Server', 'fDenyTSConnections', 0)
        $hive.DismountHive()
#>
class RegistryHive
{
    hidden [HKEY] $mountRoot = [HKEY]::LOCAL_MACHINE
    hidden [string] $mountKey = $null

    <#
        .SYNOPSIS
            Convert the enum HKEY to a string values
        
        .PARAMETER value
            The value to convert to a string.

        .NOTES
            TODO: Figure out why switch statements don't seem to work
    #>
    static hidden [string] HKeyString([HKEY]$value)
    {
        if($value -eq [HKEY]::LOCAL_MACHINE) { return 'HKLM' }
        if($value -eq [HKEY]::CURRENT_USER) { return 'HKCU' }
        return $null
    }

    <#
        .SYNOPSIS
            Return the registry hive root using reg.exe command line format 
    #>
    hidden [string]HiveRootReg()
    {
        return '{0}\{1}' -f ([RegistryHive]::HKEYString($this.mountRoot)),$this.mountKey
    }

    <#
        .SYNOPSIS
            Return the registry hive root using Set-ItemProperty format
    #>
    hidden [string]HiveRoot()
    {
        return '{0}:\{1}' -f ([RegistryHive]::HKEYString($this.mountRoot)),$this.mountKey
    }

    <#
        .SYNOPSIS
            Constructor
    #>
    RegistryHive()
    {
    }

    <#
        .SYNOPSIS
            Returns whether there is a hive already mounted
    #>
    [bool]IsMounted()
    {
        return ($this.mountKey -ne $null)
    }

    <#
        .SYNOPSIS
            Mount a hive file 

        .DESCRIPTION
            This function generates a new root key off of HKLM combined with a newly generated GUID

        .NOTES
            It is extremely important to call DismountHive() following calling this function.

        .PARAMETER FileName
            The name of the registry hive file to mount
    #>
    [void]MountHive([string]$FileName)
    {
        if($this.mountKey) {
            throw 'A hive is already mounted'
        }

        $this.mountKey = [System.Guid]::NewGuid().ToString()

        # TODO : Resolve mountKey and if it exists generate a new one

        $regPath = Join-Path ([Environment]::SystemDirectory) 'reg.exe'
        If (-not (Test-Path $regPath)) {
            throw 'Cannot find reg.exe in ' + $regPath
        }

        $regArgs = @(
            'LOAD',
            ($this.HiveRootReg()),
            $FileName
        )

        $returnCode = Start-Process `
            -FilePath $regPath `
            -ArgumentList $regArgs `
            -NoNewWindow `
            -Wait `
            -PassThru

        If ($returnCode.ExitCode -ne 0) {
            throw 'Failed to execute reg.exe'
        }
    }

    <#
        .SYNOPSIS
            Dismount the currently mounted registry file.

        .NOTES
            This function will fail if the registry key is in use elsewhere like regedit
    #>
    [void]DismountHive()
    {
        if(-not $this.mountKey) {
            throw 'A hive is not mounted'
        }

        $regPath = Join-Path ([Environment]::SystemDirectory) 'reg.exe'
        If (-not (Test-Path $regPath)) {
            throw 'Cannot find reg.exe in ' + $regPath
        }

        $regArgs = @(
            'UNLOAD',
            ($this.HiveRootReg())
        )

        $returnCode = Start-Process `
            -FilePath $regPath `
            -ArgumentList $regArgs `
            -NoNewWindow `
            -Wait `
            -PassThru

        If ($returnCode.ExitCode -ne 0) {
            throw 'Failed to execute reg.exe'
        }

        $this.mountKey = $null
    }

    <#
        .SYNOPSIS
            Set the value of a key in the registry.

        .PARAMETER Path
            The path within the mounted registry hive to the key. The key
            should be prefixed with a backslash.

        .PARAMETER Key
            The name of the value within the key to set

        .PARAMETER Value
            The value to set.
    #>
    [void]SetItemProperty([string]$Path, [string]$Key, [string]$Value)
    {
        $registryPath = ($this.HiveRoot() + $Path)
        Set-ItemProperty -Path $registryPath -Name $Key -Value $Value
    }

    <#
        .SYNOPSIS
            Set the value of a key in the registry.

        .PARAMETER Path
            The path within the mounted registry hive to the key. The key
            should be prefixed with a backslash.

        .PARAMETER Key
            The name of the value within the key to set

        .PARAMETER Value
            The value to set.
    #>
    [void]SetItemProperty([string]$Path, [string]$Key, [Int32]$Value)
    {
        $registryPath = ($this.HiveRoot() + $Path)
        Set-ItemProperty -Path $registryPath -Name $Key -Value $Value
    }
}
