#!/bin/sh

# /bin/sh on Solaris is not a POSIX compatible shell, but /usr/bin/ksh is.
if [ `uname -s` = 'SunOS' -a "${POSIX_SHELL}" != "true" ]; then
    POSIX_SHELL="true"
    export POSIX_SHELL
    exec /usr/bin/ksh $0 $@
fi
unset POSIX_SHELL # clear it so if we invoke other scripts, they run as ksh as well

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
SCRIPT=$SCRIPTPATH/${0##*/}
BASEDIR=$SCRIPTPATH
BUILD_CONFIG=$BASEDIR/rocksdb/make_config.mk

ROCKSDB_VSN="4.9"
SNAPPY_VSN="1.1.1"
ZLIB_VSN="1.2.8"
BZIP2_VSN="1.0.6"
LZ4_VSN="r127"

set -e

if [ `basename $PWD` != "c_src" ]; then
    # originally "pushd c_src" of bash
    # but no need to use directory stack push here
    cd c_src
fi


# detecting gmake and if exists use it
# if not use make
# (code from github.com/tuncer/re2/c_src/build_deps.sh
which gmake 1>/dev/null 2>/dev/null && MAKE=gmake
MAKE=${MAKE:-make}

# Changed "make" to $MAKE

case "$1" in
    rm-deps)
        rm -rf rocksdb system snappy-$SNAPPY_VSN lz4-$LZ4_VSN bzip2-$BZIP2_VSN zlib-$ZLIB_VSN rocksdb-$ROCKSDB_VSN.tar.gz
        ;;

    clean)
        rm -rf system snappy-$SNAPPY_VSN lz4-$LZ4_VSN bzip2-$BZIP2_VSN zlib-$ZLIB_VSN
        if [ -d rocksdb ]; then
            (cd rocksdb && $MAKE clean)
        fi
        ;;

    test)
        export CFLAGS="$CFLAGS -I $BASEDIR/system/include"
        export CXXFLAGS="$CXXFLAGS -I $BASEDIR/system/include"
        export LDFLAGS="$LDFLAGS -L$BASEDIR/system/lib"
        export LD_LIBRARY_PATH="$BASEDIR/rocksdb:$BASEDIR/system/lib:$LD_LIBRARY_PATH"

        (cd rocksdb && $MAKE ldb_tests)

        ;;

    get-deps)
        if [ ! -d rocksdb ]; then
            ROCKSDBURL="https://github.com/facebook/rocksdb/archive/v$ROCKSDB_VSN.tar.gz"
            ROCKSDBTARGZ="rocksdb-$ROCKSDB_VSN.tar.gz"
            echo Downloading $ROCKSDBURL...
            curl -L -o $ROCKSDBTARGZ $ROCKSDBURL
            tar -xzf $ROCKSDBTARGZ
            mv rocksdb-$ROCKSDB_VSN rocksdb
        fi
        ;;

    *)
        if [ ! -d snappy-$SNAPPY_VSN ]; then
            tar -xzf snappy-$SNAPPY_VSN.tar.gz
            (cd snappy-$SNAPPY_VSN && export CXXFLAGS="-static-libstdc++  -fPIC" && ./configure --prefix=$BASEDIR/system --libdir=$BASEDIR/system/lib --with-pic)
        fi

        if [ ! -f system/lib/libsnappy.a ]; then
            (cd snappy-$SNAPPY_VSN && $MAKE && $MAKE install)
        fi

        if [ ! -d lz4-$LZ4_VSN ]; then
            tar -xzf lz4-$LZ4_VSN.tar.gz
            (cd lz4-$LZ4_VSN/lib && make CFLAGS='-fPIC' all)
        fi

        if [ ! -f system/lib/liblz4.a ]; then
            (cp lz4-$LZ4_VSN/lib/liblz4.a  system/lib/)
        fi

        if [ ! -d lbzip2-$BZIP2_VSN ]; then
            tar -xzf bzip2-$BZIP2_VSN.tar.gz
            (cd bzip2-$BZIP2_VSN && make libbz2.a CFLAGS='-fPIC -O2 -g -D_FILE_OFFSET_BITS=64')
        fi

        if [ ! -f system/lib/libbz2.a ]; then
            (cp bzip2-$BZIP2_VSN/libbz2.a system/lib/)
        fi

        if [ ! -d zlib-$ZLIB_VSN ]; then
            tar -xzf zlib-$ZLIB_VSN.tar.gz
            (cd zlib-$ZLIB_VSN && CFLAGS='-fPIC' ./configure --static && make)
        fi

        if [ ! -f system/lib/libz.a ]; then
            (cp zlib-$ZLIB_VSN/libz.a system/lib/)
        fi

        export CFLAGS="$CFLAGS -I $BASEDIR/system/include"
        export CXXFLAGS="$CXXFLAGS -I $BASEDIR/system/include"
        export LDFLAGS="$LDFLAGS -L$BASEDIR/system/lib"
        export LD_LIBRARY_PATH="$BASEDIR/system/lib:$LD_LIBRARY_PATH"

        sh $SCRIPT get-deps
        if [ ! -f rocksdb/librocksdb.a ]; then
            grep -q NewIterators rocksdb/utilities/ttl/db_ttl_impl.cc || patch -p0 -f -d rocksdb/ < dbwithttl_improvements_brigadier.patch
            (cd rocksdb && export CXXFLAGS="-static-libstdc++  -fPIC" && PORTABLE=1 $MAKE static_lib)
        fi
        ;;
esac