FROM ubuntu:20.04

ARG HOME=/root
ARG REPOS=$HOME/repos
ARG TOOLS=$HOME/tools

WORKDIR $HOME

RUN mkdir -p $REPOS $TOOLS

RUN echo 'source "$TOOLS/tools.sh"' >> $HOME/.bashrc

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
	atool \
	curl \
	jq \
	keyutils \
	libxml2-utils \
	magic-wormhole \
	net-tools \
	nodejs \
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
	
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -LO https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl \
	&& install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
	&& rm kubectl

RUN curl https://rakubrew.org/install-on-perl.sh | sh \
	&& echo 'eval "$($HOME/.rakubrew/bin/rakubrew init Bash)"' >> ~/.bashrc \
	&& echo 'eval "$($HOME/.rakubrew/bin/rakubrew init Bash)"' >> ~/.profile \
	&& bash -c "$HOME/.rakubrew/bin/rakubrew init"

RUN apt-get clean

COPY . tools/
RUN bash -c 'source "$TOOLS/tools.sh" --sync && wait'
RUN echo 'source "$TOOLS/tools.sh"' >> $HOME/.profile

ENV REPOS=$REPOS
ENV TOOLS=$TOOLS

# ENTRYPOINT ["/bin/bash", "-c"]
