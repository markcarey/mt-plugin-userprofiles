#########################################################

package UserProfiles::Pro::Object::Profile;
use strict;

use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'author_id' => 'integer not null',
        'nickname' => 'string(255)',
        'email' => 'string(75)',
        'url' => 'string(255)',
		'birthdate' => 'datetime',
        'first_name' => 'string(50)',
        'last_name' => 'string(50)',
        'address' => 'string(100)',
        'city' => 'string(50)',
        'state' => 'string(50)',
        'country' => 'string(50)',
        'mobile_phone' => 'string(50)',
        'land_phone' => 'string(50)',
		'sex' => 'string(10)',
		'marital_status' => 'string(10)',
		'occupation' => 'string(50)',
		'company' => 'string(50)',
        'signature' => 'text',
        'about_me' => 'text',
        'actvities' => 'text',
        'interests' => 'text',
        'music' => 'text',
        'tv_shows' => 'text',
        'movies' => 'text',
        'books' => 'text',
        'quotes' => 'text',
    },
    indexes => {
        id => 1,
        author_id => 1,
		created_on => 1
    },
    meta => 1,
    child_of => 'MT::Author',
    audit => 1,
    datasource => 'userprofiles_profile',
    primary_key => 'id',
});

sub class_label {
    MT->translate("User Profile");
}

sub class_label_plural {
    MT->translate("User Profiles");
}

sub author {
	my $profile = shift;
	my $author = MT->model('author')->load($profile->author_id);
}


## the following adds a convenience method to MT::Author
## in order to access a profile by $author->profile
## creates a new profile if none found for the author

package MT::Author;

sub profile {
	my $author = shift;
	require UserProfiles::Pro::Object::Profile;
	my $profile = UserProfiles::Pro::Object::Profile->load({ author_id => $author->id });
	if (!$profile) {
		$profile = UserProfiles::Pro::Object::Profile->new;
		$profile->author_id($author->id);
	}
	$profile;
}

sub cache_key {
    my($author_id, $key);
    if (@_ == 3) {
        ($author_id, $key) = @_[1, 2];
    } else {
        ($author_id, $key) = ($_[0]->id, $_[1]);
    }
    return sprintf "author%s-%d", $key, $author_id;
}


1;