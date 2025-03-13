# Get all VM Scale Sets uniform instances. Does not include flexible instances which we do not use.
#
# Environment and business area matching is case-insensitive.
#
# Usage: get_vmss_instances [environment] [business_area]
# Example: get_vmss_instances "development" "cross-cutting"
#
function get_vmss_instances() {
    log "----------------------------------------------"
    log "Running az graph query..."

    env_selector=$(env_selector "$1")
    area_selector=$(area_selector "$2")

    az graph query -q "
    computeresources
    | where type =~ 'microsoft.compute/virtualmachinescalesets/virtualmachines'
    $env_selector
    $area_selector
    | where tags.autoShutdown == 'true'
    | where not (name matches regex '(^aks-|-aks-|-aks$)')
    | where not (resourceGroup matches regex '(^aks-|-aks-|-aks$)')
    | extend vmssId = replace(@'\/virtualMachines\/[^\/]+$', '', id)
    | extend vmssName = extract(@'/([^\/]+)/virtualMachines/[^\/]+$', 1, id)
    | extend instanceIdx = extract(@'/virtualMachines/([^\/]+)$', 1, id)
    | project vmssId, vmssName, resourceGroup, subscriptionId, instanceIdx, ['tags'],
        osType = properties.storageProfile.osDisk.osType,
        vmSize=properties.hardwareProfile.vmSize,
        powerState = properties.extended.instanceView.powerState.code
    "  --first 1000 -o json

    log "az graph query complete"
}