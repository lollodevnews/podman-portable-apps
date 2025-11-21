FROM alpine:latest

# 1. Install LibreOffice, Xpra, Fonts, and Dependencies
RUN apk add --no-cache \
    libreoffice \
    ttf-dejavu font-noto terminus-font font-noto-emoji \
    adwaita-icon-theme \
    dbus-x11 mesa-dri-gallium mesa-gl \
    libx11 libxext libxrender xvfb \
    xpra xauth \
    cups-libs

# 2. Create User
# We use 'writer' as the user, but map it to UID 1000
RUN adduser -D -u 1000 writer
RUN mkdir -p /home/writer/.config/libreoffice && \
    chown -R writer:writer /home/writer/.config

USER writer
WORKDIR /home/writer

# 3. ENTRYPOINT
# --norestore: Prevents the "Document Recovery" dialog if the container is killed abruptly
ENTRYPOINT ["/usr/bin/xpra", "start", \
    "--start-child=/usr/bin/libreoffice --norestore", \
    "--bind-tcp=0.0.0.0:14500", \
    "--exit-with-children", \
    "--daemon=no", \
    "--opengl=no", \
    "--mdns=no", \
    "--notifications=no"]
