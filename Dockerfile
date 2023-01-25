FROM ubuntu:20.04

 

MAINTAINER Ryan Maus (rmaus@ntglobalmarkets.com)

 

# Configure Apt, replacing all Ubuntu apt sources with local mirrors.

COPY htgm_apt_mirror.ubuntu.list /etc/apt/sources.list

RUN apt-get update && apt-get install -y gnupg gpgv

 

# Install the gpg validation keys for third-party apt sources, then add and update the apt sources.

RUN mkdir /apt_gpg_keys

COPY apt_gpg_keys/*.gpg /apt_gpg_keys/

RUN find /apt_gpg_keys -type f -name '*.gpg' -exec apt-key add '{}' ';'

 

COPY htgm_apt_mirror.third_party.list /etc/apt/sources.list.d/

RUN apt-get update

 

# Set up timezone, before installing packages in case some package pulls in tzdata and triggers the blocking

# interactive configuration.

COPY configure_tz.sh /usr/local/htgm/bin/configure_tz.sh

RUN /usr/local/htgm/bin/configure_tz.sh

 

# Install Packages

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \

    apt-transport-https \

    binutils \

    ca-certificates \

    containerd.io \

    curl \

    docker-ce \

    docker-ce-cli \

    gdb \

    gnupg-agent \

    iftop \

    iotop \

    iptables \

    iputils-ping \

    kubectl \

    libasan5 \

    libpq5 \

    libubsan1 \

    linux-tools-${KERNEL_VERSION_STRING} \

    lsof \

    lxc \

    mtr-tiny \

    net-tools \

    netcat \

    netcat-openbsd \

    nginx \

    python3 \

    python3-ipython \

    psmisc \

    socat \

    strace \

    tcpdump \

    tshark \

    unzip \

    wget

 

 

# Install selected self-built packages (ensure libstdc++ and libgcc_s match our native and build-time environment)

RUN mkdir /htgm_debs

COPY htgm_debs/*.deb /htgm_debs/

RUN find /htgm_debs -type f -name '*.deb' -exec dpkg -i '{}' ';'

 

# Install a specific version of gcloud

# Note: the deb/apt-based source location does not allow installing arbitrarily old versions, use a cached archive.

RUN wget -O - http://third-party/google/google-cloud-sdk-412.0.0-linux-x86_64.tar.gz \

      | tar xz \

      && (cd google-cloud-sdk && ./install.sh --quiet --usage-reporting=false --command-completion=false --path-update=false) \

      && find google-cloud-sdk/bin/ -type f -exec bash -c 'ln --verbose -s $(readlink -f {}) /usr/bin/' ';'

 

# GKE v1.26 or newer require the GKE auth plugin (GCP auth plugin is deprecated)

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \

    google-cloud-sdk-gke-gcloud-auth-plugin

ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True

 

# Prepare docker

COPY docker_run_when_ready.sh /usr/local/htgm/bin/docker_run_when_ready.sh

VOLUME /var/lib/docker

EXPOSE 2375 2376

 

# Install and configure gcloud components

RUN mkdir -p /prod/gmlocal/system/${OPS_SYSTEM}/config/current/sysconfig/etc.${OPS_SYSTEM}/google_cloud

COPY htgm-farm-${FARM_SYSTEM}-service-account.json /prod/gmlocal/system/${OPS_SYSTEM}/config/current/sysconfig/etc.${OPS_SYSTEM}/google_cloud/

COPY htgm-farm-${FARM_SYSTEM}-gsutil.boto /prod/gmlocal/system/${OPS_SYSTEM}/config/current/sysconfig/etc.${OPS_SYSTEM}/google_cloud/

 

RUN gcloud auth activate-service-account \

    --key-file=/prod/gmlocal/system/${OPS_SYSTEM}/config/current/sysconfig/etc.${OPS_SYSTEM}/google_cloud/htgm-farm-${FARM_SYSTEM}-service-account.json

RUN gcloud config set project htgm-farm-${FARM_SYSTEM}

RUN yes | gcloud auth configure-docker

 

# Set up nginx.www_dir_server.conf

RUN mkdir -p /var/local/htgm

COPY nginx.www_dir_server.conf /var/local/htgm/nginx.www_dir_server.conf
