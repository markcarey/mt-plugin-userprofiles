package UserProfiles::Tags;
use strict;

sub author_image_url {
	my $ctx = shift;
	my $args = shift;
	my $size = $args->{size} || 50;
	$args->{width} = $size;
	my $author;
	if (my $id = $args->{id}) {
		$author = MT->model('author')->load($id);
	} else {
		$author = $ctx->stash('author');
	}
	if (!$author && (my $entry = $ctx->stash('entry'))) {
		$author = $entry->author;
	}
	if (!$author) { return ''; }
	my $url = $author->userpic_url(Width => $size, Height => $size, Square => 1);
}

sub commenter_image_url {
	my $ctx = shift;
	my $args = shift;
	my $size = $args->{size} || 50;
	$args->{width} = $size;
	my $author = $ctx->stash('commenter');
	if (!$author && (my $comment = $ctx->stash('comment'))) {
		if ($comment->commenter_id) {
			$author = MT->model('author')->load($comment->commenter_id);
		}
	}
	if (!$author) { return ''; }
	my $url = $author->userpic_url(Width => $size, Height => $size, Square => 1);
}


sub if_author_image {
    my ($ctx, $args, $cond) = @_;
	my $author;
	if (my $id = $args->{id}) {
		$author = MT->model('author')->load($id);
	} else {
		$author = $ctx->stash('author');
	}
	if (!$author && (my $entry = $ctx->stash('entry'))) {
		$author = $entry->author;
	}
	return 0 if !$author;
	my $profile_asset_id = $author->userpic_asset_id;
	return $profile_asset_id || 0;
}

sub if_commenter_image {
    my ($ctx, $args, $cond) = @_;
	my $author = $ctx->stash('commenter');
	if (!$author && (my $comment = $ctx->stash('comment'))) {
		if ($comment->commenter_id) {
			$author = MT->model('author')->load($comment->commenter_id);
		}
	}
	return 0 if !$author;
	my $profile_asset_id = $author->userpic_asset_id;
	return $profile_asset_id || 0;
}

sub user_profiles_script {
    my ($ctx) = @_;
    return $ctx->{config}->UserProfilesScript;
}


1;