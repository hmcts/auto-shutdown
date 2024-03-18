#!/usr/bin/env python3
import requests
import json
from datetime import datetime, date, timedelta
from dateutil.parser import parse
import numpy as np
import os

#Read GitHub environment variables
start_date = os.getenv("START_DATE")
end_date = os.getenv("END_DATE")
env_file_path = os.getenv("GITHUB_ENV")

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

#Function to add entries to the GitHub env list.
def writeStringVar(varName, varValue):
    with open(env_file_path, 'a') as env_file:
        env_file.write('\n' + varName + "=" + str(varValue) + '\n')
        env_file.close()

def azPriceAPI(vm_sku, productNameVar, osQuery,retry=0):
    try:
        #Microsoft Retail Rates Prices API query and response. (https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
        api_url = "https://prices.azure.com/api/retail/prices?currencyCode='GBP&api-version=2021-10-01-preview"
        query = "armRegionName eq 'uksouth' and skuName eq '" + vm_sku + "' and priceType eq 'Consumption' and productName eq " + osQuery
        response = requests.get(api_url, params={'$filter': query})
        json_data = json.loads(response.text)
        #Get retail price from json API response
        for item in json_data['Items']:
            vm_hour_rate = item['retailPrice']
        
        return vm_hour_rate

    #API occasionally fails to return a value which was causing issues in cost feedback to users. See DTSPO-15193
    #Retry will attempt up to 5 retries. If it is still unable to return a value, the rate will be defaulted to 0.
    except:
        if retry < 5: #Edit retry limit here.
            return azPriceAPI(vm_sku, productNameVar, osQuery,retry+1)
        else:
            print("Unable to get costs, defaulting to £0.00")
            writeStringVar("ERROR_IN_COSTS", "true")
            default_rate = 0
            return default_rate

#Cost calculation function.
#Clusters are shutdown for ~11 hours on weekday nights and 24 hours on weekend days.
#Cost is equal to hourly cluster node rate, multiplied by total number of additional running hours, multiplied by the number of cluster nodes.
#25% add to costs, to take into account the other MS Azure resources impacted by extended running hours (logs etc).
def calculate_cost(env_rate, node_count, skip_bus_days, skip_weekend_days):
    bus_hours = (11 * skip_bus_days)
    weekend_hours = (24 * skip_weekend_days)
    total_hours = (bus_hours + weekend_hours)
    node_cost = (env_rate * total_hours)*node_count
    total_cost = ((node_cost // 100) * 25) + node_cost

    return total_cost

#Read cluster SKU's and node count from text file, line by line.
#Increment "combined total" var for each SKU/node count.
with open("sku_details.txt", "r") as filestream:
    combined_total=0
    for line in filestream:
        currentLine = line.split(",")
        sku = str(currentLine[0])
        osType = str(currentLine[1])
        node_count = int(currentLine[2])
        sku_split = sku.split('_')
        sku_type = '' .join((z for z in sku_split[1] if not z.isdigit()))
        productNameVar = sku_type + sku_split[2]
        if osType == "Linux":
            linuxQuery = "'Virtual Machines " + productNameVar +  " Series'"
            sku_cost = azPriceAPI(sku, productNameVar, linuxQuery)
        elif osType == "Windows":
            windowsQuery = "'Virtual Machines " + productNameVar +  " Series Windows'"
            sku_cost = azPriceAPI(sku, productNameVar, windowsQuery)

        combined_total=(combined_total + calculate_cost(sku_cost, node_count, business_days, weekend_days))
#Round  to 2 decimal places to represent currency.
#Format value with appropriate comma for human readable currency.
    cost_output = round(combined_total, 2)
    cost_output_formatted = f"{cost_output:,}"

#Delete temp text file.
os.remove("sku_details.txt")

writeStringVar("COST_DETAILS", cost_output)
writeStringVar("COST_DETAILS_FORMATTED", cost_output_formatted)