#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

use constant COLINFOVERSION => '0.7';

# Todd Wylie
# Wed Oct 13 12:11:05 CDT 2010

# -----------------------------------------------------------------------------
# PURPOSE:
# Given a single line of information, delimited by a pre-determined character
# string, this program will print a report of the line fields with corresponding
# field ID; essentially, provides better readability of fields-to-ids.
# -----------------------------------------------------------------------------

# ** NOTE **
# Command line options treated as global variables.
my (
    $base_opt,
    $delimiter_opt,
    $wildcard_opt,
    $verbose_opt,
    $length_opt,
    $column_opt,
    $help_opt,
    $key_opt,
    $version_opt,
   );

GetOptions(
           "base=s"      => \$base_opt,
           "delimiter=s" => \$delimiter_opt,
           "wildcard=s"  => \$wildcard_opt,
           "verbose"     => \$verbose_opt,
           "length"      => \$length_opt,
           "key=s"       => \$key_opt,
           "column"      => \$column_opt,
           "help"        => \$help_opt,
           "version"     => \$version_opt,
          );

# *****************************************************************************
# MAIN LOGIC
# *****************************************************************************
if ($help_opt) {
    usage_statement();
}
elsif ($version_opt) {
    version_statement();
}
else {
    my $line = collect_line_input();
    report_colinfo( $line );
}
# *****************************************************************************


sub usage_statement {
print <<"EOF";

colinfo -------------------------------------------------------------

 USAGE:  head -1 <file> | colinfo --base [zero|one]
         --delimiter [comma|tab|space|pipe|wildcard|allchar]
         --length --verbose (--wildcard <string>) --key <file>

  --base       Starting base of ID iterations for fields. [zero|one]
  --delimiter  Delimits fields. [comma|tab|space|pipe|wildcard|allchar]
  --wildcard   Pass custom string; requires "wildcard" delimiter type.
  --length     Show length of each field. [OPTIONAL]
  --column     Override to display only column info. [OPTIONAL]
  --verbose    Ancillary information displayed with column info. [OPTIONAL]
  --key        Match a single-column key file with results. [OPTIONAL]
  --help       View option info.
  --version    Display colinfo version.

 default: colinfo --base=ONE --delimiter=TAB

---------------------------------------------------------------------

EOF
    exit;
}

sub version_statement {
    print "\n**colinfo** version " . COLINFOVERSION . "\n";
    print "Todd Wylie  <twylie\@genome.wustl.edu>\n\n";
    exit;
}


sub collect_line_input {
    # Test for STDIN passing.
    if ( -t STDIN and not @ARGV ) {
        print "\nERROR\n** No STDIN line information passed **\n\n";
        usage_statement();
    }
    else {
        # Strip off the end-of-line line return; also, if multiple lines were
        # inadvertently passed, use just the first line.
        my $first_line = <STDIN>;
        my @lines = split (/\n/, $first_line);
        my $line  = $lines[0];
        chomp $line;
        return $line;
    }
}


sub report_colinfo {
    my $line = shift;

    # Eval of incoming delimiter.
    if ($delimiter_opt) {
        if (
            $delimiter_opt !~ /tab/i      &&
            $delimiter_opt !~ /comma/i    &&
            $delimiter_opt !~ /pipe/i     &&
            $delimiter_opt !~ /space/i    &&
            $delimiter_opt !~ /wildcard/i &&
            $delimiter_opt !~ /length/i   &&
            $delimiter_opt !~ /allchar/i
           ) {
            print "\nERROR\n** Invalid delimiter type: $delimiter_opt **\n\n";
            usage_statement();
        }
    }

    # Set defaults.
    my $delimiter = $delimiter_opt ? $delimiter_opt : 'tab';
    my $base      = $base_opt      ? $base_opt      : 'one';

    # Set delimiters.
    my $delimiter_char;
    if ($delimiter =~ /tab/i) {
        $delimiter_char = '\t';
    }
    elsif ($delimiter =~ /comma/i) {
        $delimiter_char = ',';
    }
    elsif ($delimiter =~ /pipe/i) {
        $delimiter_char = '\|';
    }
    elsif ($delimiter =~ /space/i) {
        $delimiter_char = '\s+';
    }
    elsif ($delimiter =~ /wildcard/i) {
        if (!$wildcard_opt) {
            print "\nERROR\n** Wildcard delimiter type requires --wildcard string. **\n\n";
            usage_statement();
        }
        $delimiter_char = $wildcard_opt;
    }
    elsif ($delimiter =~ /allchar/i) {
        $delimiter_char = '<ALL CHARACTERS>';
    }

    # Set base.
    my $base_num;
    if ($base =~ /one/i) {
        $base_num = 1;
    }
    elsif ($base =~ /zero/i) {
        $base_num = 0;
    }

    # Reporting: Split fields and iterate.
    my @fields;
    unless ($delimiter_char eq '<ALL CHARACTERS>') {
        @fields = split (/$delimiter_char/, $line);
    }
    else {
        @fields = split ('', $line);
    }
    my $number_of_fields = scalar( @fields );

    # If key exists, then read the file and check the format.
    my @key_fields = ();
    if ($key_opt) {
        open (KEY, "$key_opt") or die 'could not open KEY file';
        while (<KEY>) {
            chomp;
            next if ($_ =~ /^\s*$/);
            push (@key_fields, $_);
        }
        close (KEY);

        my $number_of_keys = scalar( @key_fields );

        # Bail out if key and fields are disparate in length.
        if ($number_of_keys != $number_of_fields) {
            print "\nERROR\n** Number of keys and fields does not match! **\n\n";
            usage_statement();
        }
    }

    # Check for LENGTH inclusion. Check for COLUMN switch... overrides
    # everything else the user has requested.
    my $length_eval = ($length_opt) ? 'TRUE' : 'FALSE';
    my $column_eval = ($column_opt) ? 'TRUE' : 'FALSE';

    my $col_i  = ($base_num - 1);
    if ($verbose_opt) {
        verbose_printing(
                         \@fields,
                         $col_i,
                         $base,
                         $delimiter_char,
                         $delimiter,
                         $length_eval,
                         $column_eval,
                         \@key_fields,
                        );
    }
    else {
        non_verbose_printing(
                             \@fields,
                             $col_i,
                             $base,
                             $delimiter_char,
                             $delimiter,
                             $length_eval,
                             $column_eval,
                             \@key_fields,
                            );
    }

    return;
}


sub verbose_printing {
    my (
        $fields_aref,
        $col_i, $base,
        $delimiter_char,
        $delimiter,
        $length_eval,
        $column_eval,
        $key_fields_aref,
       ) = @_;

    # Split fields and iterate.
    unless ($column_eval eq 'TRUE') {
        # HEADER
        print "\n";
        print "KEY       : $key_opt\n" if ($key_opt);
        print "DELIMITER : $delimiter /$delimiter_char/\n";
        print "BASE      : $base\n\n";
        if ($length_eval eq 'TRUE') {
            unless (@{ $key_fields_aref } > 0) {
                print join (" | ", 'CHAR LENGTH', 'FIELD ID', 'VALUE') . "\n";
            }
            else {
                print join (" | ", 'CHAR LENGTH', 'FIELD ID', 'KEY', 'VALUE') . "\n";
            }
        }
        else {
            unless (@{ $key_fields_aref } > 0) {
                print join (" | ", 'FIELD ID', 'VALUE') . "\n";
            }
            else {
                print join (" | ", 'FIELD ID', 'KEY', 'VALUE') . "\n";
            }
        }
        print '-' x 77 . "\n";

        # BODY
        foreach my $field (@{ $fields_aref }) {
            $col_i++;
            if ($length_eval eq 'TRUE') {
                unless (@{ $key_fields_aref } > 0) {
                    print join (
                                "\t",
                                length( $field ),
                                '[' . $col_i . ']',

                                $field,
                               ) . "\n";
                }
                else {
                    print join (
                                "\t",
                                length( $field ),
                                '[' . $col_i . ']',
                                $$key_fields_aref[$col_i - 1],
                                $field,
                               ) . "\n";
                }
            }
            else {
                unless (@{ $key_fields_aref } > 0) {
                    print join (
                                "\t",
                                '[' . $col_i . ']',
                                $field,
                               ) . "\n";
                }
                else {
                    print join (
                                "\t",
                                '[' . $col_i . ']',
                                $$key_fields_aref[$col_i - 1],
                                $field,
                               ) . "\n";
                }
            }
        }
        print '-' x 77 . "\n";
        print "\n";
    }
    else {
        # Overrides everything to just display the column information.
        foreach my $field (@{ $fields_aref }) { print $field . "\n" }
    }

    return;
}


sub non_verbose_printing {
    my (
        $fields_aref,
        $col_i,
        $base,
        $delimiter_char,
        $delimiter,
        $length_eval,
        $column_eval,
        $key_fields_aref,
       ) = @_;

    # Split fields and iterate.
    unless ($column_eval eq 'TRUE') {
        foreach my $field (@{ $fields_aref }) {
            $col_i++;
            if ($length_eval eq 'TRUE') {
                unless (@{ $key_fields_aref } > 0) {
                    print join (
                                "\t",
                                length( $field ),
                                $col_i,
                                $field,
                               ) . "\n";
                }
                else {
                    print join (
                                "\t",
                                length( $field ),
                                $col_i,
                                $$key_fields_aref[$col_i - 1],
                                $field,
                               ) . "\n";
                }
            }
            else {
                unless (@{ $key_fields_aref } > 0) {
                    print join (
                                "\t",
                                $col_i,
                                $field,
                               ) . "\n";
                }
                else {
                    print join (
                                "\t",
                                $col_i,
                                $$key_fields_aref[$col_i - 1],
                                $field,
                               ) . "\n";
                }
            }
        }
    }
    else {
        # Overrides everything to just display the column information.
        foreach my $field (@{ $fields_aref }) { print $field . "\n" }
    }

    return;
}

__END__
