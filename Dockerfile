FROM alpine:3.24

ARG XRAY_VERSION=v26.11.9

RUN apk add --no-cache ca-certificates curl unzip bash gettext \
    && ARCH=$(case "$(uname -m)" in x86_64) echo "64";; aarch64) echo "arm64-v8a";; *) echo "64";; esac) \
    && curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${ARCH}.zip" -o /tmp/xray.zip \
    && unzip /tmp/xray.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -f /tmp/xray.zip

RUN mkdir -p /etc/xray

COPY config.json.template /etc/xray/config.json.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
