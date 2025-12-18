
# Script to check return type of Blake2b
IO.inspect(Sutra.Blake2b.blake2b_256("hello"), label: "Hash Output")
IO.inspect(byte_size(Sutra.Blake2b.blake2b_256("hello")), label: "Hash Size")
