package Catalyst::Plugin::AtomPP;
use strict;
use base qw/Class::Accessor::Fast/;
use Catalyst::Action;
use Catalyst::Utils;
use XML::Atom::Entry;

our $VERSION = '0.05_01';

__PACKAGE__->mk_accessors(qw/_request_body_raw/);

=head1 NAME

Catalyst::Plugin::AtomPP - Dispatch AtomPP methods with Catalyst.

=head1 SYNOPSIS

  use Catalyst qw/AtomPP/;

  sub entry : Local {
      my ($self, $c) = @_;
      $c->atom;             # dispatch AtomPP methods.
  }

  sub create_entry : Remote {
      my ($self, $c, $entry) = @_;
      # $entry is XML::Atom Object from Request content

      ...
  }

  sub retrieve_entry : Remote {
      my ($self, $c) = @_;

      ...
  }

  sub update_entry : Remote {
      ...
  }

  sub delete_entry : Remote {
      ...
  }

=head1 DESCRIPTION

This plugin allows you to dispatch AtomPP methods with Catalyst.

Require other authentication plugin, if needed.
(Authentication::CDBI::Basic, WSSE, or so)

=head1 AUTO RESPONSE FUTURE

If you set true value at $c->config->{atompp}->{auto_response}, AtomPP plugin set automatically $c->res->status or $c->res->body by value that Remote method returned.

If your remote method return /^\d{3}$/ ( 200 or so ), AtomPP plugin execute $c->res->status( 200 );

Or return XML::Atom::Entry or XML::Atom::Feed object, execute $c->res->body( $xmlatom_obj->as_xml );

Or other not false value returned, then execute $c->res->body( $returnd_value );

=head1 METHODS

=over 4

=cut

sub prepare_body_chunk {
    my ( $c, $chunk ) = @_;

    my $body = $c->request->{_body};
    $body->add( $chunk );

    $c->_request_body_raw( ( $c->_request_body_raw || '' ) . $chunk );
}

=item atom

=cut

sub atom {
    my $c = shift;
    my $method = shift;

    my $class = caller(0);
    ($method = $c->req->action) =~ s!.*/!! unless $method;

    my %prefixes = (
        POST   => 'create_',
        GET    => 'retrieve_',
        PUT    => 'update_',
        DELETE => 'delete_',
    );

    if (my $prefix = $prefixes{$c->req->method}) {
        $method = $prefix.$method;
    } else {
        $c->log->debug(qq!Unsupported Method "@{[$c->req->method]}" called!) if $c->debug;
        $c->res->status(501);
        return;
    }

    $c->log->debug("Method: $method") if $c->debug;

    if (my $code = $class->can($method)) {
        my $pp;

        for my $attr (@{ attributes::get($code) || [] }) {
            $pp++ if $attr eq 'Remote';
        }

        if ($pp) {
            my $content = $c->_request_body_raw;
            my $entry;

            eval{
                $entry = XML::Atom::Entry->new( \$content );
            };

            $c->log->debug( $@ ) if ($c->debug and $@);

            if ($c->req->body and !$entry) {
                $c->log->debug("Request body is not well-formed.") if $c->debug;
                $c->res->status(415);
            } else {
                $class = $c->components->{$class} || $class;
                my @args = @{$c->req->args};
                $c->req->args([$entry]) if $entry;

                my $name = ref $class || $class;
                my $action = Catalyst::Action->new({
                    name      => $method,
                    code      => $code,
                    reverse   => "-> $name->$method",
                    class     => $name,
                    namespace => Catalyst::Utils::class2prefix(
                        $name, $c->config->{case_sensitive}
                    ),
                });
                $c->state( $c->execute( $class, $action ) );

                $c->res->content_type('application/xml; charset=utf-8');

                # set status or body automaticaly
                if ( $c->config->{atompp}->{auto_response} and $c->state ) {
                    if ( $c->state =~ /^(\d{3})$/ ) {
                        $c->log->debug("Auto Status: $1") if $c->debug;
                        $c->res->status( $1 );
                    }
                    elsif ( ref($c->state) =~ /XML::Atom::(Feed|Entry)/ ) {
                        my $xml = $c->state->as_xml;
                        if ($] >= 5.008) {
                            require Encode;
                            Encode::_utf8_off( $xml );
                        }
                        $c->res->body( $xml );
                    }
                    else {
                        $c->res->body( $c->state )
                    }
                }

                $c->res->body($c->state);
                $c->req->args(\@args);
            }
        }

        else {
            $c->log->debug(qq!Method "$method" has no Atom attribute!) if $c->debug;
            $c->res->status(501);
        }
    }

    $c->state;
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::XMLRPC>.

=head1 AUTHOR

Daisuke Murase, E<lt>typester@cpan.orgE<gt>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

1;

