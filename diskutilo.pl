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
#diskutilo: $jid, $name, @groups, [$presence, $resources, $prio, $info], vcard.

#@account

my $account = jabber->new("megavac", "megavac.ath.cx", "5222", "huHuhu", "diskutilo", \&on_chat);
#my $account = jabber->new("fremo", "jabber.org", "5222", "", "diskutilo");
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
#    $account->add_contact("fred\@megavac.ath.cx", "MOI");
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
	$account->add_contact($jid, $name);
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
#    $account->{username} = $username_widget->get_text();
#    $account->{hostname} = $hostname_widget->get_text();
#    $account->{port} = $port_widget->get_text();
#    $account->{resource} = $resource_widget->get_text();
#    $account->{password} = $password_widget->get_text();
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
