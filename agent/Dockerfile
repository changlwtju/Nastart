FROM python:3.13-alpine

RUN apk add --no-cache openssl
RUN addgroup -S nastart && adduser -S -G nastart -h /app nastart
WORKDIR /app
COPY --chmod=0555 nastart_agent.py docker_socket_proxy.py /app/
RUN mkdir -p /data && chown nastart:nastart /data

USER nastart
EXPOSE 8787
VOLUME ["/data"]
ENTRYPOINT ["python3", "/app/nastart_agent.py"]
