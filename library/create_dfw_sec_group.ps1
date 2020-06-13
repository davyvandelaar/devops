#!powershell

# Copyright: Davy van de Laar
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

# input parameters
$params = Parse-Args $args -supports_check_mode $true
$securitygroup = Get-AnsibleParam -obj $params -name "security_group" -type "str" -failifempty $true
$ssouser = Get-AnsibleParam -obj $params -name "sso_user" -type "str" -failifempty $true
$ssopassword = Get-AnsibleParam -obj $params -name "sso_password" -type "str" -failifempty $true
$vcenter = Get-AnsibleParam -obj $params -name "vcenter" -type "str" -failifempty $true
$dynamicmemberid = Get-AnsibleParam -obj $params -name "dynamic_memberid" -type "str" -failifempty $true
# result status
$result = @{
    changed = $false
    securitygroup = $securitygroup
}

# make connection with nsx and vcenter
try {
        Connect-NsxServer -vCenterServer $vcenter -Username $ssouser -Password $ssopassword
    }
    catch {
        Fail-Json -obj $result "check credentials or contact administrator"
    }

# check if securitygroup exists, if not exist create new securitygroup
if (Get-NsxSecurityGroup -Name $securitygroup ){
    $result.securitygroup = "security group $securitygroup already exists"
}
else {
    try{
        $criteria = New-NsxDynamicCriteriaSpec -Key VmName -Condition starts_with -Value $dynamicmemberid
        New-NsxSecurityGroup -Name $securitygroup
        Get-NsxSecurityGroup -Name $securitygroup | Add-NsxDynamicMemberSet -SetOperator AND -CriteriaOperator ANY -DynamicCriteriaSpec $criteria
    } catch { Fail-Json -obj $result "unknown error creating rule $securitygroup" }
    $result.changed = $true
}
Exit-Json -obj $result
