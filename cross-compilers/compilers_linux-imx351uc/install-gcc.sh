set -e -x

CHOST=$(${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-final/gcc/xgcc -dumpmachine)
pushd ${SRC_DIR}/.build/$CHOST/build/build-cc-gcc-final/

# libtool wants to use ranlib that is here
export PATH=$PATH:${SRC_DIR}/.build/$CHOST/buildtools/bin

make -C gcc prefix=${PREFIX} install-driver install-gcc-ar install-headers install-plugin

install -m755 -t ${PREFIX}/bin/ gcc/gcov{,-tool}
install -m755 -t ${PREFIX}/bin/ gcc/{cc1,collect2}

make -C $CHOST/libgcc prefix=${PREFIX} install
# rm ${PREFIX}/lib/libgcc_s.so*

make prefix=${PREFIX} install-libcc1
install -d ${PREFIX}/share/gdb/auto-load/usr/lib

make prefix=${PREFIX} install-fixincludes
make -C gcc prefix=${PREFIX} install-mkheaders

if [[ -d $CHOST/libgomp ]]; then
  make -C $CHOST/libgomp prefix=${PREFIX} install-nodist_toolexeclibHEADERS \
  install-nodist_libsubincludeHEADERS
fi

if [[ -d $CHOST/libitm ]]; then
  make -C $CHOST/libitm prefix=${PREFIX} install-nodist_toolexeclibHEADERS
fi

if [[ -d $CHOST/libquadmath ]]; then
  make -C $CHOST/libquadmath prefix=${PREFIX} install-nodist_libsubincludeHEADERS
fi

if [[ -d $CHOST/libsanitizer ]]; then
  make -C $CHOST/libsanitizer prefix=${PREFIX} install-nodist_{saninclude,toolexeclib}HEADERS
fi

if [[ -d $CHOST/libsanitizer/asan ]]; then
  make -C $CHOST/libsanitizer/asan prefix=${PREFIX} install-nodist_toolexeclibHEADERS
fi

make -C libiberty prefix=${PREFIX} install
# install PIC version of libiberty
install -m644 libiberty/pic/libiberty.a ${PREFIX}/lib

make -C gcc prefix=${PREFIX} install-man install-info

make -C gcc prefix=${PREFIX} install-po

# many packages expect this symlink
[[ -f ${PREFIX}/bin/cc ]] && rm ${PREFIX}/bin/cc
pushd ${PREFIX}/bin
  ln -s $CHOST-gcc cc
popd

# POSIX conformance launcher scripts for c89 and c99
cat > ${PREFIX}/bin/c89 <<"EOF"
#!/bin/sh
fl="-std=c89"
for opt; do
  case "$opt" in
    -ansi|-std=c89|-std=iso9899:1990) fl="";;
    -std=*) echo "`basename $0` called with non ANSI/ISO C option $opt" >&2
      exit 1;;
  esac
done
exec gcc $fl ${1+"$@"}
EOF

  cat > ${PREFIX}/bin/c99 <<"EOF"
#!/bin/sh
fl="-std=c99"
for opt; do
  case "$opt" in
    -std=c99|-std=iso9899:1999) fl="";;
    -std=*) echo "`basename $0` called with non ISO C99 option $opt" >&2
      exit 1;;
  esac
done
exec gcc $fl ${1+"$@"}
EOF

  chmod 755 ${PREFIX}/bin/c{8,9}9

rm $PREFIX/bin/${CHOST}-gcc-${PKG_VERSION}

popd

# Install uClibc headers
pushd ${SRC_DIR}/.build/$CHOST/build/build-libc-startfiles/multilib
  make CROSS_COMPILE=${CHOST}- PREFIX=${PREFIX}/${CHOST}/sysroot/ MULTILIB_DIR=lib LOCALE_DATA_FILENAME=uClibc-locale-030818.tgz STRIPTOOL=true V=2 UCLIBC_EXTRA_CFLAGS=-pipe headers
popd

# Install Runtime Library Exception
install -Dm644 $SRC_DIR/.build/src/gcc-${PKG_VERSION}/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/gcc/RUNTIME.LIBRARY.EXCEPTION

mkdir -p ${PREFIX}/etc/conda/{de,}activate.d
cp "${SRC_DIR}"/activate-gcc.sh ${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.sh
cp "${SRC_DIR}"/deactivate-gcc.sh ${PREFIX}/etc/conda/deactivate.d/deactivate-${PKG_NAME}.sh