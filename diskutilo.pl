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
my $main_win;
my $conf_win;
my $add_win;
my $add_nb;
my $state;
my $contacts;

my $add_account_username;
my $add_account_hostname;
my $add_account_port;
my $add_account_resource;
my $add_account_password;

my $add_contact_jid;
my $add_contact_name;
my $add_contact_group;

my %chatwin = ();

# Roster:
#jabber: jid, name, subs, groups
#gtk: group- name, presence.
#diskutilo: $jid, $name, @groups, [$presence, $resources, $prio, $info, @history], %vcard.

#Je doit pouvoir retrouver un contact dans ma liste 

#my $jabber = jabber->new("fred", "megavac.ath.cx", "5222", "rigili", "diskutilo", \&on_chat);
my $jabber = jabber->new("megavac", "megavac.ath.cx", "5222", "huHuhu", "diskutilo", \&on_chat);
#my $jabber = jabber->new("fremo", "jabber.org", "5222", "", "diskutilo");
$glade = Gtk2::GladeXML->new("diskutilo.glade");
$glade->signal_autoconnect_from_package('main');
init_gui();
Gtk2->main;
exit 0;

sub init_gui {
    $main_win = $glade->get_widget('main');
    $conf_win = $glade->get_widget('config');
    $add_win  = $glade->get_widget('add');
    $add_nb  = $glade->get_widget('add_nb');
    $add_contact_jid = $glade->get_widget('add_contact_jid');
    $add_contact_name = $glade->get_widget('add_contact_name');
    $add_contact_group = $glade->get_widget('add_contact_group');
    $state   = $glade->get_widget('state');

    my $TV = $glade->get_widget('contacts');
    $contacts = Gtk2::ListStore->new ('Glib::String', 'Glib::String');
    $TV->set_model ($contacts);
    $TV->set_rules_hint (0);
    $TV->set_search_column (0);
    my $renderer = Gtk2::CellRendererText->new;
    my $column = Gtk2::TreeViewColumn->new_with_attributes ("JID",
							    $renderer,
							    text => 1);
    $column->set_sort_column_id (0);
    $TV->append_column ($column);

    $TV->show_all;

#    $contacts->set_headers_clickable(1);
#    foreach ($contacts->get_columns()) {
#        $_->set_resizable(1);
#        $_->set_sizing('grow-only');
#    }
    $state->set_active(0);
}

sub diskutilo_connect {
    $jabber->Connect() ne -1 or return -1;

    if($jabber->Get_roster() == -1)
    {
	print "HEEEUUUERRR ! no roster !\n";
    }

    foreach (keys %{$jabber->{roster}})
    {
	my $iter = $contacts->append;
	$contacts->set ($iter, 0, $_, 1, $jabber->{roster}->{$_}->{name});
    }
    return 0;
}

sub diskutilo_disconnect {
    Glib::Source->remove($jabber->{process_ID}) if(defined($jabber->{process_ID}));
      $contacts->clear;
      $jabber->Disconnect();
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

sub on_main_config_button_clicked {
    $conf_win->show;
#    $conf_win->on_top;
}

sub on_main_add_button_clicked {
    $add_win->show;
#    $conf_win->on_top;
}

sub on_main_delete_event {
    Gtk2->main_quit;
}

sub on_add_delete_event {
    my $w = shift;
    $w->hide;
    1;#consume this event!
}

sub on_add_button_clicked {
    my $jid = $add_contact_jid->get_text();
    my $name = $add_contact_name->get_text();

    my $page = $add_nb->get_current_page;

    if($page == 0)
    {
	print "add account\n";
    }
    elsif($page == 1)
    {
	print "add contact: jid: $jid, name: $name\n";
	$jabber->add_contact($jid, $name);
    }
    if($page == 2)
    {
	print "add transport\n";
    }
    $add_win->hide;
}

sub on_config_delete_event {
    my $w = shift;
    $w->hide;
#    $jabber->{username} = $username_widget->get_text();
#    $jabber->{hostname} = $hostname_widget->get_text();
#    $jabber->{port} = $port_widget->get_text();
#    $jabber->{resource} = $resource_widget->get_text();
#    $jabber->{password} = $password_widget->get_text();
    1;#consume this event!
}

sub on_chat_delete {
    my ($widget, $event, $data) = @_;
    my ($jabber, $jid) = @{$data};
    delete $chatwin{$jid};
    0;
}

sub open_chat {
    my ($jabber, $jid) = @_;

    my $chat = Gtk2::Window->new;
    $chat->signal_connect (delete_event => \&on_chat_delete, [$jabber, $jid]);
#$chat->signal_connect (destroy_event => \&on_chat_delete, [$jabber, $jid]);
    $chat->set_title ("Chat with $jid");
    $chat->set_size_request(200, 200);
    my $vbox = Gtk2::VBox->new;
    $chat->add($vbox);
    my $scroller = Gtk2::ScrolledWindow->new;
    $scroller->set_policy (qw(never automatic));

    $vbox->pack_start ($scroller, 1, 1, 0);
    my $recv = Gtk2::TextView->new;
    $recv->can_focus(0);
    $recv->set (editable => 0);
    $recv->set_cursor_visible (0);
    $recv->set (wrap_mode => "word");	
    $scroller->add ($recv);
    my $send = Gtk2::Entry->new;
    $send->set_activates_default(1);
    $send->signal_connect (key_release_event => \&on_chat_key, [$jabber, $jid]);
    $vbox->pack_start ($send, 0, 0, 0);
    $send->grab_focus();
    $chat->show_all;
    $chatwin{$jid} = [$chat, $recv];
}

sub on_contacts_row_activated {
    my $widget = shift;

    my ($path) = $widget->get_cursor;

    my $iter = $contacts->get_iter ($path);
    my ($jid) = $contacts->get ($iter, 0);

    if(exists ($chatwin{$jid}))
    {
	#put chatwin on top;
    }
    else
    {
	open_chat($jabber, $jid);
    }
    return 1; # consume event
}

sub chat_add_text {
    my ($jabber, $jid, $text) = @_;

    open_chat($jabber, $jid) if(!exists $chatwin{$jid});
    my $TV = $chatwin{$jid}[1];
    my $buffer = $TV->get_buffer;
    my $iter = $buffer->get_end_iter;
    $buffer->insert($iter, $text . "\n");
    $iter = $buffer->get_end_iter;
    $TV->scroll_to_iter ($iter, 0, 0, 0, 0)
}

sub on_chat_key {
    my ($widget, $event, $data) = @_;
    my ($jabber, $jid) = @{$data};

    my $keypress = $event->keyval;    
    if ($keypress == $Gtk2::Gdk::Keysyms{KP_Enter} ||
        $keypress == $Gtk2::Gdk::Keysyms{Return}){
	my $body = $widget->get_text();
	if($body ne "")
	{
	    $widget->set_text("");
	    $jabber->send_chat($jid, $body);
	    chat_add_text($jabber, $jid, "mi : " . $body);
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
    my ($jabber, $jid, $body) = @_;
    $jid =~ s!\/.*$!!; # remove any resource suffix from JID
    my $name = $jid;

    my $name = $jabber->{roster}->{$jid}->{name}
    if(defined($jabber->{roster}->{$jid}->{name}));
    chat_add_text($jabber, $jid, $name . ": " . $body);
}
