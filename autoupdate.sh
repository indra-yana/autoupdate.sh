#!/bin/bash

# Project directory
LOG_DIR="/home/path-to-logs-directory/logs"
DIR="/home/path-to-project-directory/app"

# Repository branch
# BRANCH="$(git rev-parse --abbrev-ref HEAD)"  # use auto detect branch
BRANCH="staging"

# Github token
TOKEN="provide_github_token"
TIMEOUT="30s"

# Folder owner permission, may different in your server
OWNER="www-data:www-data"

# Automatically log the output of this script to a file!
begin_logging() {
   sudo mkdir -p $LOG_DIR
   exec > >(tee -a "$LOG_DIR/autoupdate_logs-`date +"%d_%m_%Y"`.log") 2>&1
}

# Project script update! you can change this script depends on your framework
begin_project_script_update() {
    echo -e "Runnning project script!\n"
    echo -e "Running composer\n"
    sleep 2s
    sudo composer install -n --no-plugins --no-scripts

    # Artisan command
    echo -e "Running artisan command \n"
    sleep 2s
    sudo php artisan migrate -n --force
    sudo php artisan schedule:clear-cache
    sudo php artisan cache:clear
    sudo php artisan view:clear
    sudo php artisan config:clear
    sudo php artisan clear-compiled
    # Add any other command here...

    # Suppervisor command
    echo -e "Running supervisor command \n"
    sleep 2s
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl restart all

    # Building Assets
    echo -e "Build production assets \n"
    sleep 2s
    sudo npm install
    sudo npm run build

    # Filessytem
    echo -e "Changing permission \n"
    sleep 2s
    sudo chown -R $OWNER $DIR
}

# Github script update!
begin_github_script_update() {
    if [ "$TOKEN" = "" ]; then
        echo "The github token is empty or null. Please provide it to continue!"
        sleep 2s
        exit
    fi

    echo -e "Runnning github script!\n"
    echo -e "Checking if repository is clean\n"
    sudo git checkout $BRANCH

    if [[ `sudo git status --porcelain` ]]; then
        echo -e "Found changes in this repository please stash and check it manualy before continuing \n"
        sudo git status
        exit
    else
        echo -e "No changes detected \n"
    fi

    ORIGIN="$(git remote -v | awk 'NR==2{print$2}' | sed s/github/$TOKEN@github/)"
    
    echo -e "Checking connection to see if the git server is up and running (will time out after $TIMEOUT) \n"
    if timeout "$TIMEOUT" sudo git ls-remote $ORIGIN > /dev/null 2>&1; then       
        echo "Git server is available"
    else
        echo "Git server is not available (check your VPN, or internet connection); exiting..."
        exit
    fi

    echo -e "Checking if any changes in remote repository \n"
    if [ "`sudo git log --pretty=%H ...refs/heads/$BRANCH^ | head -n 1`" = "`sudo git ls-remote $ORIGIN -h refs/heads/$BRANCH |cut -f1`" ] ; then
        echo -e "No changes in remote repository!\n"
        exit
    fi

    echo -e "Pulling repository \n"
    sudo git pull $ORIGIN $BRANCH
}

main() {
    echo ""
    echo "========================================================================================="
    echo "Updating project... Please CTRL + C to abort"
    echo "on $(date)."
    echo "========================================================================================="
    echo ""
    
    echo -e "Entering project directory... \n"
    sleep 3s
    cd $DIR

    if [ "$1" = "project-only" ]; then
        begin_project_script_update
    else
        begin_github_script_update
        begin_project_script_update
    fi

    echo -e "Done!\n"
    sleep 1s
    exit
}

# --------------------------------------------------------------------------------------------------
# main program entry point
# --------------------------------------------------------------------------------------------------
begin_logging
main "$@"
