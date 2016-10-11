enum HKEY {
    LOCAL_MACHINE = 1
    CURRENT_USER = 2
}

class RegistryHive
{
    hidden [HKEY] $mountRoot = [HKEY]::LOCAL_MACHINE
    hidden [string] $mountKey = $null

    static hidden [string] HKeyString([HKEY]$value)
    {
        if($value -eq [HKEY]::LOCAL_MACHINE) { return 'HKLM' }
        if($value -eq [HKEY]::CURRENT_USER) { return 'HKCU' }
        return $null
    }

    hidden [string]HiveRootReg()
    {
        return '{0}\{1}' -f ([RegistryHive]::HKEYString($this.mountRoot)),$this.mountKey
    }

    hidden [string]HiveRoot()
    {
        return '{0}:\{1}' -f ([RegistryHive]::HKEYString($this.mountRoot)),$this.mountKey
    }

    RegistryHive()
    {
    }

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

    [void]SetItemProperty([string]$Path, [string]$Key, [string]$Value)
    {
        $registryPath = ($this.HiveRoot() + $Path)
        Set-ItemProperty -Path $registryPath -Name $Key -Value $Value
    }

    [void]SetItemProperty([string]$Path, [string]$Key, [Int32]$Value)
    {
        $registryPath = ($this.HiveRoot() + $Path)
        Set-ItemProperty -Path $registryPath -Name $Key -Value $Value
    }
}

$foo = [RegistryHive]::new()
$foo.MountHive('F:\Windows\System32\config\SYSTEM')

$foo.SetItemProperty('\ControlSet001\Control\Terminal Server', 'fDenyTSConnections', 0)

