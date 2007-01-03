#  Copyright (C) 2007  Stanislav Sinyagin
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
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# $Id$
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# This module is an interface to the XML config builder
# It allows to create the Torrus XML config file from
# easy configuration directves (for those afraid of XML mostly)

package Torrus::EasyTarget;

use strict;
use Torrus::Log;
use Torrus::ConfigBuilder;


our @defaultIncludes;
our @defaultTemplates;
our %defaultParams;
     


sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;

    return $self;
}


# takes the configuration hash and builds the XML config
# Key is the node path. If it ends with "/", it's a subtree
# Otherwise it's a leaf
# By default, SNMP collector objects are created
# Other types of objects need to override the default parameters.
# Hash values are hashrefs with parameter=>value pairs.
# Parameters are normal Torrus XML parameters, plus some special
# uppercase words:
#  OUTXML => 'myisp1/targets1.xml'
#  BUNDLE => 'myisp1/easytargets.xml'
#  INCLUDE => 'config1.xml, config2.xml'
#  TEMPLATES => 'custom-template1, custom-template2'
#
# Parameters accepted at global level:
#  OUTXML, BUNDLE, INCLUDE

sub genConfig
{
    my $self = shift;
    my $cfg = shift;
    my $options = shift;

    if( not defined( $options ) )
    {
        $options = {};
    }
    
    my $ok = 1;
    my %outputBundles;
    my %outFiles;
    my %includeFiles;
    
    my $globalOutFile = $cfg->{'OUTXML'};
    if( defined( $globalOutFile ) )
    {
        delete $cfg->{'OUTXML'};
        $globalOutFile = absXmlFilename( $globalOutFile );
    }
        
    foreach my $file ( @defaultIncludes )
    {
        $includeFiles{$file} = 1;
    }
    
    if( defined( $cfg->{'INCLUDE'} ) )
    {
        foreach my $file ( split( /\s+,\s+/, $cfg->{'INCLUDE'} ) )
        {
            $includeFiles{$file} = 1;
        }
    }
    
    my %globalParameters;
    foreach my $param ( keys %defaultParams )
    {
        $globalParameters{$param} = $defaultParams{$param};
    }

    foreach my $node ( sort keys %{$cfg} )
    {
        if( $node !~ /^\// )
        {
            if( $node !~ /\// )
            {
                # This is a global parameter definition
                $globalParameters{$node} = $cfg->{$node};
            }
            else
            {
                Error('Node path must start with slash (/): ' . $node);
                $ok = 0;
            }
        }
        else
        {
            my $outxml = $cfg->{$node}{'OUTXML'};
            if( not defined( $outxml ) )
            {
                $outxml = $globalOutFile;
            }
            if( not defined( $outxml ) )
            {
                Error('Mandatory OUTXML is missing in ' . $node);
                $ok = 0;
            }
            else
            {
                $outxml = absXmlFilename( $outxml );
                
                $outFiles{$outxml}{$node} = 1;

                if( defined( $cfg->{$node}{'BUNDLE'} ) )
                {
                    $outputBundles{absXmlFilename($cfg->{$node}{'BUNDLE'})} =
                        $outxml;
                }
                elsif( defined( $cfg->{'BUNDLE'} ) )
                {
                    $outputBundles{absXmlFilename($cfg->{'BUNDLE'})} =
                        $outxml;
                }

                if( defined( $cfg->{$node}{'INCLUDE'} ) )
                {
                    foreach my $file ( split( /\s+,\s+/,
                                              $cfg->{$node}{'INCLUDE'} ) )
                    {
                        $includeFiles{$file} = 1;
                    }
                }

            }
        }
    }

    if( not $ok )
    {
        Warn('Found errors in the input configuration, the generated ' .
             'results might not appear to be what you expect');
    }

    my $creator = $options->{'Creator'}; 
    if( not defined( $creator ) )
    {
        $creator = 'Generated by EasyTarget';
    }

    my %writtenFiles;
    
    foreach my $outxml ( sort keys %outFiles )
    {
        my $cb = new Torrus::ConfigBuilder;

        $cb->addCreatorInfo( $creator );

        $cb->addRequiredFiles();

        foreach my $file ( sort keys %includeFiles )
        {
            $cb->addFileInclusion( $file );
        }

        foreach my $node ( sort keys %{$outFiles{$outxml}} )
        {
            my $thisIsSubtree = ( $node =~ /\/$/ );
            
            # Chop the first and last slashes
            my $path = $node;
            $path =~ s/^\///;
            $path =~ s/\/$//;

            my @pathElements = split( '/', $path );
            my $nodeElementName = pop( @pathElements );
                
            # generate subtree path XML
            my $subtreeNode = undef;
            foreach my $subtreeName ( @pathElements )
            {
                $subtreeNode = $cb->addSubtree( $subtreeNode, $subtreeName );
            }

            my $params = {};
            my $templates = [];
            
            # Propagate global parameters and templates at the leaf level
            if( not $thisIsSubtree )
            {
                foreach my $param ( keys %globalParameters )
                {
                    $params->{$param} = $globalParameters{$param};
                }
                
                if( defined( $nodeElementName ) )
                {
                    $params->{'rrd-ds'} = $nodeElementName;
                }
             
                push( @{$templates}, @defaultTemplates );
                if( defined( $cfg->{$node}{'TEMPLATES'} ) )
                {
                    push( @{$templates},
                          split( /\s+,\s+/, $cfg->{$node}{'TEMPLATES'} ) );
                }                
            }
                
            foreach my $param ( keys %{$cfg->{$node}} )
            {
                if( $param !~ /^[A-Z]/ )
                {
                    $params->{$param} = $cfg->{$node}{$param};
                }
            }

            if( defined( $nodeElementName ) )
            {
                if( $thisIsSubtree )
                {
                    $cb->addSubtree( $subtreeNode,
                                     $nodeElementName,
                                     $params,
                                     $templates );
                }
                else
                {
                    $cb->addLeaf( $subtreeNode,
                                  $nodeElementName,
                                  $params,
                                  $templates );
                }
            }
            else
            {
                # This is the root subtree
                $cb->addParams( $subtreeNode, $params );
            }
        }

        my $writeOk = $cb->toFile( $outxml );
        if( $writeOk )
        {
            $writtenFiles{$outxml} = 1;
            Verbose('Wrote ' . $outxml);
        }
        else
        {
            Error('Cannot write ' . $outxml . ': ' . $!);
            $writeOk = 0;
        }
        $ok = $writeOk ? $ok : 0;
    }

    foreach my $bundleName ( sort keys %outputBundles )
    {
        my $cb = new Torrus::ConfigBuilder;
        $cb->addCreatorInfo( $creator );

        foreach my $bundleMember
            ( sort keys %{$outputBundles{$bundleName}} )
        {
            if( $writtenFiles{$bundleMember} )
            {
                $cb->addFileInclusion( relXmlFilename( $bundleMember ) );
            }
            else
            {
                Error('The file ' . relXmlFilename( $bundleMember ) .
                      ' was not included in the bundle ' .
                      relXmlFilename( $bundleName ));
            }             
        }
        
        my $writeOk = $cb->toFile( $bundleName );
        if( $writeOk )
        {
            Verbose('Wrote ' . $bundleName);
        }
        else
        {
            Error('Cannot write ' . $bundleName . ': ' . $!);
            $writeOk = 0;
        }
        $ok = $writeOk ? $ok : 0;
    }

    return $ok;
}
            

# Replaces $XMLCONFIG with the XML root directory
sub absXmlFilename
{
    my $filename = shift;

    my $subst = '$XMLCONFIG';
    my $offset = index( $filename, $subst );
    if( $offset >= 0 )
    {
        my $len = length( $subst );
        substr( $filename, $offset, $len ) = $Torrus::EasyTarget::siteXmlDir;
    }
    else
    {
        if( $filename !~ /^\// )
        {
            $filename = $Torrus::EasyTarget::siteXmlDir . '/' . $filename;
        }
    }
    return $filename;
}
            
            
# Removes XML root directory from path
sub relXmlFilename
{
    my $filename = shift;

    my $subst = $Torrus::EasyTarget::siteXmlDir;
    my $len = length( $subst );

    if( $filename =~ /^\// )
    {
        my $offset = index( $filename, $subst );
        if( $offset == 0 )
        {
            $filename = substr( $filename, $len );
            # we don't know if xmldir has a trailing slash
            $filename =~ s/^\///;
        }
    }
    return $filename;
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
