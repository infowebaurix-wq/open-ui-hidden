FROM ghcr.io/open-webui/open-webui:0.8.8-ollama@sha256:781938633d6d445daa489fcdc0c1988c4c875e6358175f484fdd8a89aa152503

USER root
RUN apt-get update && apt-get install -y proxychains-ng socat && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["uvicorn","open_webui.main:app","--host","0.0.0.0","--port","8080","--forwarded-allow-ips='*'"] 
