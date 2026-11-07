FROM postgres:17-alpine
RUN apk add --no-cache rclone
COPY backup.sh /usr/local/bin/backup.sh
ENTRYPOINT ["/usr/local/bin/backup.sh"]
