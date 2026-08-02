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
# Drop the base image's bundled web client. It belongs to JELLYFIN_BASE (a 10.x release), not to
# this server, and anything that starts the server without --nowebclient will serve it: its
# apiclient revalidates stored credentials with X-MediaBrowser-Token, which this server rejects
# unless EnableLegacyAuthorization is set, so every client silently drops its session on reconnect.
# Removing it makes that a startup error instead. Serve the matching jellyfin-web image via
# --webdir/JELLYFIN_WEB_DIR when a web-hosting (non-headless) server is wanted.
RUN rm -rf /jellyfin/jellyfin-web
# JELLYFIN_FFMPEG / data / cache env are inherited from the base image. Web UI is served
# separately, so run headless.
ENTRYPOINT ["/jellyfin/jellyfin", "--nowebclient"]
