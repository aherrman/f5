#!/usr/bin/perl -w

# Runs the system command that was passed in.
# If the command's return is nonzero then it calls die.
sub checkedSyscall {
  my ($cmd) = @_;
  system($cmd);
  $retcode = $? >> 8;
  if($retcode != 0) {
    die "Command failed: $cmd";
  }
}

# Runs the system command that was passed in and returns the output of the
# call as an array of lines.
# If the command's return is nonzero then it calls die.
sub checkedSyscallA {
  my ($cmd) = @_;
  my @results = `$cmd`;
  if($? != 0) {
    die "Command failed: $cmd";
  }
  return @results;
}

# Runs the system command that was passed in and returns the output of the
# call as a string
# If the command's return is nonzero then it calls die.
sub checkedSyscallS {
  my ($cmd) = @_;
  my $results = `$cmd`;
  if($? != 0) {
    die "Command failed: $cmd";
  }
  return $results;
}

1;
