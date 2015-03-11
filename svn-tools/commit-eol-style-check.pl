#!/usr/bin/env perl

# ====================================================================
# commit-eol-style-check.pl: check that every added file with a specific
# file name extension has the svn:eol-style property set. If any
# file fails this test the user is sent a verbose error message
# suggesting solutions and the commit is aborted.
#
# Usage: commit-eol-style-check.pl REPOS TXN-NAME
# ====================================================================
# Copyright (c) 2007 Thomas Bluemel.  All rights reserved.
# Copyright (c) 2014 Colin Finck.  All rights reserved.
#
# - Based on commit-mime-type-check.pl, r1644863
#   https://svn.apache.org/repos/asf/subversion/trunk/contrib/hook-scripts/check-mime-type.pl
# - Patched with check-mime-type-2.patch from
#   http://mail-archives.apache.org/mod_mbox/subversion-dev/201403.mbox/%3C1576503.m6XB7udPXQ@hurry.speechfxinc.com%3E
#   to support Subversion 1.8.x
#
# ====================================================================
# Most of commit-mime-type-check.pl was taken from
# commit-access-control.pl, Revision 9986, 2004-06-14 16:29:22 -0400.
# ====================================================================
# Copyright (c) 2000-2004 CollabNet.  All rights reserved.
#
# This software is licensed as described in the file COPYING, which
# you should have received as part of this distribution.  The terms
# are also available at http://subversion.tigris.org/license.html.
# If newer versions of this license are posted there, you may use a
# newer version instead, at your option.
#
# This software consists of voluntary contributions made by many
# individuals.  For exact contribution history, see the revision
# history and logs, available at http://subversion.tigris.org/.
# ====================================================================

# Turn on warnings the best way depending on the Perl version.
BEGIN {
  if ( $] >= 5.006_000)
    { require warnings; import warnings; }
  else
    { $^W = 1; }
}

use strict;
use Carp;

######################################################################
# Configuration section.

# Svnlook path.
my $svnlook = "/usr/bin/svnlook";

# Since the path to svnlook depends upon the local installation
# preferences, check that the required program exists to insure that
# the administrator has set up the script properly.
{
  my $ok = 1;
  foreach my $program ($svnlook)
    {
      if (-e $program)
        {
          unless (-x $program)
            {
              warn "$0: required program `$program' is not executable, ",
                   "edit $0.\n";
              $ok = 0;
            }
        }
      else
        {
          warn "$0: required program `$program' does not exist, edit $0.\n";
          $ok = 0;
        }
    }
  exit 1 unless $ok;
}

######################################################################
# Initial setup/command-line handling.

&usage unless @ARGV == 2;

my $repos        = shift;
my $txn          = shift;
my $err_msg = "$0: repository directory `$repos' ";

&usage("$err_msg does not exist.") unless (-e $repos);
&usage("$err_msg is not a directory.") unless (-d $repos);

######################################################################
# Harvest data using svnlook.

# Figure out what files have added/modified properties using svnlook.
my @paths_to_check;
my $props_changed_re = qr/^(?:A |[U_ ]U)  (.*[^\/])$/;
foreach my $line (&read_from_process($svnlook, 'changed', $repos, '-t', $txn)) {
    if ($line =~ /$props_changed_re/) {
        push(@paths_to_check, $1);
    }
}

my @errors;

# We are using 'svnlook propget' here instead of 'svnlook proplist'
# because the output of 'svnlook proplist' without --xml could be ambiguous
# with multiline properties.
my @properties = ('svn:mime-type', 'svn:eol-style');
my $mime_text_re = qr/^text\//;
my $mime_application_re = qr/^application\//;
my $proplist_name_re = qr/^  (.*)$/;
my $properties_pat = '(?:' . join('|', map {quotemeta} @properties) . ')'; 
my $grep_re = qr/^$properties_pat$/;

foreach my $path ( @paths_to_check ) {

    my %prop_map = ();

    # See what properties we do have
    my @path_props = &read_from_process($svnlook, 'proplist', $repos, '-t', $txn, '--', $path);

    # filter out only the ones we care about
    my @filtered = grep {/$grep_re/} map { $_ =~ s/$proplist_name_re/$1/; $_; } @path_props;

    # Grab filtered properties
    foreach my $prop (@filtered) {
        $prop_map{$prop} = join("\n", &read_from_process($svnlook, 'propget', $repos,
                                                         $prop, '-t', $txn, '--', $path));
    }
    
    # Detect error conditions and add them to @errors
    if (not $prop_map{$properties[1]})
    {
        if ($prop_map{$properties[0]} and $prop_map{$properties[0]} =~ /$mime_text_re/)
        {
            push @errors, "$path : svn:mime-type indicates a text file but svn:eol-style is not set";
        }
        else
        {
            if ($path =~ /\.(c|cpp|cxx|h|hpp|hxx|rc|in|spec|mak|jam|s|asm|ini|txt|patch|bat|cmd|sh|pl|py|def|rbuild|xml|html|css|manifest|dsp|dsw|sln|vcproj)$/i)
            {
                if (not ($prop_map{$properties[0]} and $prop_map{$properties[0]} =~ /$mime_application_re/))
                {
                    push @errors, "$path : svn:eol-style is not set";
                }
            }
        }
    }
}

# If there are any errors list the problem files and give information
# on how to avoid the problem. Hopefully people will set up auto-props
# and will not see this verbose message more than once.
if (@errors)
  {
    warn "$0:\n\n",
         join("\n", @errors), "\n\n",
         <<EOS;
    Every added file that has the svn:mime-type property set to text
    must also have a svn:eol-style property set. All other files with
    a certain file extension that typically indicates a text file
    must have at least the svn:eol-style property set. To overcome this
    requirement, set the svn:mime-type to application/octet-stream.

    For text files try
    svn propset svn:mime-type text/plain path/of/file
    svn propset svn:eol-style native path/of/file

    You may want to consider uncommenting the auto-props section
    in your ~/.subversion/config file. Read the Subversion book
    (http://svnbook.red-bean.com/), Chapter 7, Properties section,
    Automatic Property Setting subsection for more help.
EOS
    exit 1;
  }
else
  {
    exit 0;
  }

sub usage
{
  warn "@_\n" if @_;
  die "usage: $0 REPOS TXN-NAME\n";
}

sub safe_read_from_pipe
{
  unless (@_)
    {
      croak "$0: safe_read_from_pipe passed no arguments.\n";
    }
  print "Running @_\n";
  my $pid = open(SAFE_READ, '-|', @_);
  unless (defined $pid)
    {
      die "$0: cannot fork: $!\n";
    }
  unless ($pid)
    {
      open(STDERR, ">&STDOUT")
        or die "$0: cannot dup STDOUT: $!\n";
      exec(@_)
        or die "$0: cannot exec `@_': $!\n";
    }
  my @output;
  while (<SAFE_READ>)
    {
      chomp;
      push(@output, $_);
    }
  close(SAFE_READ);
  my $result = $?;
  my $exit   = $result >> 8;
  my $signal = $result & 127;
  my $cd     = $result & 128 ? "with core dump" : "";
  if ($signal or $cd)
    {
      warn "$0: pipe from `@_' failed $cd: exit=$exit signal=$signal\n";
    }
  if (wantarray)
    {
      return ($result, @output);
    }
  else
    {
      return $result;
    }
}

sub read_from_process
  {
  unless (@_)
    {
      croak "$0: read_from_process passed no arguments.\n";
    }
  my ($status, @output) = &safe_read_from_pipe(@_);
  if ($status)
    {
      if (@output)
        {
          die "$0: `@_' failed with this output:\n", join("\n", @output), "\n";
        }
      else
        {
          die "$0: `@_' failed with no output.\n";
        }
    }
  else
    {
      return @output;
    }
}
