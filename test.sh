#!/bin/bash

# find . -name .cache -delete
set -xe

find . -name *.o -delete

cargo run examples/hello-world.c:build1
cargo run examples/hello-world.c:build2

cargo run examples/hello2:hello
cargo run examples/hello2:hello_nested

cargo run examples/hello3:app

echo "All ok!"
