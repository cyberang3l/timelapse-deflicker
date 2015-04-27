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
use Image::ExifTool qw(:Public);

#use File::Spec;

# Global variables
my $VERBOSE       = 0;
my $DEBUG         = 0;
my $RollingWindow = 15;
my $Passes        = 1;

#Define namespace and tag for luminance, to be used in the XMP files.
%Image::ExifTool::UserDefined::luminance = (
    GROUPS => { 0 => 'XMP', 1 => 'XMP-luminance', 2 => 'Image' },
    NAMESPACE => { 'luminance' => 'https://github.com/cyberang3l/timelapse-deflicker' }, #Sort of semi stable reference?
    WRITABLE => 'string',
    luminance => {}
);

%Image::ExifTool::UserDefined = (
    # new XMP namespaces (ie. XMP-xxx) must be added to the Main XMP table:
    'Image::ExifTool::XMP::Main' => {
        luminance => {
            SubDirectory => {
                TagTable => 'Image::ExifTool::UserDefined::luminance'
            },
        },
    }
);

#####################
# handle flags and arguments
# h is "help" (no arguments)
# v is "verbose" (no arguments)
# d is "debug" (no arguments)
# w is "rolling window size" (single numeric argument)
# p is "passes" (single numeric argument)
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

#This integer test fails on "+n", but that isn't serious here.
die "The rolling average window for luminance smoothing should be a positive number greater or equal to 2" if ! ($RollingWindow eq int( $RollingWindow ) && $RollingWindow > 1 ) ;
die "The number of passes should be a positive number greater or equal to 1"                               if ! ($Passes eq int( $Passes ) && $Passes > 0 ) ;

# Create hash to hold luminance values.
# Format will be: TODO: Add this here
my %luminance;

# The working directory is the current directory.
my $data_dir = ".";
opendir( DATA_DIR, $data_dir ) || die "Cannot open $data_dir\n";
#Put list of files in the directory into an array:
my @files = readdir(DATA_DIR);
#Assume that the files are named in dictionary sequence - they will be processed as such.
@files = sort @files;

#Initialize count variable to number files in hash
my $count = 0;

#Initialize a variable to hold the previous image type detected - if this changes, warn user
my $prevfmt = "";

#Process the list of files, putting all image files into the luminance hash.
if ( scalar @files != 0 ) {
  foreach my $filename (@files) {
      my $ft   = File::Type->new();
      my $type = $ft->mime_type($filename);
      my ( $filetype, $fileformat ) = split( /\//, $type );
      #If it's an image file, add it to the luminance hash.
      if ( $filetype eq "image" ) {
        #Check whether we have a new image format - this is probably unwanted, so warn the user.
        if ( $prevfmt eq "" ) { $prevfmt = $fileformat } elsif ( $prevfmt ne "warned" && $prevfmt ne $fileformat ) {
          say "Images of type $prevfmt and $fileformat detected! ARE YOU SURE THIS IS JUST ONE IMAGE SEQUENCE?";
          #no more warnings about this from now on
          $prevfmt = "warned"
        }
        $luminance{$count}{filename} = $filename;
        $count++;
      }
  }
}

my $max_entries = scalar( keys %luminance );

if ( $max_entries < 2 ) { die "Cannot process less than two files.\n" }

say "$max_entries image files to be processed.";
say "Original luminance of Images is being calculated";
#Determine luminance of each file and add to the hash.
luminance_det();

my $CurrentPass = 1;

while ( $CurrentPass <= $Passes ) {
  say "\n-------------- LUMINANCE SMOOTHING PASS $CurrentPass/$Passes --------------\n";
  new_luminance_calculation();
  $CurrentPass++;
}

say "\n\n-------------- CHANGING OF BRIGHTNESS WITH THE CALCULATED VALUES --------------\n";
luminance_change();

say "\n\nJob completed";
say "$max_entries files have been processed";

#####################
# Helper routines

#Determine luminance of each image; add to hash.
sub luminance_det {
  my $progress    = Term::ProgressBar->new( { count => $max_entries } );

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    verbose("Original luminance of Image $luminance{$i}{filename} is being processed...\n");
    
    #Create exifTool object for the image
    my $exifTool = new Image::ExifTool;
    my $exifinfo; #variable to hold info read from xmp file if present.

    #If there's already an xmp file for this filename, read it.
    if (-e $luminance{$i}{filename}.".xmp") { 
      $exifinfo = $exifTool->ImageInfo($luminance{$i}{filename}.".xmp");
      debug("Found xmp file: $luminance{$i}{filename}.xmp\n")
    }
    #Now, if it already has a luminance value, just use that:
    if ( length $$exifinfo{Luminance} ) {
      # Set it as the original and target value to start out with.
      $luminance{$i}{value} = $luminance{$i}{original} = $$exifinfo{Luminance};
      debug("Read luminance $$exifinfo{Luminance} from xmp file: $luminance{$i}{filename}.xmp\n")
    }
    else {
      #Create ImageMagick object for the image
      my $image = Image::Magick->new;
      #Evaluate the image using ImageMagick.
      $image->Read($luminance{$i}{filename});
      my @statistics = $image->Statistics();
      # Use the command "identify -verbose <some image file>" in order to see why $R, $G and $B
      # are read from the following index in the statistics array
      # This is the average R, G and B for the whole image.
      my $R          = @statistics[ ( 0 * 7 ) + 3 ];
      my $G          = @statistics[ ( 1 * 7 ) + 3 ];
      my $B          = @statistics[ ( 2 * 7 ) + 3 ];

      # We use the following formula to get the perceived luminance.
      # Set it as the original and target value to start out with.
      $luminance{$i}{value} = $luminance{$i}{original} = 0.299 * $R + 0.587 * $G + 0.114 * $B;

      #Write luminance info to an xmp file.
      #This is the xmp for the input file, so it contains the original luminance.
      $exifTool->SetNewValue(luminance => $luminance{$i}{original}); 
      #If there is already an xmp file, just update it:
      if (-e $luminance{$i}{filename}.".xmp") { 
        $exifTool->WriteInfo($luminance{$i}{filename} . ".xmp")
      }
      #Otherwise, create a new one:
      else {
        $exifTool->WriteInfo(undef, $luminance{$i}{filename} . ".xmp", 'XMP'); #Write the XMP file
      }
    }
    $progress->update( $i + 1 );
  }
}

sub new_luminance_calculation {
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
  my $progress = Term::ProgressBar->new( { count => $max_entries } );

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    debug("Original luminance of $luminance{$i}{filename}: $luminance{$i}{original}\n");
    debug("Changed luminance of $luminance{$i}{filename}: $luminance{$i}{value}\n");

    my $brightness = ( 1 / ( $luminance{$i}{original} / $luminance{$i}{value} ) ) * 100;

    debug("Imagemagick will set brightness of $luminance{$i}{filename} to: $brightness\n");

    if ( !-d "Deflickered" ) {
      mkdir("Deflickered") || die "Error creating directory: $!\n";
    }
    #TODO: Create directory name with timestamp to avoid overwriting previous work.

    debug("Changing brightness of $luminance{$i}{filename} and saving to the destination directory...\n");
    my $image = Image::Magick->new;
    $image->Read( $luminance{$i}{filename} );

    $image->Mogrify( 'modulate', brightness => $brightness );

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
