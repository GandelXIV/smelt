#!/bin/bash

# find . -name .cache -delete
set -xe

if [ $1 == "release" ];
then
  cargo build --release;
  RUN="target/release/smelt";
else
  RUN="cargo run";
fi

find . -name *.o -delete

$RUN examples/hello-world.c:build1
$RUN examples/hello-world.c:build2

$RUN examples/hello2:hello
$RUN examples/hello2:hello_nested

$RUN examples/hello3:app

echo "All ok!"
