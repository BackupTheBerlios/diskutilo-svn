package jabber;
use strict;
use warnings;
use Net::Jabber qw (Client);
#Imagine un lien vers une chatroom pour discuter de la page en cours
#A coté du lien, il pourait etre affiché le nombre de membres et les
#derniere choses qui ont été dites, tout simple, non ?

my %accounts = {};

sub new
{
    my ($class,$username,$hostname,$port,$password,$resource, $on_chat) = @_;
    my $this = {};
    bless($this, $class);
    $this->{connection} = undef;
    $this->{username} = $username;
    $this->{hostname} = $hostname;
    $this->{port} = $port;
    $this->{password} = $password;
    $this->{resource} = $resource;
    $this->{on_chat} = $on_chat;

    return $this;
}

sub Connect {
    my ($this) = @_;

    print "this: $this\n";

    if(defined $this->{connection})
    {
	print "Already connected Coco ! ($!)\n";
	return -1;
    }

    $this->{connection} = Net::Jabber::Client->new();
    $this->{connection}->Connect( "hostname" => $this->{hostname},
	"port" => $this->{port} );

    if(!$this->{connection}->Connected())
    {
	print "Cannot connect gal ! ($!)\n";
	return -1;
    }

    my @result = $this->{connection}->AuthSend( "username" => $this->{username},
	"password" => $this->{password},
	"resource" => $this->{resource});
    if($result[0] ne "ok")
    {
	print "Cannot authenticate dude ! ($!)\n";
	return -1;
    }

    $this->{connection}->SetCallBacks(message => \&jabber_callback_message,
	presence => \&jabber_callback_presence,
	iq => \&jabber_callback_IQ);

    $this->{connection}->PresenceSend(type=>"available", show=>"available");
    $this->{process_ID} = Glib::Timeout->add(200,
	sub {$this->{connection}->Process(0);1;});

    my $jid = $this->{username}."@".$this->{hostname}."/".$this->{resource};
    $accounts{$jid} = $this;

    return 0;
}

sub Get_roster { 
    my ($this) = @_;
    my %roster = $this->{connection}->RosterGet();
    $this->{roster} = \%roster;
    return 0;
}

sub Disconnect {
    my ($this) = @_;

    return -1 if(!defined $this->{connection});
    $this->{connection}->Disconnect();
    $this->{connection} = undef;

    my $jid = $this->{username}."@".$this->{hostname}."/".$this->{resource};
    delete $accounts{$jid};

    return 0;
}

sub send_chat {
    my ($this, $JID, $body) = @_;

    my $msg = Net::Jabber::Message->new();
    $msg->SetMessage( "to" => $JID,
		      "type" => "chat",
		      "body" => $body);
    $this->{connection}->Send($msg);
}

sub jabber_callback_message
{
    my $sid = shift;
    my $message = shift;

    my $type = $message->GetType();
    my $fromJID = $message->GetFrom("jid");
    my $toJID = $message->GetTo("jid");
    my $from = $message->GetFrom();
    my $to = $message->GetTo();

#    my $from = $fromJID->GetUserID();
#    my $to = $toJID->GetUserID();
    my $resource = $fromJID->GetResource();
    my $subject = $message->GetSubject();
    my $body = $message->GetBody();

    $accounts{$to}->{on_chat}($accounts{$to}, $from, $body);

#    $this->{on_chat}($this, $from, $body);

    print "===\n";
    print "Message ($type)\n";
    print "  From: $from/$fromJID ($resource)\n";
    print "  To: $to/$toJID ($resource)\n";
    print "  Subject: $subject\n";
    print "  Body:\n$body\n";
#    print "===\n";
#    print $message->GetXML(),"\n";
#    print "===\n";
}

sub jabber_callback_presence
{
    my $sid = shift;
    my $presence = shift;

    my $from = $presence->GetFrom();
    my $type = $presence->GetType();
    my $status = $presence->GetStatus();
#    print "===\n";
#    print "Presence\n";
#    print "  From $from\n";
#    print "  Type: $type\n";
#    print "  Status: $status\n";
#    print "===\n";
#    print $presence->GetXML(),"\n";
#    print "===\n";
}

sub jabber_callback_IQ
{
    my $sid = shift;
    my $iq = shift;
    
    my $from = $iq->GetFrom();
    my $type = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
#    print "===\n";
#    print "IQ\n";
#    print "  From $from\n";
#    print "  Type: $type\n";
#    print "  XMLNS: $xmlns";
#    print "===\n";
#    print $iq->GetXML(),"\n";
#    print "===\n";
}


1;

