package UserProfiles::Upgrade;

use strict;

sub migrate_userpics {
	my ($author) = @_;
	return 1 if $author->userpic_asset_id;

#	return 1 if ($author->id != 999999);				## CHANGE THIS !!!!!!!!!!!!!!!!

	my $asset_id = $author->profile_asset_id;
	return 1 if !$asset_id;

	my $asset = MT->model('asset')->load($asset_id);
	return 1 if !$asset;

	my $ext = $asset->file_ext;
	my $from_filepath = $asset->file_path;

	if (!stat($from_filepath)) {
		MT->log("Error migrating userpic for author_id " . $author->id . ". No file found at $from_filepath");
		return 1;
	}

	use File::Basename;
	my $basename = basename($from_filepath);
	my $rel = '/support/uploads/' . $basename;
	my $staticpath = MT->instance->static_file_path;
	my $to_filepath = $staticpath . $rel;
#	MT->log("from is $from_filepath and to is $to_filepath");

	my $suffix = 1;
	while (stat($to_filepath)) {
		$rel =~ s!(_[0-9]+)?(\.$ext)$!_$suffix$2!;
		$to_filepath = $staticpath . $rel;
		$basename = basename($to_filepath);
#		MT->log("new to path is $to_filepath");
		$suffix++;
	}

	use File::Copy;
	copy($from_filepath,$to_filepath)
		or die "Userpic migration failed. Please make sure the /mt-static/support/uploads/ directory is writable (CHMOD 777). Error: $!";

	$asset->blog_id(0);
	$asset->created_by($author->id);
	$asset->file_name($basename);
	$asset->file_path('%s'.$rel);
	$asset->url('%s'.$rel);
	$asset->tags('@userpic');
	$asset->save;	

	$author->userpic_asset_id($asset->id);
	$author->profile_asset_id(undef);
	$author->save;

}

1;
