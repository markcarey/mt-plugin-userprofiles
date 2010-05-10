package UserProfiles::App::CMS;

use strict;

sub install_templates {
	my $app = shift;
	my $installer;
	eval { $installer = MT::Plugin::TemplateInstaller->instance; };
	if ($@) {
		$app->build_page('get_template_installer.tmpl');		
	} else {
		$app->forward('install_blog_templates',@_);
	}
}

1;