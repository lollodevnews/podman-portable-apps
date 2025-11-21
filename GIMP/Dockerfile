FROM alpine:latest

# 1. Install GIMP, Graphics Drivers, Fonts, and Xpra
RUN apk add --no-cache \
    gimp \
    ttf-dejavu font-noto adwaita-icon-theme \
    dbus-x11 mesa-dri-gallium mesa-gl \
    libx11 libxext libxrender xvfb \
    xpra xauth

# 2. Create User 'artist' (UID 1000)
RUN adduser -D -u 1000 artist
# GIMP stores configs in .config/GIMP
RUN mkdir -p /home/artist/.config/GIMP && \
    chown -R artist:artist /home/artist

USER artist
WORKDIR /home/artist

# 3. ENTRYPOINT
# Launch GIMP directly
ENTRYPOINT ["/usr/bin/xpra", "start", \
    "--start-child=/usr/bin/gimp", \
    "--bind-tcp=0.0.0.0:14500", \
    "--exit-with-children", \
    "--daemon=no", \
    "--opengl=no", \
    "--mdns=no", \
    "--notifications=no"]
