# Movable Type plugin for User Profiles
# 1.0 - orginal release of free version
# 1.5 - commenter upload of avatars + Pro version features
# 1.51 - bug fix for attempted profile build during initial install
# 1.52 - check for XML::Parser and skip those imports when not found, skip Profile build gracefully when no blog_id found
# 1.53 - skip author/comment URL generation if blog_id not set (solves error after upgrade on dashboard).
# 1.6 - updated for MT 4.1, including migration to 4.1 "userpic" feature
# 1.61 - another fix for XML::Parser error
# 1.62 - fix for default Gravatar "G" icon being imported.
# 1.63 - fix for callback not firing when save Extended Profile - Thanks to Chad Everett for reporting this one

package MT::Plugin::UserProfiles;
use strict;
use base 'MT::Plugin';
use vars qw($VERSION);
$VERSION = '1.63';
use MT;

MT::Author->install_meta({
    columns => [
        'profile_asset_id',
    ],
});

my $plugin = MT::Plugin::UserProfiles->new({
    name => 'User Profiles Pro',
	id => 'UserProfiles',
    description => "Adds user profiles to your MT4 blogs. Pro Version",
	doc_link => "http://mt-hacks.com/userprofiles.html",
	plugin_link => "http://mt-hacks.com/userprofiles.html",
	author_name => "Mark Carey",
	author_link => "http://mt-hacks.com/",
    version => $VERSION,
	system_config_template => 'system_settings.tmpl',
	blog_config_template => 'blog_settings.tmpl',
	settings => new MT::PluginSettings([
        ['profile_upload_path', { Default => '' }],
        ['profile_blog_id', { Default => '' }],
        ]),
	schema_version  => '17',   # for plugin version 1.61
});
MT->add_plugin($plugin);

my $cfg = MT->config;
my $plugin_schema = $cfg->PluginSchemaVersion || {};
if (!$plugin_schema->{'UserProfiles'}) {
    $plugin_schema->{'UserProfiles'} = -1;
    $cfg->PluginSchemaVersion($plugin_schema, 1);
}

sub instance { $plugin; }

sub init_registry {
	my $component = shift;
	my $reg = {
		'applications' => {
			'cms' => {
				'methods' => {
#					'userprofiles_start_image' => '$UserProfiles::UserProfiles::App::CMS::start_image',
#					'save_profile_image' => '$UserProfiles::UserProfiles::App::CMS::save_profile_image',
#					'remove_profile_image' => '$UserProfiles::UserProfiles::App::CMS::remove_profile_image',
					'install_userprofiles_templates' => '$UserProfiles::UserProfiles::App::CMS::install_templates',
					'edit_userprofile' => '$UserProfiles::UserProfiles::Pro::App::CMS::cms_edit_userprofile',
					'save_userprofile' => '$UserProfiles::UserProfiles::Pro::App::CMS::cms_save_userprofile',
				}
			},
			'userprofiles' => {
				'handler' => 'UserProfiles::App',
				'methods' => {
					'edit_userprofile' => '$UserProfiles::UserProfiles::App::UserProfiles::edit_userprofile',
					'save_userprofile' => '$UserProfiles::UserProfiles::App::UserProfiles::save_userprofile',
					'start_image' => '$UserProfiles::UserProfiles::App::UserProfiles::start_image',
					'add_image' => '$UserProfiles::UserProfiles::App::UserProfiles::add_image',
					'save_image' => '$UserProfiles::UserProfiles::App::UserProfiles::save_image',
					'remove_image' => '$UserProfiles::UserProfiles::App::UserProfiles::remove_image',
					'save_extendedprofile' => '$UserProfiles::UserProfiles::Pro::App::UserProfiles::save_extendedprofile',
					'get_image' => '$UserProfiles::UserProfiles::Pro::App::UserProfiles::get_image',
				},
			},
		},
		'config_settings' => {
			'UserProfilesScript' => {
                default => 'plugins/UserProfiles/mt-userprofiles.cgi',
                path    => 1,
			},
		},
        'object_types' => {
           'profile'	=> 'UserProfiles::Pro::Object::Profile',
        },
		'callbacks' => {
#			'MT::App::CMS::template_param.edit_author' => '$UserProfiles::UserProfiles::Callbacks::edit_author',
#			'MT::App::CMS::template_param.dialog/asset_options' => '$UserProfiles::UserProfiles::Callbacks::asset_options_params',
#			'MT::App::CMS::template_param.asset_options' => '$UserProfiles::UserProfiles::Callbacks::asset_options_params',
#			'MT::App::CMS::template_source.asset_options' => '$UserProfiles::UserProfiles::Callbacks::asset_options',
#			'MT::App::CMS::template_source.this_is_you' => '$UserProfiles::UserProfiles::Callbacks::this_is_you',
			'MT::App::CMS::template_source.users_content_nav' => '$UserProfiles::UserProfiles::Pro::Callbacks::users_content_nav',
			'MT::Comment::post_save' => '$UserProfiles::UserProfiles::Pro::Callbacks::post_save_comment',
			'MT::Entry::post_save' => '$UserProfiles::UserProfiles::Pro::Callbacks::post_save_entry',
			'MT::Author::post_save' => '$UserProfiles::UserProfiles::Pro::Callbacks::post_save_author',
			'UserProfiles::Pro::Object::Profile::post_save' => '$UserProfiles::UserProfiles::Pro::Callbacks::post_save_profile',
			'MT::Template::post_save' => '$UserProfiles::UserProfiles::Pro::Callbacks::post_save_template',
		},
        'tags' => {
            'function' => {
                'AuthorImageURL' => '$UserProfiles::UserProfiles::Tags::author_image_url',
                'CommenterImageURL' => '$UserProfiles::UserProfiles::Tags::commenter_image_url',
                'UserProfilesScript' => '$UserProfiles::UserProfiles::Tags::user_profiles_script',
                'AuthorProfileURL' => '$UserProfiles::UserProfiles::Pro::Tags::author_profile_url',
                'CommenterProfileURL' => '$UserProfiles::UserProfiles::Pro::Tags::commenter_profile_url',
                'UserProfile' => '$UserProfiles::UserProfiles::Pro::Tags::user_profile_tag',
				'CommentAuthorLink' => '$UserProfiles::UserProfiles::Pro::Tags::comment_author_link',
				'EntryAuthorLink' => '$UserProfiles::UserProfiles::Pro::Tags::entry_author_link',
                'UserPostCount' => '$UserProfiles::UserProfiles::Pro::Tags::post_count',
                'AuthorPostCount' => '$UserProfiles::UserProfiles::Pro::Tags::post_count',
                'CommenterPostCount' => '$UserProfiles::UserProfiles::Pro::Tags::post_count',
                'UserJoinDate' => '$UserProfiles::UserProfiles::Pro::Tags::join_date',
                'AuthorJoinDate' => '$UserProfiles::UserProfiles::Pro::Tags::join_date',
                'CommenterJoinDate' => '$UserProfiles::UserProfiles::Pro::Tags::join_date',
            },
            'block' => {
                'IfAuthorImage?' => '$UserProfiles::UserProfiles::Tags::if_author_image',
                'IfCommenterImage?' => '$UserProfiles::UserProfiles::Tags::if_commenter_image',
				'IfUserProfilesPro?' => sub { return 1; },
                'AuthorComments' => '$UserProfiles::UserProfiles::Pro::Tags::author_comments',
            },
        },
		'upgrade_functions' => {
    	    'import_images' => {
        	    version_limit => 1.231,   # runs for schema_version < 1.231  -- plugin version 1.5x
	            updater => {
                	type => 'author',
                	label => 'Importing author photos...',
                	condition => sub { !$_[0]->profile_asset_id && !$_[0]->userpic_asset_id },
                	code => '$UserProfile::UserProfiles::Pro::Util::import_images',
                }
        	},
    	    'migrate_userpics' => {
        	    version_limit => 17,   # plugin version 1.61
	            updater => {
                	type => 'author',
                	label => 'Migrating userpics...',
                	condition => sub { $_[0]->profile_asset_id && !$_[0]->userpic_asset_id },
                	code => '$UserProfile::UserProfiles::Upgrade::migrate_userpics',
                }
        	},
    	},
	};
	$component->registry($reg);
}

1;

