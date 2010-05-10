package UserProfiles::Pro::Tags;
use strict;

use MT::Util qw( format_ts );
use UserProfiles::Pro::Publisher qw( profile_archive_file );
use MT::Promise qw( delay );

sub user_profile_tag {
	my ($ctx,$args) = @_;
	my $author;
	if ($args->{author_id}) {
		$author = MT->model('author')->load($args->{author_id});
	} 
    if (!$author && $ctx->stash('comment')) { 
        my $comment = $ctx->stash('comment'); 
        $author = MT->model('author')->load($comment->commenter_id) if ($comment && $comment->commenter_id);
		return '' if !$author; 
    }
    if (!$author && $ctx->stash('entry')) { 
        my $entry = $ctx->stash('entry'); 
        $author = $entry->author; 
    }
	unless ($author) {
		$author = $ctx->stash('author');
	}
	return '' if !$author;
#	MT->log("author id is " . $author->id);
	use UserProfiles::Pro::Object::Profile;
	my $profile = $author->profile;
	return '' if !$profile->id;
	my $field = $args->{field};
	if ($field eq 'birthdate') {
		return '' if ($profile->$field eq '00000000000000');
		return format_ts($args->{date_format},$profile->$field) if $args->{date_format};
	}
	if (!$profile->has_column($field)) {
		UserProfiles::Pro::Object::Profile->install_meta({ columns => [ $field ], });
	}
	return $profile->$field || '';
}

sub author_profile_url {
	my $ctx = shift;
	my $args = shift;
#	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	return '' if !$blog_id;
	my $blog = MT->model('blog')->load($blog_id);
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
	my $file = profile_archive_file($author,$blog);
    my $site_url = $blog->site_url;
    $site_url .= '/' unless $site_url =~ m!/$!;
	my $url = $site_url . $file;
    $url = MT::Util::strip_index($url, $blog) unless $args->{with_index};
    $url;
}

sub commenter_profile_url {
	my $ctx = shift;
	my $args = shift;
#	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::UserProfiles->instance;
	my $config = $plugin->get_config_hash('system');
	my $blog_id = $config->{profile_blog_id};
	return '' if !$blog_id;
	my $blog = MT->model('blog')->load($blog_id);
	my $author = $ctx->stash('commenter');
	if (!$author && (my $comment = $ctx->stash('comment'))) {
		if ($comment->commenter_id) {
			$author = MT->model('author')->load($comment->commenter_id);
		}
	}
	if (!$author) { return ''; }
	my $file = profile_archive_file($author,$blog);
    my $site_url = $blog->site_url;
    $site_url .= '/' unless $site_url =~ m!/$!;
	my $url = $site_url . $file;
    $url = MT::Util::strip_index($url, $blog) unless $args->{with_index};
    $url;
}

sub comment_author_link {
    my($ctx, $args) = @_;
#	my $plugin = MT::Plugin::UserProfiles->instance;
#	my $config = $plugin->get_config_hash('blog:'.$ctx->stash('blog_id'));
    my $c = $ctx->stash('comment')
        or return $ctx->_no_comment_error('MT' . $ctx->stash('tag'));
	if ($c->commenter_id) {
		my $url = commenter_profile_url($ctx,$args);
        return sprintf qq(<a href="%s">%s</a>), $url, $c->author;
	} else {
		return MT::Template::Context::_hdlr_comment_author_link($ctx,$args);
	}
}

sub entry_author_link {
    my($ctx, $args) = @_;
#	my $plugin = MT::Plugin::UserProfiles->instance;
#	my $config = $plugin->get_config_hash('blog:'.$ctx->stash('blog_id'));
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));
	my $author = $e->author;
	return '' if !$author;   # for unlikely case where no author object is found (reported by Tim McFall)
	my $displayname = $author->nickname || $author->name;
	my $url = author_profile_url($ctx,$args);
    return sprintf qq(<a href="%s">%s</a>), $url, $displayname;
}

sub author_comments {
    my($ctx, $args, $cond) = @_;
    my @comments;
    my $comments = $ctx->stash('comments');
    if ($comments) {
        @comments = @$comments;
    } else {
        my $blog_id = $ctx->stash('blog_id');
        my $blog = $ctx->stash('blog');
        my (%terms, %args);
        $terms{commenter_id} = $ctx->stash('author')->id if $ctx->stash('author');   #added for AuthorComments tag, rest is same
        $terms{visible} = 1;
        $ctx->set_blog_load_context($args, \%terms, \%args)
            or return $ctx->error($ctx->errstr);

        my $so = lc ($args->{sort_order} || ($blog ? $blog->sort_order_comments : undef) || 'ascend');
        ## If there is a "lastn" arg, then we need to check if there is an entry
        ## in context. If so, grab the N most recent comments for that entry;
        ## otherwise, grab the N most recent comments for the entire blog.
        my $n = $args->{lastn};
        if (my $e = $ctx->stash('entry')) {
            ## Sort in descending order, then grab the first $n ($n most
            ## recent) comments.
            my $comments = $e->comments;
            @comments = $so eq 'ascend' ?
                sort { $a->created_on <=> $b->created_on } @$comments :
                sort { $b->created_on <=> $a->created_on } @$comments;
            # filter out comments from unapproved commenters
            @comments = grep { $_->visible() } @comments;

            if ($n) {
                my $max = $n - 1 > $#comments ? $#comments : $n - 1;
                @comments = $so eq 'ascend' ?
                    @comments[$#comments-$max..$#comments] :
                    @comments[0..$max];
            }
        } else {
            $args{'sort'} = 'created_on';
            $args{'direction'} = 'descend';
            require MT::Comment;
            my $iter = MT::Comment->load_iter(\%terms, \%args);
            my %entries;
            while (my $c = $iter->()) {
                my $e = $entries{$c->entry_id} ||= $c->entry;
                next unless $e;
                next if $e->status != MT::Entry::RELEASE();
                push @comments, $c;
                if ($n && (scalar @comments == $n)) {
                    $iter->('finish');
                    last;
                }
            }
            @comments = $so eq 'ascend' ?
                sort { $a->created_on <=> $b->created_on } @comments :
                sort { $b->created_on <=> $a->created_on } @comments;
        }

        @comments = grep { $_->visible() } @comments;
    }

    my $html = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $i = 1;

    local $ctx->{__stash}{commenter} = $ctx->{__stash}{commenter};
    my $vars = $ctx->{__stash}{vars} ||= {};
    for my $c (@comments) {
        local $vars->{__first__} = $i == 1;
        local $vars->{__last__} = ($i == scalar @comments);
        local $vars->{__odd__} = ($i % 2) == 1;
        local $vars->{__even__} = ($i % 2) == 0;
        local $vars->{__counter__} = $i;
        local $ctx->{__stash}{blog} = $c->blog;
        local $ctx->{__stash}{blog_id} = $c->blog_id;
        local $ctx->{__stash}{comment} = $c;
        local $ctx->{current_timestamp} = $c->created_on;
        $ctx->stash('comment_order_num', $i);
        if ($c->commenter_id) {
            $ctx->stash('commenter', delay(sub {MT::Author->load($c->commenter_id)}));
        } else {
            $ctx->stash('commenter', undef);
        }
        my $out = $builder->build($ctx, $tokens,
            { CommentsHeader => $i == 1,
              CommentsFooter => ($i == scalar @comments), %$cond } );
        return $ctx->error( $builder->errstr ) unless defined $out;
        $html .= $out;
        $i++;
    }
    if (!@comments) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
    $html;
}

sub join_date {
    my($ctx, $args) = @_;
	my $author;
	if ($args->{author_id}) {
		$author = MT->model('author')->load($args->{author_id});
	} else {
		$author = $ctx->stash('author');
	}
    unless ($author) { 
        my $comment = $ctx->stash('comment'); 
        $author = MT->model('author')->load($comment->commenter_id) if ($comment && $comment->commenter_id); 
    }
    unless ($author) { 
        my $entry = $ctx->stash('entry'); 
        $author = $entry->author if $entry; 
    }
	return '?' if !$author;
    $args->{ts} = $author->created_on;
    MT::Template::Context::_hdlr_date($ctx, $args);
}

sub post_count {
    my($ctx, $args) = @_;
	my $author;
	if ($args->{author_id}) {
		$author = MT->model('author')->load($args->{author_id});
	} else {
		$author = $ctx->stash('author');
	}
    unless ($author) { 
        my $comment = $ctx->stash('comment'); 
        $author = MT->model('author')->load($comment->commenter_id) if ($comment && $comment->commenter_id); 
    }
    unless ($author) { 
        my $entry = $ctx->stash('entry'); 
        $author = $entry->author if $entry; 
    }
	return '?' if !$author;
	my $post_count = entry_post_count($author) + comment_post_count($author);	
}

sub entry_post_count {
	my ($author) = @_;
    $author->cache_property('entry_post_count', sub {
        my $cache = MT::Memcached->instance;
        my $memkey = $author->cache_key('entrypostcount');
        if (defined( my $count = $cache->get($memkey) )) {
            return $count;
        } else { 
            require MT::Entry;
            my $count = MT::Entry->count({
                author_id => $author->id,
#                status => MT::Entry::RELEASE()
            });
            $cache->add($memkey, $count, 7 * 24 * 60 * 60);  ## 1 week.
            return $count;
        }
    });
}

sub comment_post_count {
	my ($author) = @_;
    $author->cache_property('comment_post_count', sub {
        my $cache = MT::Memcached->instance;
        my $memkey = $author->cache_key('commentpostcount');
        if (defined( my $count = $cache->get($memkey) )) {
            return $count;
        } else { 
            require MT::Comment;
            my $count = MT::Comment->count({
                commenter_id => $author->id,
                visible => 1
            });
            $cache->add($memkey, $count, 7 * 24 * 60 * 60);  ## 1 week.
            return $count;
        }
    });
}

MT::Comment->add_trigger( post_save => sub {
    my($clone, $comment) = @_;
	my $commenter_id = $comment->commenter_id;
	return if !$commenter_id;
    ## Note: This flag is set in MT::Comment::visible().
    if (my $delta = $comment->{__changed}{visibility}) {
        my $memkey = MT::Author->cache_key($commenter_id, 'commentpostcount');
        my $cache = MT::Memcached->instance;
        if ($delta > 0) {
            $cache->incr($memkey, $delta);
        } elsif ($delta < 0) {
            $cache->decr($memkey, abs $delta);
        }
    }
} );

MT::Comment->add_trigger( post_remove => sub {
    my($comment) = @_;
	my $commenter_id = $comment->commenter_id;
	return if !$commenter_id;
    ## If this comment was published, decrement the cached count of
    ## visible comments on the entry.
    if ($comment->visible && !$comment->is_changed('visible')) {
        my $memkey = MT::Author->cache_key($commenter_id, 'commentpostcount');
        MT::Memcached->instance->decr($memkey, 1);
    }
} );

MT::Entry->add_trigger( post_remove => sub {
    my($entry) = @_;
	my $author_id = $entry->author_id;
    my $memkey = MT::Author->cache_key($author_id, 'commentpostcount');
    MT::Memcached->instance->decr($memkey, 1);
} );


1;