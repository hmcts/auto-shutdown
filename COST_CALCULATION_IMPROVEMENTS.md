# Cost Calculation Improvements

## Overview

This enhancement extends the existing cost calculation system to support additional Azure resource types beyond AKS clusters and VM Scale Sets. The system now supports:

- **Virtual Machines** - Individual VMs with accurate SKU detection
- **Application Gateways** - With tier and capacity-based pricing
- **PostgreSQL Flexible Servers** - With compute tier-based pricing  
- **SQL Managed Instances** - With vCore-based pricing

## Key Features

### 1. Scalable Resource Type Support

The system uses a new data format that includes resource type information:
```
ResourceType,SKU,OS/Tier,Count
```

Examples:
```
VM,Standard_D2s_v3,Linux,2
ApplicationGateway,Standard_v2,Standard_v2,1
FlexibleServer,GP_Standard_D2ds_v4,PostgreSQL,1
SqlManagedInstance,GP_Gen5_4,GeneralPurpose,1
```

### 2. Backward Compatibility

The system maintains full backward compatibility with the existing format:
```
SKU,OS,Count
```

Legacy entries are automatically treated as VM resources.

### 3. Enhanced SKU Detection

- **Virtual Machines**: Extracts actual VM size and OS type from Azure properties
- **Application Gateways**: Detects tier, name, and capacity from Azure SKU properties
- **Flexible Servers**: Extracts compute tier and VM size from Azure SKU properties
- **SQL Managed Instances**: Detects service tier, generation, and vCore count

### 4. Robust Pricing API Integration

- Supports different Azure Pricing API product names for each resource type
- Includes fallback pricing when API is unavailable
- Maintains existing retry logic and error handling

### 5. Resource-Specific Cost Calculations

While most resources use the standard shutdown schedule calculation, the system is designed to support resource-specific cost models if needed in the future.

## Implementation Details

### New Functions in `resource-details.sh`

1. **`countResource()`** - Enhanced resource counting with type support
2. **`get_vm_costs()`** - Collects Virtual Machine cost information
3. **`get_appgateway_costs()`** - Collects Application Gateway cost information
4. **`get_flexible_server_costs()`** - Collects Flexible Server cost information
5. **`get_sqlmi_costs()`** - Collects SQL Managed Instance cost information

### Enhanced `cost-calculator.py`

1. **`get_fallback_pricing()`** - Provides fallback pricing when API is unavailable
2. **`azPriceAPI()`** - Enhanced to handle different resource types and product names
3. **Main processing loop** - Supports both new and legacy data formats

## Azure Graph Queries

The system uses enhanced Azure Resource Graph queries to extract pricing-relevant information:

### Virtual Machines
```kql
resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| where tags.autoShutdown == 'true'
| project name, resourceGroup, subscriptionId, ['tags'], 
  properties.hardwareProfile.vmSize, properties.storageProfile.osDisk.osType
```

### Application Gateways
```kql
resources
| where type =~ 'microsoft.network/applicationgateways'
| where tags.autoShutdown == 'true'  
| project name, resourceGroup, subscriptionId, ['tags'],
  properties.sku.tier, properties.sku.name, properties.sku.capacity
```

### PostgreSQL Flexible Servers
```kql
resources
| where type =~ 'microsoft.dbforpostgresql/flexibleservers'
| where tags.autoShutdown == 'true'
| project name, resourceGroup, subscriptionId, ['tags'],
  properties.sku.tier, properties.sku.name
```

### SQL Managed Instances
```kql
resources
| where type =~ 'microsoft.sql/managedinstances'
| where tags.autoShutdown == 'true'
| project name, resourceGroup, subscriptionId, ['tags'],
  properties.sku.tier, properties.sku.family, properties.vCores
```

## Adding New Resource Types

To add support for additional resource types in the future:

1. **Create collection function** in `resource-details.sh`:
   ```bash
   function get_newresource_costs() {
       # Azure graph query to get resources with SKU info
       # Process each resource and call countResource
   }
   ```

2. **Add to main collection** in `resource-details.sh`:
   ```bash
   get_newresource_costs
   ```

3. **Add pricing logic** in `cost-calculator.py`:
   ```python
   elif resource_type == "NewResourceType":
       productName = "'New Resource Product Name'"
   ```

4. **Add fallback pricing** in `cost-calculator.py`:
   ```python
   "NewResourceType": {
       "SKU_Name": hourly_rate
   }
   ```

## Testing

The implementation includes comprehensive tests covering:

- Legacy format compatibility
- New format support  
- Mixed format handling
- All resource types
- Stay-on-late functionality
- Error handling and fallback pricing

Run tests with:
```bash
# Basic functionality test
./test_cost_calculation.sh

# Comprehensive test suite  
./final_test_suite.sh
```

## Cost Estimation Accuracy

The system maintains the existing 25% buffer for unmeasurable costs and uses realistic fallback pricing when the Azure Pricing API is unavailable. This ensures cost estimates remain useful even in degraded conditions.

## Future Enhancements

Potential future improvements:
- Resource-specific cost calculation models
- Regional pricing support
- Reserved instance pricing consideration
- More granular Application Gateway data processing costs
- Disk and storage cost calculations