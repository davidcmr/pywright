FROM python:3.13-slim
ENV DISPLAY=:99

# Install system dependencies and create user
RUN apt update && \
    apt install -y xvfb ffmpeg unzip curl pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils pulseaudio-utils dbus-x11 dbus-user-session && \
    groupadd -r pwuser && \
    useradd -r -g pwuser -m pwuser && \
    rm -rf /var/lib/apt/lists/*

# Install uv (system-wide, accessible to all users)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    install -m 755 /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || \
    (mkdir -p /usr/local/bin && cp /root/.local/bin/uv /usr/local/bin/uv && chmod +x /usr/local/bin/uv)
ENV PATH="/usr/local/bin:/root/.local/bin:$PATH"

# Install Playwright browsers as root (needed for system dependencies)
RUN uvx playwright@1.57.0 install --with-deps chrome --no-shell

WORKDIR /app

# Copy Python project files
COPY pyproject.toml uv.lock* ./
COPY src/ ./src/

# Copy and extract user_data.tar.gz (using system tar)
COPY user_data.tar.gz .
RUN mkdir -p user_data videos /tmp/.X11-unix /run/user && \
    if [ -f user_data.tar.gz ]; then \
        tar -xzf user_data.tar.gz && \
        rm -f user_data.tar.gz; \
    fi && \
    chown -R pwuser:pwuser /app /tmp/.X11-unix && \
    chmod -R 755 /app && \
    chmod 1777 /tmp/.X11-unix && \
    chmod 755 /run/user && \
    mkdir -p /run/user/$(id -u pwuser) && \
    chown pwuser:pwuser /run/user/$(id -u pwuser) && \
    chmod 700 /run/user/$(id -u pwuser)



# Install Python dependencies using uv
# Use --frozen if uv.lock exists, otherwise sync without it
RUN if [ -f uv.lock ]; then uv sync --frozen; else uv sync; fi

# Ensure uv is accessible to pwuser (add to system PATH)
RUN echo 'export PATH="/usr/local/bin:/root/.local/bin:$PATH"' >> /etc/profile && \
    echo 'export PATH="/usr/local/bin:/root/.local/bin:$PATH"' >> /home/pwuser/.bashrc

# Copy installed browsers from root's cache to non-root user's cache
RUN mkdir -p /home/pwuser/.cache/ms-playwright && \
    if [ -d /root/.cache/ms-playwright ]; then \
        cp -r /root/.cache/ms-playwright/* /home/pwuser/.cache/ms-playwright/ || true; \
    fi && \
    chown -R pwuser:pwuser /home/pwuser/.cache

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to non-root user (entrypoint will run as pwuser)
USER pwuser

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uv", "run", "pywright"]
