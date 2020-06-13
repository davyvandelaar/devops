#!powershell

# Copyright: Davy van de Laar
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"
# input parameters
$params = Parse-Args $args -supports_check_mode $true
$firewallsection = Get-AnsibleParam -obj $params -name "firewall_section" -type "str" -failifempty $true
$firewallrule = Get-AnsibleParam -obj $params -name "firewall_rule" -type "str" -failifempty $true
$securitygroup = Get-AnsibleParam -obj $params -name "security_group" -type "str" -failifempty $true
$ssouser = Get-AnsibleParam -obj $params -name "sso_user" -type "str" -failifempty $true
$ssopassword = Get-AnsibleParam -obj $params -name "sso_password" -type "str" -failifempty $true
$vcenter = Get-AnsibleParam -obj $params -name "vcenter" -type "str" -failifempty $true

# result status
$result = @{
    changed = $false
    firewallrule = $firewallrule
    firewallsection = $firewallsection
    securitygroup = $securitygroup
}

# make connection with nsx and vcenter
try {
        Connect-NsxServer -vCenterServer $vcenter -Username $ssouser -Password $ssopassword
    }
    catch {
        Fail-Json -obj $result "check credentials or contact administrator"
    }

# check if firewallsection exists, this is a requirement to continue
# check if rule exists in section, if not exists create rule within section at bottom of section, with allow rule
if (Get-NsxFirewallSection -Name $firewallsection){
    $result.firewallsection = "section $firewallsection exists"
} 
else { Fail-Json -obj $result.firewallsection "section $firewallsection does not exist, check firewall_section or contact administrator" }

If (Get-NsxFirewallSection -Name $firewallsection | Get-NsxFirewallRule -Name $firewallrule){
    $result.firewallrule = "firewall rule $firewallrule already exists in $firewallsection"
}
else {
    try{
        Get-NsxFirewallSection $firewallsection | New-NsxFirewallRule -Name $firewallrule -source (Get-NsxSecurityGroup $securitygroup) -Destination (Get-NsxSecurityGroup $securitygroup) -Action Allow -Position Bottom -EnableLogging 
    } catch { Fail-Json -obj $result "unknown error creating rule $firewallrule" }
    $result.changed = $true
}

Exit-Json -obj $result