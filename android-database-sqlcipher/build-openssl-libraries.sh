#! /usr/bin/env bash

MINIMUM_ANDROID_SDK_VERSION=$1
MINIMUM_ANDROID_64_BIT_SDK_VERSION=$2

(cd src/main/external/openssl;

 if [ ! ${MINIMUM_ANDROID_SDK_VERSION} ]; then
     echo "MINIMUM_ANDROID_SDK_VERSION was not provided, include and rerun"
     exit 1
 fi

 if [ ! ${MINIMUM_ANDROID_64_BIT_SDK_VERSION} ]; then
     echo "MINIMUM_ANDROID_64_BIT_SDK_VERSION was not provided, include and rerun"
     exit 1
 fi

 if [ ! ${ANDROID_NDK_ROOT} ]; then
     echo "ANDROID_NDK_ROOT environment variable not set, set and rerun"
     exit 1
 fi

 ANDROID_LIB_ROOT=../android-libs
 ANDROID_TOOLCHAIN_DIR=/tmp/sqlcipher-android-toolchain
 OPENSSL_CONFIGURE_OPTIONS="no-krb5 no-idea no-camellia \
        no-seed no-bf no-cast no-rc2 no-rc4 no-rc5 no-md2 \
        no-md4 no-ripemd no-rsa no-ecdh no-sock no-ssl2 no-ssl3 \
        no-dsa no-dh no-ec no-ecdsa no-tls1 no-pbe no-pkcs \
        no-tlsext no-pem no-rfc3779 no-whirlpool no-ui no-srp \
        no-ssltrace no-tlsext no-mdc2 no-ecdh no-engine \
        no-tls2 no-srtp -fPIC"

 HOST_INFO=`uname -a`
 case ${HOST_INFO} in
     Darwin*)
         TOOLCHAIN_SYSTEM=darwin-x86
         ;;
     Linux*)
         if [[ "${HOST_INFO}" == *i686* ]]
         then
             TOOLCHAIN_SYSTEM=linux-x86
         else
             TOOLCHAIN_SYSTEM=linux-x86_64
         fi
         ;;
     *)
         echo "Toolchain unknown for host system"
         exit 1
         ;;
 esac

 rm -rf ${ANDROID_LIB_ROOT}
 ./Configure dist

 for SQLCIPHER_TARGET_PLATFORM in armeabi armeabi-v7a x86 x86_64 arm64-v8a
 do
     echo "Building for libcrypto.a,libssl.so for ${SQLCIPHER_TARGET_PLATFORM}"
     case "${SQLCIPHER_TARGET_PLATFORM}" in
         armeabi)
             TOOLCHAIN_ARCH=arm
             TOOLCHAIN_PREFIX=arm-linux-androideabi
             CONFIGURE_ARCH=android
             PLATFORM_OUTPUT_DIR=armeabi
             ANDROID_API_VERSION=${MINIMUM_ANDROID_SDK_VERSION}
             OFFSET_BITS=32
             ;;
         armeabi-v7a)
             TOOLCHAIN_ARCH=arm
             TOOLCHAIN_PREFIX=arm-linux-androideabi
             CONFIGURE_ARCH=android -march=armv7-a
             PLATFORM_OUTPUT_DIR=armeabi-v7a
             ANDROID_API_VERSION=${MINIMUM_ANDROID_SDK_VERSION}
             OFFSET_BITS=32
             ;;
         x86)
             TOOLCHAIN_ARCH=x86
             TOOLCHAIN_PREFIX=i686-linux-android
             CONFIGURE_ARCH=android-x86
             PLATFORM_OUTPUT_DIR=x86
             ANDROID_API_VERSION=${MINIMUM_ANDROID_SDK_VERSION}
             OFFSET_BITS=32
             ;;
         x86_64)
             TOOLCHAIN_ARCH=x86_64
             TOOLCHAIN_PREFIX=x86_64-linux-android
             CONFIGURE_ARCH=android64
             PLATFORM_OUTPUT_DIR=x86_64
             ANDROID_API_VERSION=${MINIMUM_ANDROID_64_BIT_SDK_VERSION}
             OFFSET_BITS=64
             ;;
         arm64-v8a)
             TOOLCHAIN_ARCH=arm64
             TOOLCHAIN_PREFIX=aarch64-linux-android
             CONFIGURE_ARCH=android64-aarch64
             PLATFORM_OUTPUT_DIR=arm64-v8a
             ANDROID_API_VERSION=${MINIMUM_ANDROID_64_BIT_SDK_VERSION}
             OFFSET_BITS=64
             ;;
         *)
             echo "Unsupported build platform:${SQLCIPHER_TARGET_PLATFORM}"
             exit 1
     esac

     rm -rf ${ANDROID_TOOLCHAIN_DIR}
     mkdir -p "${ANDROID_LIB_ROOT}/${SQLCIPHER_TARGET_PLATFORM}"
     python ${ANDROID_NDK_ROOT}/build/tools/make_standalone_toolchain.py \
            --arch ${TOOLCHAIN_ARCH} \
            --api ${ANDROID_API_VERSION} \
            --install-dir ${ANDROID_TOOLCHAIN_DIR}

     if [ $? -ne 0 ]; then
         echo "Error executing make_standalone_toolchain.py for ${TOOLCHAIN_ARCH}"
         exit 1
     fi

     export PATH=${ANDROID_TOOLCHAIN_DIR}/bin:$PATH
     export CROSS_SYSROOT=${ANDROID_TOOLCHAIN_DIR}/sysroot

     RANLIB=${TOOLCHAIN_PREFIX}-ranlib \
           AR=${TOOLCHAIN_PREFIX}-ar \
           CC=${TOOLCHAIN_PREFIX}-gcc \
           ./Configure shared "${CONFIGURE_ARCH}" \
           -D__ANDROID_API__=${ANDROID_API_VERSION} \
           -D_FILE_OFFSET_BITS=${OFFSET_BITS} \
           "${OPENSSL_CONFIGURE_OPTIONS}"

     if [ $? -ne 0 ]; then
         echo "Error executing:./Configure ${CONFIGURE_ARCH} ${OPENSSL_CONFIGURE_OPTIONS}"
         exit 1
     fi

     make clean
     make

     if [ $? -ne 0 ]; then
         echo "Error executing make for platform:${SQLCIPHER_TARGET_PLATFORM}"
         exit 1
     fi

     mv libcrypto*.so* libssl*.so* ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}
 done
)
