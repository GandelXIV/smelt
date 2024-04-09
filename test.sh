#!/bin/bash

find . -name .cache delete

cargo run examples/hello-world.c:build1
cargo run examples/hello-world.c:build2
cargo run examples/hello2:hello
