import json
import os
from datetime import datetime
from datetime import date
from dateutil.parser import parse
#Vars
listObj = []
filepath = "issues_list.json"
new_data = json.loads(os.environ.get("NEW_DATA", "{}"))
# Check if "Skip shutdown start date" is None or empty
skip_shutdown_start_date = new_data.get("Skip shutdown start date", None)
if skip_shutdown_start_date is None:
    new_data["start_date"] = new_data.pop("On Demand start date")
    new_data["end_date"] = new_data.pop("On Demand end date")
    new_data["request_type"] = "start"
else:
    new_data["start_date"] = new_data.pop("Skip shutdown start date")
    new_data["end_date"] = new_data.pop("Skip shutdown end date")
    new_data["request_type"] = "stop"
new_data["environment"] = new_data.pop("Environment")
new_data["business_area"] = new_data.pop("Business area")
new_data["change_jira_id"] = new_data.pop("Change or Jira reference")
new_data["business_area"] = new_data["business_area"].lower()
new_data["stay_on_late"] = new_data.pop("Do you need this exclusion past 23:00?")
print("==================")
issue_number = os.environ.get("ISSUE_NUMBER")
github_repository = os.environ.get("GITHUB_REPO")
today = date.today()
env_file_path = os.getenv("GITHUB_ENV")

def update_env_vars(var_to_update, new_var):
    env_vars_file = open(env_file_path, 'rt')
    env_vars_contents = env_vars_file.read()
    if var_to_update in env_vars_contents:
        env_vars_contents = env_vars_contents.replace(var_to_update, new_var)
        env_vars_file.close()
        env_vars_file = open(env_file_path, 'wt')
        env_vars_file.write(env_vars_contents)
        env_vars_file.close()
        print(var_to_update + " has been updated to " + new_var)
    else:
        print("var does not exist")

with open(env_file_path, 'a') as env_file:
    env_file.write('\n' + "PROCESS_SUCCESS=false" + '\n')
    env_file.write("ISSUE_COMMENT=Processing failed")
    env_file.close()

if new_data:
    new_data["issue_link"] = ("https://github.com/" + github_repository + "/issues/" + issue_number)
    #Business area validation
    try:
        if new_data["business_area"] not in ("cft", "cross-cutting"):
            raise RuntimeError("Error: Business area does not exist")
    except RuntimeError:
            update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: Business area does not exist")
            print("Business area RuntimeError")
            exit(0)
    except:
            update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: Unexpected business area")
            print("Unexpected Error in business area")
            exit(0)

#Start Date logic
    try:
        new_data["start_date"] = parse(new_data["start_date"], dayfirst=True).date()
        if new_data["start_date"] < today:
            raise RuntimeError("Start Date is in the past")
        else:
            date_start_date = new_data["start_date"]
            new_data["start_date"] = new_data["start_date"].strftime("%d-%m-%Y")
    except RuntimeError:
            update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: Start date cannot be in the past")
            print("RuntimeError")
            exit(0)
    except:
            update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: Unexpected start date format")
            print("Unexpected Error")
            exit(0)
#End Date logic
    if new_data["end_date"] == "_No response_":
        if date_start_date > today:
            new_data["end_date"] = new_data["start_date"]
        elif date_start_date == today:
            new_data["end_date"] = today.strftime("%d-%m-%Y")
    elif new_data["end_date"] != "_No response_":
        try:
            new_data["end_date"] = parse(new_data["end_date"], dayfirst=True).date()
            if new_data["end_date"] < date_start_date:
                print("in if statement")
                raise RuntimeError("End date cannot be before start date")
            else:
                print("in else")
                date_end_date = new_data["end_date"]
                new_data["end_date"] = new_data["end_date"].strftime("%d-%m-%Y")
        except RuntimeError:
                update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: End date cannot be before start date")
                exit(0)
        except:
                update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Error: Unexpected end date format")
                exit(0)
#Write to file
try:
    with open(filepath, "r") as json_file:
        listObj = json.load(json_file)
        listObj.append(new_data)
        json_file.close()
except FileNotFoundError:
    with open(filepath, "w") as json_file:
        print("Creating new issues_list.json file")
        listObj.append(new_data)
finally:
    with open(filepath, 'w') as json_file:
        json.dump(listObj, json_file, indent=4)
        json_file.close()

    update_env_vars("ISSUE_COMMENT=Processing failed", "ISSUE_COMMENT=Processed Correctly")
    update_env_vars("PROCESS_SUCCESS=false", "PROCESS_SUCCESS=true")