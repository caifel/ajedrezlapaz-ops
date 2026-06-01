FROM oven/bun:1-debian

ARG USERNAME=mario
ARG LAZYGIT_VERSION=0.44.1
ARG NVM_VERSION=0.40.3
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SHELL=/bin/zsh \
    EDITOR=nvim \
    VISUAL=nvim \
    BUN_INSTALL=/home/${USERNAME}/.bun \
    NVM_DIR=/usr/local/nvm \
    PATH=/home/${USERNAME}/.bun/bin:$PATH

# System packages for an interactive development workstation.
# nodejs/npm are intentionally present for Mason/LazyVim LSP installs;
# project dependencies and app scripts still run with Bun.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bat \
      build-essential \
      ca-certificates \
      curl \
      fd-find \
      fzf \
      git \
      gnupg \
      htop \
      jq \
      less \
      libsqlite3-dev \
      lsof \
      man-db \
      nodejs \
      npm \
      openssh-client \
      openssl \
      pkg-config \
      redis-tools \
      ripgrep \
      rsync \
      shellcheck \
      sqlite3 \
      sudo \
      tmux \
      tree \
      unzip \
      wget \
      xz-utils \
      yq \
      zip \
      zsh \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && rm -rf /var/lib/apt/lists/*

# Docker sets TARGETARCH for the machine doing the build.
# Apple Silicon Macs use arm64; Intel/AMD Linux machines usually use amd64.
# Neovim and Lazygit publish binaries with slightly different architecture names,
# so this maps Docker's architecture value to each project's download naming.
RUN case "${TARGETARCH}" in \
      amd64) NVIM_ARCH="x86_64"; LAZYGIT_ARCH="x86_64" ;; \
      arm64) NVIM_ARCH="arm64"; LAZYGIT_ARCH="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
      | tar -xz -C /opt \
    && ln -s "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim \
    && curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin lazygit

# Global command-line helpers installed through Bun.
RUN BUN_INSTALL=/usr/local bun install -g \
      create-next-app \
      tree-sitter-cli@0.22.6 \
      tsx \
      typescript

# Install nvm globally; the workstation .zshrc loads it for interactive use.
RUN mkdir -p "${NVM_DIR}" \
    && curl -fsSL "https://github.com/nvm-sh/nvm/archive/refs/tags/v${NVM_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C "${NVM_DIR}" \
    && chown -R bun:bun "${NVM_DIR}"

# The Bun image already contains a non-root user named "bun".
# Rename it to the workstation user so files in mounted volumes are owned by mario.
RUN groupmod --new-name ${USERNAME} bun \
    && usermod --login ${USERNAME} --move-home --home /home/${USERNAME} bun \
    && chsh --shell /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /alp /home/${USERNAME}/.config /home/${USERNAME}/.bun/install/cache \
    && chown -R ${USERNAME}:${USERNAME} /alp /home/${USERNAME}

COPY docker/ws/entrypoint.sh /usr/local/bin/ws-entrypoint

RUN chmod +x /usr/local/bin/ws-entrypoint \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}
WORKDIR /alp

ARG NODE_VERSION=lts/*

RUN mkdir -p ~/.config ~/.bun/install/cache ~/.cache \
    && bash -lc '. "$NVM_DIR/nvm.sh" \
      && nvm install "$NODE_VERSION" \
      && nvm alias default "$NODE_VERSION" \
      && npm install -g @vegamo/deepcode-cli \
      && nvm cache clear'

ENTRYPOINT ["ws-entrypoint"]
CMD ["zsh"]
