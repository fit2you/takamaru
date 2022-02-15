ARG RUBY_VERSION
FROM ruby:${RUBY_VERSION}-slim-bullseye

# SSL hotfix
RUN apt-get update -qq \
  && apt-get install libgnutls30 -y \
  && apt-get install ca-certificates -y \
  && update-ca-certificates

# Common dependencies
RUN apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  bash-completion \
  build-essential \
  curl \
  git \
  git-flow \
  gnupg2 \
  htop \
  httpie \
  iputils-ping \
  less \
  lsb-release \
  nano \
  ssh \
  sudo \
  vim \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

# Upgrade rubygems
RUN gem update --system

# Add user sasori
RUN useradd -m -s /bin/bash sasori \
  && usermod -aG sudo sasori \
  && echo "sasori ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Bash config
RUN echo "export HISTFILE=/history/.bash_history" >> /home/sasori/.bashrc \
  && echo 'export PROMPT_COMMAND="history -a"' >> /home/sasori/.bashrc \
  && git clone https://github.com/magicmonty/bash-git-prompt.git /home/sasori/.bash-git-prompt --depth=1 \
  && echo 'if [ -f "$HOME/.bash-git-prompt/gitprompt.sh" ]; then GIT_PROMPT_ONLY_IN_REPO=1; source $HOME/.bash-git-prompt/gitprompt.sh; fi' >> /home/sasori/.bashrc \
  && echo 'source /usr/share/bash-completion/completions/git' >> /home/sasori/.bashrc

# IRB config
RUN echo "require 'irb/ext/save-history'" >> /home/sasori/.irbrc \
  && echo "IRB.conf[:SAVE_HISTORY] = 1000" >> /home/sasori/.irbrc \
  && echo "IRB.conf[:HISTORY_FILE] = \"/history/.irb-history\"" >> /home/sasori/.irbrc

# Volumes & permissions
RUN mkdir -p /usr/local/bundle \
  && mkdir -p /history \
  && chown -R sasori:sasori /usr/local/bundle \
  && chown -R sasori:sasori /history \
  && chown -R sasori:sasori /home/sasori

# Docker compose command script
COPY .sasori/command.sh /home/sasori/command.sh
RUN chmod +x /home/sasori/command.sh

USER sasori