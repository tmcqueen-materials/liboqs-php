#!/bin/bash
# Remove old build files and make new build directory
rm -rf build
mkdir -p build

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ -e "$LIBOQS_ROOT" ]] || [[ -e "$script_dir/liboqs" ]]; then
    echo "liboqs directory already exists, skipping cloning"; \
else \
    git clone https://github.com/open-quantum-safe/liboqs.git; \
    cd liboqs; \
    git checkout 0.14.0; \
    curl https://raw.githubusercontent.com/tmcqueen-materials/kafkacrypto/refs/heads/master/liboqs-sphincs+-slhdsa.patch > liboqs-sphincs+-slhdsa.patch; \
    patch -p1 < liboqs-sphincs+-slhdsa.patch; \
    cd ..; \
    export LIBOQS_ROOT=$(pwd)/liboqs; \
fi

if [[ -e "$LIBOQS_ROOT/build/lib/liboqs.a" ]]; then
    echo "liboqs library already builded, skipping compilation"; \
else \
    rm -rf $LIBOQS_ROOT/build; \
    cmake -GNinja -B $LIBOQS_ROOT/build $LIBOQS_ROOT -DOQS_MINIMAL_BUILD="KEM_ntruprime_sntrup761;SIG_sphincs_shake256_128f_simple;KEM_ml_kem_1024;SIG_slh_dsa_pure_shake_128f" && ninja -j $(nproc) -C $LIBOQS_ROOT/build; \
fi

# Compile the C++ wrapper
swig -php -c++ -o ./build/oqsphp_wrap.cpp -I$LIBOQS_ROOT/build/include oqsphp.i

# Compile the C++ wrapper and link it with liboqs
# without -std=c++11 or -std=c++20 it fails with exception definition
gcc -std=c++20 -O2 -fPIC `php-config --includes` -I$LIBOQS_ROOT/build/include -c ./build/oqsphp_wrap.cpp -o ./build/oqsphp_wrap.o

# Create the PHP wrapper
gcc -std=c++20 -shared ./build/oqsphp_wrap.o -L$LIBOQS_ROOT/build/lib -loqs -o ./build/oqsphp.so
echo "Finished"
