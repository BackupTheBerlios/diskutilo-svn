package gui_glade;
use strict;
use warnings;
use Gtk2 '-init'; # auto-initialize Gtk2
use Gtk2::GladeXML;
use Gtk2::SimpleList;   # easy wrapper for list views
use Gtk2::Gdk::Keysyms; # keyboard code constants
use Gtk2::TrayIcon;
#use Gtk2::TrayIcon;
use XML::Simple qw(:strict);
use Data::Dumper;

use constant ROSTER_COL_ID => 0; #Account, Group, contact|agent
use constant ROSTER_COL_TYPE => 1;
use constant ROSTER_COL_NAME => 2;
use constant ROSTER_COL_STATE => 3;

#Images pour les status
#Fenetre de Messages
#Roster editable
#ADD et CONFIG
#menus a tous les étages

#SSL
#GPG
#PROXY

#White board
#ChatWorld

my @diskutilo_xpm = (
'16 16 5 1',
'       c None',
'.      c #050B00',
'+      c #FAFDF9',
'@      c #C4E1AC',
'#      c #ACD38A',
'       ..       ',
'      .+@.      ',
'     .+@@@.     ',
'     .+@@@.     ',
' ....+@@@@@.... ',
'.+++@@@@@@@@@##.',
'.+@@@@@@@@@@###.',
' .@@@@@@@@@###. ',
'  .@@@@@@@###.  ',
'   .@@@@@###.   ',
'   .#@@#####.   ',
'  .##########.  ',
'  .####..####.  ',
'  .###.  .###.  ',
'   ...    ...   ',
'                ');


sub ontop {
    my ($win) = @_;
    $win->show;
    my $gdkwin = $win->window;
    $gdkwin->focus(1);
}

sub new {
    my ($class, $config, $diskutilo) = @_;
    my $this = {};
    bless($this, $class);

    $this->{glade} = Gtk2::GladeXML->new("diskutilo.glade");
    #ADD
    $this->{add}->{win}      = $this->{glade}->get_widget('add');
    $this->{add}->{win}->signal_connect (delete_event => sub{on_delete_hide(@_);1});
    $this->{add}->{notebook} = $this->{glade}->get_widget('add_nb');
    $this->{add}->{cancel} = $this->{glade}->get_widget('add_cancel');
    $this->{add}->{cancel}->signal_connect (clicked => sub{$this->on_add_cancel;1});
    $this->{add}->{ok} = $this->{glade}->get_widget('add_ok');
    $this->{add}->{ok}->signal_connect (clicked => sub{$this->on_add_ok;1});

    #ADD_ACCOUNT
    $this->{add}->{account}->{jid}      = $this->{glade}->get_widget ('add_account_jid');
    $this->{add}->{account}->{jid}->signal_connect(key_release_event => sub{$this->on_add_account_jid;1});
    $this->{add}->{account}->{password} = $this->{glade}->get_widget ('add_account_password');
    $this->{add}->{account}->{advanced} = $this->{glade}->get_widget ('add_account_advanced');
    $this->{add}->{account}->{advanced}->signal_connect (pressed => sub{$this->on_add_account_advanced(@_);1;});
    $this->{add}->{account}->{advanced_settings} = $this->{glade}->get_widget ('add_account_advanced_settings');
    $this->{add}->{account}->{hostname} = $this->{glade}->get_widget ('add_account_hostname');
    $this->{add}->{account}->{port}     = $this->{glade}->get_widget ('add_account_port');
    $this->{add}->{account}->{resource} = $this->{glade}->get_widget ('add_account_resource');
    $this->{add}->{account}->{state}    = $this->{glade}->get_widget ('add_account_state');
    $this->{add}->{account}->{ssl}      = $this->{glade}->get_widget ('add_account_ssl');
#    $this->{add}->{account}->{auto_reconnect} = $this->{glade}->get_widget ('add_account_auto_reconnect');
    #ADD_CONTACT
    $this->{add}->{contact}->{jid}   = $this->{glade}->get_widget ('add_contact_jid');
    $this->{add}->{contact}->{name}  = $this->{glade}->get_widget ('add_contact_name');
    $this->{add}->{contact}->{group} = $this->{glade}->get_widget ('add_contact_group');

    #CONFIG
    $this->{config}->{win} = $this->{glade}->get_widget ('config');
    $this->{config}->{win}->signal_connect (delete_event => sub{on_delete_hide(@_);1});
    $this->{config}->{notebook} = $this->{glade}->get_widget ('config_NB');
    #CONFIG_ACCOUNTS
    $this->{config}->{accounts}->{account}  = $this->{glade}->get_widget ('config_accounts_account');
    $this->{config}->{accounts}->{jid}      = $this->{glade}->get_widget ('config_accounts_jid');
    $this->{config}->{accounts}->{hostname} = $this->{glade}->get_widget ('config_accounts_hostname');
    $this->{config}->{accounts}->{port}     = $this->{glade}->get_widget ('config_accounts_port');
    $this->{config}->{accounts}->{password} = $this->{glade}->get_widget ('config_accounts_password');
    $this->{config}->{accounts}->{resource} = $this->{glade}->get_widget ('config_accounts_resource');
    $this->{config}->{accounts}->{ssl}      = $this->{glade}->get_widget ('config_accounts_ssl');

    #MAIN
    $this->{main}->{win} = $this->{glade}->get_widget ('main');
    $this->{main}->{win}->signal_connect (destroy => sub{Gtk2->main_quit;1});
    $this->{main}->{add} = $this->{glade}->get_widget ('main_add');
    $this->{main}->{add}->signal_connect (clicked => sub{$this->on_add_show;1});
    $this->{main}->{state} = $this->{glade}->get_widget ('main_state');
    $this->{main}->{state}->signal_connect (changed => sub{$this->on_main_state_changed(@_);1});
    $this->{main}->{config} = $this->{glade}->get_widget ('main_config');
    $this->{main}->{config}->signal_connect (clicked => sub{ontop($this->{config}->{win});1});
    $this->{main}->{contacts}->{model} = Gtk2::TreeStore->new ('Glib::String', 'Glib::String', 'Glib::String', 'Glib::String');
    $this->{main}->{contacts}->{treeview} = $this->{glade}->get_widget ('main_contacts');
    $this->{main}->{contacts}->{treeview}->signal_connect (row_activated => sub{$this->on_contact_row_activated(@_);1});

    $this->{window_group} = Gtk2::WindowGroup->new;
    $this->{window_group}->add_window ($this->{add}->{win});
    $this->{window_group}->add_window ($this->{main}->{win});
    $this->{window_group}->add_window ($this->{config}->{win});

    #Roster
    $this->{main}->{contacts}->{treeview}->set_model ($this->{main}->{contacts}->{model});
    #ROSTER:COLUMN STATE
    my $renderer = Gtk2::CellRendererPixbuf->new;
    my $column = Gtk2::TreeViewColumn->new_with_attributes ("State", $renderer); 
    
    $this->{main}->{contacts}->{treeview}->append_column ($column);
    #ROSTER:COLUMN NAME/ID
    $renderer = Gtk2::CellRendererText->new;
    $column = Gtk2::TreeViewColumn->new_with_attributes ("Name", $renderer, 'text' => ROSTER_COL_NAME);
    $this->{main}->{contacts}->{treeview}->append_column ($column);
    #
    $this->{main}->{contacts}->{treeview}->signal_connect_after (button_release_event => sub{$this->on_contact_menu(@_);1});
    $this->{main}->{contacts}->{treeview}->show_all;

    # create tray icon
    my $icon = Gtk2::TrayIcon->new('Diskutilo');
    my $iconEB = Gtk2::EventBox->new;
    # attach event to tray icon to show menu
    $iconEB->signal_connect("button-release-event", sub{$this->on_icon_menu(@_);1});
    # adding tray icon image
    my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_xpm_data (@diskutilo_xpm);
    my $image = Gtk2::Image->new_from_pixbuf ($pixbuf);
    $iconEB->add($image);
    $icon->add($iconEB);
    $icon->show_all;

    $this->{chat_wins} = ();

    $this->{diskutilo} = $diskutilo;
    $this->load_icons("icons");

    return $this;
}

#piano russe orovitz

sub load_icons {
    my ($this, $dir_name) = @_;
    my $file_name = $dir_name . "/icondef.xml";

#    my $iconset = XMLin($file_name, ForceArray => 1, KeyAttr => "x") if (-e $file_name);
#    print Dumper($iconset);

#    foreach (@{$iconset->{icon}}) {
#	print "object: $_->{content}: " foreach (@{$_->{object}});
#	print "x: $_->{xmlns}: $_->{content}\n" foreach (@{$_->{x}});
#    }

    foreach (qw/offline xa dnd away chat online/) {
	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file ($_.".png");
	$this->{state_icon}->{$_} = \$pixbuf;
    }
}

sub main {
    Gtk2->main;
}

#MAIN
sub on_icon_menu {
    my ($this, $widget, $event) = @_;

    print "on_icon_menu: " . $event->type . "\n";
    #afficher les properties.

    if($event->button() == 3) {
	my $menu = Gtk2::Menu->new();
	menu_append($menu, "Quit", sub{1});
	my $submenu = Gtk2::Menu->new();
	menu_append($submenu, "OffLine", sub{$this->{diskutilo}->set_state("offline");1});
	menu_append($submenu, "xa", sub{$this->{diskutilo}->set_state("xa");1});
	menu_append($submenu, "dnd", sub{$this->{diskutilo}->set_state("dnd");1});
	menu_append($submenu, "away", sub{$this->{diskutilo}->set_state("away");1});
	menu_append($submenu, "Chat", sub{$this->{diskutilo}->set_state("chat");1});
	menu_append($submenu, "Online"=>sub{$this->{diskutilo}->set_state("online");1});
	menu_append($menu, "State", $submenu);
	$menu->popup(undef, undef, undef, undef, $event->button,$event->time);
	return 1;
    }
    return undef;
}

sub add_account {
    my ($this, $ajid, $name) = @_;
    $name = $ajid if(!defined($name) or $name eq "");
    my $iter = $this->{main}->{contacts}->{model}->append(undef);
    $this->{main}->{contacts}->{model}->set ($iter, ROSTER_COL_ID, $ajid, ROSTER_COL_NAME, $name);
}

sub del_account {
    my ($this, $ajid) = @_;
    my $iter = $this->account_iter($ajid);
    $this->{main}->{contacts}->{model}->remove ($iter);    
}

sub on_main_state_changed {
    my ($this, $widget) = @_;
    my $states = { 0 => "online", 1 => "chat", 2 => "dnd", 3 => "xa", 4 => "away", 5 => "offline"};
    $this->{diskutilo}->set_global_state($states->{$widget->get_active});
}

sub set_account_state {
    my ($this, $ajid, $state, $process) = @_;
    my $iter = $this->account_iter($ajid);

#    $this->{main}->{contacts}->{model}->set ($iter, ROSTER_COL_STATE, $this->{state_icon}->{$state});

    if($state eq "unavailable") {
	#FIXME: update chat wins
	my $iter = $this->{main}->{contacts}->{model}->iter_children($this->account_iter($ajid));
	while(defined($iter)) {
	    my $iter_remove = $iter;
	    $iter = $this->{main}->{contacts}->{model}->iter_next($iter);
	    $this->{main}->{contacts}->{model}->remove ($iter_remove);
	}
	if(defined($this->{$ajid}->{process_ID})) {
	    Glib::Source->remove($this->{$ajid}->{process_ID});
	}
    } else {
	$this->{$ajid}->{process_ID} = Glib::Timeout->add(200, $process);
    }
}

#ROSTER
sub on_contact_presence {
    my ($this, $ajid, $fjid, $state) = @_;
    my $jid = $fjid;
    $jid =~ s!\/.*$!!;
    my $iter = $this->contact_iter($ajid, $jid);
    $iter = $this->add_contact($ajid, $jid) unless(defined($iter));
    if($state eq "unavailable") {
	$this->{main}->{contacts}->{model}->remove ($iter);
	if(defined($this->{chat_wins}->{$ajid}->{$jid})) {
	    $this->{chat_wins}->{$ajid}->{$jid}->{win}->destroy;
	    delete $this->{chat_wins}->{$ajid}->{$jid};
	}
    } else {
#	$this->{main}->{contacts}->{model}->set ($iter, ROSTER_COL_STATE, $this->{state_icon}->{$state});
    }
}

sub on_contact_row_activated {
    my ($this, $widget) = @_;
    my ($path) = $widget->get_cursor;    
    my ($ajid, $jid) = $this->get_account_contact($path);
    print "ajid: $ajid, jid: $jid\n";
    $this->open_chat($ajid, $jid) if(defined($jid));
}

sub on_contact_menu {
    my ($this, $widget, $event) = @_;

    if($event->button() == 3) {
	my ($x,$y) = $event->get_coords;
	my ($path, $column, $px, $py) = $widget->get_path_at_pos($x,$y);
	my ($ajid, $jid) = $this->get_account_contact($path);
	if(defined($ajid)) {
	    my $menu = Gtk2::Menu->new();
	    if(defined($jid)) {
		menu_append($menu, "Delete", sub{1});
		menu_append($menu, "Chat", sub{$this->open_chat($ajid, $jid)});
	    } else {
		menu_append($menu, "Delete", sub{$this->{diskutilo}->del_account($ajid)});
		my $submenu = Gtk2::Menu->new();
		menu_append($submenu, "OffLine", sub{$this->{diskutilo}->set_account_state($ajid, "offline");1});
		menu_append($submenu, "xa", sub{$this->{diskutilo}->set_account_state($ajid, "xa");1});
		menu_append($submenu, "dnd", sub{$this->{diskutilo}->set_account_state($ajid, "dnd");1});
		menu_append($submenu, "away", sub{$this->{diskutilo}->set_account_state($ajid, "away");1});
		menu_append($submenu, "Chat", sub{$this->{diskutilo}->set_account_state($ajid, "chat");1});
		menu_append($submenu, "Online"=>sub{$this->{diskutilo}->set_account_state($ajid, "online");1});
		menu_append($menu, "State", $submenu);
	    }
	    $menu->popup(undef, undef, undef, undef, $event->button,$event->time);
	    return 1;
	}
    }
    return undef;
}

#COMMIT
sub config_commit {
}

#ADD
sub on_add_show {
    my ($this) = @_;

    $this->{add}->{account}->{port}->set_text("5222");
    $this->{add}->{account}->{resource}->set_text("diskutilo");    
    ontop($this->{add}->{win});
}

sub on_add_cancel {
    my ($this) = @_;
    #clean add fields
    $this->{add}->{win}->hide;
    return 1;
}

sub on_add_ok {
    my ($this) = @_;
    my $keep = 0;
    my $page = $this->{add}->{notebook}->get_current_page;
    $keep = $this->on_add_account if($page == 0);
    $keep = $this->on_add_contact if($page == 1);
    $this->{add}->{win}->hide if($keep==0);
    return 1;
}

sub on_add_account_advanced {
    my ($this) = @_;

    if($this->{add}->{account}->{advanced}->get_active == 0) {
	$this->{add}->{account}->{advanced_settings}->set_sensitive(1);
    } else {
	$this->{add}->{account}->{advanced_settings}->set_sensitive(0);
    }
}

sub on_add_account_jid {
    my ($this, $pad, $event) = @_;

    if($this->{add}->{account}->{advanced}->get_active == 0) {
	my $jid = $this->{add}->{account}->{jid}->get_text;
	my ($username,$hostname,$port,$resource) = JID2UHPR($jid);
	$this->{add}->{account}->{hostname}->set_text($hostname) if($hostname);
	$this->{add}->{account}->{port}->set_text($port) if($port);
	$this->{add}->{account}->{resource}->set_text($resource) if($resource);
    }
}

sub on_add_account {
    my ($this) = @_;
    my $config = ();

    my $jid = $this->{add}->{account}->{jid}->get_text;
    my ($username,$hostname,$port,$resource) = JID2UHPR($jid);

    $this->{add}->{account}->{hostname}->set_text($hostname) if($hostname);
    $this->{add}->{account}->{port}->set_text($port) if($port);
    $this->{add}->{account}->{resource}->set_text($resource) if($resource);

    $config->{username} = $username;
    $config->{hostname} = $this->{add}->{account}->{hostname}->get_text;
    $config->{hostname} = $hostname if(!$config->{hostname} and $hostname);
    $config->{port}     = $this->{add}->{account}->{port}->get_text;
    $config->{port}     = $port if(!$config->{port} and $port);
    $config->{password} = $this->{add}->{account}->{password}->get_text;
    $config->{resource} = $this->{add}->{account}->{resource}->get_text;
    $config->{resource} = $resource if(!$config->{resource} and $resource);
    $config->{ssl}      = $this->{add}->{account}->{ssl}->get_active;
    return $this->fill_it($this->{add}->{account}->{jid}, "Jabber ID") if(!$username or !$hostname);
    return $this->fill_it($this->{add}->{account}->{hostname}, "Hostname") if($config->{hostname} eq "");
    $config->{port} = 5222 if($config->{port} eq "");

    my $ajid = $config->{username} . "\@" . $config->{hostname};
    $this->{diskutilo}->add_account($ajid, $config);
    return 0;#return DONOTKEEPITOPEN
}

sub add_contact {
    my ($this, $ajid, $jid) = @_;
    my ($name) = $this->{diskutilo}->get_contact_roster_info($ajid, $jid);
    my $iter = $this->{main}->{contacts}->{model}->append($this->account_iter($ajid));
    $name = $jid if(not defined($name) or $name eq "");
    $this->{main}->{contacts}->{model}->set ($iter, ROSTER_COL_ID, $jid, ROSTER_COL_NAME, $name);
    return $iter;
}

#CHAT
sub open_chat {
    my ($this, $ajid, $jid) = @_;

    if(exists ($this->{chat_wins}->{$ajid}->{$jid})) {
	ontop($this->{chat_wins}->{$ajid}->{$jid}->{win});
    } else {
	my $glade = Gtk2::GladeXML->new("diskutilo-chat.glade");
	$this->{chat_wins}->{$ajid}->{$jid}->{win} = $glade->get_widget("chat");
	$this->{chat_wins}->{$ajid}->{$jid}->{win}->signal_connect (delete_event => sub{return $this->on_chat_delete($ajid, $jid)});
	$this->{window_group}->add_window ($this->{chat_wins}->{$ajid}->{$jid}->{win});
	$this->{chat_wins}->{$ajid}->{$jid}->{win}->set_title($jid);
	$this->{chat_wins}->{$ajid}->{$jid}->{conv} = $glade->get_widget("conv");
	$this->{chat_wins}->{$ajid}->{$jid}->{conv}->set (wrap_mode => "word");	

	my $pad = $glade->get_widget("pad"); #isn't "pad" a good name ?
	$pad->signal_connect(key_release_event => sub{return $this->on_pad_key_release($ajid, $jid, @_)});
	$pad->signal_connect(key_press_event => sub{return $this->on_pad_key_press($ajid, $jid, @_)});
    }
}

sub on_chat_delete {
    my ($this, $ajid, $jid) = @_;
    $this->{chat_wins}->{$ajid}->{$jid}->{win}->hide;
    1;
}

sub on_chat {
    my ($this, $ajid, $fjid, $body) = @_;
    my $jid = $fjid;
    $jid =~ s!\/.*$!!;
    # my ($jid) = ($fjid =~ m!^(.*)\/?.*$!);HTF I can do it ?!!
    # print "on_chat: fjid: $fjid, jid: $jid\n";
    $this->open_chat($ajid, $jid);
    my $buffer = $this->{chat_wins}->{$ajid}->{$jid}->{conv}->get_buffer;
    my $iter = $buffer->get_end_iter;
    if($jid eq $ajid) {
	$buffer->insert($iter, "me: " . $body);
    } else {
	$buffer->insert($iter, "$ajid: " . $body);
    }
    $iter = $buffer->get_end_iter;
    $buffer->insert($iter, "\n");
    $this->{chat_wins}->{$ajid}->{$jid}->{conv}->scroll_to_iter ($iter, 0, 0, 0, 0)
}

sub on_message {
    my ($this, $ajid, $fjid, $subject, $body) = @_;
    my $jid = $fjid;
    $jid =~ s!\/.*$!!;
    print "MESSAGE !";
    $this->on_chat($ajid, $fjid, $body);
}

sub on_headline {
    my ($this, $ajid, $fjid, $subject, $headline) = @_;
}

#HTF I can have the type of the event ?!!
sub on_pad_key_release {
    my ($this, $ajid, $jid, $pad, $event) = @_;
    my $keyval = $event->keyval;    

    if ($keyval == $Gtk2::Gdk::Keysyms{KP_Enter} ||
	$keyval == $Gtk2::Gdk::Keysyms{Return}){
	my $body = $pad->get_text();
	if($body ne "") {
	    $pad->set_text("");
	    $this->{diskutilo}->send_chat($ajid, $jid, $body);
	    $this->on_chat($ajid, $jid, $body);
	}
	return 1; # consume keyrelease
    }
    return 0; # let gtk have the keypress
}

sub on_pad_key_press {
    my ($this, $ajid, $jid, $pad, $event) = @_;

    if ($event->keyval == $Gtk2::Gdk::Keysyms{Escape}) {
	$this->{chat_wins}->{$ajid}->{$jid}->{win}->hide;
	return 1; # consume keypress
    }
    return 0; # let gtk have the keypress
}

#TOOL
sub on_delete_hide {
    my $win = shift;
    $win->hide;
    1;#consume this event!
}

sub get_account_contact {
    my ($this, $path) = @_;
    my $iter;
    my @who;

    return undef if(!defined($path));

    $iter = $this->{main}->{contacts}->{model}->get_iter ($path);
    unshift(@who, $this->{main}->{contacts}->{model}->get ($iter, ROSTER_COL_ID));
    if($path->get_depth == 2) {
	$path->up;
	$iter = $this->{main}->{contacts}->{model}->get_iter ($path);
	unshift(@who, $this->{main}->{contacts}->{model}->get ($iter, ROSTER_COL_ID));
    }
    return @who;
}

sub account_iter {
    my ($this, $ajid) = @_;
    my $iter = $this->{main}->{contacts}->{model}->get_iter_first;
    while(defined($iter)) {
	return $iter if($this->{main}->{contacts}->{model}->get ($iter, ROSTER_COL_ID) eq $ajid);
	$iter = $this->{main}->{contacts}->{model}->iter_next($iter);
    }
    return undef;
}

sub contact_iter {
    my ($this, $ajid, $jid) = @_;
    my $account = $this->account_iter($ajid);
    my $iter = $this->{main}->{contacts}->{model}->iter_children ($account);
    while(defined($iter)) {
	return $iter if($this->{main}->{contacts}->{model}->get ($iter, ROSTER_COL_ID) eq $jid);
	$iter = $this->{main}->{contacts}->{model}->iter_next($iter);
    }
    return undef;
}

sub fill_it {
    my ($this, $widget, $field_name) = @_;
    my $dialog = Gtk2::Dialog->new ('Message', $this->{main}->{win}, 'destroy-with-parent', 'gtk-ok' => 'none');
    my $label = Gtk2::Label->new ("You have to specify a " . $field_name);
    $dialog->vbox->add ($label);
    $dialog->signal_connect (response => sub { $_[0]->destroy });
    $dialog->show_all;
    $widget->grab_focus;
    return 1;#return KEEPITOPEN
}

sub menu_append {
    my ($menu, $name, $content) = @_;
    my $item = Gtk2::MenuItem->new($name);
    $menu->append($item);
    my ($type) = ref($content);
    if($type =~ /CODE/) {
	$item->signal_connect(activate => $content);
    } else {
	$item->set_submenu($content);
    }
    $item->show();
    return $item;
}

sub JID2UHPR {
    my ($jid) = @_;

    return ($jid =~ m/^([\w.]+)\@([\w.]+)\:?(\d+)?\/?(\w+)?$/);
}

1;
