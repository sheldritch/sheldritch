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
	openssl \
	rename \
	sudo \
	wbritish \
	wget \
	yq \
	zip

ARG DEPENDENCY_PROXY=""
ARG SHELL=bash
ENV SHELL=$SHELL

RUN apt-get install -q=3 --no-install-recommends $SHELL

# Copy the tools and configure them in the profile
COPY . $LIBS/sheldritch

RUN $SHELL $SHELDRITCH/_install.sh \
	&& $SHELL -c 'source "$SHELDRITCH/_test.sh"'

# --login ensures /etc/profile is read
RUN echo >>/entrypoint.sh "#!/bin/sh" && \
	echo >>/entrypoint.sh ' \
if [ "$#" -eq 1 ]; then \
	'$SHELL' --login -c "source '$SHELDRITCH'/sheldritch.full.sh; $1" sheldritch \
; elif [ "$#" -eq 0 ]; then \
	'$SHELL' --login \
; else \
	'$SHELL' --login -c '\''source '$SHELDRITCH'/sheldritch.full.sh; "$0" "$@"'\'' "$@" \
; fi' \
	&& chmod 755 /entrypoint.sh

RUN cat /entrypoint.sh

# Entrypoint:
# If only one arg is given to docker, run as if it were a script (conventional Docker shell operation)
# If arguments are given, treat like a command and ensure all args are quoted
ENTRYPOINT ["/entrypoint.sh"]
CMD []

RUN apt-get -qq update && apt-get -qq upgrade
