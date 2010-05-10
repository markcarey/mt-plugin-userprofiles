package UserProfiles::Pro::App::UserProfiles;

use strict;

use base qw( UserProfiles::App::UserProfiles );
use MT::Util qw( decode_url );
use UserProfiles::Pro::Util qw( import_images );

sub save_extendedprofile {
    my $app = shift;
    my $author = $app->_get_user();
	return $app->handle_error( $app->translate('Login Session Expired') ) if !$author;
	my $id = $app->param('id');
	my $author_id = $author->id;
	use UserProfiles::Pro::Object::Profile;
	my $profile = $author->profile;

	my @up_fields = $app->param();
    foreach (@up_fields) {
        if (m/^userprofiles_(.*?)$/) {
			my $fieldname = $1;
			next if $fieldname eq 'id';
			next if $fieldname eq 'author_id';
			if (!$profile->has_column($fieldname)) {
				UserProfiles::Pro::Object::Profile->install_meta({ columns => [ $fieldname ], });
			}
            $profile->$fieldname($app->param('userprofiles_'.$fieldname));
        }
    }
	$profile->save;
	my $return_link = $app->uri . $app->uri_params(
            'mode' => 'edit_userprofile',
            args   => {
                author_id => $profile->author_id,
				saved => 1,
				extended_profile => 1,
            }
	);
	$return_link .= decode_url($app->param('return_args'));
	$app->redirect($return_link);
	

}

sub get_image {			# ajax function
	my $app = shift;
	my $commenter = $app->_get_user();
	return '' if !$commenter;
	if (!$commenter->userpic_asset_id) {
		import_images($commenter);
	}
	my $url;
	if ($commenter->userpic_asset_id) {
		require MT::Template::Context;
#		my $ctx = MT::Template::Context->new;
#		my $args = { width => 50 };
#		$ctx->{__stash}{asset} = MT->model('asset')->load($commenter->profile_asset_id);
#		$url = MT::Template::Context::_hdlr_asset_thumbnail_url($ctx,$args) || '';
		$url = $commenter->userpic_url(Square => 1, Height => 50, Width => 50);
	} else {
		$url = 'none';
	}
	my %img_cookie = (
        -name    => 'commenter_img',
        -value   => $url,
        -path    => '/',
        -expires => "+2592000s"
    );
    $app->bake_cookie(%img_cookie);
	return 'none' if ($url eq 'none');
	return '<img src="'.$url.'" />';
}

1;