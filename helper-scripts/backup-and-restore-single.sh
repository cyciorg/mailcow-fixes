#!/bin/bash

MAILCOW_INSTALL_PATH="/opt/mailcow-dockerized"
LOG_FILE="/var/log/mailcow_backup_restore.log"
COMPOSE_PROJECT_NAME="mailcowdockerized"

if [[ -f "${MAILCOW_INSTALL_PATH}/mailcow.conf" ]]; then
    source "${MAILCOW_INSTALL_PATH}/mailcow.conf"
else
    echo "Mailcow configuration file not found. Exiting."
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

backup_sql() {
    local backup_path="$1/mailcow_sql_$(date +%F_%H-%M-%S).sql.gz"
    local sql_container_name="mysql-mailcow"
    local sql_container=$(docker ps --filter name=${sql_container_name} --format "{{.Names}}")

    if [[ -z "$sql_container" ]]; then
        log "Mailcow SQL container not found. Ensure Mailcow is running."
        return 1
    fi

    log "Backing up Mailcow SQL database..."
    docker exec "$sql_container" mysqldump -u"$DBUSER" -p"$DBPASS" --all-databases --single-transaction | gzip >"$backup_path"
    log "SQL database backup completed."
}

backup_vmail() {
    local email_address="$1"
    local backup_location="$2"
    local domain="${email_address##*@}"
    local user="${email_address%@*}"
    local date=$(date +%F_%H-%M-%S)
    local backup_file_name="vmail_${domain}_${user}_${date}.tar.gz"

    log "Backing up vMail data for $email_address..."
    log "Checking directory: /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data/${domain}/${user}"

    docker run --rm \
        -v mailcowdockerized_vmail-vol-1:/vmail:ro \
        -v "${backup_location}:/backup" \
        alpine \
        sh -c "ls -la /vmail && ls -la /backup && tar -czvf '/backup/${backup_file_name}' -C '/vmail/${domain}/${user}' ."

    if [ $? -eq 0 ]; then
        log "vMail data backup for $email_address completed successfully. Archive: ${backup_location}/${backup_file_name}"
    else
        log "Failed to backup vMail data for $email_address."
        return 1
    fi
}

restore_sql() {
    local backup_location="$1"
    local sql_backup_file=$(find "${backup_location}" -name "mailcow_sql_*.sql.gz" -print -quit)

    if [[ ! -f "${sql_backup_file}" ]]; then
        log "SQL backup file not found in ${backup_location}."
        return 1
    fi

    local sql_container=$(docker ps --filter name=mysql-mailcow --format "{{.Names}}" | head -n 1)

    if [[ -z "$sql_container" ]]; then
        log "Mailcow SQL container not found. Ensure Mailcow is running."
        return 1
    fi

    log "Restoring Mailcow SQL database from ${sql_backup_file}..."
    zcat "${sql_backup_file}" | docker exec -i "$sql_container" mysql -u"$DBUSER" -p"$DBPASS"
    log "SQL database restore completed."
}

restore_vmail() {
    local backup_location="$1"
    local email_address="$2"
    local domain="${email_address##*@}"
    local user="${email_address%@*}"
    local vmail_volume_path="/var/lib/docker/volumes/${COMPOSE_PROJECT_NAME}_vmail-vol-1/_data"

    local vmail_backup_file=$(find "${backup_location}" -name "vmail_${domain}_${user}_*.tar.gz" -print -quit)

    if [[ ! -f "${vmail_backup_file}" ]]; then
        log "vMail backup file for ${email_address} not found in ${backup_location}."
        return 1
    fi

    log "Restoring vMail data for ${email_address} from ${vmail_backup_file}..."

    # Extract the backup file inside the container
    docker run --rm -v "${vmail_volume_path}:/vmail" -v "${backup_location}:/backup" alpine:latest sh -c "tar -xzvf /backup/$(basename "${vmail_backup_file}") -C /vmail/${domain}/${user}"

    if [ $? -eq 0 ]; then
        log "vMail data restore for ${email_address} completed."
    else
        log "Failed to restore vMail data for ${email_address}."
        return 1
    fi
}

main() {
    local operation="$1"
    local backup_location="$2"
    local email_address="$3"

    case "$operation" in
    -b)
        backup_location="${backup_location}/mailcow_backup_$(date +%F_%H-%M-%S)"
        mkdir -p "$backup_location"
        backup_sql "$backup_location"
        backup_vmail "$email_address" "$backup_location"
        ;;
    -r)
        restore_sql "$backup_location"
        restore_vmail "$backup_location" "$email_address"
        ;;
    *)
        echo "Invalid operation: $operation"
        echo "Usage: $0 -b <email_address> <backup_location> | $0 -r <backup_location> <email_address>"
        exit 1
        ;;
    esac
}

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 -b <email_address> <backup_location> | $0 -r <backup_location> <email_address>"
    exit 1
fi

main "$@"
