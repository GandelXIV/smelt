-- Regular version

main = make {
  outs = {"main.o"},
  srcs = {"main.c"},
  cmds = {"gcc -c main.c -o main.o"},
}

lib = make {
  outs = {"lib.o"},
  srcs = {"lib.c"},
  cmds = {"gcc -c lib.c -o lib.o"},
}

hello = make {
  outs = {"hello"},
  srcs = {main, lib},
  cmds = {"gcc main.o lib.o -o hello"}
}

-- Nested version

hello_nested = make {
  outs = {"hello"},
  cmds = {"gcc main.o lib.o -o hello"},
  srcs = {
    make {
      outs = {"main.o"},
      srcs = {"main.c"},
      cmds = {"gcc -c main.c -o main.o"},
    },

    make {
      outs = {"lib.o"},
      srcs = {"lib.c"},
      cmds = {"gcc -c lib.c -o lib.o"},
    },
  },
}
