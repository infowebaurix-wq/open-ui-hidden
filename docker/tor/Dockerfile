FROM alpine@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

# Install Tor from the base image repository. Exact pkg revisions can disappear
# from Alpine indexes and break CI builds unexpectedly.
RUN apk add --no-cache tor

# Create a non-root user for Tor
RUN addgroup -S toruser && adduser -S -G toruser -h /var/lib/tor toruser

# Create directories for Tor data and configuration with correct permissions
RUN mkdir -p /var/lib/tor && \
    mkdir -p /var/lib/tor/hs && \
    chown -R toruser:toruser /var/lib/tor && \
    chmod -R 700 /var/lib/tor

# Copy custom torrc configuration and entrypoint script
COPY torrc /etc/tor/torrc
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    # Ensure entrypoint.sh uses /bin/sh
    sed -i '1s|#!/bin/bash|#!/bin/sh|' /entrypoint.sh

USER toruser

VOLUME /var/lib/tor

EXPOSE 9050

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tor", "-f", "/etc/tor/torrc"] 
