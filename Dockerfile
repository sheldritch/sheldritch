# TODO: rewrite
ARG DEPENDENCY_PROXY=""

FROM ${DEPENDENCY_PROXY}debian:stable-slim as dependencies

ARG HOME=/root
ARG LIBS=/lib/shell
ARG SHELDRITCH=$LIBS/sheldritch
ENV LIBS=$LIBS
ENV SHELDRITCH=$SHELDRITCH
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR $HOME

# Install anything we can get from apt
# Keep alphabetical please!
RUN apt-get update -q=3 && apt-get install -q=3 --no-install-recommends \
	curl \
	file \
	git \
	jq \
	libxml2-utils \
	net-tools \
	rename \
	sudo \
	wget \
	yq \
	zip

# Copy the tools and configure them in the bash profile
COPY . $LIBS/sheldritch

RUN $SHELDRITCH/_install.sh \
	&& bash -c 'source "$SHELDRITCH/_test.sh"'

# --login ensures /etc/profile is read
RUN echo >>/usr/local/bin/bash '/bin/bash --login "$@"' \
	&& chmod 755 /usr/local/bin/bash

# Entrypoint:
# If only one arg is given to docker, run as if it were a script (conventional Docker shell operation)
# If arguments are given, treat like a command and ensure all args are quoted
ENTRYPOINT ["/bin/bash", "--login", "-c", "[ $# -eq 0 ] && eval $0 || \"$0\" \"$@\" "]
CMD [ "bash" ]

RUN apt-get -qq update && apt-get -qq upgrade
