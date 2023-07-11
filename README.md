# aks-auto-shutdown
Config for Auto-Shutdown/Start of the AKS clusters

In the near future, all environments excluding Production will be automatically shutdown. This action is to reduce the unnecessary infrastructure costs while the environments are not in use.

## Default cluster shutdown hours

20:00 to 06:30 everyday of the week.

## Skip shutdown functionality

In the event that an environment or environments are needed outside of the default hours, you can raise an "issue" to automatically exclude it from the shutdown schedule.
- [Complete this issue form](https://github.com/hmcts/aks-auto-shutdown/issues/new?assignees=&labels=&projects=&template=shutdown_form.yaml).
- Multiple environments within the same "Business area" can be selected at the same time.
- "Cross-Cutting" = Shared Services
- Enter the "start date" for when automatic shutdown skips should begin.
- If available, enter an end date for when your desired enviornment nolonger needs to be skipped from the automatic shutdown schedule.
- If no end date is provided, it will default to the same day as the start date.
- Select "Submit new issue"
- Wait for form processing to complete (~30 seconds) - you will see feedback comments if there are errors or when processing is complete.
    - In the event you need to edit your issue due to an error (unexpected date format error).
    - You can select the three dots (...) followed by "Edit"
    - Make your change
    - Select "Update comment"
    - Processing checks will automatically restart.
- Issue will automatically close
- Review [shutdown exclusions json](https://github.com/hmcts/aks-auto-shutdown/blob/master/issues_list.json)