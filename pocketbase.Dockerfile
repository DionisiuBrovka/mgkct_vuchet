FROM alpine:3.20
RUN apk add --no-cache curl
WORKDIR /pb
COPY data/pocketbase/pocketbase /pb/pocketbase
COPY data/pocketbase/pb_migrations /pb/pb_migrations
COPY data/pocketbase/pb_hooks /pb/pb_hooks
COPY entrypoint.sh /pb/entrypoint.sh
RUN chmod +x /pb/pocketbase /pb/entrypoint.sh
VOLUME ["/pb/pb_data"]
EXPOSE 8090
CMD ["/pb/entrypoint.sh"]
