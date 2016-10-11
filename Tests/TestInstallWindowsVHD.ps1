using module '..\Modules\WindowsVhd.psm1'
using module '..\Modules\BcdBoot.psm1'

$DebugPreference = "Continue"
$vhdx = [WindowsVhd]::new('C:\Temp\TestImage1.vhdx')
$vhdx.CreateFromISO('C:\Shares\ISO Files\Microsoft\Windows Server 2016 TP5\en_windows_server_2016_technical_preview_5_x64_dvd_8512312.iso', 'SERVERDATACENTERCORE', 100GB)
$vhdx.Dismount()
#$vhdx.Mount()

#[BcdBoot]::ConfigureUEFIBoot($vhdx.windowsDriveLetter, $vhdx.systemDriveLetter)

#$vhdx.Dismount()
