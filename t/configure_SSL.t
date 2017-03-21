#!perl

use strict;
use warnings;

use Socket ();
use IO::Socket::SSL;
    
use Test::More;
#BEGIN {
#    require '/usr/local/cpanel/t/Cpanel-Interconnect_signal_intr.t';    ## no critic (RequireBarewordIncludes)
#}

#do './testlib.pl' || do './t/testlib.pl' || die "no testlib";
my $PING_PONG_MAX = 20;

my %server_options = (
    SSL_server    => 1,
    SSL_cert_file => "certs/server-cert.pem",
    SSL_key_file  => 'certs/server-key.pem',
);

for(1..20) {
    my ($kid, $parent) = set_up_socket_for_ping_pong();
    my ($kid2, $parent2) = set_up_socket_for_ping_pong();
    undef $parent;

    ($kid, $parent) = set_up_socket_for_ping_pong();
}
#print {$parent} "Foo\n";
#waitpid($parent, 0);
ok(1, "HERE2\n");


done_testing();
exit;

sub set_up_socket_for_ping_pong {
    socketpair(
        my $client,
        my $parent_socket,
        &Socket::AF_UNIX,
        &Socket::SOCK_STREAM,
        &Socket::PF_UNSPEC
    );

    my $pid = fork;
    
    die("Can't fork") unless defined $pid;
    ##### Child process.
    if ( $pid == 0 ) {
        $client->blocking(0);
        select(undef, undef, undef, 1);
        my $buffer;
        $client->read($buffer, 20, 0);
        is( $SSL_ERROR, SSL_WANT_READ, "Server Nonblocking Check 1");

        sleep 5;
        IO::Socket::SSL->start_SSL($client, SSL_verify_mode => 0 )
            or die "Can’t upgrade child to SSL: $IO::Socket::SSL::SSL_ERROR";
            
        _ping_pong($client, $client);
        exit;
    }
    
    ##### Parent process
    $parent_socket->blocking(0);

    diag sprintf("CHILD ($pid) = %s, PARENT ($$) = %s", fileno($client), fileno($parent_socket));
    my $started_ssl = 0;
    while ( !$started_ssl ) {
        if ( IO::Socket::SSL->start_SSL( $parent_socket, %server_options ) ) {
            $started_ssl = 1;
        }
        else {
            diag ("0------- - $IO::Socket::SSL::SSL_ERROR");
            next if $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_READ;# =~ m{read first}i;
            die "Can’t upgrade parent to SSL: $IO::Socket::SSL::SSL_ERROR";
        }
    }

    close $client;

    return ( $pid, $parent_socket );
}

sub _ping_pong {
    my ( $in_fh, $out_fh  ) = @_;

    #die "need to set report file handle" if !$PING_PONG_REPORT_FH;

    foreach my $num (1..$PING_PONG_MAX) {

        #syswrite( $PING_PONG_REPORT_FH, "$label:$num\n" );
        syswrite( $out_fh,              "$num\n" );
    }


    undef($in_fh);
    undef($out_fh);

    return;
}