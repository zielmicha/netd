#!/bin/sh
set -e
cd "$(dirname "$0")"

if [ -e nimenv.local ]; then
  echo 'nimenv.local exists. You may use `nimenv build` instead of this script.'
  #exit 1
fi

mkdir -p .nimenv/nim
mkdir -p .nimenv/deps

NIMHASH=cd61f5e5768d4063596d6df578ae9bb5f9d52430773542987e91050b848cb1a9
if ! [ -e .nimenv/nimhash -a \( "$(cat .nimenv/nimhash)" = "$NIMHASH" \) ]; then
  echo "Downloading Nim http://nim-lang.org/download/nim-0.13.0.tar.xz (sha256: $NIMHASH)"
  wget http://nim-lang.org/download/nim-0.13.0.tar.xz -O .nimenv/nim.tar.xz
  if ! [ "$(sha256sum < .nimenv/nim.tar.xz)" = "$NIMHASH  -" ]; then
    echo "verification failed"
    exit 1
  fi
  echo "Unpacking Nim..."
  rm -r .nimenv/nim
  mkdir -p .nimenv/nim
  cd .nimenv/nim
  tar xJf ../nim.tar.xz
  mv nim-*/* .
  echo "Building Nim..."
  make -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
  echo $NIMHASH > .nimenv/nimhash
fi

get_dep() {
  set -e
  cd .nimenv/deps
  name="$1"
  url="$2"
  hash="$3"
  srcpath="$4"
  new=0
  if ! [ -e "$name" ]; then
    git clone --recursive "$url" "$name"
    new=1
  fi
  if ! [ "$(cd "$name" && git rev-parse HEAD)" = "$hash" -a $new -eq 0 ]; then
     cd "$name"
     git fetch --all
     git checkout -q "$hash"
     git submodule update --init
     cd ..
  fi
  cd ../..
  echo "path: \".nimenv/deps/$name$srcpath\"" >> nim.cfg
}

echo "path: \".\"" > nim.cfg

get_dep dbus https://github.com/zielmicha/nim-dbus 8226618625141e55ea65fb9f89807de662b3d182 ''
get_dep libcommon https://github.com/networkosnet/libcommon e51cc7898529b80741898b7029b76b3559b8fdf2 ''
get_dep niceconf https://github.com/networkosnet/niceconf ccf617c397e6c8933d9fca910524136c45e3af8a ''
get_dep reactor https://github.com/zielmicha/reactor.nim 21c0bd813601a93c244e89b478a615039207e07f ''

echo '# reactor.nim requires pthreads
threads: "on"

# enable debugging
passC: "-g"
passL: "-g"

verbosity: "0"
hint[ConvFromXtoItselfNotNeeded]: "off"
hint[XDeclaredButNotUsed]: "off"

debugger: "native"

@if release:
  gcc.options.always = "-w -fno-strict-overflow -flto"
  gcc.cpp.options.always = "-w -fno-strict-overflow -flto"
  clang.options.always = "-w -fno-strict-overflow -flto"
  clang.cpp.options.always = "-w -fno-strict-overflow -flto"
  obj_checks: on
  field_checks: on
  bound_checks: on
@end' >> nim.cfg

mkdir -p bin
ln -sf ../.nimenv/nim/bin/nim bin/nim

echo "building netd"; nim c --out:"$PWD/bin/netd" netd.nim
