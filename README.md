# autoupdate.sh

### a simple CI/CD implementation for your projects.
Shell script for auto update project. Add autoupdate.sh script in your cronjob!

Example:
```bash
15 05,12 * * 1-5 cd /home/user/autoupdate && ./autoupdate.sh >> /dev/null 2>&1
```
Note: run with superuser / sudo privileges
