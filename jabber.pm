package jabber;
use strict;
use warnings;
use Net::Jabber qw (Client);
use Data::Dumper;

#we cannot have to connections to the same account:
# fix it by adding resource in the hash key of %account.

#Imagine un lien vers une chatroom pour discuter de la page en cours
#A coté du lien, il pourait etre affiché le nombre de membres et les
#dernière choses qui ont été dites, tout simple, non ?


my %accounts = ();

sub new {
    my ($class, $config, $diskutilo) = @_;
    my $this = {};
    bless($this, $class);
    $this->{connection} = undef;
    $this->{username} = $config->{username};
    $this->{hostname} = $config->{hostname};
    $this->{port} = $config->{port};
    $this->{password} = $config->{password};
    $this->{resource} = $config->{resource};
    $this->{diskutilo} = $diskutilo;
    $accounts{$this->{username}."\@".$this->{hostname}} = $this;
    return $this;
}

sub Connect {
    my ($this) = @_;

    $SIG{ALRM} = sub { print "SIG_ALARMED\n"; 1 };
    alarm 1;
    if(defined $this->{connection}) {
	print "Already connected Coco ! ($!)\n";
	return 0;
    }
    my $connection = Net::Jabber::Client->new();
    $connection->Connect ("hostname" => $this->{hostname},
			  "port" => $this->{port});
    unless($connection->Connected()) {
	print "Cannot connect gal ! ($!)\n";
	return -1;
    }
    my @result = $connection->AuthSend( "username" => $this->{username},
	"password" => $this->{password},
	"resource" => $this->{resource});
    if(not @result or $result[0] ne "ok") {
	print "Cannot authenticate dude ! ($!)\n";
	return -1;
    }
    my %roster = $connection->RosterGet();
    $this->{roster} = \%roster;
    $this->{connection} = $connection;
    $connection->SetCallBacks(presence => \&jabber_callback_presence,
			      message => \&jabber_callback_message,
			      iq => \&jabber_callback_IQ);
    alarm 0;
    return 0;
}

sub show_jabber {
    my ($show) = @_;
    if(grep {$_ eq $show} qw(online chat away dnd xa offline)){
	return "" if($show eq "online");
	return "unavailable" if($show eq "offline");
    }
}

sub Process {
    my ($this) = @_;

    #workaround NET::Jabber hangs
    $SIG{ALRM} = sub { print "SIG_ALARMED\n"; };
    alarm 1;
    $this->{connection}->Process(0);
    alarm 0;
}

sub Disconnect {
    my ($this) = @_;

    return -1 unless(defined $this->{connection});
    $this->{connection}->Disconnect();
    $this->{connection} = undef;
    my $jid = $this->{username}."@".$this->{hostname};#."/".$this->{resource};
    return 0;
}

sub set_state {
    my ($this, $show, $status) = @_;

    if($show eq "offline") {
	$this->Disconnect();
    } else {
	return -1 if($this->Connect() == -1);
	if(grep {$_ eq $show} qw(available chat away dnd xa online)){
	    $this->{connection}->PresenceSend(show=>show_jabber($show), status=>$status);
	}
    }
    return 0;
}

#CONTACT
sub send_chat {
    my ($this, $JID, $body) = @_;

    my $msg = Net::Jabber::Message->new();
    $msg->SetMessage( "to" => $JID, "type" => "chat", "body" => $body);
    $this->{connection}->Send($msg);
}

sub add_contact {
    my ($this, $jid, $name) = @_;
    $name = $jid;# if($name eq "");
    print "JID: $jid\n";
    $this->{connection}->RosterAdd (jid => $jid, name => $name);
    $this->{connection}->Subscription (to => $jid, type => "subscribe");
}

sub contact_set_name {
    my ($this, $name) = @_;

    my $iq = new Net::Jabber::IQ();
    my $query = $iq->NewQuery("jabber:iq:roster");
    $query->SetName($name);
}

sub remove_contact {
    my ($this, $jid) = @_;
    $this->RosterRemove(jid=>$jid);
}

sub jabber_callback_message {
    my $sid = shift;
    my $message = shift;

    my $type = $message->GetType();
    my $fromJID = $message->GetFrom("jid");
#    my $toJID = $message->GetTo("jid");
    my $from = $message->GetFrom();
    my $to = $message->GetTo();
    $to =~ s!\/.*$!!; # remove any resource suffix from JID
    my $resource = $fromJID->GetResource();
    my $subject = $message->GetSubject();
    my $body = $message->GetBody();

    $type = "message" if($type eq "normal");
    $type = "message" unless($type);

    $accounts{$to}->{diskutilo}->on_contact_message($to, $from, $type, $body, $subject);
}

sub jabber_callback_presence {
    my $sid = shift;
    my $presence = shift;

    my $to = $presence->GetTo();
    $to =~ s!\/.*$!!; # remove any resource suffix from JID

    my $from = $presence->GetFrom();
    my $type = $presence->GetType();# availa
    my $status = $presence->GetStatus();
    my $show = $presence->GetShow();

#    print Dumper($presence) if($to eq "error");
#    print Dumper($presence) if($status eq "Online");
#    print $presence->GetXML(),"\n";
#    print "===\n";

    my $state = "unknown";
    #print "===Presence: $from: $to: [$type-$status-$show]\n";
    if($type eq "unavailable") {
	$state = "offline";
    } elsif($type eq "") {
	if($show eq "") {
	    $state = "online";
	} else {
	    $state = $show;
	}
    } elsif($type eq "error") {
	return;
    } else {
	print "===Presence: $from: $to: [$type-$status-$show]\n";
    }
    $accounts{$to}->{diskutilo}->on_contact_presence($to, $from, $state);
}

sub jabber_callback_IQ {
    my $sid = shift;
    my $iq = shift;

    my $to = $iq->GetTo();
    $to =~ s!\/.*$!!; # remove any resource suffix from JID

    my $from = $iq->GetFrom();
    my $type = $iq->GetType();

    print "===IQ: $from: $type\n";

    my $query = $iq->GetQuery();
    if(defined $query) {
	my $xmlns = $query->GetXMLNS();
#	print "  XMLNS: \"$xmlns\"\n";

	if($type eq "get") {
	    my $reply = $iq->Reply();
	    my $reply_query = $reply->GetQuery();
	    if($xmlns eq "jabber:iq:version") {
#		print "RQ: $reply_query\n";
#		my $item = $reply_query->AddItem();
#		$item->SetItem(os => "Bidux");
#		$reply_query->SetOS(); #Net::jabber do not allow us to modify it...
		$reply_query->SetName("Diskutilo");
		$reply_query->SetVersion();
	    }
	    $accounts{$to}->{connection}->Send($reply);
	}
    }
#    print "XML:" .  $iq->GetXML() . "\n";
}

1;
