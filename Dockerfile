ARG FROM=alpine
ARG TAG=3.12
FROM ${FROM}:${TAG}

ARG BUILD_DATE
ARG BUILD_NAME
ARG BUILD_VCS_REF
ARG BUILD_VCS_URL
ARG BUILD_VERSION

LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name=$BUILD_NAME
LABEL org.label-schema.description="OpenLDAP inside a docker container."
LABEL org.label-schema.usage="README.md"
LABEL org.label-schema.url="https://github.com/timrabl/openldap-docker"
LABEL org.label-schema.vcs-url=$BUILD_VCS_URL
LABEL org.label-schema.vcs-ref=$BUILD_VCS_REF
LABEL org.label-schema.vendor="Tim Rabl"
LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.schema-version=$BUILD_VERSION
LABEL org.label-schema.docker.cmd="docker run -d -p 636:636 -v slapd.{subst,conf}:/etc/openldap/slapd.{subst,conf} -e SUFFIX='dc=example,dc=org' -e LDAP_PASSWORD='verysecurepassword' timrabl/openldap:latest"
LABEL org.label-schema.docker.cmd.devel="docker run -d -p 636:636 -v slapd.{subst,conf}:/etc/openldap/slapd.{subst,conf} -e LDAP_DEBUG='-1' -e SUFFIX='dc=example,dc=org' -e LDAP_PASSWORD='verysecurepassword' timrabl/openldap:latest"
LABEL org.label-schema.docker.cmd.test=""
LABEL org.label-schema.docker.cmd.debug="docker exec -it $CONTAINER /bin/sh"
LABEL org.label-schema.docker.cmd.help="docker exec -it $CONTAINER /usr/local/bin/docker-entrypoint.sh [-h | --help]"
LABEL org.label-schema.docker.params ="README.md"

ENV LDAP_DATA_DIR="/var/lib/openldap/openldap-data/"

RUN apk --no-cache --update add gettext openssl openldap openldap-back-mdb \
        openldap-clients openldap-overlay-memberof \
        openldap-overlay-refint && \
    rm -rf /var/cache/apk/* /etc/openldap/slapd.*

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

VOLUME ${LDAP_DATA_DIR}

EXPOSE 636
