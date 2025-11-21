FROM alpine:latest

# 1. Install VLC, GUI, System Deps, AND GStreamer (For Audio)
RUN apk add --no-cache \
    vlc \
    vlc-qt \
    ttf-dejavu font-noto adwaita-icon-theme \
    dbus-x11 mesa-dri-gallium mesa-gl \
    libx11 libxext libxrender xvfb \
    pulseaudio pulseaudio-utils alsa-plugins-pulse alsa-utils \
    xpra v4l-utils xauth \
    qt5-qtbase qt5-qtbase-x11 qt5-qtsvg qt5-qtdeclarative qt5-qtx11extras \
    # ---> ADD THESE GSTREAMER PLUGINS <---
    gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly

# 2. Configure Audio
RUN echo -e 'pcm.!default type pulse\nctl.!default type pulse' > /etc/asound.conf

# ... (Rest of file remains the same) ...

# 3. Create User
RUN adduser -D -u 1000 mediauser
RUN mkdir -p /home/mediauser/.config/pulse && \
    chown -R mediauser:mediauser /home/mediauser/.config

USER mediauser
WORKDIR /home/mediauser

# 4. ENTRYPOINT
ENTRYPOINT ["/usr/bin/xpra", "start", \
    "--start-child=/usr/bin/vlc --ignore-config --intf=qt", \
    "--bind-tcp=0.0.0.0:14500", \
    "--exit-with-children", \
    "--daemon=no", \
    "--opengl=no", \
    "--mdns=no", \
    "--notifications=no"]
