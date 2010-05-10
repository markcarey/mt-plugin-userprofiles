package UserProfiles::Pro::Publisher;
use strict;
use base 'Exporter';

our @EXPORT_OK = qw( profile_archive_file );
use MT::Util qw( dirify );

sub rebuild_user_profile {
	my $app = MT->instance;
    my %param = @_;
	my $author = $param{Author} or return;
	my $blog;
    unless ( $blog = $param{Blog} ) {
        my $blog_id = $param{BlogID};
        $blog = MT::Blog->load($blog_id)
          or return MT->log(
            MT->translate(
                "Rebuild User Profile Error: Load of blog '[_1]' failed: [_2]", $blog_id,
                MT::Blog->errstr
            )
          );
    }
	return if !$blog;

	# get file name and path
	my $file = profile_archive_file($author,$blog);
    my $site_root = $blog->site_path;
	require File::Spec;
	$file = File::Spec->catfile( $site_root, $file );

	# get User Profile template
	my $tmpl;
	unless ($tmpl = $param{Template}) {
	    my $cached_tmpl = MT->instance->request('__cached_templates')
    	  || MT->instance->request( '__cached_templates', {} );
		my $cache_key = 'user_profile_' . $blog->id;
    	$tmpl = $cached_tmpl->{$cache_key};
    	unless ($tmpl) {
        	$tmpl = MT->model('template')->load({ name => 'User Profile', blog_id => $blog->id });
        	if ($cached_tmpl) {
            	$cached_tmpl->{$cache_key} = $tmpl;
        	}
    	}
	}

	# set up context
	my $ctx = $tmpl->context;
	$ctx->var( 'author_name', $author->name );
    $ctx->{__stash}{author} = $author;
    $ctx->{__stash}{blog} = $blog;
    $ctx->{__stash}{blog_id} = $blog->id;

	# build the file
	my $html = $tmpl->build( $ctx, undef);
    my $fmgr = $blog->file_mgr;
	use File::Basename;
    my $path = dirname($file);
    $path =~ s!/$!!
		unless $path eq '/'; ## OS X doesn't like / at the end in mkdir().
    unless ( $fmgr->exists($path) ) {
    	$fmgr->mkpath($path)
        	or return $app->trans_error( "Error making path '[_1]': [_2]",
                    $path, $fmgr->errstr );
    }
    my $use_temp_files = !$app->{NoTempFiles};
    my $temp_file = $use_temp_files ? "$file.new" : $file;
    defined( $fmgr->put_data( $html, $temp_file ) )
    	or return $app->trans_error( "Writing to '[_1]' failed: [_2]",
        $temp_file, $fmgr->errstr );
    if ($use_temp_files) {
    	$fmgr->rename( $temp_file, $file )
        	or return $app->trans_error(
                    "Renaming tempfile '[_1]' failed: [_2]",
                    $temp_file, $fmgr->errstr );
    }
	1;
}

sub rebuild_all_user_profiles {
	my ($blog_id, $tmpl) = @_;
	my $start_time = time;
	my $blog = MT->model('blog')->load($blog_id);
	return if !$blog;
	use MT::Author;
	my $iter = MT::Author->load_iter();
	while (my $author = $iter->()) {
		rebuild_user_profile(Author => $author, Blog => $blog, Template => $tmpl);
	}
	my $total_time = time - $start_time;
	MT->log('User Profiles have been rebuilt ('.$total_time.' seconds)');
	
}

sub profile_archive_file {
	my ($author,$blog) = @_;
	return if !$blog;
	my $file_tmpl = "profile/%s/index";
	my $name;
	if ($author->auth_type eq 'MT') {
		$name = $author->name;
	} else {
    	$name = dirify($author->nickname).'_'.$author->id;
	}
    $name = "author" . $author->id if $name !~ /\w/;
    my $file = sprintf( $file_tmpl, $name );
	my $ext = $blog->file_extension;
    $file .= '.' . $ext if $ext;
}


1;