FROM debian:13-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_DATE
ARG VERSION=debian13
ARG TARGETARCH
ARG DESKTOP=xfce
ARG KUBECTL_VERSION=1.37.1
ARG HELM_VERSION=4.3.0
ARG HEADLAMP_VERSION=0.45.0
ARG K9S_VERSION=0.51.0
ARG FREELENS_VERSION=1.10.3
ARG KUBECM_VERSION=0.35.1
ARG KUBECTX_VERSION=0.11.0

LABEL org.opencontainers.image.title="Debian XRDP workstation" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="Michael Trip"

RUN case "${DESKTOP}" in \
        xfce) desktop_packages="xfce4 xfce4-goodies elementary-xfce-icon-theme" ;; \
        mate) desktop_packages="mate-desktop-environment-core mate-terminal mate-themes" ;; \
        *) echo "Unsupported DESKTOP: ${DESKTOP}" >&2; exit 1 ;; \
    esac \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        bash-completion \
        ca-certificates \
        chromium \
        chromium-sandbox \
        curl \
        dbus \
        dbus-x11 \
        default-jre-headless \
        desktop-base \
        fastfetch \
        firefox-esr \
        fonts-dejavu \
        fonts-liberation \
        gnome-themes-extra \
        gnupg \
        gvfs \
        inetutils-traceroute \
        iputils-ping \
        locales \
        libreoffice \
        libglib2.0-bin \
        man-db \
        mate-polkit \
        pluma \
        procps \
        sudo \
        tar \
        thunderbird \
        tilix \
        tini \
        vim \
        wget \
        xdg-utils \
        xorgxrdp \
        xrdp \
        openssh-client \
        zsh \
        ${desktop_packages} \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl --retry 5 --retry-all-errors -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: https://packages.microsoft.com/repos/code' \
        'Suites: stable' \
        'Components: main' \
        'Architectures: amd64 arm64' \
        'Signed-By: /etc/apt/keyrings/packages.microsoft.gpg' \
        > /etc/apt/sources.list.d/vscode.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends code

# Discover launcher names from the package (older releases used code*.desktop).
RUN launchers="$(dpkg -L code | sed -n '\|^/usr/share/applications/.*\.desktop$|p')" \
    && test -n "$launchers" \
    && printf '%s\n' "$launchers" | xargs sed -i 's|^Exec=/usr/share/code/code |Exec=/usr/local/bin/code |'

RUN case "${TARGETARCH}" in \
        amd64) KUBECM_ARCH=x86_64; HEADLAMP_ARCH=x64 ;; \
        arm64) KUBECM_ARCH=arm64; HEADLAMP_ARCH=arm64 ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl --retry 5 --retry-all-errors -fsSLo /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/kubectl.sha256 \
        "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" \
    && printf '%s  %s\n' "$(cat /tmp/kubectl.sha256)" /usr/local/bin/kubectl | sha256sum --check - \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/helm.tar.gz \
        "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/helm.sha256 \
        "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" \
    && printf '%s  %s\n' "$(cut -d' ' -f1 /tmp/helm.sha256)" /tmp/helm.tar.gz | sha256sum --check - \
    && tar -xzf /tmp/helm.tar.gz -C /tmp \
    && mv "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/k9s.tar.gz \
        "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/k9s.tar.gz -C /usr/local/bin k9s \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/kubecm.tar.gz \
        "https://github.com/sunny0826/kubecm/releases/download/v${KUBECM_VERSION}/kubecm_v${KUBECM_VERSION}_Linux_${KUBECM_ARCH}.tar.gz" \
    && tar -xzf /tmp/kubecm.tar.gz -C /usr/local/bin kubecm \
    && curl --retry 5 --retry-all-errors -fsSLo /usr/local/bin/kubectx \
        "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx" \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/freelens.deb \
        "https://github.com/freelensapp/freelens/releases/download/v${FREELENS_VERSION}/Freelens-${FREELENS_VERSION}-linux-${TARGETARCH}.deb" \
    && apt-get install -y --no-install-recommends /tmp/freelens.deb \
    && curl --retry 5 --retry-all-errors -fsSLo /tmp/headlamp.tar.gz \
        "https://github.com/kubernetes-sigs/headlamp/releases/download/v${HEADLAMP_VERSION}/Headlamp-${HEADLAMP_VERSION}-linux-${HEADLAMP_ARCH}.tar.gz" \
    && mkdir -p /opt/headlamp \
    && tar -xzf /tmp/headlamp.tar.gz -C /opt/headlamp --strip-components=1 \
    && chmod 0755 /usr/local/bin/kubectl /usr/local/bin/helm \
        /usr/local/bin/k9s /usr/local/bin/kubecm /usr/local/bin/kubectx \
    && adduser xrdp ssl-cert \
    && sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

COPY config/skel/ /tmp/desktop-defaults/xfce/
COPY config/skel-mate/ /tmp/desktop-defaults/mate/
COPY config/mate-theme.gschema.override /tmp/mate-theme.gschema.override
RUN install -d -m 0755 /usr/share/wallpapers
COPY --chmod=0644 config/wallpaper.png /usr/share/wallpapers/wallpaper.png
COPY config/chromium-container.conf /etc/chromium.d/99-container-sandbox
COPY config/code-wrapper /usr/local/bin/code
COPY config/headlamp-wrapper /usr/local/bin/headlamp
COPY config/headlamp.desktop /usr/local/share/applications/headlamp.desktop
COPY config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN cp -a "/tmp/desktop-defaults/${DESKTOP}/." /etc/skel/ \
    && if [ "${DESKTOP}" = mate ]; then \
        install -m 0644 /tmp/mate-theme.gschema.override \
            /usr/share/glib-2.0/schemas/90_xrdp-mate.gschema.override \
        && glib-compile-schemas --strict /usr/share/glib-2.0/schemas; \
    fi \
    && rm -rf /tmp/desktop-defaults /tmp/mate-theme.gschema.override \
    && if [ "${DESKTOP}" = xfce ]; then \
        sed -i '/<property name="LockCommand"/a\    <property name="PromptOnLogout" type="bool" value="true"/>' \
        /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml \
    && sed -i 's|/usr/share/images/desktop-base/default|/usr/share/wallpapers/wallpaper.png|g' \
        /usr/share/desktop-base/profiles/xdg-config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
    && cp /usr/share/desktop-base/profiles/xdg-config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
        /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml; \
    fi \
    && chmod 0755 /usr/local/bin/code /usr/local/bin/docker-entrypoint.sh \
        /usr/local/bin/headlamp /etc/skel/.xsession \
    && mkdir -p /home /run/xrdp /var/run/xrdp

VOLUME ["/home"]
EXPOSE 3389

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD pgrep -x xrdp >/dev/null && pgrep -x xrdp-sesman >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/docker-entrypoint.sh"]
