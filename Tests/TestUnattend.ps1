using module '..\Modules\UnattendXml.psm1'

$unattend = [UnattendXml]::new()
$unattend.SetComputerName('BobsPC')
$unattend.SetRegisteredOwner('Bob Minion')
$unattend.SetRegisteredOrganization('Minions Evil Empire')
$unattend.SetTimeZone('W. Europe Standard Time')
$unattend.SetAdministratorPassword('C1sco12345')
$unattend.SetInterfaceIPAddress('Ethernet', '10.1.1.5', 24, '10.1.1.1')
$unattend.SetDHCPEnabled('Ethernet', $false)
$unattend.SetRouterDiscoveryEnabled('Ethernet', $false)
$unattend.SetInterfaceIPv4Metric('Ethernet', 10)

$unattend.AddFirstLogonCommand('Get a directory', 'dir')
$unattend.AddFirstLogonCommand('come take my hand', 'bob a ran')
$unattend.AddFirstLogonCommand('Minions rule!', 'Bob stuart kevin')

$unattend.AddRunSynchronousCommand('First command', '', 'bob@minions.com', 'banana', 'feed the minions') | Out-Null
$unattend.AddRunSynchronousCommand('Second command', '', 'marcia@brady.com', 'OhMyGoodness', 'brushmyhair.exe', [EnumWillReboot]::Always) | Out-Null
$unattend.AddRunSynchronousCommand('Third command', "there's a story") | Out-Null

$unattend.SetRemoteDesktopEnabled()

$unattend.ToXml()

Exit