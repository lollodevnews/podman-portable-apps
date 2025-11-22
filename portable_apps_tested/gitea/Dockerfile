FROM alpine:latest

# 1. Install Gitea, Git, Terminal, and Xpra
RUN apk add --no-cache \
    gitea \
    git \
    sqlite \
    openssh \
    xterm \
    bash \
    ttf-dejavu font-noto \
    xpra xauth \
    xvfb \
    dbus-x11

# 2. Create User 'git' (UID 1000 to match appAssistant defaults)
RUN adduser -D -u 1000 git
RUN mkdir -p /home/git/.config && chown -R git:git /home/git

# 3. Configure Gitea Storage (Persist to Home)
ENV GITEA_WORK_DIR=/home/git/gitea
ENV USER=git

USER git
WORKDIR /home/git

# 4. ENTRYPOINT
# We launch xterm. Inside xterm, the user will manually start Gitea.
# We use "+sb" to ensure the scrollbar is visible.
ENTRYPOINT ["/usr/bin/xpra", "start", \
    "--start-child=/usr/bin/xterm -bg black -fg white -fa 'Monospace' -fs 12 +sb", \
    "--bind-tcp=0.0.0.0:14500", \
    "--exit-with-children", \
    "--daemon=no", \
    "--opengl=no", \
    "--mdns=no", \
    "--notifications=no"]
