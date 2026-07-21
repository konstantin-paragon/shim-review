FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SHIM_VERSION=16.1
ENV SHIM_TARBALL_SHA256=46319cd228d8f2c06c744241c0f342412329a7c630436fce7f82cf6936b1d603

RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        build-essential \
        wget \
        bsdextrautils \
        dos2unix \
        libelf-dev

COPY . /shim-review

WORKDIR /shim-review

RUN wget -q \
        https://github.com/rhboot/shim/releases/download/${SHIM_VERSION}/shim-${SHIM_VERSION}.tar.bz2 && \
    echo "${SHIM_TARBALL_SHA256}  shim-${SHIM_VERSION}.tar.bz2" | sha256sum --check -

RUN tar -xjf shim-${SHIM_VERSION}.tar.bz2

WORKDIR /shim-review/shim-${SHIM_VERSION}

RUN cp /shim-review/sbat.csv data/sbat.csv

RUN mkdir -p build-x86-64

RUN make -C build-x86-64 \
    ARCH=x86_64 \
    TOPDIR=.. \
    -f ../Makefile \
    POST_PROCESS_PE_FLAGS="-n" \
    VENDOR_CERT_FILE=/shim-review/paragon_vendor_cert.der \
    DESTDIR=/out \
    EFIDIR=paragon \
    install 2>&1 | tee /build.log

RUN hexdump -Cv /out/boot/efi/EFI/paragon/shimx64.efi > built-shimx64.hex && \
    hexdump -Cv /shim-review/shimx64.efi > orig-shimx64.hex && \
    diff -u orig-shimx64.hex built-shimx64.hex

RUN hexdump -Cv /out/boot/efi/EFI/paragon/mmx64.efi > built-mmx64.hex && \
    hexdump -Cv /shim-review/mmx64.efi > orig-mmx64.hex && \
    diff -u orig-mmx64.hex built-mmx64.hex

RUN sha256sum \
    /out/boot/efi/EFI/paragon/shimx64.efi \
    /out/boot/efi/EFI/paragon/mmx64.efi

RUN mkdir -p /artifacts && \
    cp /out/boot/efi/EFI/paragon/shimx64.efi /artifacts/ && \
    cp /out/boot/efi/EFI/paragon/mmx64.efi /artifacts/ && \
    cp /build.log /artifacts/
   
RUN sha256sum /artifacts/* > /artifacts/SHA256SUMS

CMD cp -a /artifacts/. /shim-review/
