import json
import sys

def remove_entry(issue_number):
    filepath = "issues_list.json"
    
    try:
        with open(filepath, "r") as json_file:
            data = json.load(json_file)
            
            entry_found = False

            # Find and remove the entry with the given issue number
            for i, entry in enumerate(data):
                if entry.get("issue_link") == f"https://github.com/hmcts/aks-auto-shutdown-releases/issues/{issue_number}":
                    del data[i]
                    entry_found = True
                    
            if entry_found:
                # Write the modified data back to the file
                with open(filepath, "w") as json_file:
                    json.dump(data, json_file, indent=4)
                print(f"Entry associated with issue {issue_number} removed successfully.")
            else:
                print(f"Entry for issue {issue_number} was not found")

    except FileNotFoundError:
        print("issues_list.json file not found.")
    
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python remove_entry.py <issue_number>")
        sys.exit(1)

remove_entry(sys.argv[1])