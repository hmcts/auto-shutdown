
import json
import os
from datetime import datetime
from datetime import date

listObj = []
filepath = 'issues_list.json'
new_data = os.environ.get('NEW_DATA')
today = date.today()
print(new_data)
try:
  with open(filepath, "r") as json_file:
    listObj = json.load(json_file)
except FileNotFoundError:
  with open(filepath, "w") as json_file:
    listObj.append(new_data)
    json.dump(listObj, json_file, indent=4)
else:
  for x in range(len(listObj)):
    d = json.loads(listObj[x]) 
    if d['Skip shutdown end date'] == "_No response_":
      end_date = today
    else:
      end_date = datetime.strptime(d['Skip shutdown end date'], '%d-%m-%Y').date()
    if today > end_date:
         listObj.pop(x)
  if new_data:
    listObj.append(new_data)
  with open(filepath, "w") as json_file:
    json.dump(listObj, json_file, indent=4)

