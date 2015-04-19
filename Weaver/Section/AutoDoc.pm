use strictures 2;

package Pod::Weaver::Section::AutoDoc;

# ABSTRACT: Assemble documentation gathered from Sub::Documentation

use Carp;
use Method::Signatures::WithDocumentation;
use Module::Metadata;
use Sub::Documentation qw(search_documentation);
use List::MoreUtils qw(uniq);
use Class::Load qw(try_load_class);

use Moose;
use Moose::Util::TypeConstraints ();

with 'Pod::Weaver::Role::Section';

use Pod::Elemental::Element::Nested;
use Pod::Elemental::Element::Pod5::Command;
use Pod::Elemental::Element::Pod5::Ordinary;
use Pod::Elemental::Element::Pod5::Verbatim;

# VERSION

func _nested ($type, $command, $content, @children) {
    return Pod::Elemental::Element::Nested->new({
        type      => $type,
        command   => $command,
        content   => $content,
        children  => \@children,
    });
}

func _command($command, $content = '') {
    return Pod::Elemental::Element::Pod5::Command->new(
        command => $command, content => $content
    );
}

func _list(@items) {
    my @elements;
    push @elements => _command(over => 4);
    foreach my $item (@items) {
        my ($text, @rest);
        if (ref $item eq 'ARRAY') {
            ($text, @rest) = @$item;
        } else {
            $text = $item;
        }
        push @elements => _command(item => '* '.$text);
        push @elements => @rest;
    }
    push @elements => _command('back');
    return @elements;
}

func _ordinary(@contents) {
    map { Pod::Elemental::Element::Pod5::Ordinary->new(content => $_) } @contents
}

func _verbatim(@contents) {
    map { Pod::Elemental::Element::Pod5::Verbatim->new(content => $_) } @contents
}

func _subdoc_getoftype ($type, @doc) {
    my @RV = map { $_->{documentation} } grep { $_->{type} eq $type } @doc;
    return wantarray ? @RV : $RV[0];
}

func _subdoc_getnames (@doc) {
    uniq sort map { $_->{name} } @doc;
}

func _filter_pkglist (@list) {
    grep !m{^(?:UNIVERSAL|main)$}, @list
}

func _get_parents ($ns) { 
    no strict 'refs'; ## no critic
    _filter_pkglist(@{ $ns . '::ISA' });
}

func _trim (Str $str!) {
    $str =~ s{^\s*}{}s;
    $str =~ s{\s*$}{}s;
    $str;
}

func _tidy(Str $str!) {
    $str =~ m{^(?:\s*\n([ \t\r]+)|(\s+))\S}s or return $str;
    my $indent = quotemeta $1;
    $str =~ s{^$indent}{}mg;
    $str =~ s{([\n]){2,}}{$1 x 2}seg;
    _trim($str);
}

func _indent(Str $str!, Str|Int $indent = 8) {
    if ($indent =~ m{^\d+$}s) {
        $indent = ' ' x $indent;
    }
    $str =~ s{^(.+)$}{$indent$1}mgr;
}

func _create_links_in_contraint ($constraint) {
    $constraint = Moose::Util::TypeConstraints::normalize_type_constraint_name($constraint);
    if ($constraint =~ m{\|}) {
        my @constraints = split /\|/, $constraint;
        #$constraint = Moose::Util::TypeConstraints::create_type_constraint_union($constraint)->type_constraints;
        return join(' | ', map { _create_links_in_contraint($_) } @constraints);
    }
    $constraint = Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($constraint);
    if (ref($constraint) =~ m{^Moose::Meta::TypeConstraint::(?:Class|Role)$}) {
        my $class = $constraint->class;
        return $class ? "L<$class>" : $class;
    } elsif (ref($constraint) eq 'Moose::Meta::TypeConstraint::Parameterized') {
        return sprintf '%s[ %s ]', $constraint->parameterized_from, _create_links_in_contraint($constraint->type_parameter);
    } else {
        return ''.$constraint;
    }
}

func _get_methods ($prefix, $parent, $type, @documentation) {
    my @methods;
    foreach my $name (_subdoc_getnames(@documentation)) {
        next if $name =~ m{^_};
        my @subdoc = grep { $_->{name} eq $name } @documentation;
        next unless _subdoc_getoftype(type => @subdoc) eq $type;
        my $purpose = _subdoc_getoftype(purpose => @subdoc);
        my @pods = _subdoc_getoftype(pod => @subdoc);
        my @params =  _subdoc_getoftype(param_signature => @subdoc);
        my %params_desc = map {( $_ => 1 )} _subdoc_getoftype(param => @subdoc);
        my $since = _subdoc_getoftype(since => @subdoc);
        my @authors = _subdoc_getoftype(author => @subdoc);
        my $returns = _subdoc_getoftype(returns => @subdoc);
        my @throws = _subdoc_getoftype(throws => @subdoc);
        my $example = _subdoc_getoftype(example => @subdoc);
        my $deprecated = _subdoc_getoftype(deprecated => @subdoc);
        my $signature = _subdoc_getoftype(signature => @subdoc);

        my @children;

        if (defined $parent) {
            push @children => _ordinary("Inherited from L<$parent>");
        }

        if (defined $purpose) {
            push @children => _ordinary(_tidy($purpose));
        }

        if (defined $example) {
            push @children => _ordinary("B<Synopsis:>");
            push @children => _verbatim(_indent(_tidy($example)));
        }

        if (@params) {
            push @children => _ordinary("B<Parameters:>");
            my @list;
            foreach my $param (@params) {
                my ($param_type, $param_name, @param_opts) = @$param;
                my @desc = map { s{^\s*\Q$param_name\E:\s*(.*)\s*$}{$1}r } map { delete $params_desc{$_}; $_ } grep { m{^\s*\Q$param_name\E:} } keys %params_desc;
                push @list => [
                    (_create_links_in_contraint($param_type)." C<<< $param_name >>>".(@param_opts ? " (".join(', ', @param_opts).")" : "")),
                    map { _ordinary(_tidy($_)) } @desc
                ];
            }
            push @children => _list(@list);
        }

        if (keys %params_desc) {
            push @children => _list(keys %params_desc);
        }

        push @children => map { _ordinary(_tidy($_)) } @pods;

        if (defined $returns) {
            push @children => _ordinary("B<Returns:>");
            push @children => _ordinary(_tidy($returns));
        }

        if (@throws) {
            push @children => _ordinary("B<Throws:>");
            my @list;
            foreach my $throw (@throws) {
                push @list => _tidy($throw);
            }
            push @children => _list(@list);
        }

        if (defined $since) {
            push @children => _ordinary("B<Available since:> "._trim($since));
        }

        if (defined $deprecated) {
            push @children => _ordinary("B<DEPRECATION WARNING:>");
            push @children => _ordinary(_tidy($deprecated));
        }

        if (@authors) {
            push @children => _ordinary("B<Author:> ".join(', ', map { _trim($_) } @authors));
        }

        my $fullname = $prefix.$name;
        $fullname .= " ($signature)" if defined $signature;
        $fullname .= " B<DEPRECATED>" if defined $deprecated;

        push @methods => _nested('command', 'head2', $fullname, @children);
    }
    return @methods;
}

func _proc_ns ($prefix, $super, $ns, @documentation) {
    my @methods = _get_methods($prefix, $super, 'method', @documentation);

    my @parents = _get_parents( $ns );

    my %parents = ($ns => \@parents);

    foreach my $parent (@parents) {
        @documentation = search_documentation(
            package => $parent,
            glob_type => 'CODE',
        );
        my $R = _proc_ns ($prefix, $parent, $parent, @documentation);
        %parents = (%parents, %{ $R->{parents} });
        push @methods => @{ $R->{methods} };
    }

    return {
        methods => \@methods,
        parents => \%parents,
    };
}

use namespace::clean;

method weave_section ($doc, $input) {
    
    my $filename = $input->{filename};

    my $info = Module::Metadata->new_from_file( $filename );
    
    my $module = $info->name;
    
    try_load_class($module) or require($filename) or croak("cannot load $module (in file $filename)");
    
    my @namespaces = _filter_pkglist($info->packages_inside);
    
    my (@methods, @functions, %parents);
    
    foreach my $ns (@namespaces) {
        my @documentation = search_documentation(
            package => $ns,
            glob_type => 'CODE',
        );

        my $prefix = $module ne $ns ? "${ns}::" : "";
        
        my $R = _proc_ns($prefix, undef, $ns, @documentation);

        push @methods => @{ $R->{methods} };

        push @functions => _get_methods($prefix, undef, 'func', @documentation);

        %parents = (%parents, %{ $R->{parents} });

    }
    
    push @{ $doc->children } => _nested('command', 'head1', 'METHODS', @methods) if @methods;
    push @{ $doc->children } => _nested('command', 'head1', 'FUNCTIONS', @functions) if @functions;
    
    if (keys %parents) {
        my @extends;
        if (keys %parents > 1) {
            foreach my $ns (sort keys %parents) {
                my @parents = @{ $parents{$ns} };
                next unless @parents;
                my @list;
                foreach my $parent (@parents) {
                    push @list => "L<$parent>";
                }
                push @extends => _nested('command', 'head2', $ns, _list(@list));
            }
        } else {
            my ($ns) = keys %parents;
            my @parents = @{ $parents{$ns} };
            if (@parents) {
                my @list;
                foreach my $parent (@parents) {
                    push @list => "L<$parent>";
                }
                push @extends => _list(@list);
            }
        }
        push @{ $doc->children } => _nested('command', 'head1', 'EXTENDS', @extends); 
    }
}

1;

__END__

=pod

=head1 DESCRIPTION

This module adds up to three new sections into your pod: L<METHODS|/"METHODS SECTION">, L<FUNCTIONS|/"FUNCTIONS SECTION"> and L<EXTENDS/"EXTENDS SECTION">.

Any documentation gathered by L<Sub::Documentation> will be assembled to an auto-generated pod for each method/function. Attribute definitions are not supported yet.

If the module extends some other module, and that module (or any module in the inheritance chain) uses L<Sub::Documentation>, than the inherited methods will be included in the documentation.

=head1 SYNOPSIS

Put

    [AutoDoc]

into your C<weaver.ini>.

=head1 SECTIONS

The sections will be added in this order to your pod at the desired position.

=head2 METHODS SECTION

To distinguish I<code> objects as a class method, the param I<type> should contain I<method>. Only objects with that attribute are assembled in this section.

First, a pod command (head2) with the method name and a brief attribute list is printed. This maybe append with C<<< B<DEPRECATED> >>>.

Then these paragraphes are followed in this order:

=over 4

=item * A notice if the method was inherited from another module, with a link to it.

=item * The I<purpose> of the method.

=item * The synopsis of the method, identified by I<example>.

=item * A list of all parameters with documentation (if available by identifier I<param>)

=item * All additional documentation identified by I<pod>

=item * The return value of the method, identified by I<returns>

=item * All throwables, identified by I<throws>

=item * A list, since when this method is available, identified by I<since>

=item * The deprecation warning, identified by I<deprecated>

=item * The list of all especially named authors, indentified by I<author>

=back

=head2 FUNCTIONS SECTION

To distinguish I<code> objects as a class function, the param I<type> should contain I<func>. Only objects with that attribute are assembled in this section.

The rules to not differ from L<methods|/"METHODS SECTION">, so see there for a detailed description.

=head2 EXTENDS SECTION

Inserts a simple list of all parent classes with links to them.

=head1 FORMATTING TIPS

Multiline attributes (I<Purpose>, I<Example>, I<Pod>, I<Returns>, I<Throws>, I<Deprecated> and I<Param>) are trimmed and re-indented by resetting all indentations to the first indentation with non-whitechars on the line. So, the following statement:

    sub xxx :
        Pod(
            Lorem
              Ipsum
        )
    { ... }

results in:

    =pod
    
    Lorem
      Ipsum
    
    =cut

But for the I<Example> attribute, the verbatim block is automatically indented. Thus,

    sub xxx :
        Example(
            my $xxx = xxx;
        )
    { ... }

results in:

    =pod
    
            my $xxx = xxx;
    
    =cut

The single-line attributes I<Since> and I<Author> should contain no line breaks.

For some readers it might be confusing the read a subroutine definition with many attributes. Theres is no best practise at the moment, but I suggest this template:

    func foobar (Int $amount = 1) :
        Purpose(
            Prints out I<foo> and I<bar>
        )
        Example(
            foobar(2); # prints two foos and two bars
        )
        Param(
            $amount: how many foo and bar should be printed
        )
        Pod(
            This function is an example to show you a fancy way for its documentation
        )
        Returns(
            True on success
        )
        Throws(
            An error message if there is no output device
        )
        Since(
            1.000
        )
        Deprecated(
            Use L</foobar_v2> instead.
        )
        Author(
            John Doe
        )
    { ... }

The resulting pod looks like:

    =head2 foobar ([ Int $amount ]) B<DEPRECATED>
    
    Prints out I<foo> and I<bar>
    
    B<Synopsis:>
    
            foobar(2); # prints two foos and two bars
    
    B<Parameters:>
    
    =over 4
    
    =item * Int C<<< $amount >>> (optional, defaults to C<<<  1 >>>)
    
    how many foo and bar should be printed
    
    =back
    
    This function is an example to show you a fancy way for its documentation
    
    B<Returns:>
    
    True on success
    
    B<Throws:>
    
    =over 4
    
    =item * An error message if there is no output device
    
    =back
    
    B<Available since:> 1.000
    
    B<DEPRECATION WARNING:>
    
    Use L</foobar_v2> instead.
    
    B<Author:> John Doe

