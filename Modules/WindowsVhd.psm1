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

using module '.\BcdBoot.psm1'
using module '.\RegistryHive.psm1'

<#
    .SYNOPSIS
        A class for creating and manipulating VHDX files for Windows Server 2016 

    .DESCRIPTION
        WindowsVHD is an API and a series of tools which abstract most of the process of
        automating the installation of Windows Server 2016 within a VHDX for UEFI booting.

        In addition, there are extensive customization commands such as mounting and
        editing the system registry of the VHD, inserting drivers, adding Windows roles,
        and adding files like unattend.xml

    .NOTES
        TODO: Figure out how to use proper namespaces and types. ciminstance is really not 
        good as it's a parent class type. In addition, it would be nice to have a proper type
        for $this.vhdPath
#>
class WindowsVhd
{
    hidden static [string]$GptTypeUEFISystem = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    hidden static [string]$GptTypeMicrosoftReserved = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    hidden static [string]$GptTypeMicrosoftBasic = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    [string]$vhdPath = $null
    hidden $vhd = $null
    hidden [ciminstance]$disk = $null
    hidden [ciminstance]$windowsPartition = $null
    hidden [string]$windowsDriveLetter = $null
    hidden [ciminstance]$systemPartition = $null
    hidden [string]$systemDriveLetter = $null
    hidden [RegistryHive]$systemRegistryHive = $null

    <#
        .SYNOPSIS
            Constructor

        .PARAMETER vhdPath
            A string containing the path to a VHD file
    #>
    WindowsVhd([string]$vhdPath) {
        $this.vhdPath = $vhdPath
    }

    <#
        .SYNOPSIS
            Returns the mounted Windows drive letter
    #>
    [string]GetWindowsDriveLetter()
    {
        return $this.windowsDriveLetter
    }

    <#
        .SYNOPSIS
            Returns the mounted System drive letter
    #>
    [string]GetSystemDriveLetter()
    {
        return $this.systemDriveLetter
    }

    <#
        .SYNOPSIS
            Attempts to identify and mount the UEFI system partition
    #>
    hidden [void]MountSystemPartition() 
    {
        if($this.systemPartition) {
            throw 'A system partition is already mounted'
        }

        $partitions = $this.disk | Get-Partition
        $this.systemPartition = $partitions | Where { $_.GptType -eq [WindowsVhd]::GptTypeUEFISystem }
        if ($this.systemPartition) {
            $this.systemPartition | Add-PartitionAccessPath -AssignDriveLetter
            $this.systemPartition = $this.systemPartition | Get-Partition
            $this.systemDriveLetter = $this.systemPartition.AccessPaths[0].trimend('\').replace('\?', '??')
            $driveLetter = $this.systemDriveLetter[0]

            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root "$($driveLetter):\"
        }
    }

    <#
        .SYNOPSIS
            Attempts to identify and mount the Windows partition

        .NOTES
            This function currently guesses the windows partition by simply choosing a partition which
            is neither a reserved partition or a UEFI system partition.
    #>
    hidden [void]MountWindowsPartition()
    {
        $partitions = $this.disk | Get-Partition
        # TODO : Find a better way of guessing what the windows partition is. This is probably better handled by using BCDEdit
        $this.windowsPartition = $partitions | Where { ($_.GptType -ne [WindowsVhd]::GptTypeUEFISystem) -and ($_.GptType -ne [WindowsVhd]::GptTypeMicrosoftReserved) -and ([char]::IsLetter($_.DriveLetter[0])) }
        if ($this.windowsPartition) {
            $this.windowsDriveLetter = "$($this.windowsPartition.DriveLetter):"
        }
    }

    <#
        .SYNOPSIS
            Attempts to mount the VHD file.
        
        .DESCRIPTION
            This function mounts the Windows partition as well as the UEFI system partition 
            if available.
    #>
    [void]Mount() {
        if($this.vhd) {
            throw 'There is already a VHD mounted'
        }

        $this.vhd = Get-VHD -Path $this.vhdPath

        $mountResult = $this.vhd | Mount-VHD -Passthru

        $this.disk = $mountResult | Get-Disk
        If ($this.disk -eq $null) {
            $this.vhd | Dismount-VHD 
            $this.vhd = $null

            throw 'Failed to mount disk'
        }

        $this.MountSystemPartition()
        $this.MountWindowsPartition()
    }

    <#
        .SYNOPSIS
            Dismounts the VHD
    #>
    [void]Dismount() {
        If($this.systemRegistryHive) {
            If($this.systemRegistryHive.IsMounted()) {
                $this.systemRegistryHive.DismountHive()
            }
            $this.systemRegistryHive = $null
        }
        
        If($this.systemPartition) {
            $this.systemPartition | Remove-PartitionAccessPath -AccessPath $this.systemPartition.AccessPaths[0]
            $this.systemDriveLetter = $null
            $this.systemPartition = $null
        }

        If($this.windowsPartition) {
            $this.windowsPartition = $null
            $this.windowsDriveLetter = $null
        }

        If ($this.Vhd -ne $null) {
            $this.vhd | Dismount-VHD 
            $this.disk = $null
            $this.vhd = $null
        }
    }

    <#
        .SYNOPSIS
            Dismounts and remounts the VHD
    #>
    [void] Remount()
    {
        $this.Dismount()
        $this.Mount()
    }

    <#
        .SYNOPSIS
            Creates a new VHDX file
        
        .PARAMETER ImageSizeBytes
            The size of the image to create. If the image is dynamic, this is the maximum size

        .PARAMETER BlockSizeBytes
            The size of a block on the image. 1MB is common

        .PARAMETER Dynamic
            Specifices whether to create a dynamic image or not.
    #>
    [void] NewImage(
        [int64] $ImageSizeBytes,
        [int64] $BlockSizeBytes,
        [bool] $Dynamic) 
    {
        If ($this.vhd -ne $null) {
            throw 'VHD already assigned'
        }

        If ($Dynamic) {
            $this.vhd = New-VHD -Path $this.vhdPath -SizeBytes $ImageSizeBytes -BlockSizeBytes $BlockSizeBytes -Dynamic
        } else {
            $this.vhd = New-VHD -Path $this.vhdPath -SizeBytes $ImageSizeBytes -BlockSizeBytes $BlockSizeBytes
        }

        $this.disk = $this.vhd | Mount-VHD -Passthru | Get-Disk
    }

    <#
        .SYNOPSIS
            Initializes the VHD as a GPT disk
    #>
    [void] InitializeGPTDisk() {
        Initialize-Disk -Number $this.disk.Number -PartitionStyle GPT
    }

    <#
        .SYNOPSIS
            Creates and formats a UEFI System partition.

        .PARAMETER PartitionSizeBytes
            The size of the partition to create

        .LINK
            https://en.wikipedia.org/wiki/EFI_system_partition
    #>
    hidden [CimInstance] CreateSystemPartition([UInt64]$PartitionSizeBytes)
    {
        $this.systemPartition = New-Partition -DiskNumber $this.disk.Number -Size $PartitionSizeBytes -GptType ([WindowsVhd]::GptTypeMicrosoftBasic)
        $systemVolume = Format-Volume -Partition $this.systemPartition -FileSystem FAT32 -Force -Confirm:$false
        $this.systemPartition | Set-Partition -GptType ([WindowsVhd]::GptTypeUEFISystem)
        $this.systemPartition | Add-PartitionAccessPath -AssignDriveLetter
        $this.systemPartition = $this.systemPartition | Get-Partition

        return $this.systemPartition
    }

    <#
        .SYNOPSIS
           Creates a reserved partition

        .PARAMETER PartitionSizeBytes
            The size of the partition to create

        .LINK
            https://en.wikipedia.org/wiki/Microsoft_Reserved_Partition
    #>
    hidden [CimInstance] CreateReservedPartition([UInt64]$PartitionSizeBytes)
    {
        $reservedPartition = New-Partition -DiskNumber $this.disk.Number -Size $PartitionSizeBytes -GptType ([WindowsVhd]::GptTypeMicrosoftReserved)
        return $reservedPartition
    }

    <#
        .SYNOPSIS
            Creates and formats an NTFS partition using the remaining space of the drive.
    #>
    hidden [CimInstance] CreateAndFormatNTFSPartition()
    {
        $this.windowsPartition = New-Partition -DiskNumber $this.disk.Number -UseMaximumSize -GptType ([WindowsVhd]::GptTypeMicrosoftBasic)
        $windowsVolume = Format-Volume -Partition $this.windowsPartition -FileSystem NTFS -Force -Confirm:$false
        $this.windowsPartition | Add-PartitionAccessPath -AssignDriveLetter
        $this.windowsPartition = $this.windowsPartition | Get-Partition

        return $this.windowsPartition
    }

    <#
        .SYNOPSIS
            Creates a new VHDX and installs Windows to the disk from an ISO file
        
        .DESCRIPTION
            Creates a VHDX file employing a GPT partition system, UEFI booting and NTFS disk type. Then
            Windows Server is installed to the partition and configured to boot.

        .PARAMETER IsoPath
            The path to the ISO file to use for installation

        .PARAMETER Edition
            The name of the edition to install. This must align with the names returned by Get-WindowsImage

        .PARAMETER
            The size of the image to create

        .LINK
            https://technet.microsoft.com/en-us/library/dn376495.aspx

        .NOTES
            This is developed and tested only against Windows Server 2016
    #>
    [void]CreateFromISO(
        [string] $IsoPath,
        [string] $Edition,
        [int64] $ImageSizeBytes)
    {
        [ciminstance]$mountIsoResult = $null
        [char]$driveLetter = ' '

        Try {
            $mountIsoResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
        } Catch {
            throw '...Failed to mount ' + $IsoPath
        }

        Try {
            # Refresh variable... might be a bug... see Convert-WindowsImage.
            $mountIsoResult = Get-DiskImage -ImagePath $IsoPath

            $driveLetter = ($mountIsoResult | Get-Volume).DriveLetter

            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root "$($driveLetter):\"
        } Catch {
            Write-Debug 'Failed to complete mounting of ' + $IsoPath
            Dismount-DiskImage -ImagePath $IsoPath 
            throw '... Failed to get mount the ISO as a drive'
        }
           
        [string]$sourceWim = '{0}:\Sources\install.wim' -f $driveLetter

        Try {
            If (!(Test-Path $sourceWim)) {
                throw $sourceWim + ' does not appear to exist'
            }
            
            $windowsImages = Get-WindowsImage -ImagePath $sourceWim
            $windowsImage = $windowsImages | Where { $_.ImageName.EndsWith($Edition) }
            If (-not $windowsImage -or ($windowsImage -is [System.Array])) {
                throw 'Edition ' + $Edition + ' not found within the given ISO'
            }

            $windowsImageIndex = $windowsImage[0].ImageIndex

            $this.NewImage($ImageSizeBytes, 1MB, $true)
            Write-Debug '...Initializing disk image as GPT'
            $this.InitializeGPTDisk()
            Write-Debug '...Creating 200MB system partition'
            $this.CreateSystemPartition(200MB)
            Write-Debug '...Creating 128MB reserved partition'
            $this.CreateReservedPartition(128MB)
            Write-Debug '...Creating Windows partition with remaining space. Formatting as NTFS'
            $this.CreateAndFormatNTFSPartition()
            Write-Debug '...Dismounting and remounting image to refresh it'
            $this.Remount()

            Write-Debug '...Installing Windows to the Windows partition'
            Expand-WindowsImage -ApplyPath $this.windowsDriveLetter -ImagePath $sourceWim -Index $windowsImageIndex
            Write-Debug '...Writing UEFI boot image to system drive'
            [BcdBoot]::ConfigureUEFIBoot($this.windowsDriveLetter, $this.systemDriveLetter)
        } Catch {
            Write-Debug $_.Exception.Message
            $this.Dismount()
        } Finally {
            Write-Debug 'Dismounting image'
            Dismount-DiskImage -ImagePath $IsoPath 
        }
    }

    <#
        .SYNOPSIS
            Mounts the windows system registry hive from the VHD file
        
        .NOTES
            If DismountHive() is called on the returned object, the hive object
            will clean itself up, but will leave a "hanging pointer" within this class.
            This function can be called again if needed and it will work cleanly. Also
            the hive will be automatically dismounted if the VHD is dismounted.
    #>
    [RegistryHive]MountSystemRegistryHive()
    {
        [string]$systemHivePath = '{0}\Windows\System32\config\SYSTEM' -f $this.windowsDriveLetter
        try {
            if($this.systemRegistryHive) {

            } else {
                $this.systemRegistryHive = [RegistryHive]::new()
            }

            if(-not $this.systemRegistryHive.IsMounted()) {
                $this.systemRegistryHive.MountHive($systemHivePath)
            }
        } catch {
            $this.systemRegistryHive = $null
            throw 'Failed to mount the system registry hive'
        }
        return $systemHivePath
    }
}

