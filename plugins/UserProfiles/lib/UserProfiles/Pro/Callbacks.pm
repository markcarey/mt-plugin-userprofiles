package UserProfiles::Pro::Callbacks;
use strict;

sub users_content_nav {
	my ($cb, $app, $template) = @_;
	my $old = qq{<mt:unless name="new_object">};
	$old = quotemeta($old);
	my $new = <<NEW;
    <li><a href="<mt:var name="SCRIPT_URL">?__mode=edit_userprofile&author_id=<mt:var name="id">"><b><__trans phrase="Extended"></b></a></li>
NEW
	$$template =~ s/($old)/$1$new/;
}

sub post_save_comment {
	my ($cb, $comment, $orig_comment) = @_;
	if ($comment->commenter_id) {
		my $plugin = MT::Plugin::UserProfiles->instance;
		my $config = $plugin->get_config_hash('system');
		my $blog_id = $config->{profile_blog_id};
		if (!$blog_id) {
			MT->log('User Profiles Pro could not find blog_id setting in System-wide plugin settings (post_save_comment)');
			return;
		}
		my $author = MT->model('author')->load($comment->commenter_id);
		MT::Util::start_background_task(
        	sub {
				rebuild_user_profile(Author => $author, BlogID => $blog_id);
			}
		);		
	}
	return 1;
}

sub post_save_entry {
	my ($cb, $entry, $orig_entry) = @_;
	my $author = $entry->author;
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	if (!$blog_id) {
		MT->log('User Profiles Pro could not find blog_id setting in System-wide plugin settings (post_save_entry)');
		return;
	}
    MT::Util::start_background_task(
        sub {
			rebuild_user_profile(Author => $author, BlogID => $blog_id);
		}
	);
	return 1;
}

sub post_save_author {
	my ($cb, $author, $orig_author) = @_;
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	if (!$blog_id) {
		MT->log('User Profiles Pro could not find blog_id setting in System-wide plugin settings (post_save_author)');
		return;
	}
    MT::Util::start_background_task(
        sub {
			rebuild_user_profile(Author => $author, BlogID => $blog_id);
		}
	);
	return 1;
}

sub post_save_profile {
	my ($cb, $profile, $orig_profile) = @_;
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	if (!$blog_id) {
		MT->log('User Profiles Pro could not find blog_id setting in System-wide plugin settings (post_save_profile)');
		return;
	}
	my $author = $profile->author;
    MT::Util::start_background_task(
        sub {
			rebuild_user_profile(Author => $author, BlogID => $blog_id);
		}
	);
	return 1;
}

sub post_save_template {
	my ($cb, $tmpl, $orig_tmpl) = @_;
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	if (!$blog_id) {
		MT->log('User Profiles Pro could not find blog_id setting in System-wide plugin settings (post_save_template)');
		return;
	}
	if (($tmpl->name eq 'User Profile') && ($tmpl->blog_id == $blog_id)) {
	    MT::Util::start_background_task(
    	    sub {
				rebuild_all_user_profiles($blog_id,$tmpl);	
			}
		);
	}
}

sub rebuild_user_profile {
	use UserProfiles::Pro::Publisher;
	UserProfiles::Pro::Publisher::rebuild_user_profile(@_);	
}

sub rebuild_all_user_profiles {
	use UserProfiles::Pro::Publisher;
	UserProfiles::Pro::Publisher::rebuild_all_user_profiles(@_);	
}


1;