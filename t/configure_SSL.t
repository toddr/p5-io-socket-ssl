#!perl

use strict;
use warnings;

use Socket ();
use IO::Socket::SSL;

use Test::More tests => 1;

do './testlib.pl' || do './t/testlib.pl' || die "no testlib";

my $PING_PONG_MAX = 20;

my %server_options = (
    SSL_server      => 1,
    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
    SSL_cert_file   => "certs/server-cert.pem",
    SSL_key_file    => 'certs/server-key.pem',
);

my $main_process_id = $$;

$SIG{'USR1'} = sub { };    # do nothing

my $boomer_pid = fork();
die q{Failed to fork} unless defined $boomer_pid;
start_boomer($main_process_id) unless $boomer_pid;

for ( 1 .. 100 ) {
    my ( $kid, $parent ) = set_up_socket_for_ping_pong();
    undef $parent;
    waitpid $kid, 0;

}
ok( 1, "We survive without any errors\n" );

kill 9, $boomer_pid;
waitpid $boomer_pid, 0;

done_testing();
exit;

sub start_boomer {
    my $parent_pid = shift;

    while (1) {    # let's spam it
        kill 'USR1', $parent_pid;
        select( undef, undef, undef, 0.01 );
    }

    return;
}

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
        IO::Socket::SSL->start_SSL( $client, SSL_verify_mode => 0 )
          or die "CanÕt upgrade child to SSL: $IO::Socket::SSL::SSL_ERROR";

        _ping_pong( $client, $client );
        exit;
    }

    ##### Parent process
    $parent_socket->blocking(0);

    diag sprintf( "CHILD ($pid) = %s, PARENT ($$) = %s", fileno($client), fileno($parent_socket) );
    my $started_ssl = 0;
    while ( !$started_ssl ) {
        if ( IO::Socket::SSL->start_SSL( $parent_socket, %server_options ) ) {
            $started_ssl = 1;
        }
        else {
            next if $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_READ;
            die "Cannot upgrade parent to SSL: $IO::Socket::SSL::SSL_ERROR";
        }
    }

    close $client;

    return ( $pid, $parent_socket );
}

sub _ping_pong {
    my ( $in_fh, $out_fh ) = @_;

    foreach my $num ( 1 .. $PING_PONG_MAX ) {
        syswrite( $out_fh, "$num\n" );
    }

    undef($in_fh);
    undef($out_fh);

    return;
}
