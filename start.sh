#!/bin/bash

set -e

: "${HOST_BASE:?"HOST_BASE env variable is required"}"
: "${S3_PATH:?"S3_PATH env variable is required"}"

FOLDER_NAME=${FOLDER_NAME:-backup}
HOST_BUCKET=${HOST_BUCKET:-"$HOST_BASE"}
export DATA_PATH=${DATA_PATH:-/data/}
CRON_SCHEDULE=${CRON_SCHEDULE:-0 1 * * *}


echo "host_base=$HOST_BASE" >> /root/.s3cfg
echo "host_bucket=$HOST_BUCKET" >> /root/.s3cfg

if [[ -n "$ACCESS_KEY"  &&  -n "$SECRET_KEY" ]]; then
    echo "access_key=$ACCESS_KEY" >> /root/.s3cfg
    echo "secret_key=$SECRET_KEY" >> /root/.s3cfg
else
    echo "No ACCESS_KEY and SECRET_KEY env variable found, assume use of IAM"
fi

if [[ "$1" == 'no-cron' ]]; then
    exec /sync.sh
elif [[ "$1" == 'get' ]]; then
    exec /get.sh
elif [[ "$1" == 'delete' ]]; then
    exec /usr/local/bin/s3cmd del -r "$S3_PATH"
else
    LOGFIFO='/var/log/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
        mkfifo "$LOGFIFO"
    fi
    CRON_ENV="PARAMS='$PARAMS'"
    CRON_ENV="$CRON_ENV\nDATA_PATH='$DATA_PATH'"
    CRON_ENV="$CRON_ENV\nMAX_AGE='$MAX_AGE'"
    CRON_ENV="$CRON_ENV\nS3_PATH='$S3_PATH'"
    CRON_ENV="$CRON_ENV\nFOLDER_NAME='$FOLDER_NAME'"
    echo -e "$CRON_ENV\n$CRON_SCHEDULE /put.sh > $LOGFIFO 2>&1" | crontab -
    crontab -l
    cron
    tail -f "$LOGFIFO"
fi
