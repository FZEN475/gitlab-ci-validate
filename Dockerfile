FROM registry.gitlab.com/to-be-continuous/tools/tbc-check@sha256:410ecb40adbca3d4e6d60ba5607f22c1c99967fac53c3310fdc90b61b2b1bfde
ARG SCHEME=https
ARG CI_SERVER_HOST=example.gitlab.com
ARG CI_PROJECT_ID=0
ARG GITLAB_CI_FILES=".gitlab-ci.yml"

ENV SCHEME=$SCHEME \
    CI_SERVER_HOST=$CI_SERVER_HOST \
    CI_PROJECT_ID=$CI_PROJECT_ID \
    GITLAB_CI_FILES=$GITLAB_CI_FILES

RUN apk update \
    && apk add --no-cache \
        "openssl>=3.5.6-r0" \
        "musl>=1.2.5-r23" \
        "musl-utils>=1.2.5-r23" \
        "util-linux>=2.41.4-r0" \
        "libuuid>=2.41.4-r0" \
        "curl>=8.17.0-r1" \
        "jq>=1.8.1-r0" \
    && rm -rf /var/cache/apk/*

COPY ci/ /ci

RUN chmod +x /ci/entrypoint.sh

WORKDIR /source

ENTRYPOINT ["/ci/entrypoint.sh"]
