ARG DEPENDENCY_PROXY=""

FROM ${DEPENDENCY_PROXY}debian:stable-slim AS install_scripts

COPY . /tmp/tools
WORKDIR /tmp/tools
RUN mkdir /root/install \
	&& for file in $(find */ -name '*install.sh'); do cp -r --parents "$(dirname $file)" /root/install; done \
	&& cp -r --parents -t /root/install \
		META6.json \
		_install.sh \
		install \
		util/system/system.sh

RUN mkdir /root/tools \
	&& find /root -name '*install.sh' -exec grep use_tool {} + \
		| awk '{print $2}' | uniq \
		| xargs cp -t /root/tools --parents util/shell/base.sh 

# Use debian rather than Ubuntu, as it's smaller and **much** faster to install everything!
FROM ${DEPENDENCY_PROXY}debian:stable-slim as dependencies

ARG HOME=/root
ARG REPOS=$HOME/repos
ARG TOOLS=$HOME/tools
ENV REPOS=$REPOS
ENV TOOLS=$TOOLS
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR $HOME

# Install anything we can get from apt
# Keep alphabetical please!
RUN apt-get update -q=3 && apt-get install -q=3 --no-install-recommends \
	atool \
	curl \
	git \
	jq \
	ldap-utils \
	libxml2-utils \
	net-tools \
	nodejs \
	npm \
	p7zip \
	postgresql \
	postgresql-client-common \
	redis-tools \
	rename \
	shellcheck \
	sudo \
	vim \
	wget \
	zip

# Install yarn
# then install the bitwarden CLI
RUN npm install -g yarn \
	&& yarn global add @bitwarden/cli@2022.6.2

# Install Helm and Kubectl
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
	&& curl -LO https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl \
	&& install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
	&& rm kubectl

FROM dependencies as final

COPY --from=install_scripts /root/install $TOOLS/
COPY --from=install_scripts /root/tools $TOOLS/

RUN $TOOLS/_install.sh

# Copy the tools and configure them in the bash profile
COPY . $TOOLS
RUN mkdir -p $REPOS $TOOLS \
	&& bash -c 'source "$TOOLS/tools.sh" --sync && wait && source "$TOOLS/_test.sh"'

# --login ensures /etc/profile is read
RUN echo >>/usr/local/bin/bash '/bin/bash --login "$@"' \
	&& chmod 755 /usr/local/bin/bash

# Entrypoint:
# If only one arg is given to docker, run as if it were a script (conventional Docker shell operation)
# If arguments are given, treat like a command and ensure all args are quoted
ENTRYPOINT ["/bin/bash", "--login", "-c", "[ $# -eq 0 ] && eval $0 || \"$0\" \"$@\" "]
CMD [ "bash" ]

RUN apt-get -qq update && apt-get -qq upgrade
