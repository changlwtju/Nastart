FROM python:3.13-alpine AS agent-runtime

RUN apk add --no-cache openssl
RUN addgroup -S nastart && adduser -S -G nastart -h /app nastart
WORKDIR /app
COPY --chmod=0555 nastart_agent.py docker_socket_proxy.py qrencoder.py /app/
COPY --chmod=0444 qrencoder-LICENSE.txt /app/
RUN mkdir -p /data && chown nastart:nastart /data

USER nastart
EXPOSE 8787
ENTRYPOINT ["python3", "/app/nastart_agent.py"]

FROM agent-runtime AS discovery
USER root
RUN python3 -m pip install --no-cache-dir --only-binary=:all: zeroconf==0.154.0 ifaddr==0.2.0
USER nastart

FROM agent-runtime AS agent
VOLUME ["/data"]
