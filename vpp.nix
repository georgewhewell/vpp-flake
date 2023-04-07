{ stdenv
, cmake
, ninja
, python3
, pkg-config
, dpdk
, libbpf
, libbsd
, libelf
, libnl
, libmnl
, libuuid
, zlib
, libpcap
, jansson
, libconfuse
, mbedtls
, openssl
, rdma-core
, check
, subunit
, writeScript
, vppSource
, lib
}:

assert lib.versionAtLeast dpdk.version "21.11";

let
  version = vppSource.rev;
  versionScript = writeScript "version" "echo ${version}-foo-bar";
in

stdenv.mkDerivation {
  pname = "vpp";
  inherit version;

  src = "${vppSource}/src";

  nativeBuildInputs = [
    cmake
    ninja
    (python3.withPackages (p: [ p.ply ]))
    pkg-config
  ];

  buildInputs = [
    dpdk
    libbpf
    libbsd
    libelf
    libnl
    libmnl
    libuuid
    libpcap
    jansson
    zlib
    libconfuse
    mbedtls
    openssl
    rdma-core
  ];

  checkInputs = [
    check # surprise dep: cmake lists are not `find_package`ing it
    subunit
  ];

  doCheck = true;

  postPatch = ''
    # pkg-config --list-all
    #exit 1
    cp ${versionScript} scripts/version

    # the whole packaging stuff is full of impure scripts and
    # not needed in our case
    # sed -i 's/cmake pkg/cmake/' CMakeLists.txt

    # Nix has no /etc/os-release.
    substituteInPlace pkg/CMakeLists.txt --replace 'file(READ "/etc/os-release" os_release)' 'set(os_release "NAME=NIX; ID=nix")'


    # So much about -Wall
    sed -i 's/-Wall/-Wall -Wno-stringop-overflow -Wno-unused-variable/' \
        CMakeLists.txt

    # this script produces impure results
    sed -i \
        -e 's/$(whoami)/itseme/' \
        -e 's/$(hostname)/mario/' \
        -e 's/^DATE_FMT.*$//' \
        -e 's/^SOURCE_DATE_EPOCH.*$//' \
        -e 's/^VPP_BUILD_DATE=.*$/VPP_BUILD_DATE="2022-01-01T00:00:00"/' \
        -e 's|$(git rev-parse[^)]\+)|/vpp-src|' \
        scripts/generate_version_h

    patchShebangs .
  '';

  cmakeFlags = [ "-DVPP_USE_SYSTEM_DPDK=1" ];
}
