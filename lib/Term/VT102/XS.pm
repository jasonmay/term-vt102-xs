package Term::VT102::XS;
use strict;
use warnings;

our $VERSION = '0.01';
use base 'Term::VT102';

require XSLoader;
XSLoader::load('Term::VT102::XS', $VERSION);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Term::VT102::XS - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Term::VT102::XS;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Term::VT102::XS, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

jasonmay, E<lt>jasonmay@localE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by jasonmay

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
