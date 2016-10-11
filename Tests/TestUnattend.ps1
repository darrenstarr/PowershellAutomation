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
$unattend.ToXml()

Exit