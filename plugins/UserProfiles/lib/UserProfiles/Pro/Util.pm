package UserProfiles::Pro::Util;

use strict;
use base 'Exporter';

use MT::Util qw( dirify );

our @EXPORT_OK = qw( import_images );

sub import_images {
	my ($author) = @_;
	return if $author->userpic_asset_id;

	my $image;
	$image = get_gravatar_image($author->email) if $author->email;
	if (!$image && ($author->auth_type eq 'Vox' or $author->auth_type eq 'LiveJournal')) {
		$image = get_foaf_image($author);
	}
	if (!$image) {
		$image = get_blogcatalog_image($author);
	}
	if (!$image) {
		$image = get_mybloglog_image($author);
	}
	if ($image) {
		# now write image to disk
#		my $plugin = MT->component('userprofiles');
#		my $config = $plugin->get_config_hash('system');
#		my $blog_id = $config->{profile_blog_id};
#		if ($blog_id) {
#			my $blog = MT->model('blog')->load($blog_id);
#			my $blog_config = $plugin->get_config_hash('blog:'.$blog_id);
			my $filename = dirify($author->nickname) . '-'.$author->id. '.jpg';
			require File::Spec;
			my $path = File::Spec->catdir(MT->instance->static_file_path,'support', 'uploads',$filename);
			my $asset_file = File::Spec->catfile( '%s', 'support', 'uploads',$filename );
		    require File::Basename;
			my $local_basename = File::Basename::basename($path);
        	require MT::FileMgr;
        	my $fmgr = MT::FileMgr->new('Local');
#			my $fmgr = $blog->file_mgr;
			$fmgr->put_data( $image, $path, 'upload' )
				or MT->log("Error importing image: " . $fmgr->errstr);	
			MT->log($image);
			eval { require Image::Size; };
			return if $@;
			my ( $w, $h, $id ) = Image::Size::imgsize(\$image);

			# create asset
			use MT::Asset;
			my $asset = MT::Asset::Image->new;
   			$asset->file_path($asset_file);
   			$asset->file_name($local_basename);
   			$asset->url($asset_file);
   			$asset->file_ext('jpg');
   			$asset->blog_id(0);
		    $asset->image_width($w);
	        $asset->image_height($h);
	  	    $asset->mime_type('image/jpeg');
			$asset->created_by($author->id);
			$asset->tags('@userpic');
			$asset->save
				or MT->log("Error creating asset: " . $asset->errstr);

			# add asset to profile
			$author->userpic_asset_id($asset->id)
				or MT->log("Error adding asset to author: " . $author->errstr);
			$author->save;
#		}
	}
}

sub get_gravatar_image {
	my ($email) = @_;
	my $app = MT->instance;
	use Digest::MD5 qw(md5_hex);
#	my $url = "http://www.gravatar.com/avatar.php?gravatar_id=".md5_hex($email)."&amp;default=http%3A%2F%2Fnoneplease";
	my $url = "http://www.gravatar.com/avatar/".md5_hex($email)."?default=http%3A%2F%2Fnoneplease";
    my $ua = $app->new_ua( { timeout => 20 } );
   	return 0 unless $ua;
    my $req = new HTTP::Request( GET => $url );
   	my $resp = $ua->request($req);
   	my $result = $resp->content();
	return $result;
}

sub get_foaf_image {
	my ($author) = @_;
	eval { require XML::Parser; };
   	return if ($@);
	my $url = $author->url;
	my $app = MT->instance;
	my $path;
	if ($author->auth_type eq 'Vox') {
		$url .= "profile/foaf.rdf";
		$path = '/RDF:RDF/Person/img';
	} elsif ($author->auth_type eq 'LiveJournal') {
		$url .= "data/foaf";
		$path = '/RDF:RDF/foaf:Person/foaf:img';
	} else {
		$url = get_foaf_url();
		$path = '/RDF:RDF/foaf:Person/foaf:img';
	}
	return if !$url;
    my $ua = $app->new_ua( { timeout => 20 } );
   	return 0 unless $ua;
    my $req = new HTTP::Request( GET => $url );
   	my $resp = $ua->request($req);
    if($resp->is_success) {
	    my $image_url;
		require XML::XPath;
        my $xml = XML::XPath->new( xml => $resp->content );
        $xml->set_namespace('RDF', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
        $xml->set_namespace('FOAF', 'http://xmlns.com/foaf/0.1/');
		my $img_el;
		eval { ($img_el) = $xml->findnodes($path); };
		return if $@;
        if($img_el) {
    	    $image_url = $img_el->getAttribute('rdf:resource');
        }
        $xml->cleanup;
		if ($image_url) {
    		my $ua = $app->new_ua( { timeout => 20 } );
   			return 0 unless $ua;
    		my $req = new HTTP::Request( GET => $image_url );
   			my $resp = $ua->request($req);
   			my $result = $resp->content();
			return $result;
		}
	}
}

sub get_mybloglog_image {
	my ($author) = @_;
	return if (!$author->url && !$author->email);
	my $app = MT->instance;
	use URI::Escape;
	my $url = "http://pub.mybloglog.com/coiserv.php?href=";
	if ($author->url) {
		$url .= uri_escape($author->url);
	} else {
		$url .= uri_escape('mailto:'.$author->email);
	}
    my $ua = $app->new_ua( { timeout => 20 } );
   	return 0 unless $ua;
    my $req = new HTTP::Request( GET => $url );
   	my $resp = $ua->request($req);
   	my $result = $resp->content();
	if ($result) {
		eval { require Image::Size; };
		return if $@;
		my ( $w, $h, $id ) = Image::Size::imgsize(\$result);
		return if ($w == 18 || $h == 18);
	}
	return $result;
}

sub get_blogcatalog_image {
	my ($author) = @_;
	eval { require XML::Parser; };
   	return if ($@);
	return if (!$author->url);
	my $app = MT->instance;
	use URI::Escape;
	my $url = "http://api.blogcatalog.com/bloginfo?bcwsid=x8DzWJ1PaK&url=";
	$url .= uri_escape($author->url);

    my $ua = $app->new_ua( { timeout => 20 } );
   	return 0 unless $ua;
    my $req = new HTTP::Request( GET => $url );
   	my $resp = $ua->request($req);
   	my $result = $resp->content();

    if($result) {
		require XML::XPath;
        my $xml = XML::XPath->new( xml => $result ) 
			or return;
        $xml->set_namespace('BCAPI', 'http://api.blogcatalog.com/dtd/bcapi-001.xml');
		my $path = "/bcapi/result/weblog/user";
		my $image_url;
		my $username;
		eval { ($username) = $xml->findnodes($path); };
		return if $@;
        if ($username) {
			$username = $username->string_value;
			use Data::Dumper;
			$xml->cleanup;
			$url = "http://api.blogcatalog.com/getinfo?bcwsid=x8DzWJ1PaK&username=".$username;
    		$req = new HTTP::Request( GET => $url );
   			$resp = $ua->request($req);
			if ($resp->is_success) {
				$xml = XML::XPath->new( xml => $resp->content() );
				$path = "/bcapi/result/avatar";
        		eval { $image_url = $xml->findnodes($path); };
				return if $@;
				$image_url = $image_url->string_value;
			}
        }
        $xml->cleanup;
		if ($image_url && $image_url !~ m/default\.gif$/) {
    		my $ua = $app->new_ua( { timeout => 20 } );
   			return 0 unless $ua;
    		my $req = new HTTP::Request( GET => $image_url );
   			my $resp = $ua->request($req);
   			my $result = $resp->content();
			return $result;
		}
	}
}

sub get_foaf_url {
	# TODO
}