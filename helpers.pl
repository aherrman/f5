# Validates a format string, dying if the format is missing any of the expected
# tokens
#
# validateFormat(fmt, name, tokens):
#   fmt - The format string to validate
#   name - The name of the format (used in the error message if it fails)
#   tokens - Array of the expected tokens
sub validateFormat {
  my ($fmt, $name, @tokens) = @_;

  foreach $token (@tokens) {
    if(!($fmt =~ m/$token/)) {
      die "$name format does not contain the $token replacement token: $fmt\n";
    }
  }
}

1;
