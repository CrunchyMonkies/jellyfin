# syntax=docker/dockerfile:1
#
# CrunchyMonkies headless Jellyfin server image.
#
# This is the patched CrunchyMonkies/jellyfin fork (adds the public HLS arg-builder on
# EncodingHelper used by the distributed-transcoding plugin). The web client is shipped
# and served separately (CrunchyMonkies/jellyfin-web via nginx), so this image runs the
# server with --nowebclient.
#
# The server is published self-contained (it carries its own .NET runtime), then overlaid
# onto the official Jellyfin image purely to inherit jellyfin-ffmpeg, the VAAPI/QSV/Mesa
# drivers, and fonts — so probing and any local fallback transcode work out of the box.

ARG DOTNET_VERSION=10.0
# Runtime base: reused only for jellyfin-ffmpeg + GPU drivers + fonts. Pin to a stable
# release; overridable at build time.
ARG JELLYFIN_BASE=jellyfin/jellyfin:10.10.7

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS builder
WORKDIR /src
COPY . .
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
        --configuration Release \
        --self-contained true \
        --runtime linux-x64 \
        --output /jellyfin \
        -p:DebugType=none \
        -p:DebugSymbols=false

FROM ${JELLYFIN_BASE}
# Overlay our patched, self-contained headless server over the official binaries.
COPY --from=builder /jellyfin /jellyfin
# JELLYFIN_FFMPEG / data / cache env are inherited from the base image. Web UI is served
# separately, so run headless.
ENTRYPOINT ["/jellyfin/jellyfin", "--nowebclient"]
