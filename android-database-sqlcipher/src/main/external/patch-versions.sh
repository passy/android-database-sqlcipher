#!/bin/bash

set -x

for so in **/libssl.so
do
     greadelf -d $so | grep SONAME | grep 1.1
     if [ $? -eq 0 ]; then
          patchelf --set-soname libssl.so $so
          patchelf --remove-needed libcrypto.so.1.1 $so
          patchelf --add-needed libcrypto.so $so
     fi
done

for so in **/libcrypto.so
do
     greadelf -d $so | grep SONAME | grep 1.1
     if [ $? -eq 0 ]; then
          patchelf --set-soname libcrypto.so $so
     fi
done
