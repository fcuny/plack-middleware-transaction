package Plack::Middleware::Transaction;

use strict;
use warnings;

use Data::UUID::LibUUID;
use Sys::Hostname;

use parent qw/Plack::Middleware/;
use Plack::Util::Accessor qw/host/;

sub prepare_app {
    my $self = shift;
    $self->host(hostname());
}

sub call {
    my ( $self, $env ) = @_;

    my $uuid = new_uuid_string();

    my $revision = `git rev-parse HEAD` || undef;
    chomp $revision if ($revision);

    $self->response_cb(
        $self->app->($env),
        sub {
            my $res     = shift;
            my $headers = $res->[1];

            if ($self->host) {
                $self->logger( $env, "[$uuid] is running on host" . $self->host );
                Plack::Util::header_set( $headers, 'X-Hostname', $self->host );
            }

            if ($revision) {
                $self->logger( $env, "[$uuid] is on git revision " . $revision );
                Plack::Util::header_set( $headers, 'X-Revision', $revision );
            }

            $self->logger( $env, "[$uuid] Transaction completed" );
            Plack::Util::header_set( $headers, 'X-Transaction', $uuid );
            return $res;
        }
    );
}

sub logger {
    my ( $self, $env, $message ) = @_;

    if ( $env->{'psgix.logger'} ) {
        $env->{'psgix.logger'}->(
            {
                level   => 'info',
                message => $message,
            }
        );
    }
}

1;
