#  Copyright (C) 2010  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

# Stanislav Sinyagin <ssinyagin@k-open.com>

# Apache mod_perl handler. See http://perl.apache.org

package Torrus::Apache2Handler;

use strict;
use warnings;

use Apache2::Const -compile => qw(:common);

use Torrus::CGI;

sub handler : method
{
    my($class, $r) = @_;

    # Before torrus-1.0.9, Apache2 handler was designed
    # for "SetHandler modperl". Now it should be used with perl-script
    # handler only
    
    if( $r->handler() ne 'perl-script')
    {
        $r->content_type('text/plain');
        $r->print("Apache configuration must be changed.\n");
        $r->print("The current version ot Torrus is incompatible with ");
        $r->print("\"SetHandler modperl\" statement.\n");
        $r->print("Change it to:\n");
        $r->print("  SetHandler perl-script\n");
        return Apache2::Const::OK;
    }
    
    my $q = CGI->new($r);
    Torrus::CGI->process( $q );

    return Apache2::Const::OK;    
}



1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
