#!/usr/bin/perl -w
#Diskutilo

use strict;
use warnings;

use Gtk2 '-init'; # auto-initialize Gtk2
use Gtk2::GladeXML;
use Gtk2::SimpleList;   # easy wrapper for list views
use Gtk2::Gdk::Keysyms; # keyboard code constants
use jabber;

use open ":utf8";

my $glade;
my $mainwin;
my $confwin;
my $state;
my $contacts;

my $username_widget;
my $hostname_widget;
my $port_widget;
my $resource_widget;
my $password_widget;

my %chatwin = ();

my $account = jabber->new("megavac", "megavac.ath.cx", "5222", "huHuhu", "diskutilo", \&on_chat);
#my $account = jabber->new("fremo", "jabber.org", "5222", "", "diskutilo");
$glade = Gtk2::GladeXML->new("diskutilo.glade");
$glade->signal_autoconnect_from_package('main');
init_gui();
Gtk2->main;
exit 0;

sub init_gui {
    $mainwin = $glade->get_widget('main');
    $confwin = $glade->get_widget('config');
    $state   = $glade->get_widget('state');
    $username_widget = $glade->get_widget('username');
    $username_widget->set_text("megavac");
    $hostname_widget = $glade->get_widget('hostname');
    $hostname_widget->set_text("megavac.ath.cx");
    $port_widget = $glade->get_widget('port');
    $port_widget->set_text("5222");
    $resource_widget = $glade->get_widget('resource');
    $resource_widget->set_text("Diskutilo");
    $password_widget = $glade->get_widget('password');
    $password_widget->set_text("huHuhu");

    my $widget = $glade->get_widget('contacts');
#    my $contacts_model = Gtk2::TreeStore->new(qw/ Glib::String Glib::String /)
#    $contacts = Gtk2::SimpleList->new_with_model( )
    $contacts = Gtk2::SimpleList->new_from_treeview(
        $widget, 'jid' => 'text');
    $contacts->set_headers_clickable(1);
    foreach ($contacts->get_columns()) {
        $_->set_resizable(1);
        $_->set_sizing('grow-only');
    }
    $state->set_active(0);
}

sub diskutilo_connect {
    $account->Connect() ne -1 or return -1;
    
    if($account->Get_roster() == -1)
    {
	print "HEEEUUUERRR ! no roster !\n";
    }

    if(defined($contacts))
    {
	@{$contacts->{data}} = ();
	foreach my $contact (keys %{$account->{roster}})
	    {
		print "contact: $contact, $account->{roster}->{$contact}->{name}\n";
		push @{$contacts->{data}}, [$contact];
	    }
    }
    return 0;
}

sub diskutilo_disconnect {
    Glib::Source->remove($account->{process_ID}) if(defined($account->{process_ID}));
      @{$contacts->{data}} = ();
      $account->Disconnect();
      return 0;
}

sub on_state_changed {
    my ($state) = @_;
    if($state->get_active()==0) # State connected
    {
	diskutilo_connect() == 0 or $state->set_active(1);
    }
    elsif($state->get_active() == 1) # State disconnected
    {
	diskutilo_disconnect();
    }
}

sub on_main_delete_event {
    Gtk2->main_quit;
}

sub on_config_button_clicked {
    $confwin->show;
#    $confwin->on_top;
}

sub on_config_destroy_event {
    my $w = shift;
    $w->hide;
    $account->{username} = $username_widget->get_text();
    $account->{hostname} = $hostname_widget->get_text();
    $account->{port} = $port_widget->get_text();
    $account->{resource} = $resource_widget->get_text();
    $account->{password} = $password_widget->get_text();

    1;#consume this event!
}

sub on_chat_delete {
    my ($widget, $event, $data) = @_;
    my ($account, $jid) = @{$data};
    delete $chatwin{$jid};
    0;
}

sub open_chat {
    my ($account, $jid) = @_;

    my $chat = Gtk2::Window->new;
    $chat->signal_connect (delete_event => \&on_chat_delete, [$account, $jid]);
#$chat->signal_connect (destroy_event => \&on_chat_delete, [$account, $jid]);
    $chat->set_title ("Chat with $jid");
    my $vbox = Gtk2::VBox->new;
    $chat->add($vbox);
    my $scroller = Gtk2::ScrolledWindow->new;
    $scroller->set_policy (qw(never automatic));

    $vbox->add ($scroller);
    my $recv = Gtk2::TextView->new;
    $recv->set (editable => 0);
    $recv->set (wrap_mode => "word");	
    $scroller->add ($recv);
    my $send = Gtk2::Entry->new;
    $send->set_activates_default(1);
    $send->grab_focus;
    $send->signal_connect (key_release_event => \&on_chat_key, [$account, $jid]);
    $vbox->add ($send);
    $chat->show_all;
    $chatwin{$jid} = [$chat, $recv];
}

sub on_contacts_row_activated {
    my $widget = shift;

    my $index = ($widget->get_selected_indices())[0];
    my $jid = $widget->{data}[$index][0];

    return 1 if(exists ($chatwin{$jid}));

    open_chat($account, $jid);

    return 1; # consume event
}

sub on_chat_key {
    my ($widget, $event, $data) = @_;
    my ($account, $jid) = @{$data};

    my $keypress = $event->keyval;    
    if ($keypress == $Gtk2::Gdk::Keysyms{KP_Enter} ||
        $keypress == $Gtk2::Gdk::Keysyms{Return}){
	my $body = $widget->get_text();
	if($body ne "")
	{
	    $widget->set_text("");
	    $account->send_chat($jid, $body);
	    my $buffer = $chatwin{$jid}[1]->get_buffer;
	    my $iter = $buffer->get_end_iter;
	    $buffer->insert($iter, "moi: " . $body . "\n");
	}
	return 1; # consume keypress
    }

    if ($keypress == $Gtk2::Gdk::Keysyms{Escape}) {
	$chatwin{$jid}[0]->destroy;
	delete $chatwin{$jid};
	return 1; # consume keypress
    }
    return 0; # let gtk have the keypress
}

sub on_chat {
    my ($account, $jid, $body) = @_;
    $jid =~ s!\/.*$!!; # remove any resource suffix from JID
    open_chat($account, $jid) if(!exists $chatwin{$jid});
    my $buffer = $chatwin{$jid}[1]->get_buffer;
    my $iter = $buffer->get_end_iter;
    $buffer->insert($iter, $jid . ": " . $body . "\n");
}
