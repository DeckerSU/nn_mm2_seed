# Stage 1: Build the kdf binary
#
# rust:slim-bookworm is used instead of komodoofficial/ci-container:latest.
# Reason: inside a Docker build (overlay filesystem) the following command fails
# with "Invalid cross-device link (os error 18)" because rustup cannot rename
# files across overlay layers when installing or rolling back a toolchain:
#
#   RUN rustup toolchain install stable --no-self-update --profile=minimal && rustup default stable
#
# rust:slim-bookworm ships with the stable toolchain already correctly installed,
# so the extra rustup call is not needed.
#
# To revert to ci-container and manage the toolchain explicitly, replace the FROM line with:
#   FROM komodoofficial/ci-container:latest AS builder
# and add after it:
#   RUN rustup toolchain install stable --no-self-update --profile=minimal && rustup default stable
FROM rust:slim-bookworm AS builder

# Install build dependencies: protoc, git, and C toolchain essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler \
    pkg-config \
    libssl-dev \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone the GLEEC fork at the staging branch and build
RUN git clone --branch staging --depth 1 https://github.com/GLEECBTC/komodo-defi-framework /build/komodo-defi-framework
WORKDIR /build/komodo-defi-framework
RUN cargo build --release

# Stage 2: Minimal runtime image — equivalent to komodoofficial/komodo-defi-framework:dev-latest
FROM docker.io/debian:stable-slim AS kdf-base
WORKDIR /kdf
COPY --from=builder /build/komodo-defi-framework/target/release/kdf /usr/local/bin/kdf
EXPOSE 7783
CMD ["kdf"]

# Stage 3: Final image with extra packages and non-root user
FROM kdf-base
LABEL maintainer="deckersu@protonmail.com"

ARG DEBIAN_FRONTEND=noninteractive
ARG GROUP_ID
ARG USER_ID

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates curl nano jq wget htop sqlite3 adduser; \
	rm -rf /var/lib/apt/lists/*; \
	addgroup --gid ${GROUP_ID:-1000} komodian || true; \
	adduser --disabled-password --gecos '' --uid ${USER_ID:-1000} --gid ${GROUP_ID:-1000} komodian || true

ENV MM2_CONF_PATH=/home/komodian/kdf/MM2.json
ENV MM_COINS_PATH=/home/komodian/.kdf/coins
ENV MM_LOG=/home/komodian/kdf/kdf.log
ENV USERPASS=RPC_UserP@SSW0RD

WORKDIR /home/komodian/kdf
COPY ./ /home/komodian/kdf

RUN PATH=/usr/local/bin/:$PATH
RUN chown -R komodian:komodian /home/komodian
USER komodian
EXPOSE 7783 32326
