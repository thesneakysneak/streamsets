FROM jeanblanchard/java:serverjre-8
MAINTAINER Adam Kunicki <adam@streamsets.com>

ARG SDC_URL=https://archives.streamsets.com/datacollector/3.5.2/tarball/streamsets-datacollector-all-3.5.2.tgz
ARG SDC_USER=sdc
ARG SDC_VERSION=3.5.2

RUN apk --no-cache add bash \
    curl \
    krb5-libs \
    libstdc++ \
    sed
    
RUN apk add --no-cache bash bash-doc bash-completion
RUN apk add --no-cache musl-dev 
RUN apk add --no-cache gfortran gdb make



RUN echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
  && apk add --update \
              musl \
              build-base \
              linux-headers \
              ca-certificates \
              python3 \
              python3-dev \
              postgresql-dev \
              bash \
  && pip3 install --no-cache-dir --upgrade --force-reinstall pip \
  && rm /var/cache/apk/*

RUN cd /usr/bin \
  && ln -sf easy_install-3.5 easy_install \
  && ln -sf idle3.5 idle \
  && ln -sf pydoc3.5 pydoc \
  && ln -sf python3.5 python \
  && ln -sf python3.5-config python-config \
  && ln -sf pip3.5 pip

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

RUN pip3 install --no-cache-dir virtualenv


# The paths below should generally be attached to a VOLUME for persistence.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
ENV SDC_CONF=/etc/sdc \
    SDC_DATA=/data \
    SDC_DIST="/opt/streamsets-datacollector" \
    SDC_LOG=/logs \
    SDC_RESOURCES=/resources
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/streamsets-libs-extras"

RUN addgroup -S ${SDC_USER} && \
    adduser -S ${SDC_USER} ${SDC_USER}

RUN cd /tmp && \
    curl -o /tmp/sdc.tgz -L "${SDC_URL}" && \
    mkdir /opt/streamsets-datacollector && \
    tar xzf /tmp/sdc.tgz --strip-components 1 -C /opt/streamsets-datacollector && \
    rm -rf /tmp/sdc.tgz

# Create necessary directories.
RUN mkdir -p /mnt \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}"

# Move configuration to /etc/sdc
RUN mv "${SDC_DIST}/etc" "${SDC_CONF}"

# Use short option -s as long option --status is not supported on alpine linux.
RUN sed -i 's|--status|-s|' "${SDC_DIST}/libexec/_stagelibs"

# Setup filesystem permissions.
RUN chown -R "${SDC_USER}:${SDC_USER}" "${SDC_DIST}/streamsets-libs" \
    "${SDC_CONF}" \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}" \
    "${STREAMSETS_LIBRARIES_EXTRA_DIR}"

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc", "-exec"]
