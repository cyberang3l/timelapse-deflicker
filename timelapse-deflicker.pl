#!/usr/bin/perl

# Script for simple and fast photo deflickering using imagemagick library
# Copyright Vangelis Tasoulas (cyberang3l@gmail.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Needed packages
use Getopt::Std;
use strict "vars";
use feature "say";
use Image::Magick;
use Data::Dumper;
use File::Type;
use Term::ProgressBar;

#use File::Spec;

# Global variables
my $VERBOSE       = 0;
my $DEBUG         = 0;
my $RollingWindow = 15;
my $Passes        = 1;

#####################
# handle flags and arguments
# Example: c == "-c", c: == "-c argument"
my $opt_string = 'hvdw:p:';
getopts( "$opt_string", \my %opt ) or usage() and exit 1;

# print help message if -h is invoked
if ( $opt{'h'} ) {
  usage();
  exit 0;
}

$VERBOSE       = 1         if $opt{'v'};
$DEBUG         = 1         if $opt{'d'};
$RollingWindow = $opt{'w'} if defined( $opt{'w'} );
$Passes        = $opt{'p'} if defined( $opt{'p'} );

die "The rolling average window for luminance smoothing should be a positive number greater or equal to 2" if ( $RollingWindow < 2 );
die "The number of passes should be a positive number greater or equal to 1"                               if ( $Passes < 1 );

# main program content
my %luminance;

my $data_dir = ".";

opendir( DATA_DIR, $data_dir ) || die "Cannot open $data_dir\n";
my @files = readdir(DATA_DIR);
@files = sort @files;

my $count = 0;

if ( scalar @files != 0 ) {

  say "Original luminance of Images is being calculated";
  say "Please be patient as this might take several minutes...";

  foreach my $filename (@files) {

    my $ft   = File::Type->new();
    my $type = $ft->mime_type($filename);

    #say "$data_dir/$filename";
    my ( $filetype, $fileformat ) = split( /\//, $type );
    if ( $filetype eq "image" ) {
      verbose("Original luminance of Image $filename is being processed...\n");

      my $image = Image::Magick->new;
      $image->Read($filename);
      my @statistics = $image->Statistics();
      my $R          = @statistics[ ( 0 * 7 ) + 3 ];
      my $G          = @statistics[ ( 1 * 7 ) + 3 ];
      my $B          = @statistics[ ( 2 * 7 ) + 3 ];

      $luminance{$count}{original} = 0.299 * $R + 0.587 * $G + 0.114 * $B;

      #$luminance{$count}{original} = 0.2126 * $R + 0.7152 * $G + 0.0722 * $B;
      $luminance{$count}{value}    = $luminance{$count}{original};
      $luminance{$count}{filename} = $filename;

      #$luminance{$count}{abs_path_filename} = File::Spec->rel2abs($filename);
      $count++;
    }

  }

}

my $max_entries = scalar( keys %luminance );

say "$max_entries images found in the folder which will be processed further.";

my $CurrentPass = 1;

while ( $CurrentPass <= $Passes ) {
  say "\n-------------- LUMINANCE SMOOTHING PASS $CurrentPass/$Passes --------------\n";
  luminance_calculation();
  $CurrentPass++;
}

say "\n\n-------------- CHANGING OF BRIGHTNESS WITH THE CALCULATED VALUES --------------\n";
luminance_change();

say "\n\nJob completed";
say "$max_entries files have been processed";

#####################
# Helper routines

sub luminance_calculation {
  my $max_entries = scalar( keys %luminance );
  my $progress    = Term::ProgressBar->new( { count => $max_entries } );
  my $low_window  = int( $RollingWindow / 2 );
  my $high_window = $RollingWindow - $low_window;

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    my $sample_avg_count = 0;
    my $avg_lumi         = 0;
    for ( my $j = ( $i - $low_window ); $j < ( $i + $high_window ); $j++ ) {
      if ( $j >= 0 and $j < $max_entries ) {
        $sample_avg_count++;
        $avg_lumi += $luminance{$j}{value};
      }
    }
    $luminance{$i}{value} = $avg_lumi / $sample_avg_count;

    $progress->update( $i + 1 );
  }
}

sub luminance_change {
  my $max_entries = scalar( keys %luminance );
  my $progress = Term::ProgressBar->new( { count => $max_entries } );

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    debug("Original luminance of $luminance{$i}{filename}: $luminance{$i}{original}\n");
    debug(" Changed luminance of $luminance{$i}{filename}: $luminance{$i}{value}\n");

    my $brightness = ( 1 / ( $luminance{$i}{original} / $luminance{$i}{value} ) ) * 100;

    #my $gamma = 1 / ( $luminance{$i}{original} / $luminance{$i}{value} );

    debug("Imagemagick will set brightness of $luminance{$i}{filename} to: $brightness\n");

    #debug("Imagemagick will set gamma value of $luminance{$i}{filename} to: $gamma\n");

    if ( !-d "Deflickered" ) {
      mkdir("Deflickered") || die "Error creating directory: $!\n";
    }

    debug("Changing brightness of $luminance{$i}{filename} and saving to the destination directory...\n");
    my $image = Image::Magick->new;
    $image->Read( $luminance{$i}{filename} );

    $image->Mogrify( 'modulate', brightness => $brightness );

    #$image->Gamma( gamma => $gamma, channel => 'All' );
    $image->Write( "Deflickered/" . $luminance{$i}{filename} );

    $progress->update( $i + 1 );
  }
}

sub usage {

  # prints the correct use of this script
  say "Usage:";
  say "-w    Choose the rolling average window for luminance smoothing (Default 15)";
  say "-p    Number of luminance smoothing passes (Default 1)";
  say "       Sometimes 2 passes might give better results.";
  say "       Usually you would not want a number higher than 2.";
  say "-h    Usage";
  say "-v    Verbose";
  say "-d    Debug";
}

sub verbose {
  print $_[0] if ($VERBOSE);
}

sub debug {
  print $_[0] if ($DEBUG);
}
