#!/usr/bin/perl -w
#Diskutilo

use strict;
use warnings;

use Gtk2 '-init'; # auto-initialize Gtk2
use Gtk2::GladeXML;
use Gtk2::SimpleList;   # easy wrapper for list views
use Gtk2::Gdk::Keysyms; # keyboard code constants
use XML::Simple qw(:strict);
use Data::Dumper;
use jabber;

#use open ":utf8";

#my %config;
#%accounts by jid
#   $username
#   $hostname
#   $port
#   $resource
#   $password

my %diskutilo;
#%UI
#   $glade
#   $main_main
#   $conf_win

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

my $config_accounts_username;
my $config_accounts_hostname;
my $config_accounts_port;
my $config_accounts_resource;
my $config_accounts_password;

my $add_contact_jid;
my $add_contact_name;
my $add_contact_group;

my $config_accounts_account;

my $jabber;

my %chat_wins = ();

# Roster:
#jabber: jid, name, subs, groups
#gtk: group- name, presence.
#diskutilo: $jid, $name, @groups, [$presence, $resources, $prio, $info, @history], %vcard.

#Je doit pouvoir retrouver un contact dans ma liste 

my $config_file_name = "config";
my $config;
if (-e $config_file_name)
{
    $config = XMLin($config_file_name, ForceArray => 1, KeyAttr => "key");
}

if(defined($config->{accounts}))
{
    foreach (keys(%{$config->{accounts}}))
    {
	add_account($config->{accounts}->{$_});
    }
}

print Dumper($config);
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

    $add_account_username = $glade->get_widget('add_account_username');
    $add_account_hostname = $glade->get_widget('add_account_hostname');
    $add_account_port = $glade->get_widget('add_account_port');
    $add_account_resource = $glade->get_widget('add_account_resource');
    $add_account_password = $glade->get_widget('add_account_password');

    $config_accounts_username = $glade->get_widget('config_accounts_username');
    $config_accounts_hostname = $glade->get_widget('config_accounts_hostname');
    $config_accounts_port = $glade->get_widget('config_accounts_port');
    $config_accounts_resource = $glade->get_widget('config_accounts_resource');
    $config_accounts_password = $glade->get_widget('config_accounts_password');

    $config_accounts_account = $glade->get_widget('config_accounts_account');

    $state   = $glade->get_widget('state');

    my $TV = $glade->get_widget('contacts');
    $contacts = Gtk2::TreeStore->new ('Glib::String', 'Glib::String');
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

sub add_account {
    my ($account) = @_;
    my $jid = $account->{username} . "\@" . $account->{hostname};
    print "Account: $jid\n";
    $jabber->{$jid} = jabber->new($account, \&on_chat);
}

sub diskutilo_connect {
#FIXME: Account
#    my $jabber->{$jid} = %diskutilo->{jabber}

    foreach (keys(%{$jabber}))
    {
	return -1 if(!defined($jabber->{$_}));
	$jabber->{$_}->Connect() ne -1 or return -1;
	if($jabber->{$_}->Get_roster() == -1)
	{
	    print "HEEEUUUERRR ! no roster !\n";
	}
	my $account_iter = $contacts->append(undef);
	$contacts->set ($account_iter, 0, $_, 1, $_);
	foreach my $c (keys %{$jabber->{$_}->{roster}})
	{
	    my $iter = $contacts->append($account_iter);
	    $contacts->set ($iter, 0, $c, 1, $jabber->{$_}->{roster}->{$c}->{name});
	}
    }
    return 0;
}

sub diskutilo_disconnect {
#FIXME: Account
#    my $jabber->{$jid} = %diskutilo->{jabber}

    foreach (keys(%{$jabber}))
    {
	return 0 if(!defined($jabber->{$_}));
	Glib::Source->remove($jabber->{$_}->{process_ID}) if(defined($jabber->{$_}->{process_ID}));
	$contacts->clear;
	$jabber->{$_}->Disconnect();
    }
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
    $config_accounts_account->remove_text(0) while $config_accounts_account->get_model()->iter_n_children() != 0;

    if(defined($config->{accounts}))
    {
	foreach ($config->{accounts})
	{
	    my $jid = $_->{username} . "\@" . $_->{hostname};
	    $config_accounts_account->append_text($jid);
	}
	$config_accounts_account->set_active(0);
    }

    $conf_win->show;
#    $conf_win->on_top;
}

sub on_config_accounts_account_changed {
    my $model = $config_accounts_account->get_model;
    my $iter = $config_accounts_account->get_active_iter;
    my ($jid) = $model->get_value($iter);

    print "jid: $jid\n";

  $config_accounts_username->set_text($config->{accounts}->{$jid}->{username});
  $config_accounts_hostname->set_text($config->{accounts}->{$jid}->{hostname});
  $config_accounts_port->set_text($config->{accounts}->{$jid}->{port});
  $config_accounts_resource->set_text($config->{accounts}->{$jid}->{resource});
  $config_accounts_password->set_text($config->{accounts}->{$jid}->{password});
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

sub fill_it {
    my ($widget, $field_name) = @_;
    my $dialog = Gtk2::Dialog->new ('Message', $main_win, 'destroy-with-parent', 'gtk-ok' => 'none');
    my $label = Gtk2::Label->new ("You have to specify a " . $field_name);
    $dialog->vbox->add ($label);
    $dialog->signal_connect (response => sub { $_[0]->destroy });
    $dialog->show_all;
    $widget->grab_focus;
    return 1;
}

sub on_add_button_clicked {
#FIXME: Account
#    my $jabber->{$jid} = %diskutilo->{jabber}

    my $page = $add_nb->get_current_page;

    if($page == 0)
    {
	print "add account\n";

	my $username = $add_account_username->get_text();
	my $hostname = $add_account_hostname->get_text();
	my $port     = $add_account_port->get_text();
	my $resource = $add_account_resource->get_text();
	my $password = $add_account_password->get_text();

	return fill_it($add_account_username, "username") if($username eq "");
	return fill_it($add_account_hostname, "hostname") if($hostname eq "");
	$port = 5222 if($port eq "");
	$resource = "Diskutilo" if($resource eq "");

	my $jid = $username . "\@" . $hostname;

	$config->{accounts}=() if(!defined($config->{accounts}));
	$config->{accounts}->{$jid}=();

	$config->{accounts}->{$jid}->{username} = $username;
	$config->{accounts}->{$jid}->{hostname} = $hostname;
	$config->{accounts}->{$jid}->{port} = $port;
	$config->{accounts}->{$jid}->{resource} = $resource;
	$config->{accounts}->{$jid}->{password} = $password;

	add_account($config->{accounts}->{$jid});

	print "config: " . XMLout($config, KeyAttr => "key", OutputFile => $config_file_name) . "\n";
    }
    elsif($page == 1)
    {
	my $account = "";#$add_contact_account->get_text();
	my $jid =     $add_contact_jid->get_text();
	my $name =    $add_contact_name->get_text();
	print "add contact: jid: $jid, name: $name\n";
	$jabber->{$account}->add_contact($jid, $name);
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
#    $jabber->{$jid}->{username} = $username_widget->get_text();
#    $jabber->{hostname} = $hostname_widget->get_text();
#    $jabber->{port} = $port_widget->get_text();
#    $jabber->{resource} = $resource_widget->get_text();
#    $jabber->{password} = $password_widget->get_text();
    1;#consume this event!
}

sub on_chat_delete {
    my ($widget, $event, $data) = @_;
    my ($jabber, $jid) = @{$data};
    delete $chat_wins{$jid};
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
    $chat_wins{$jid} = [$chat, $recv];
}

sub on_contacts_row_activated {
    my ($widget) = @_;

#FIXME: check if we are on a contact item

    my ($path) = $widget->get_cursor;

    my $iter = $contacts->get_iter ($path);
    my ($jid) = $contacts->get ($iter, 0);

    if(exists ($chat_wins{$jid}))
    {
	#put chat_wins on top;
    }
    else
    {
	$path->up;
	my $iter = $contacts->get_iter ($path);
	my ($ajid) = $contacts->get ($iter, 0);
	print "ajid: $ajid\n";
	open_chat($jabber->{$ajid}, $jid);
    }
    return 1; # consume event
}

sub chat_add_text {
    my ($jabber, $jid, $text) = @_;

    open_chat($jabber, $jid) if(!exists $chat_wins{$jid});
    my $TV = $chat_wins{$jid}[1];
    my $buffer = $TV->get_buffer;
    my $iter = $buffer->get_end_iter;
    $buffer->insert($iter, $text . "\n");
    $iter = $buffer->get_end_iter;
    $TV->scroll_to_iter ($iter, 0, 0, 0, 0)
}

sub on_chat_key {
    my ($widget, $event, $data) = @_;
    my ($jabber, $jid) = @{$data};

    print "jabber: $jid\n";

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
	$chat_wins{$jid}[0]->destroy;
	delete $chat_wins{$jid};
	return 1; # consume keypress
    }
    return 0; # let gtk have the keypress
}

sub on_chat {
    my ($jabber, $jid, $body) = @_;
    $jid =~ s!\/.*$!!; # remove any resource suffix from JID
    my $name = $jid;

    $name = $jabber->{roster}->{$jid}->{name} if(defined($jabber->{roster}->{$jid}->{name}));
    chat_add_text($jabber, $jid, $name . ": " . $body);
}
