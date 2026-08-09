FROM python:3.13-alpine

RUN addgroup -S nastart && adduser -S -G nastart -h /app nastart
WORKDIR /app
COPY nastart_agent.py /app/nastart_agent.py
RUN chmod 0555 /app/nastart_agent.py && mkdir -p /data && chown nastart:nastart /data

USER nastart
EXPOSE 8787
VOLUME ["/data"]
ENTRYPOINT ["python3", "/app/nastart_agent.py"]
