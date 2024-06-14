FROM tobix/wine:devel
MAINTAINER Tobias Gruetzmacher "tobias-docker@23.gs"

ENV WINEDEBUG -all
ENV WINEPREFIX /opt/wineprefix

COPY wine-init.sh SHA256SUMS.txt keys.gpg /tmp/helper/
COPY mkuserwineprefix entrypoint.sh /opt/

RUN mkdir /opt/scripts

# Prepare environment
RUN xvfb-run sh /tmp/helper/wine-init.sh

# renovate: datasource=github-tags depName=python/cpython versioning=pep440
ARG PYTHON_VERSION=3.12.4
# renovate: datasource=github-releases depName=upx/upx versioning=loose
ARG UPX_VERSION=4.2.4

RUN umask 0 && cd /tmp/helper && \
  curl -LOOO \
    https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-amd64.exe{,.asc} \
    https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-win64.zip \
  && \
  gpgv --keyring ./keys.gpg python-${PYTHON_VERSION}-amd64.exe.asc python-${PYTHON_VERSION}-amd64.exe && \
  sha256sum -c SHA256SUMS.txt && \
  xvfb-run sh -c "\
    wine python-${PYTHON_VERSION}-amd64.exe /quiet TargetDir=C:\\Python \
      Include_doc=0 InstallAllUsers=1 PrependPath=1; \
    wineserver -w" && \
  unzip upx*.zip && \
  mv -v upx*/upx.exe ${WINEPREFIX}/drive_c/windows/ && \
  cd .. && rm -Rf helper

# Install some python software
RUN umask 0 && xvfb-run sh -c "\
  wine pip install --no-warn-script-location pyinstaller MetaTrader5; \
  wineserver -w"

RUN apt update && apt install -y make gcc musl-dev libx11-dev \
            libxft-dev libxext-dev libssl3 \
            musl

RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y  --no-install-recommends xorg xserver-xorg-video-dummy

COPY assets/xorg.conf /etc/X11/xorg.conf
COPY assets/xorg.conf.d /etc/X11/xorg.conf.d

RUN apt install -y x11vnc wget curl

# Configure init
RUN echo "bump001"
COPY assets/supervisord.conf /etc/supervisord.conf

ENV DISPLAY :0

# Openbox window manager
RUN apt install -y openbox
COPY assets/openbox/mayday/mayday-arc /usr/share/themes/mayday-arc
COPY assets/openbox/mayday/mayday-arc-dark /usr/share/themes/mayday-arc-dark
COPY assets/openbox/mayday/mayday-grey /usr/share/themes/mayday-grey
COPY assets/openbox/mayday/mayday-plane /usr/share/themes/mayday-plane
COPY assets/openbox/mayday/thesis /usr/share/themes/thesis
COPY assets/openbox/rc.xml /etc/xdg/openbox/rc.xml
COPY assets/openbox/menu.xml /etc/xdg/openbox/menu.xml

ENV USER=root
ENV PASSWORD=root

RUN echo "$USER:$PASSWORD" | /usr/sbin/chpasswd

RUN apt install -y slim
COPY assets/slim/slim.conf /etc/slim.conf

# A decent system font
# RUN apt install -y font-noto
# COPY assets/fonts.conf /etc/fonts/fonts.conf

RUN apt install -y stterm

# Some other resources
RUN apt install -y supervisor

# COPY assets/xinit/Xresources /etc/X11/Xresources
# COPY assets/xinit/xinitrc.d /etc/X11/xinit/xinitrc.d

COPY assets/x11vnc-session.sh /opt/x11vnc-session.sh
COPY assets/start.sh /opt/start.sh

# RUN ln -s /usr/bin/wine64 /usr/bin/wine

RUN wget https://dl.winehq.org/wine/wine-gecko/2.40/wine_gecko-2.40-x86_64.msi
RUN msiexec /i wine_gecko-2.40-x86_64.msi

RUN ln -s -f /var/run/slim.auth ~/.Xauthority
EXPOSE 5900 15555 15556 15557 15558

#ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
