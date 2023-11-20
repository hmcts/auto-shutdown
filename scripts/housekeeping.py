import json
import os
from datetime import date
from dateutil.parser import parse

env_file = os.getenv("GITHUB_ENV")
filepath = "issues_list.json"
today = date.today()
listObj = []
temp_listObj = []

try:
    with open(filepath, "r") as json_file:
        listObj = json.load(json_file)
        with open(env_file, "a") as env_file:
            env_file.write("JSON_FILE_EXISTS=true")
except FileNotFoundError:
    print("No file to clean up")
    with open(env_file, "a") as env_file:
        env_file.write("JSON_FILE_EXISTS=false")
    exit(0)

for x in range(len(listObj)):
    d = listObj[x]
    end_date = parse(d["end_date"], dayfirst=True).date()
    #logic: if entry is valid, it will write to a new file, which replaces the exisiting file.
    if today > end_date:
        print("======== Deleting ========")
        print(d)
    else:
        print("======== Valid Entry ========")
        temp_listObj.append(d)

listObj = temp_listObj

with open(filepath, "w") as json_file:
    json.dump(listObj, json_file, indent=4)
