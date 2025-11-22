FROM alpine:latest

# 1. Install Dependencies (Firefox, Audio, Xpra, GStreamer, Webcam)
RUN apk add --no-cache \
    firefox \
    ttf-dejavu \
    font-noto \
    adwaita-icon-theme \
    dbus-x11 \
    mesa-dri-gallium \
    mesa-gl \
    libx11 \
    libxext \
    libxrender \
    xvfb \
    pulseaudio \
    pulseaudio-utils \
    alsa-plugins-pulse \
    alsa-utils \
    xpra \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-bad \
    gst-plugins-ugly \
    v4l-utils

# 2. Configure ALSA -> Pulse
RUN echo -e 'pcm.!default type pulse\nctl.!default type pulse' > /etc/asound.conf

# 3. Create User (Standard 1000)
RUN adduser -D -u 1000 browser
RUN mkdir -p /home/browser/.config/pulse && \
    chown -R browser:browser /home/browser/.config

USER browser
WORKDIR /home/browser

# 4. ENTRYPOINT
ENTRYPOINT ["/usr/bin/xpra", "start", \
    "--start-child=/usr/bin/firefox", \
    "--bind-tcp=0.0.0.0:14500", \
    "--exit-with-children", \
    "--daemon=no", \
    "--opengl=no", \
    "--mdns=no", \
    "--notifications=no"] 
