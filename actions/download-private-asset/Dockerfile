FROM alpine:latest

RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  jq

COPY download-private-asset.sh /usr/bin/download-private-asset.sh
RUN chmod +x /usr/bin/download-private-asset.sh

ENTRYPOINT ["/usr/bin/download-private-asset.sh"]
