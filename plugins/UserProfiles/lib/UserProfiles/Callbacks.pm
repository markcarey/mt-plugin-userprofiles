package UserProfiles::Callbacks;
use strict;

use UserProfiles::Util qw ( crop_to_square );

sub edit_author {
    my ($eh, $app, $param, $tmpl) = @_;
    return unless UNIVERSAL::isa($tmpl, 'MT::Template');
	my $author = MT::Author->load($app->param('id'));
	my $ctx = $tmpl->context;
	$ctx->{__stash}{author} = $author;
	$tmpl->context($ctx);
    my $url_field = $tmpl->getElementById('name')
        or return $app->error('cannot get the url block');
    my $image_field = $tmpl->createElement('app:setting', {
        id => 'image',
        label => $app->translate('Image'),  })
        or return $app->error('cannot create the image element');
#	my $blog_id = primary_blog($app->param('id'));
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $system_config = $plugin->get_config_hash('system');
    my $blog_id = $system_config->{profile_blog_id};
	my $innerHTML = <<HTML;
		<mt:setvarblock name="profile_image"><mt:AuthorImageURL size="50"></mt:setvarblock>
		<mt:if name="profile_image">
	        <img src="<mt:var name="profile_image">" /><br />
		<a href="javascript:void(0)" onclick="return openDialog(false, 'userprofiles_start_image','author_id=<mt:var name="id">&amp;blog_id=$blog_id')">Click here to change the profile image</a> - (<a href="<mt:var name="script_url">?__mode=remove_profile_image&author_id=<mt:var name="id">">remove image</a>)
		<mt:else>
		<a href="javascript:void(0)" onclick="return openDialog(false, 'userprofiles_start_image','author_id=<mt:var name="id">&amp;blog_id=$blog_id')">Click here to add a profile image</a>
		</mt:if>
HTML
	$image_field->innerHTML( $innerHTML );
    $tmpl->insertBefore($image_field, $url_field)
        or return $app->error('failed to insertAfter.');
}

sub asset_options_params {
    my ($eh, $app, $param, $tmpl) = @_;
    return unless UNIVERSAL::isa($tmpl, 'MT::Template');
	if ($app->param('userprofiles')) {
#		MT->log('profile image uploaded');
		my $asset_id = $param->{asset_id};
		my $asset = MT::Asset->load($asset_id);
	   	my $ctx = $tmpl->context;
		$ctx->{__stash}{asset} = $asset;
		$tmpl->context($ctx);
		$asset = crop_to_square($asset);
#       require MT::Tag;
#       my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
#       my @tags = MT::Tag->split( $tag_delim, $tags );
		my @tags = ("profileimage");
        $asset->set_tags(@tags);
		$asset->save;
 #		MT->log('created profile custom');
		$param->{author_id} = $app->param('author_id');
	}
}

sub asset_options {
	my ($cb, $app, $template) = @_;
	if ($app->param('userprofiles')) {
		require File::Spec;
		my $plugin = MT::Plugin::UserProfiles->instance;
		my $path = $plugin->path || '';
		my $new_tmpl = File::Spec->catdir($path,'tmpl','save_profile_image.tmpl');
		$$template = <<HTML;
<mt:include name="$new_tmpl">
HTML
	}
}

sub this_is_you {
	my ($cb, $app, $template) = @_;
	my $old = qq{<div class="user-stats">};
	$old = quotemeta($old);
	my $new = <<MTML;
<div class="user-pic">
<mt:setvarblock name="profile_image"><mt:AuthorImageURL id="\$author_id" size="50"></mt:setvarblock>
<mt:setvarblock name="image_url"><mt:if name="profile_image"><mt:var name="profile_image"><mt:else><mt:var name="static_uri">images/user-pic.gif</mt:if></mt:setvarblock>
	<a href="<mt:var name="mt_url">?__mode=view&amp;_type=author&amp;id=<mt:var name="author_id">"><img src="<mt:var name="image_url">" alt="" width="50px" height="50px" /></a>
</div>
MTML
	$$template =~ s/($old)/$new$1/;
}




1;