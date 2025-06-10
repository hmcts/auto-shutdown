#!/usr/bin/env python3
import requests
import json
from datetime import datetime, date, timedelta
from dateutil.parser import parse
import numpy as np
import os

print("Calculating costs...")

#Read GitHub environment variables
start_date = os.getenv("START_DATE")
end_date = os.getenv("END_DATE")
env_file_path = os.getenv("GITHUB_ENV")
stay_on_late = os.getenv("STAY_ON_LATE")

#Read start/end dates from env vars
start = parse(start_date, dayfirst=True).date()
start_date = start.strftime("%d-%m-%Y")
end = parse(end_date, dayfirst=True).date()
end_date = end.strftime("%d-%m-%Y")

#Get number of business days between 2 dates
business_days = np.busday_count(start, (end + timedelta(days=1)))

#Get num of days in span. +1 to include initial day. Weekend days is equal to total days subtract business days.
diff = (end - start).days
total_days = (diff +1)
weekend_days = (total_days - business_days)

def getBusHours(stayOnLate):
    if stayOnLate == "Yes":
        businessHours = 11
    else:
        businessHours = 3
    
    return businessHours

def getWeekendHours(stayOnLate):
    if stayOnLate == "Yes":
        weekendHours = 24
    else:
        weekendHours = 11
    
    return weekendHours

#Function to add entries to the GitHub env list.
def writeStringVar(varName, varValue):
    with open(env_file_path, 'a') as env_file:
        env_file.write('\n' + varName + "=" + str(varValue) + '\n')
        env_file.close()

def get_fallback_pricing(resource_type, sku, os_or_tier):
    """
    Provide fallback pricing when API is not available (for testing)
    These are approximate hourly rates in GBP for common configurations
    """
    fallback_prices = {
        "VM": {
            "Standard_D2s_v3": 0.096,
            "Standard_D4s_v3": 0.192,
            "Standard_B2s": 0.041,
            "Standard_B4ms": 0.166
        },
        "ApplicationGateway": {
            "Standard_v2": 0.0252,  # Base gateway price per hour
            "WAF_v2": 0.0327
        },
        "FlexibleServer": {
            "GP_Standard_D2ds_v4": 0.096,
            "B_Standard_B1ms": 0.013
        },
        "SqlManagedInstance": {
            "GP_Gen5_4": 1.344,  # 4 vCore General Purpose
            "GP_Gen5_8": 2.688
        }
    }
    
    resource_prices = fallback_prices.get(resource_type, {})
    return resource_prices.get(sku, 0.05)  # Default to 5p/hour if not found

def azPriceAPI(resource_type, sku, os_or_tier, retry=0):
    """
    Query Azure Pricing API for different resource types
    """
    try:
        api_url = "https://prices.azure.com/api/retail/prices?currencyCode='GBP'&api-version=2021-10-01-preview"
        
        # Build product name and query based on resource type
        if resource_type == "VM":
            # Extract VM series from SKU (e.g., Standard_D4ds_v5 -> D4dsv5)
            sku_split = sku.split('_')
            sku_type = ''.join((z for z in sku_split[1] if not z.isdigit()))
            productNameVar = sku_type + sku_split[2]
            
            if os_or_tier == "Linux":
                productName = f"'Virtual Machines {productNameVar} Series'"
            elif os_or_tier == "Windows":
                productName = f"'Virtual Machines {productNameVar} Series Windows'"
            else:
                productName = f"'Virtual Machines {productNameVar} Series'"
                
        elif resource_type == "ApplicationGateway":
            productName = "'Application Gateway'"
            # Application Gateway pricing is more complex, often includes data processing
            # For simplicity, we'll use base gateway pricing
            
        elif resource_type == "FlexibleServer":
            productName = "'Azure Database for PostgreSQL Flexible Server'"
            # Flexible server SKUs are different format
            
        elif resource_type == "SqlManagedInstance":
            productName = "'SQL Managed Instance'"
            # SQL MI has vCore-based pricing
            
        else:
            # Default fallback for unknown types
            print(f"Unknown resource type: {resource_type}, defaulting to VM pricing")
            sku_split = sku.split('_')
            sku_type = ''.join((z for z in sku_split[1] if not z.isdigit()))
            productNameVar = sku_type + sku_split[2]
            productName = f"'Virtual Machines {productNameVar} Series'"

        query = f"armRegionName eq 'uksouth' and skuName eq '{sku}' and priceType eq 'Consumption' and productName eq {productName}"
        
        response = requests.get(api_url, params={'$filter': query})
        json_data = json.loads(response.text)
        
        # Get retail price from json API response
        for item in json_data['Items']:
            return item['retailPrice']
        
        # If no exact match found, try fallback strategies
        if resource_type == "ApplicationGateway":
            # Try simpler query for Application Gateway
            query = f"armRegionName eq 'uksouth' and priceType eq 'Consumption' and productName eq 'Application Gateway'"
            response = requests.get(api_url, params={'$filter': query})
            json_data = json.loads(response.text)
            for item in json_data['Items']:
                if 'Standard' in item.get('skuName', ''):
                    return item['retailPrice']
        
        # If still no match, return 0 (will be handled by retry logic)
        raise Exception(f"No pricing found for {resource_type} {sku}")

    except Exception as e:
        # Retry logic - attempt up to 5 retries
        if retry < 5:
            return azPriceAPI(resource_type, sku, os_or_tier, retry + 1)
        else:
            print(f"Unable to get costs from API for {resource_type} {sku}, using fallback pricing")
            # Use fallback pricing instead of defaulting to 0
            fallback_price = get_fallback_pricing(resource_type, sku, os_or_tier)
            if fallback_price == 0:
                writeStringVar("ERROR_IN_COSTS", "true")
            return fallback_price

#Cost calculation function.
#Clusters are shutdown for ~11 hours on weekday nights and 24 hours on weekend days.
#Cost is equal to hourly cluster node rate, multiplied by total number of additional running hours, multiplied by the number of cluster nodes.
#25% add to costs, to take into account the other MS Azure resources impacted by extended running hours (logs etc).
def calculate_cost(env_rate, node_count, skip_bus_days, skip_weekend_days):
    bus_hours = (getBusHours(stay_on_late) * skip_bus_days)
    weekend_hours = (getWeekendHours(stay_on_late) * skip_weekend_days)
    total_hours = (bus_hours + weekend_hours)
    node_cost = (env_rate * total_hours)*node_count
    total_cost = ((node_cost // 100) * 25) + node_cost

    return total_cost

#Read resource details from text file, line by line.
#New format: ResourceType,SKU,OS/Tier,Count
#Legacy format: SKU,OS,Count (treated as VM type)
#Increment "combined total" var for each resource.
with open("sku_details.txt", "r") as filestream:
    combined_total=0
    for line in filestream:
        currentLine = line.split(",")
        
        # Handle both new format and legacy format for backward compatibility
        if len(currentLine) == 4:
            # New format: ResourceType,SKU,OS/Tier,Count
            resource_type = str(currentLine[0])
            sku = str(currentLine[1])
            os_or_tier = str(currentLine[2])
            count = int(currentLine[3])
        elif len(currentLine) == 3:
            # Legacy format: SKU,OS,Count (assume VM type)
            resource_type = "VM"
            sku = str(currentLine[0])
            os_or_tier = str(currentLine[1])
            count = int(currentLine[2])
        elif len(currentLine) == 5 and currentLine[2] == "":
            # Handle malformed line with empty field: ResourceType,SKU,,OS/Tier,Count
            resource_type = str(currentLine[0])
            sku = str(currentLine[1])
            os_or_tier = str(currentLine[3])  # Skip the empty element
            count = int(currentLine[4])
            print(f"Warning: Fixed malformed line with empty field: {line.strip()}")
        else:
            print(f"Invalid line format: {line.strip()}")
            continue
        
        print(f"Processing {resource_type}: {sku} ({os_or_tier}) x{count}")
        
        # Get pricing for this resource
        resource_cost = azPriceAPI(resource_type, sku, os_or_tier)
        
        # Calculate cost based on resource type
        if resource_type in ["VM", "FlexibleServer", "SqlManagedInstance"]:
            # These resources follow the standard shutdown schedule
            total_cost = calculate_cost(resource_cost, count, business_days, weekend_days)
        elif resource_type == "ApplicationGateway":
            # Application Gateways might have different cost calculation
            # For now, use the same calculation but could be customized
            total_cost = calculate_cost(resource_cost, count, business_days, weekend_days)
        else:
            # Default calculation for unknown types
            total_cost = calculate_cost(resource_cost, count, business_days, weekend_days)
        
        combined_total = combined_total + total_cost
#Round  to 2 decimal places to represent currency.
#Format value with appropriate comma for human readable currency.
    cost_output = round(combined_total, 2)
    cost_output_formatted = f"{cost_output:,}"

#Delete temp text file.
os.remove("sku_details.txt")

writeStringVar("COST_DETAILS", cost_output)
writeStringVar("COST_DETAILS_FORMATTED", cost_output_formatted)