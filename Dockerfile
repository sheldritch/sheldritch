ARG DEPENDENCY_PROXY=""

# Use debian rather than Ubuntu, as it's smaller and **much** faster to install everything!
FROM ${DEPENDENCY_PROXY}debian:bullseye-slim

ARG HOME=/root
ARG REPOS=$HOME/repos
ARG TOOLS=$HOME/tools
ENV REPOS=$REPOS
ENV TOOLS=$TOOLS
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR $HOME

# Install anything we can get from apt
RUN apt-get update && apt-get install -y \
	atool \
	curl \
	jq \
	keyutils \
	libxml2-utils \
	magic-wormhole \
	net-tools \
	openjdk-11-jre-headless \
	p7zip \
	postgresql \
	postgresql-client-common \
	python \
	python3 \
	redis-tools \
	rename \
	shellcheck \
	vim \
	wget \
	zip

# Install NodeJS v16, npm, and Yarn
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash \
	&& apt-get install -y nodejs \
	&& npm install -g yarn \
	&& yarn global add @bitwarden/cli@2022.6.2

# Install Helm, Kubectl, and Rakubrew
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
	&& curl -LO https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl \
	&& install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
	&& rm kubectl \
	&& curl https://rakubrew.org/install-on-perl.sh | sh \
	&& echo 'eval "$($HOME/.rakubrew/bin/rakubrew init Bash)"' >> ~/.bashrc \
	&& echo 'eval "$($HOME/.rakubrew/bin/rakubrew init Bash)"' >> ~/.profile \
	&& bash -c "$HOME/.rakubrew/bin/rakubrew init"

# Copy the tools and configure them in the bash profile
COPY . tools/
RUN mkdir -p $REPOS $TOOLS \
	&& echo 'source "$TOOLS/tools.sh"' >> $HOME/.bashrc \
	&& echo 'source "$TOOLS/tools.sh"' >> $HOME/.profile \
	&& bash -c 'source "$TOOLS/tools.sh" --sync && wait'

# ENTRYPOINT ["/bin/bash", "-c"]
