use Purple;
use XML::RSS;
use LWP::Simple;
use utf8;

%PLUGIN_INFO = (
    perl_api_version    => 2,
    name                => "Twitter Status",
    version             => "0.0.4",
    summary             => "Use a twitter feed as your Pidgin status.",
    description         => "Use a twitter feed as your Pidgin status. Based on the pidgintwitter-status plugin (http://code.google.com/p/pidgin-twitterstatus/) and Pidgin-Identica-Status  (https://code.google.com/p/pidgin-identica-status/).",
    author              => "Guy Sheffer <guysoft\@gmail.com>",
    url                 => "https://github.com/guysoft/Twitter-Status",
    load                => "plugin_load",
    unload              => "plugin_unload",
    prefs_info          => "prefs_info_cb",
);

sub fetch_url_cb {
    my $url = shift;
    my $username = shift;

    Purple::Debug::info("Twitter Status Feed", "Fetching $url.\n");
    my $feed = get($url);
    my $rss = new XML::RSS;
    $rss->parse($feed);
    my $item = shift (@{$rss->{'items'}});
    my $status = "$item->{'title'}\n";
    $status=~ s{^[A-Za-z0-9_]*: }{};
    $_ = $status;
    Purple::Debug::info("Twitter Status Feed", $_ .'\n');
    #s/$username: //;
    my $use_replies = Purple::Prefs::get_bool("/plugins/core/gtk-mattack-twitterstatus/replies");
    if ($use_replies) {
        Purple::Debug::info("twitter Status Feed", "using \@replies. \n" );
    } else {    # doen't use replies
        while ( $_ =~ /^\@/) {                 
            $item = shift ( @{$rss->{'items'} } );
			my $status = "$item->{'title'}\n";
			$status=~ s{^[A-Za-z0-9_]*: }{};
			$_ = $status;
            #s/$username: //;   
        }
    }

    my $del_tags = Purple::Prefs::get_bool("/plugins/core/gtk-mattack-twitterstatus/tags");
    if ($del_tags) {
        s/\#//g;
    }
    
    chomp ($status_message = $_);
    Purple::Debug::info("Twitter Status Feed", "Status Message is $status_message.\n");
    my $saved_status = Purple::SavedStatus::get_current();
    my $statusType = $saved_status->get_type();
    my $prev_status = $saved_status->get_message();
    Purple::Debug::info("Twitter Status Feed","Your status type is ". $statusType . "\n");
    
    Purple::Debug::info("Twitter Status Feed", "old status ".$prev_status."\n");
    Purple::Debug::info("Twitter Status Feed", "new status ".$status_message."\n");
    
    if(!($keepOnAway && $statusType == 6)) {
        if(($prev_status ne $status_message) && (length($status_message) > 1) != 0) {
            Purple::Debug::info("Twitter Status Feed", "Updating status message with ".$status_message." From ".$url."\n");
            $saved_status->set_message($status_message);
            $saved_status->set_type($statusType);
            $saved_status->activate();
        } else {
            Purple::Debug::info("Twitter Status Feed","Not updating status because it has not changed or was too short");
        }
    } else {
        Purple::Debug::info("Twitter Status Feed","Not updating status because you are away and like your message\n");
    }
}

sub timeout_cb {
    Purple::Debug::info("Twitter Status Feed", "Starting the sequence.  Pidgin's timer expired.\n");
    my $plugin = shift;
	
    my $twitterrss = Purple::Prefs::get_string("/plugins/core/gtk-mattack-twitterstatus/twitterrss");
    my $twitterurl = $twitterrss;
    #if the timeout cannot be parsed, 0 will result
    my $timeout = 0+Purple::Prefs::get_string("/plugins/core/gtk-mattack-twitterstatus/timeout");
    my $keepOnAway = Purple::Prefs::get_bool("/plugins/core/gtk-mattack-twitterstatus/onaway");
    my $status_message = "";
    if($twitterrss eq ""){
        Purple::Debug::info("Twitter Status Feed","Blank username\n");
        die "blank username";
    }
    my $agent = "pidgin-twitterstatusfeed/1.0";
	
    #give some timeout if not otherwise specified
    if($timeout eq 0) {
        Purple::Debug::info("Twitter Status Feed", "Could not parse timeout field. Using 120 seconds default.\n");
        $timeout = 120
    }
	
	
    fetch_url_cb($twitterurl,$twitterrss);
	
    # Reschedule timeout
    Purple::Debug::info("twitter Status Feed", "Rescheduling timer.\n");
    Purple::timeout_add($plugin, $timeout, \&timeout_cb, $plugin);
    Purple::Debug::info("twitter Status Feed", "New timer set for " . $timeout . " seconds.\n");
    
}

sub plugin_init {
    return %PLUGIN_INFO;
}

sub plugin_load {
    my $plugin = shift;
    Purple::Debug::info("Twitter Status Feed", "plugin_load() - Twitter Status Loaded.\n");
    
    # Here we are adding a set of preferences
    # The second argument is the default value for the preference.
    Purple::Prefs::add_none("/plugins/core/gtk-mattack-twitterstatus");
    Purple::Prefs::add_string("/plugins/core/gtk-mattack-twitterstatus/twitterrss", "");
    Purple::Prefs::add_bool("/plugins/core/gtk-mattack-ideinticastatus/onidleonly", "");
    Purple::Prefs::add_bool("/plugins/core/gtk-mattack-twitterstatus/onaway","");
    Purple::Prefs::add_string("/plugins/core/gtk-mattack-twitterstatus/timeout", "120");
    Purple::Prefs::add_bool("/plugins/core/gtk-mattack-twitterstatus/replies","");
    Purple::Prefs::add_bool("/plugins/core/gtk-mattack-twitterstatus/tags","1");

    # Schedule a timeout for 1 second from now
    Purple::timeout_add($plugin, 10, \&timeout_cb, $plugin);
}

sub plugin_unload {
    my $plugin = shift;
    Purple::Debug::info("Twitter Status Feed", "plugin_unload() - Twitter Status Unloaded.\n");
}

sub prefs_info_cb {
    # The first step is to initialize the Purple::Pref::Frame that will be returned
    $frame = Purple::PluginPref::Frame->new();

    # Create a new boolean option with a label "Boolean Label" and then add
    # it to the frame
    $ppref = Purple::PluginPref->new_with_label("Twitter Account Information");
    $frame->add($ppref);

    # Create a text box.  The default value will be "Foobar" as set by
    # plugin_load
    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/gtk-mattack-twitterstatus/twitterrss", "Twitter RSS feed");
    $ppref->set_type(2);
    $ppref->set_max_length(120);
    $frame->add($ppref);
	
    # Adding the timeout box
    $tpref = Purple::PluginPref->new_with_name_and_label("/plugins/core/gtk-mattack-twitterstatus/timeout", "Timeout Period");
    #TODO: look to see if this type can be automatically set to be an integer so we don't need to parse it later
    $tpref->set_type(2);
    $tpref->set_max_length(3);
    $frame->add($tpref);

    # Update on Away
    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/gtk-mattack-twitterstatus/onaway", "Preserve Pidgin status when extended away");
    $ppref -> set_type(3);
    $frame->add($ppref);

    # Use @replies?
    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/gtk-mattack-twitterstatus/replies", 'Use @replies for status messages');
    $ppref -> set_type(3);
    $frame->add($ppref);

    # remove #tag markup?
    $ppref = Purple::PluginPref->new_with_name_and_label (
        "/plugins/core/gtk-mattack-twitterstatus/tags", 'Remove #tag markup from status messages');
    $ppref -> set_type(3);
    $frame->add($ppref);

    return $frame;
}

