FROM --platform=linux/amd64 alpine:3.20
RUN apk add --no-cache curl
WORKDIR /pb
COPY data/pocketbase/pocketbase /pb/pocketbase
COPY data/pocketbase/pb_migrations /pb/pb_migrations
COPY data/pocketbase/pb_hooks /pb/pb_hooks
COPY entrypoint.sh /pb/entrypoint.sh
RUN test "$(uname -m)" = x86_64 \
 && test "$(sha256sum /pb/pocketbase | awk '{print $1}')" = "bfdc715d14d922f3dfcb8333cc439e7eb1d44ed602456662299bf14f4d6387b8" \
 && /pb/pocketbase --version | grep -F '0.40.1' \
 && chmod 0555 /pb/pocketbase /pb/entrypoint.sh
VOLUME ["/pb/pb_data"]
EXPOSE 8090
CMD ["/pb/entrypoint.sh"]
