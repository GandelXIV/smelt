build1 = gcc_executable {
  name = "main.c",
  outf = "app",
}

build2 = make {
  outs = {"app"},
  srcs = {"main.c"},
  cmds = {"gcc main.c -o app"},
}
