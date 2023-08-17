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

def azPriceAPI(vm_sku):
    #Microsoft Retail Rates Prices API query and response. (https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
    api_url = "https://prices.azure.com/api/retail/prices?currencyCode='GBP&api-version=2021-10-01-preview"
    query = "armRegionName eq 'uksouth' and skuName eq '" + vm_sku + "' and priceType eq 'Consumption' and productName eq 'Virtual Machines Ddsv5 Series'"
    response = requests.get(api_url, params={'$filter': query})
    json_data = json.loads(response.text)

    #Get retail price from json API response
    for item in json_data['Items']:
        vm_hour_rate = item['retailPrice']
    
    return vm_hour_rate

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
        node_count = int(currentLine[1])
        sku_cost = azPriceAPI(sku)
        combined_total=(combined_total + calculate_cost(sku_cost, node_count, business_days, weekend_days))
#Round  to 2 decimal places to represent currency.
#Format value with appropriate comma for human readable currency.
    cost_output = round(combined_total, 2)
    cost_output_formatted = f"{cost_output:,}"

#Delete temp text file.
os.remove("sku_details.txt")

#Update GitHub env vars with values for issue comment and for pipeline logic.
with open(env_file_path, 'a') as env_file:
    env_file.write('\n' + "COST_DETAILS=" + str(cost_output) + '\n')
    env_file.write("COST_DETAILS_FORMATTED=" + str(cost_output_formatted))
    env_file.close()