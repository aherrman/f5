# Helper functions for dealing with the F5
# Requires the checkedSyscall.pl file

require "checkedSyscall.pl";

$bigpipe = "bigpipe";

# Gets the information for an item from the BIG-IP
# getItem(item):
#   item - The item to get
#
# The item name needs to include both the type and name.  For example, to get a
# pool called "my_pool" you would do:
#   getItem("pool my_pool")
# Or to get a TCP profile called "my_tcp_prof" you would do:
#   getItem("profile tcp my_tcp_prof");
sub getItem {
  my ($itemName) = @_;
  if(($item = `$bigpipe $itemName list 2>&1`) && ($? == 0)) {
    return $item
  }
  return undef;
}

# Checks to see if an item exists and dies if it does.  This is useful before
# creating something if you want to fail if it already exists.
# dieIfExists(item):
#   item - The item to check for
#
# The item name needs to include both the type and name.  For example, to check
# a pool called "my_pool" you would do:
#   dieIfExists("pool my_pool")
# Or to check a TCP profile called "my_tcp_prof" you would do:
#   dieIfExists("profile tcp my_tcp_prof");
sub dieIfExists {
  my ($item) = @_;
  if($tmp = getItem($item)) {
    die "Error: $item already exists:\n$tmp\n";
  }
}

# Checks to see if an item exists and dies if it does not.
# dieIfDoesntExist(item):
#   item - The item to check for
#
# The item name needs to include both the type and name.  For example, to check
# a pool called "my_pool" you would do:
#   dieIfDoesntExist("pool my_pool")
# Or to check a TCP profile called "my_tcp_prof" you would do:
#   dieIfDoesntExist("profile tcp my_tcp_prof");
sub dieIfDoesntExist {
  my ($item) = @_;
  if(!getItem($item)) {
    die "Error: $item does not exist:\n";
  }
}

# Creates an item if it doesn't already exist.
# createIfDoesntExist(item, info):
#   item - The item to check/create
#   info - The item info to use when creating
#
# The item name needs to include both the type and name.  For example, to create a
# monitor called my_monitor you would do:
#   createIfDoesntExist("monitor my_monitor", "{ defaults from tcp }")
sub createIfDoesntExist {
  my ($item, $info) = @_;
  if(!getItem($item)) {
    checkedSyscall("$bigpipe $item $info");
  }
}

# Creates a node, dying if it already exists
# createNode(nodeIP, nodeName):
#   nodeIP - The IP address for the node
#   nodeName - The screen name to assign to the node.  Optional.
sub createNode {
  ($nodeIP, $nodeName) = @_;
  dieIfExists("node $nodeIP");

  $nodeInfo = "node $nodeIP { ";
  if($nodeName) {
    $nodeInfo .= "screen $nodeName";
  }
  $nodeInfo .= " }";

  checkedSyscall("$bigpipe $nodeInfo");
}

# Creates a pool, dying if it already exists
# createPool(name, port, monitor, members):
#   name - The name to give the pool
#   port - The port the pool members should be configured with
#   monitor - The health monitor to assign.
#   nodes - Array containing the members to add to the pool ("node:port")
sub createPool {
  my ($name, $port, $monitor, @nodes) = @_;
  my ($poolInfo);

  dieIfExists("pool $name");

  $poolInfo = "pool $name {";
  if($monitor) {
    $poolInfo .= " monitor all $monitor";
  }
  foreach $node (@nodes) {
    #dieIfDoesntExist("node $node");
    $poolInfo .= " member $node:$port";
  }
  $poolInfo .= " }";

  checkedSyscall("$bigpipe $poolInfo");
} 

# Disables all members of a pool
# disableAllPoolMembers(poolName):
#   poolName - The name of the pool to disable the members of
sub disableAllPoolMembers {
  my ($poolName) = @_;

  dieIfDoesntExist("pool $poolName");

  my ($members) = checkedSyscallA("$bigpipe pool $poolName member list");
  foreach $member (@members) {
    chomp $member;
    if(!($member =~ m/member/)) { next; }
    $member =~ s/.*member ([\S]*:[\S]*).*/$1/g;
    checkedSyscall("$bigpipe pool $poolName member $member session disable");
  }
}

# Copies a pool
# copyPool(srcName, destName):
#   srcName - The name of the pool to copy
#   destName - The name to give the new pool
sub copyPool {
  my ($srcName, $destName) = @_;
  dieIfDoesntExist("pool $srcName");
  dieIfExists("pool $destName");

  my $poolInfo = checkedSyscallS("$bigpipe pool $srcPool list");

  $poolInfo =~ s/$srcName/$destName/g;
  $poolInfo =~ s/(\r|\n)//g;
  chomp $poolInfo;

  checkedSyscall("$bigpipe $poolInfo");
}

# Adds a member to a preexisting pool
# addToPool(member, pool, enable):
#   member - The pool member to add (node:port pair)
#   pool - The pool to add the member to
#   enable - true to have the member enabled, false to have it disabled
sub addToPool {
  my ($member, $pool, $enable) = @_;

  # Default $enable to true
  if(@_ < 3) { $enable = 1; }

  # syscall will fail if the pool or node doesn't exist, so don't bother
  # checking if it exists first.

  checkedSyscall("$bigpipe pool $pool member $member add");
  if(!$enable) {
    checkedSyscall("$bigpipe pool $pool member $member session disable");
  }
}

# Adds items to a class
# addToClass(class, values)
#   class - The name of the class to modify
#   values - Array of the values to add to the class
sub addToClass {
  my ($class, @values) = @_;
  modifyClass($class, "add", @values);
}

# Removes items from a class
# removeFromClass(class, values)
#   class - The name of the class to modify
#   values - Array of the values to remove from the class
sub removeFromClass {
  my ($class, @values) = @_;
  modifyClass($class, "delete", @values);
}

# Modifies the items in a class
# modifyClass(class, action, values)
#   class - The name of the class to modify
#   action - "add" to add the values, "delete" to remove them
#   values - Array of the values to add/remove
sub modifyClass {
  my ($class, $action, @values) = @_;
  my $valString = "{ " . join(" ", @values) . " }";
  #foreach $v (@values) {
  #  $valString .= " $v";
  #}
  #$valString .= " }";
  checkedSyscall("$bigpipe class $class $action $valString");
}

# Loads a class as a hashtable, with the class entries as keys with a value of 1
# Nonexistant classes will cause an empty has to be returned
# loadClassAsHash(name)
#   name - The name of the class to load
sub loadClassAsHash {
  my ($name) = @_;
  my %values = ();
  my $classRaw = getItem("class $name");

  if($classRaw) {
    my @class = split /^/, $classRaw;
    my $len = @class;
    # Skip first and last line
    for(my $i = 1; $i < $len - 1; $i++) {
      my $val = $class[$i];
      chomp $val;
      $val =~ s/[ \t]*//g;
      $values{$val} = 1;
    }
  } else {
    print "Class $name not found\n";
  }

  return %values;
}

# Saves a class from a hashtable.
# The keys of the hash are treated as the class's entries.  Only keys with a
# true value will be loaded.
#
# Note that the keys are not wrapped in quotes, allowing numeric or other
# class types to be created.  If creating a string class then the keys need to
# include quotes.
#
# saveClassFromHash(name, values)
#   name - The name of the class to save to
#   values - Hashtable of the values.
sub saveClassFromHash {
  my ($name, %values) = @_;
  my $class = "$name {";

  for my $key (keys(%values)) {
    # Filter out anything not set to a true values
    if($values{$key}) {
      $class .= " $key";
    }
  }
  $class .= " }";

  checkedSyscall("$bigpipe class $class");
}

# Loads an iRule from a file
#
# loadRuleFromFile(name, file)
#   name - The name to use for the rule
#   file - The name of the file to load the rule from
sub loadRuleFromFile {
  my ($rulename, $filename) = @_;
  open (RULE, $filename) or die "Can't open file $filename";
  my $ruleContents = do { local $/; <RULE> };
  close (RULE);
  $ruleContents = escapeForSyscall($ruleContents);
  checkedSyscall("$bigpipe rule $rulename \"{ $ruleContents }\"");
}

sub escapeForSyscall {
  my ($escaped) = @_;
  $escaped =~ s/\\/\\\\/g;
  $escaped =~ s/"/\\"/g;
  $escaped =~ s/'/\\'/g;
  $escaped =~ s/\$/\\\$/g;
  return $escaped;
}

1;
