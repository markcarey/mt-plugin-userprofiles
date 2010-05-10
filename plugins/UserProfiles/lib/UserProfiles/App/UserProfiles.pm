package UserProfiles::App::UserProfiles;
use strict;

use base qw( MT::App::Comments );

use MT::Util
  qw( is_valid_url is_valid_email encode_url dirify decode_url );
use UserProfiles::Util qw( crop_to_square );

use MT::Author;


sub id { 'userprofiles' }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->{default_mode} = 'edit_userprofile';
#    $app->init_commenter_authenticators;
    $app;
}


sub edit_userprofile {
    my $app = shift;

    my $url;
	my $return_args;
    my $entry_id = $app->param('entry_id');
    if ($entry_id) {
        my $entry = MT::Entry->load($entry_id);
        return $app->handle_error( $app->translate("No entry ID provided") )
          unless $entry;
        $url = $entry->permalink;
		$return_args = '&entry_id='.$entry_id;
    }
    else {
        $url = is_valid_url( $app->param('static') );
		$return_args = '&static='.$url;
    }

	my $plugin = MT::Plugin::UserProfiles->instance;
	my $system_config = $plugin->get_config_hash('system');
    my $blog_id = $system_config->{profile_blog_id};
#	my $config = $plugin->get_config_hash('blog:'.$blog_id);
	my $extra_path = $system_config->{profile_upload_path} || '';

    my $commenter = $app->_get_user();
    if ($commenter) {
        return $app->handle_error( $app->translate('Permission denied') )
          unless $commenter->is_active;

        $app->user($commenter);
        my $param = {
            id       => $commenter->id,
			author_id => $commenter->id,
            name     => $commenter->name,
            nickname => $commenter->nickname,
            email    => $commenter->email,
            hint     => $commenter->hint,
            url      => $commenter->url,
			extra_path => $extra_path,
			script_url => $app->uri,
			return_args => $return_args,
            $entry_id ? ( entry_url => $url ) : ( return_url => $url ),
			$app->param('extended_profile') ? (extended_profile => 1) : (edit_profile => 1),
			$app->param('saved') ? (saved => 1) : (),
        };
        $param->{ 'auth_mode_' . lc $commenter->auth_type } = 1;
        require MT::Auth;
        $param->{'email_required'} = MT::Auth->can_recover_password ? 1 : 0;

		require MT::Template;
		my $fields_tmpl = $plugin->load_tmpl('extended_profile_fields.tmpl');
		my $ctx = $fields_tmpl->context;
    	$ctx->{__stash}{author} = $commenter;
		$fields_tmpl->context($ctx);
		my $fields = $fields_tmpl->build;
		$param->{fields} = $fields; 
		
		my $tmpl = MT::Template->load({ blog_id => $blog_id, name => 'Edit User Profile'})
			or return $app->handle_error( $app->translate('Edit User Profile template not found') );
		$tmpl = $app->_set_profile_context($tmpl,$commenter);
		$param->{tmpl_id} = $tmpl->id;
	    return $app->build_page( $tmpl, $param );
#       return $app->build_page( 'profile.tmpl', $param );
    }
    return $app->handle_error( $app->translate('Invalid login') );
}

sub save_userprofile {
    my $app = shift;
    my $q   = $app->param;

    my %param =
      map { $_ => scalar( $q->param($_) ) }
      qw( id name nickname email password pass_verify hint url entry_url return_url external_auth tmpl_id extra_path return_args);

	my $tmpl = MT->model('template')->load($param{tmpl_id});

    unless ( $param{id} =~ /\d+/ ) {
        $param{error} = $app->translate('Invalid commenter ID');
        return $app->build_page( $tmpl, \%param );
    }

    my $cmntr = $app->_get_user();
    $param{ 'auth_mode_' . lc $cmntr->auth_type } = 1;

	$tmpl = $app->_set_profile_context($tmpl,$cmntr);
	$param{tmpl_id} = $tmpl->id;

    unless ($cmntr) {
        $param{error} = $app->translate('Invalid commenter ID');
        return $app->build_page( $tmpl, \%param );
    }

    unless ( $param{external_auth} ) {
        unless ( $param{nickname} && $param{email} && $param{hint} ) {
            $param{error} =
              $app->translate('All required fields must have valid values.');   #TODO: add handling for non-MT users
            return $app->build_page( $tmpl, \%param );
        }
        if ( $param{password} ne $param{pass_verify} ) {
            $param{error} = $app->translate('Passwords do not match.');
            return $app->build_page( $tmpl, \%param );
        }
    }
    if ( $param{email} && !is_valid_email( $param{email} ) ) {
        $param{error} = $app->translate('Email Address is invalid.');
        return $app->build_page( $tmpl, \%param );
    }
    if ( $param{url} && !is_valid_url( $param{url} ) ) {
        $param{error} = $app->translate('URL is invalid.');
        return $app->build_page( $tmpl, \%param );
    }

    my $renew_session =
      $param{nickname} && ( $param{nickname} ne $cmntr->nickname ) ? 1 : 0;
    $cmntr->nickname( $param{nickname} ) if $param{nickname};
    $cmntr->email( $param{email} )       if $param{email};
    $cmntr->hint( $param{hint} )         if $param{hint};
    $cmntr->url( $param{url} )           if $param{url};
    $cmntr->set_password( $param{password} )
      if $param{password} && !$param{external_auth};
    if ( $cmntr->save ) {
        $param{saved} =
          $app->translate('Commenter profile has successfully been updated.');
    }
    else {
        $param{error} =
          $app->translate( 'Commenter profile could not be updated: [_1]',
            $cmntr->errstr );
    }
    if ($renew_session) {
        $app->_make_commenter_session( $app->make_magic_token, $cmntr->email,
            $cmntr->name,
            ($cmntr->nickname || 'User#' . $cmntr->id),
            $cmntr->id );
    }
    my $remember = $q->param('bakecookie') || 0;
    $remember = 0 if $remember eq 'Forget Info';    # another value for '0'
    if ( $cmntr && $remember ) {
        $app->_extend_commenter_session( Duration => "+1y" );
    }
	$param{edit_profile} = 1;
    return $app->build_page( $tmpl, \%param );
}


sub start_image {
    my $app = shift;
	my $blog_id = $app->param('blog_id');
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $extra_path = $config->{profile_upload_path} || '';	
	my $author_id;
	my $tmpl;
	$author_id = $app->param('author_id');
#	$tmpl = $plugin->load_tmpl('upload_profile_image.tmpl');
#	$tmpl = MT->model('template')->load({ blog_id => $blog_id, name => 'Upload Profile Image'})
#			or return $app->handle_error( $app->translate('Edit User Profile template not found') );
	$tmpl = MT->model('template')->load({ blog_id => $blog_id, name => 'Edit User Profile'})
			or return $app->handle_error( $app->translate('Edit User Profile template not found') );
	$tmpl = $app->_set_profile_context($tmpl);
	$app->build_page($tmpl,
		{ 	author_id => $author_id, 
			blog_id => $blog_id,
			extra_path => $extra_path,
			magic_token => $app->current_magic,
			script_url => $app->uri,
			upload_photo => 1,
			return_args => $app->param('return_args'),
		} );
}

sub add_image {
    my $app   = shift;
#    my $perms = $app->permissions
#      or return $app->error( $app->translate("No permissions") );
#    return $app->error( $app->translate("Permission denied.") )
#      unless $perms->can_upload;
	use Symbol;

	my $commenter = $app->_get_user();
    $app->user($commenter);

	if (!$commenter) {
		my $login_link = $app->uri . $app->uri_params(
            'mode' => 'login',
            args   => {
				blog_id => $app->param('blog_id'),
            }
		);
		$login_link .= decode_url($app->param('return_args'));
		$app->redirect($login_link);
	}

    my $q = $app->param;
    my ( $fh, $no_upload );
    if ( $ENV{MOD_PERL} ) {
        my $up = $q->upload('file');
        $no_upload = !$up || !$up->size;
        $fh = $up->fh if $up;
    }
    else {
        ## Older versions of CGI.pm didn't have an 'upload' method.
        eval { $fh = $q->upload('file') };
        if ( $@ && $@ =~ /^Undefined subroutine/ ) {
            $fh = $q->param('file');
        }
        $no_upload = !$fh;
    }
    my $info = $q->uploadInfo($fh);
    my $mimetype;
    if ($info) {
        $mimetype = $info->{'Content-Type'};
    }
    my $has_overwrite = $q->param('overwrite_yes') || $q->param('overwrite_no');
    my %param = (
        blog_id      => $q->param('blog_id'),
        entry_insert => $q->param('entry_insert'),
        middle_path  => $q->param('middle_path'),
        edit_field   => $q->param('edit_field'),
        site_path    => $q->param('site_path'),
        extra_path   => $q->param('extra_path'),
    );
    return $app->start_image( %param,
        error => $app->translate("Please select a file to upload.") )
      if $no_upload && !$has_overwrite;
    my $basename = $q->param('file') || $q->param('fname');
    $basename =~ s!\\!/!g;    ## Change backslashes to forward slashes
    $basename =~ s!^.*/!!;    ## Get rid of full directory paths
    if ( $basename =~ m!\.\.|\0|\|! ) {
        return $app->start_image( %param,
            error => $app->translate( "Invalid filename '[_1]'", $basename ) );
    }

    require File::Basename;
    my $ext =
      ( File::Basename::fileparse( $basename, qr/[A-Za-z0-9]+$/ ) )[2];
	$basename = dirify($commenter->nickname) . '-' . $commenter->id .'.' . $ext;

    my $blog_id = $q->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
#    my $fmgr = $blog->file_mgr;
     require MT::FileMgr;
     my $fmgr = MT::FileMgr->new('Local');

    ## Set up the full path to the local file; this path could start
    ## at either the Local Site Path or Local Archive Path, and could
    ## include an extra directory or two in the middle.
    my ( $root_path, $relative_path, $middle_path );
#    if ( $q->param('site_path') ) {
#        $root_path = $blog->site_path;
#    }
#    else {
#        $root_path = $blog->archive_path;
#    }
	$root_path = $app->static_file_path;

    return $app->error(
        $app->translate(
            "Before you can upload a file, you need to publish your blog."
        )
    ) unless -d $root_path;
    $relative_path = 'uploads';
    $middle_path = 'support';
    my $relative_path_save = $relative_path;
    if ( $middle_path ne '' ) {
        $relative_path =
          $middle_path . ( $relative_path ? '/' . $relative_path : '' );
    }
    my $path = $root_path;
    if ($relative_path) {
        if ( $relative_path =~ m!\.\.|\0|\|! ) {
            return $app->start_upload(
                %param,
                error => $app->translate(
                    "Invalid extra path '[_1]'", $relative_path
                )
            );
        }
        $path = File::Spec->catdir( $path, $relative_path );
        ## Untaint. We already checked for security holes in $relative_path.
        ($path) = $path =~ /(.+)/s;
        ## Build out the directory structure if it doesn't exist. DirUmask
        ## determines the permissions of the new directories.
        unless ( $fmgr->exists($path) ) {
            $fmgr->mkpath($path)
              or return $app->start_upload(
                %param,
                error => $app->translate(
                    "Can't make path '[_1]': [_2]",
                    $path, $fmgr->errstr
                )
              );
        }
    }
    my $relative_url =
      File::Spec->catfile( $relative_path, encode_url($basename) );
    $relative_path = $relative_path
      ? File::Spec->catfile( $relative_path, $basename )
      : $basename;
    my $asset_file = '%s';
    $asset_file = File::Spec->catfile( $asset_file, $relative_path );
    my $local_file = File::Spec->catfile( $path, $basename );

    ## Untaint. We have already tested $basename and $relative_path for security
    ## issues above, and we have to assume that we can trust the user's
    ## Local Archive Path setting. So we should be safe.
    ($local_file) = $local_file =~ /(.+)/s;

    my $local_basename = File::Basename::basename($local_file);

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->config('UploadUmask');
    my $old   = umask($umask);
    defined( my $bytes = $fmgr->put( $fh, $local_file, 'upload' ) )
      or return $app->error(
        $app->translate(
            "Error writing upload to '[_1]': [_2]", $local_file,
            $fmgr->errstr
        )
      );
    umask($old);

    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error(
        $app->translate(
                "Perl module Image::Size is required to determine "
              . "width and height of uploaded images."
        )
    ) if $@;
    my ( $w, $h, $id ) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    ## We are going to use $relative_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $relative_path =~ s!\\!/!g;
    $relative_path =~ s!^/!!;
    $relative_url  =~ s!\\!/!g;
    $relative_url  =~ s!^/!!;
 #   my $url = $app->param('site_path') ? $blog->site_url : $blog->archive_url;
 #   $url .= '/' unless $url =~ m!/$!;
 #   $url .= $relative_url;
	my $url = $root_path . $relative_url;
    my $asset_url = $asset_file;
 #   $asset_url .= '/' . $relative_url;

	# ext stuff was here

    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local_basename);
    my $is_image  = defined($w)
      && defined($h)
      && $asset_pkg->isa('MT::Asset::Image');
    my $asset;
    if (
        !(
            $asset = $asset_pkg->load(
                { file_path => $asset_file, blog_id => $blog_id }
            )
        )
      )
    {
        $asset = $asset_pkg->new();
        $asset->file_path($asset_file);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id(0);
        $asset->created_by( $app->user->id );
    }
    else {
        $asset->modified_by( $app->user->id );
    }
    my $original = $asset->clone;
    $asset->url($asset_url);
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save
		or MT->log("Error saving asset: ".$asset->errstr);
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    if ($is_image) {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'image',
            type  => 'image',
            Blog  => $blog,
            blog  => $blog
        );
        $app->run_callbacks(
            'cms_upload_image',
            File       => $local_file,
            file       => $local_file,
            Url        => $url,
            url        => $url,
            Size       => $bytes,
            size       => $bytes,
            Asset      => $asset,
            asset      => $asset,
            Height     => $h,
            height     => $h,
            Width      => $w,
            width      => $w,
            Type       => 'image',
            type       => 'image',
            ImageType  => $id,
            image_type => $id,
            Blog       => $blog,
            blog       => $blog
        );
    }
    else {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'file',
            type  => 'file',
            Blog  => $blog,
            blog  => $blog
        );
    }

#    $app->complete_insert(
#        asset => $asset,
#        bytes => $bytes,
#    );

	# Upload done and asset created, now do UserProfiles stuff

	$asset = crop_to_square($asset);
#   require MT::Tag;
#   my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
#   my @tags = MT::Tag->split( $tag_delim, $tags );
#	my @tags = ("profileimage");
    $asset->tags('@userpic');
	$asset->save;

#	# now display confirmation screen
#	my $tmpl = MT->model('template')->load({ blog_id => $blog_id, name => 'Upload Profile Image'})
#			or return $app->handle_error( $app->translate('Edit User Profile template not found') );
#	$tmpl = $app->_set_profile_context($tmpl,$commenter);
#	my $ctx = $tmpl->context;
#	$ctx->{__stash}{asset} = $asset;
#	$tmpl->context($ctx);
#	$app->build_page($tmpl,
#		{ 	author_id => $commenter->id, 
#			blog_id => $blog_id,
#			asset_id => $asset->id,
#			magic_token => $app->current_magic,
#			script_url => $app->uri,
#			confirm_image => 1,
#		} );

#	MT->log($asset->id);

	$commenter->userpic_asset_id($asset->id)
      		or MT->log("Error creating adding asset to author: " . $commenter->errstr);
	$commenter->save;
	my $return_link = $app->uri . $app->uri_params(
            'mode' => 'edit_userprofile',
            args   => {
                blog_id => $blog_id,
            }
	);

	# get thumbnail url
#	require MT::Template::Context;
#	my $ctx = MT::Template::Context->new;
#	my $args = { width => 50 };
#	$ctx->{__stash}{asset} = $asset;
#	my $thumb_url = MT::Template::Context::_hdlr_asset_thumbnail_url($ctx,$args) || 'none';
	my $thumb_url = $commenter->userpic_url(Width => 50, Height => 50, Square => 1) || 'none';
	my %img_cookie = (
        -name    => 'commenter_img',
        -value   => $thumb_url,
        -path    => '/',
        -expires => "+2592000s"
    );
    $app->bake_cookie(%img_cookie);
	$return_link .= decode_url($app->param('return_args'));
	$app->redirect($return_link);
}

sub _write_upload {
    my ( $upload_fh, $dest_fh ) = @_;
    my $fh = gensym();
    if ( ref($dest_fh) eq 'GLOB' ) {
        $fh = $dest_fh;
    }
    else {
        open $fh, ">$dest_fh" or return;
    }
    binmode $fh;
    binmode $upload_fh;
    my ( $bytes, $data ) = (0);
    while ( my $len = read $upload_fh, $data, 8192 ) {
        print $fh $data;
        $bytes += $len;
    }
    close $fh;
    $bytes;
}


sub save_image {		#not currently used
	my $app = shift;
	my $asset_id = $app->param('asset_id');
	my $author_id = $app->param('author_id');
	use MT::Author;
	my $author = MT::Author->load($author_id) or MT->log("Error loading author");
	$author->profile_asset_id($asset_id)
      		or MT->log("Error creating adding asset to author: " . $author->errstr);
	$author->save;
	my %img_cookie = (
        -name    => 'commenter_img',
        -value   => '',
        -path    => '/',
        -expires => "-10y"
    );
    $app->bake_cookie(%img_cookie);
	my $return_link = $app->uri . $app->uri_params(
            'mode' => 'edit_userprofile',
            args   => {
                blog_id => $app->param('blog_id'),
            }
	);
	$app->redirect($return_link);
}

sub remove_image {
	my $app = shift;
	my $author = $app->_get_user();
	return if !$author;
	$author->userpic_asset_id('');
	$author->save;
	my %img_cookie = (
        -name    => 'commenter_img',
        -value   => 'none',
        -path    => '/',
        -expires => "+2592000s"
    );
    $app->bake_cookie(%img_cookie);
	my $return_link = $app->uri . $app->uri_params(
            'mode' => 'edit_userprofile',
            args   => {
                blog_id => $app->param('blog_id'),
            }
	);
	$return_link .= decode_url($app->param('return_args'));
	$app->redirect($return_link);
}

sub _set_profile_context {
	my $app = shift;
	my ($tmpl,$author) = @_;
	my $blog = MT->model('blog')->load($tmpl->blog_id);
	my $ctx = $tmpl->context;
	$ctx->{__stash}{author} = $author if $author;
	$ctx->{__stash}{commenter} = $author if $author;
   	$ctx->{__stash}{blog} = $blog;
   	$ctx->{__stash}{blog_id} = $blog->id;
	$tmpl->context($ctx);
	$tmpl;
}

sub _get_user {
	my $app = shift;
    my ( $session, $commenter ) = $app->_get_commenter_session();
	$app->user($commenter) if $commenter;
	return $commenter || undef;
}

sub _get_commenter_session {
    my $app = shift;
    my $q   = $app->param;

    my $session_key;

    my %cookies = $app->cookies();
    if ( !$cookies{ $app->COMMENTER_COOKIE_NAME() } ) {
        return ( undef, undef );
    }
    $session_key = $cookies{ $app->COMMENTER_COOKIE_NAME() }->value() || "";
    $session_key =~ y/+/ /;
    my $cfg = $app->config;
    require MT::Session;
    my $sess_obj = MT::Session->load( { id => $session_key } );
    my $timeout = $cfg->CommentSessionTimeout;
    my $user;

    if ( $sess_obj
        && ( $user = MT::Author->load( { name => $sess_obj->name } ) ) )
    {
        return ( $session_key, $user ) if $user->type eq MT::Author::AUTHOR();
    }
    if (   !$sess_obj
        || ( $sess_obj->start() + $timeout < time )
      )
    {
        $app->_invalidate_commenter_session( \%cookies );
        return ( undef, undef );
    }
    else {

        # session is valid!
        return ( $session_key, $user );
    }
}


1;