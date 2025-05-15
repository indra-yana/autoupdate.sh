#!/bin/bash

set -euo pipefail

# -------------------------------
## 👤 Creator
#
# Name: Indra Muliana
# Email: indra26.work@gmail.com
# GitHub: [indra-yana](https://github.com/indra-yana)
# License: MIT License (bebas digunakan dengan atribusi)
# -------------------------------

# -------------------------------
# 📄 Load ENV File 
# -------------------------------
load_env() {
  local env_file="$1"
  if [[ ! -f "$env_file" ]]; then
    echo "❌ ENV file not found: $env_file"
    exit 1;
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines & comments
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Parse key=value
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"

      # Remove surrounding single quotes
      if [[ "$val" =~ ^\'(.*)\'$ ]]; then
        val="${BASH_REMATCH[1]}"
      # Remove surrounding double quotes and unescape \"
      elif [[ "$val" =~ ^\"(.*)\"$ ]]; then
        val="${BASH_REMATCH[1]}"
        val="${val//\\\"/\"}"
      fi

      export "$key=$val"
    else
      echo "⚠️ Ignoring invalid line in .env: $line"
    fi
  done < "$env_file"
}

# echo "Loading env from: $(dirname "$0")/.env"
load_env "$(dirname "$0")/.env"

# -------------------------------
# 📁 ENV Variable Checking
# Enable this if you want to checking the required ENV Variable
# -------------------------------
# APP_NAME="${APP_NAME:?APP_NAME is not set}"
# APP_ENV="${APP_ENV:?APP_ENV is not set}"

# -------------------------------
# ⚙️ Main Configuration
# -------------------------------
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
LOG_DIR="${SCRIPT_DIR}/updatelogs.d"
LOG_FILENAME="update_$(echo "${APP_NAME:-app}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')_$(date +'%d_%m_%Y').log"
APP_DIR="${APP_DIR:?APP_DIR is not set}"
BRANCH="${GITHUB_BRANCH:?GITHUB_BRANCH is not set}"
USER="${USER:?USER is not set}"
TIMEOUT="30s"

# -------------------------------
# 📜 Logging
# -------------------------------
begin_logs() {
    mkdir -p "$LOG_DIR"
    exec > >(tee -a "$LOG_DIR/$LOG_FILENAME") 2>&1
}

# -------------------------------
# 🧹 Log Cleanup (Keep last 15 days)
# -------------------------------
cleanup_logs() {
    # Hapus file log yang lebih lama dari 15 hari di dalam LOG_DIR
    find "$LOG_DIR" -type f -name '*.log' -mtime +15 -exec rm -f {} \;
    echo "🧹 Cleanup logs: Old logs older than 15 days have been cleaned up."
}

# -------------------------------
# 🔄 Update from GitHub
# -------------------------------
github_update() {
    echo -e "\n🚀 Running GitHub script update..."

    if [ -z "$GITHUB_TOKEN" ]; then
        echo "❌ GitHub token is empty. Please provide it to continue!"
        exit 1
    fi

    ORIGIN="$(git remote get-url origin | sed "s#github.com#${GITHUB_TOKEN}@github.com#")"

    # Check if git server reachable
    echo "🔗 Checking if git server reachable (will timeout after: $TIMEOUT)..."
    if ! timeout "$TIMEOUT" git ls-remote "$ORIGIN" &>/dev/null; then
        echo "❌ Git server not reachable. Check VPN / Internet connection."
        send_whatsapp
        exit 1
    else
        echo "✅ Git server is reachable."
    fi

    # Check if remote branch exists
    echo "🔀 Checking out existing remote branch: $BRANCH"
    if git ls-remote --heads "$ORIGIN" "$BRANCH" | grep -q "$BRANCH"; then
        echo "✅ Remote branch '$BRANCH' exists. Proceeding to fetch..."
    else
        echo "❌ Remote branch '$BRANCH' does not exist!"
        send_whatsapp
        exit 1
    fi

    # Check if remote branch is already fetched
    echo "🔀 Fetching remote branch: ${BRANCH}..."
    git fetch "$ORIGIN" "$BRANCH" || {
        echo "❌ Failed to fetch branch '$BRANCH'"
        send_whatsapp
        exit 1
    }

    # Checkout the branch
    echo "📦 Checking out branch: ${BRANCH}..."
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH" || {
        echo "❌ Failed to checkout or create tracking branch for '$BRANCH'"
        send_whatsapp
        exit 1
    }

    # Check if any changes in local repository
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "⚠️ Found uncommitted changes. Please stash/commit first."
        git status
        send_whatsapp
        exit 1
    fi

    LOCAL_COMMIT="$(git rev-parse HEAD)"
    REMOTE_COMMIT="$(git ls-remote "$ORIGIN" "refs/heads/$BRANCH" | cut -f1)"

    if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
        echo "✅ No changes in remote repository."
        send_whatsapp
        exit 0
    fi

    echo "📥 Remote has new changes. Pulling updates..."
    git pull "$ORIGIN" "$BRANCH" || {
        echo "❌ Pull failed"
        send_whatsapp
        exit 1
    }
}

# -------------------------------
# 🔧 Update Project (Laravel)
# -------------------------------
project_update() {
    echo -e "\n"
    echo "📦 Installing dependencies..."

    composer install -n --no-plugins --no-scripts || { 
        send_whatsapp
        exit 1 
    }

    # Laravel artisan commands
    if command -v php >/dev/null 2>&1; then
        echo "🚀 Starting Laravel artisan commands..."

        # Put app in maintenance mode
        echo "🚀 Put app in maintenance mode..."
        php artisan down

        php artisan migrate -n --force
        # php artisan storage:link
        php artisan optimize:clear
        php artisan schedule:clear-cache

        # Custom command
        if [ "$APP_ENV" = "production" ] || [ "$APP_ENV" = "staging" ]; then
            php artisan hrms:generate-acl -n -u || true
            php artisan activitylog:clean --days=360 -n --force || true
        else
            php artisan hrms:generate-acl -n -u -l || true
            php artisan activitylog:clean --days=120 -n --force || true
        fi

        # Run optimize only in production
        if [ "$APP_ENV" = "production" ] || [ "$APP_ENV" = "staging" ]; then
            echo "📦 Running optimization for production..."
            php artisan optimize
        else
            echo "ℹ️ Skipping optimize - APP_ENV is not production (current: $APP_ENV)"
        fi

        echo "✅ Laravel artisan commands completed."
    else
        echo "⚠️ Laravel artisan commands: PHP binary not found, please install it."
    fi

    # Start Supervisor
    echo -e "\n"
    echo "🚀 Updating supervisor configuration..."
    # supervisord -c /etc/supervisor/supervisord.conf
    if command -v supervisorctl >/dev/null 2>&1; then
        supervisorctl reread
        supervisorctl update
        supervisorctl restart all
    else
        echo "⚠️ supervisorctl commands not found, please install it."
    fi

    echo -e "\n"
    # NPM install
    echo "🚀 Running npm install using: npm $(npm -v), node $(node -v)..."
    npm install

    # Build FE asset 
    echo "📦 Building frontend assets..."
    npm run build

    echo -e "\n"
    echo "🔒 Fixing permissions for..."
    chown -R "$USER:$USER" "$APP_DIR" || echo "chown: Some files could not be changed"

    if command -v php >/dev/null 2>&1; then
        echo "🚀 Waking up ${APP_NAME}..."
        php artisan up
    else
        echo "⚠️ Waking up ${APP_NAME}: PHP binary not found, please install it."
    fi
}

# -------------------------------
# ✉️ Send Telegram Notification
# -------------------------------
send_telegram() {
    echo -e "\n"
    echo "✉️ Sending Telegram notification..."
    
    if [[ -z "${TELEGRAM_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo "⚠️ Skipping Telegram notification: missing one or more required environment variables (TELEGRAM_TOKEN, TELEGRAM_CHAT_ID)"
        return
    fi

    local message="${1:-✅ [${APP_NAME}] has been updated on $(date +'%A %d/%m/%Y %H:%M:%S'). Please check log to see detail!}"
    # TODO: Configure telegram
    # curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
    #     -d chat_id="$TELEGRAM_CHAT_ID" \
    #     -d text="$message" \
    #     -d parse_mode="Markdown"
}

# -------------------------------
# 📤 Send WhatsApp Notifcation
# -------------------------------
send_whatsapp() {
    echo -e "\n"
    echo "✉️ Sending whatsApp notification..."

    if [[ -z "${WPP_SESSION:-}" || -z "${WPP_BASE_URL:-}" || -z "${WPP_TOKEN:-}" || -z "${WPP_PHONE:-}" ]]; then
        echo "⚠️ Skipping WhatsApp notification: missing one or more required environment variables (WPP_SESSION, WPP_BASE_URL, WPP_TOKEN, WPP_PHONE)"
        return
    fi

    local SESSION="$WPP_SESSION"
    local PHONE="$WPP_PHONE"
    local IS_GROUP="$WPP_IS_GROUP"
    local MESSAGE="✅ [${APP_NAME}] has been updated on $(date +'%A %d/%m/%Y %H:%M:%S'). Please check log to see detail!"
    local FILE_PATH="${LOG_DIR}/${LOG_FILENAME}"
    local WPP_URL="${WPP_BASE_URL}/api/${SESSION}/send-file-base64"

    [[ -f "$FILE_PATH" ]] || { echo "⚠️ Log file not found: $FILE_PATH"; return; }

    echo "📄 Converting log file to base64..."
    local BASE64_CONTENT=$(base64 -w 0 "$FILE_PATH")
    local BASE64_PAYLOAD="data:text/plain;base64,${BASE64_CONTENT}"

    local TMP_JSON=$(mktemp)
    cat > "$TMP_JSON" <<EOF
{
  "phone": "$PHONE",
  "isGroup": $IS_GROUP,
  "filename": "$LOG_FILENAME",
  "message": "$MESSAGE",
  "base64": "$BASE64_PAYLOAD"
}
EOF

    echo "📤 Push notification with file: ${LOG_FILENAME} attached..."
    local response=$(curl --silent --show-error --write-out "HTTPSTATUS:%{http_code}" \
        --location "$WPP_URL" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer $WPP_TOKEN" \
        --data-binary @"$TMP_JSON")

    local http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    local http_body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//')

    if [[ "$http_status" -ge 200 && "$http_status" -lt 300 ]]; then
        echo "✅ Log file sent successfully. Status: $http_status"
        echo "🔍 Response: $http_body"
    else
        echo "❌ Failed to send log file. Status: $http_status"
        echo "🔍 Response: $http_body"
    fi

    # Delete temp file
    rm -f "$TMP_JSON"
}

# -------------------------------
# 🚀 Entry Point
# -------------------------------
main() {
    echo "======================================================="
    echo "⏳ Updating ${APP_NAME} project"
    echo "🗓️ On $(date +'%A %d/%m/%Y %H:%M:%S')"
    echo "======================================================="

    cd "$APP_DIR" || { echo "❌ APP_DIR not found: $APP_DIR"; exit 1; }
    start_time=$(date +%s)

    if [[ "${1:-}" == "--skip-git" ]]; then
        echo "⏭️ Skipping Git update as requested with --skip-git"
        project_update
    else
        github_update
        project_update
    fi

    cleanup_logs
    
    end_time=$(date +%s)
    elapsed=$(( end_time - start_time ))

    echo -e "\n"
    echo "✅ Done!"
    echo "🕒 Execution started at: $(date -d @$start_time '+%A %d/%m/%Y %H:%M:%S')"
    echo "🕒 Execution ended at:   $(date -d @$end_time '+%A %d/%m/%Y %H:%M:%S')"

    if (( elapsed > 60 )); then
        minutes=$(( elapsed / 60 ))
        seconds=$(( elapsed % 60 ))
        echo "⏱ Total execution time: ${minutes} minutes and ${seconds} seconds"
    else
        echo "⏱ Total execution time: ${elapsed} seconds"
    fi

    send_whatsapp
    send_telegram

    exit 0
}

begin_logs
main "$@"