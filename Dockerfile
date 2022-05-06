ARG osdistro=debian
ARG oscodename=stretch

FROM $osdistro:$oscodename
LABEL maintainer="Walter Doekes <wjdoekes+sipp@osso.nl>"

ENV DEBIAN_FRONTEND noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
#RUN sed -i -e 's:security.ubuntu.com:APTCACHE:;s:archive.ubuntu.com:APTCACHE:' /etc/apt/sources.list
#RUN printf 'deb http://PPA/ubuntu xenial COMPONENT\n\
#deb-src http://PPA/ubuntu xenial COMPONENT\r\n' >/etc/apt/sources.list.d/osso-ppa.list
#RUN apt-key adv --keyserver pgp.mit.edu --recv-keys 0xBEAD51B6B36530F5
RUN apt-get update -q
RUN apt-get install -y apt-utils
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
    bzip2 ca-certificates curl git \
    build-essential dh-autoreconf devscripts dpkg-dev equivs quilt

# Get build env again, after the FROM, before the first usage
ARG osdistro=debian
ARG osdistshort=deb
ARG oscodename=stretch
ARG upname=sipp
ARG upversion=3.6.0
ARG debepoch=
ARG debversion=0osso1

# Copy debian dir, check version
RUN mkdir -p /build/debian
COPY changelog /build/debian/changelog
RUN . /etc/os-release && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=low" && \
    head -n1 /build/debian/changelog && \
    if test "$(head -n1 /build/debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# Set up upstream source, move debian dir and jump into dir.
RUN upversion_uscore=$(echo $upversion | sed -e 's/~/_/g') && \
    upversion_dash=$(echo $upversion | sed -e 's/~/-/g') && \
    curl -L --fail "https://github.com/SIPp/sipp/releases/download/v${upversion_uscore}/${upname}-${upversion_dash}.tar.gz" \
    >/build/${upname}_${upversion}.orig.tar.gz
RUN cd /build && tar zxf "${upname}_${upversion}.orig.tar.gz" && \
    mv debian "${upname}-${upversion}/"

# Apt-get prerequisites according to control file.
COPY compat control /build/${upname}-${upversion}/debian/
RUN cd /tmp && \
    mk-build-deps --install --remove --tool "apt-get -y" \
      /build/${upname}-${upversion}/debian/control

# Build!
WORKDIR "/build/${upname}-${upversion}"
COPY . debian
RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc -sa

# FIXME:
# - run install/setup tests?
# - proper parallel build?
# - md5sum/hashes of the sources files..

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistshort=$osdistshort \
    upname=$upname upversion=$upversion debversion=$debversion
RUN . /etc/os-release && fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    mkdir -p /dist/${upname}_${fullversion} && \
    mv /build/*${fullversion}* /dist/${upname}_${fullversion}/ && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${upname}_${fullversion}/ && \
    cd / && find dist/${upname}_${fullversion} -type f >&2
