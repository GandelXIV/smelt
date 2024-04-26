build1 = gcc_executable {
  ins = {"main.c"},
  out = "app",
}

build2 = make {
  outs = {"app"},
  srcs = {"main.c"},
  cmds = {"gcc main.c -o app"},
}
