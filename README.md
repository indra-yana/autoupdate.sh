# autoupdate.sh
Shell script for auto update project, add autoupdate.sh script in your cronjob! 
let's this script do update automatically for your projects. 

Example:
```bash
15 05,12 * * 1-5 cd /home/user/autoupdate && ./autoupdate.sh >> /dev/null 2>&1
```
