FROM alpine:latest
RUN apk add --no-cache xpra xauth xvfb
RUN adduser -D -u 1000 appuser
USER appuser
WORKDIR /home/appuser
# Keep container alive by running xpra
ENTRYPOINT ["/usr/bin/xpra", "start", "--start-child=/bin/sleep infinity", "--bind-tcp=0.0.0.0:14500", "--exit-with-children", "--daemon=no", "--opengl=no", "--mdns=no", "--notifications=no"]
