FROM node:22

# Core system tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    ripgrep \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    vim \
    less \
    unzip \
    zip \
    openssh-client \
    fzf \
    bat \
    fd-find \
    tree \
    htop \
    procps \
    psmisc \
    lsof \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    sudo \
    locales \
    xclip \
    wl-clipboard \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
