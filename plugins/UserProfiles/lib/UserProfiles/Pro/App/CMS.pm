package UserProfiles::Pro::App::CMS;

use strict;

sub cms_edit_userprofile {
	my $app = shift;
	my $author = MT->model('author')->load($app->param('author_id'));
	use UserProfiles::Pro::Object::Profile;
	my $profile = $author->profile;
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	my $fields_tmpl = MT->model('template')->load({ blog_id => $blog_id, name => 'Extended Profile Fields' });
	if (!$fields_tmpl) {
		$fields_tmpl = $plugin->load_tmpl('extended_profile_fields.tmpl');
	}
	my $tmpl = $plugin->load_tmpl('edit_userprofile.tmpl');
	my $ctx = $fields_tmpl->context;
    $ctx->{__stash}{author} = $author;
	$fields_tmpl->context($ctx);
	my $fields = 	$app->build_page($fields_tmpl,
		{ 	author_id => $author->id, 
			id => $profile->id || '',
		} );
	$app->build_page($tmpl,
		{ 	author_id => $author->id, 
			id => $profile->id || '',
			fields => $fields,
			saved => $app->param('saved') || '',
		} );
}

sub cms_save_userprofile {
	my $app = shift;
	my $id = $app->param('id');
	my $author_id = $app->param('author_id')
		or return $app->error( "The author_id param is missing" );
	use UserProfiles::Pro::Object::Profile;
	my $profile;
	if ($id) {
		$profile = 	UserProfiles::Pro::Object::Profile->load($id);
	} else {
		my $author = MT->model('author')->load($author_id);
		$profile = $author->profile;
	}
	$profile->author_id($author_id) if !$profile->author_id;
	my @up_fields = $app->param();
    foreach (@up_fields) {
        if (m/^userprofiles_(.*?)$/) {
			my $fieldname = $1;
			next if $fieldname eq 'id';
			next if $fieldname eq 'author_id';
			next if ( ($fieldname eq 'birthdate') && ($app->param('userprofiles_'.$fieldname) eq '') );
			if ( ($fieldname eq 'birthdate') && ($app->param('userprofiles_'.$fieldname) !~ m!^(\d{4})-(\d{1,2})-(\d{1,2})! )) {
				return $app->error( 'Birthdate must be in the format of YYYY-MM-DD' );
			}
			if (!$profile->has_column($fieldname)) {
				UserProfiles::Pro::Object::Profile->install_meta({ columns => [ $fieldname ], });
			}
            $profile->$fieldname($app->param('userprofiles_'.$fieldname));
        }
    }

	use Data::Dumper;
	MT->log("up_fields is: " . Dumper(\@up_fields));
	MT->log("Profile object before save: " . Dumper($profile));

	$profile->save or return $app->error( $profile->errstr );
	my $return_link = $app->uri . $app->uri_params(
            'mode' => 'edit_userprofile',
            args   => {
                author_id => $profile->author_id,
				saved => 1,
            }
	);
	$app->redirect($return_link);
}

1;