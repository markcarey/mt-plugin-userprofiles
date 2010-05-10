package UserProfiles::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( crop_to_square );

sub crop_to_square {
	my ($asset) = @_;
    my $width  = $asset->image_width;
    my $height = $asset->image_height;
	if ($width == $height) { return $asset; }
	my $x = 0;
	my $y = 0;
	if ($width > $height) { 
		$x = int(($width - $height )/2);
		$width = $height;
	} else { 
		$y = int(($height - $width )/2);
		$height = $width;
	}
	require MT::Image;
   	my $img = new MT::Image( Filename => $asset->file_path )
          or MT->log(MT::Image->errstr);
	my $magick = $img->{magick};
	my $geometry = $width ."x". $height ."+". $x ."+". $y;
	$magick->Crop(geometry => $geometry);
     require MT::FileMgr;
     my $fmgr = MT::FileMgr->new('Local');
	$fmgr->put_data( $magick->ImageToBlob, $asset->file_path, 'upload' )
      		or MT->log("Error creating thumbnail file: " . $fmgr->errstr);
    $asset->image_width($width);
    $asset->image_height($height);
	$asset->save;
	return $asset;
}

1;