app = make {
  outs = { "a.out" },
  srcs = file_tree("srcs/"),
  cmds = { "gcc srcs/main.c" }
}
