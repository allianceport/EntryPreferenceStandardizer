# $Id$

package EntryPreferenceStandardizer::Plugin;

use strict;
use warnings;
use Data::Dumper;


sub plugin {
    return MT->component('EntryPreferenceStandardizer');
}

sub _log {
    my ($msg) = @_;
    return unless defined($msg);
    my $prefix = sprintf "%s:%s:%s: %s", caller();
    $msg = $prefix . $msg if $prefix;
    use MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
    return;
}

sub entry_preference_standardizer_pref {
    my $plugin = plugin();
    my ($blog_id) = @_;
    my %plugin_param;

    $plugin->load_config(\%plugin_param, 'blog:'.$blog_id);
    my $value = $plugin_param{entry_preference_standardizer_enable};
    unless ($value) {
        $plugin->load_config(\%plugin_param, 'system');
        $value = $plugin_param{entry_preference_standardizer_enable};
    }
    $value;
}


#----- Transformer
sub hdlr_edit_entry_source {
    my ($cb, $app, $tmpl_ref) = @_;

    my $instance = MT->instance();
    my $blog_id  = $instance->param('blog_id');
    my $plugin_enable_check = entry_preference_standardizer_pref($blog_id);
    return unless $plugin_enable_check;

    my $type     = $instance->param('_type');
    my $author_is_admin = $app->user->is_superuser ? $app->user->is_superuser : 0;



    #もしAdminではないならば、対象のBlogのアドミンのアカウントのIDを取得する。
    if (! $author_is_admin){
        use MT::Association;
        my $admin_info = MT::Association->load( {   blog_id   => $blog_id,
                                                    role_id   => { between => [1,2]} },
                                                {   sort      => "author_id",
                                                    direction => "ascend",
                                                    limit     => 1 } );

        #アドミンのアカウントIDの、entry_prefs/page_prefsを取得して、現在のユーザのentry_prefs/page_prefsに格納する。
        use MT::Permission;
        my $admin_permission  = MT::Permission->load( { blog_id   => $blog_id,
                                                        author_id => $admin_info->author_id },
                                                      { limit     => 1 } );

        my $author_permission = MT::Permission->load( { blog_id   => $blog_id,
                                                        author_id => $app->user->id },
                                                      { limit     => 1 } );



        if ($type eq 'entry') {
            my $prefs = $admin_permission->entry_prefs;
            $author_permission->entry_prefs($prefs);

        };
        if ($type eq 'page') {
            my $prefs = $admin_permission->page_prefs;
            $author_permission->page_prefs($prefs);
        };
        $author_permission->save or die;
    };


    if (! $author_is_admin){
        my $old = quotemeta( '<$mt:setvar name="show_display_options_link" value="1"$>' );
        my $new = "";
        $$tmpl_ref =~ s!$old!$new!;
    }else{
        1;
    };
}

sub hdlr_edit_entry_param {
    my ($cb, $app, $param, $tmpl) = @_;

    my $instance = MT->instance();
    my $blog_id  = $instance->param('blog_id');
    my $plugin_enable_check = entry_preference_standardizer_pref($blog_id);
    return unless $plugin_enable_check;

    my $author_is_admin = $app->user->is_superuser;



    if (! $author_is_admin) {
            # Switch classes of mtapp:setting to sort-disabled
        my $settings = $tmpl->getElementsByTagName('app:setting');
        for my $setting ( @$settings ) {
            my $attribute = $setting->getAttribute('class');
            if ( defined($attribute) && $attribute eq 'sort-enabled' ) {
                $setting->setAttribute('class', 'sort-disable');
            }
        }
        # Add CSS for class: .sort-disabled
        $param->{js_include} .= plugin->load_tmpl('sort_disable_css.tmpl')->text;
    }

    1;
}

#----- Hook
sub hdr_permission_post_save {
    my ($cb, $app, $obj) = @_;

    my $blog_id = $obj->blog_id;
    my $plugin_enable_check = entry_preference_standardizer_pref($blog_id);
    return unless $plugin_enable_check;

    my $instance = MT->instance();
    my $author_is_admin = $app->user->is_superuser;
    if ($author_is_admin){
        if ( $instance->mode eq 'save_entry_prefs' ) {
            my $author_id = $obj->author_id;
            use MT::Permission;
            my @results = MT::Permission->load({   blog_id   => $blog_id,
                                                author_id => { not => $author_id } } );

            my $type = $instance->param('_type');
            for my $each_result (@results) {
                if ($type eq 'entry') {
                    my $prefs = $obj->entry_prefs;
                    $each_result->entry_prefs($prefs);
                };
                if ($type eq 'page') {
                    my $prefs = $obj->page_prefs;
                    $each_result->page_prefs($prefs);
                };
                $each_result->save or die;
            };
        };
    };
    1;
};

1;
