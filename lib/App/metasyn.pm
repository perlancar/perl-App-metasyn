package App::metasyn;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

sub _shuffle_and_limit {
    my ($res, $args) = @_;
    if ($args->{shuffle}) {
        require List::Util;
        $res = [List::Util::shuffle(@$res)];
    }
    if (defined $args->{number} && $args->{number} > 0 && @$res > $args->{number}) {
        $res = [@{$res}[0 .. $args->{number}-1]];
    }
    $res;
}

$SPEC{metasyn} = {
    v => 1.1,
    summary => 'Alternative front-end to Acme::MetaSyntactic',
    description => <<'_',

This script is an alternative front-end for <pm:Acme::MetaSyntactic>. Compared
to the official CLI <prog:meta>, this CLI currently does not retrieve
themes/names remotely but:

* provides shell completion;
* provides an option to shuffle list of themes/categories/names returned;
* makes it easy to print all names in a theme;
* makes it easy to print all (or some) categories in a theme.

This CLI is more geared towards listing all themes/names/categories instead of
picking one.

_
    args => {
        action => {
            schema => ['str*', in=>[qw/list-themes list-names/]],
            default => 'list-names',
            cmdline_aliases => {
                l => { summary => 'List installed themes', is_flag => 1, code => sub { $_[0]{action} = 'list-themes' } },
            },
        },
        theme => {
            schema => 'str*',
            pos => 0,
            completion => sub {
                require Complete::Acme::MetaSyntactic;
                Complete::Acme::MetaSyntactic::complete_meta_theme_and_category(@_);
            },
        },
        shuffle => {
            schema => 'true*',
            cmdline_aliases => {R=>{}},
        },
        random_theme => {
            schema => 'true*',
            cmdline_aliases => {T=>{}},
        },
        number => {
            summary => 'Limit only return this number of results',
            schema => 'posint*',
            cmdline_aliases => {n=>{}},
        },
        categories => {
            schema => 'true*',
            cmdline_aliases => {c=>{}},
        },
    },
    examples => [
        # listing names
        {
            summary => 'List all names from the default theme, foo',
            argv => [qw//],
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'Return a single random name from the default theme (equivalent of: meta)',
            argv => [qw/-n1 -R/],
        },
        {
            summary => 'List all names from a theme',
            argv => [qw/christmas/],
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'List all names from a category of a theme in random order, return only 3 (equivalent of: meta christmas/elf 3)',
            argv => [qw(christmas/elf -n3 -R)],
        },
        {
            summary => 'Return a single random name from a theme (equivalent of: meta christmas)',
            argv => [qw(christmas -n1 -R)],
        },
        {
            summary => 'Return a single random name from a random theme',
            argv => [qw(-T -n1 -R)],
        },

        # listing themes
        {
            summary => 'List all installed themes (equivalent of: meta --themes)',
            argv => [qw/-l/],
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'List 3 random themes (equivalent of: meta --themes | shuf | head -n3)',
            argv => [qw/-l -n3 -R/],
        },
        {
            summary => 'List all installed themes, along with all their categories',
            argv => [qw/-l -c/],
            'x.doc.max_result_lines' => 10,
        },

        # listing categories
        {
            summary => 'List all categories from a theme',
            argv => [qw(christmas -c)],
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'List 2 categories from a theme, in random order',
            argv => [qw(christmas -c -n2 -R)],
            'x.doc.max_result_lines' => 10,
        },
    ],
    links => [
        {url=>'prog:meta'},
    ],
};
sub metasyn {
    no strict 'refs';
    require Acme::MetaSyntactic;

    my %args = @_;

    my $action = $args{action};

    if ($action eq 'list-themes') {
        my @res;
        for my $th (Acme::MetaSyntactic->new->themes) {
            if ($args{categories}) {
                my $pkg = "Acme::MetaSyntactic::$th";
                (my $pkg_pm = "$pkg.pm") =~ s!::!/!g;
                return [500, "Can't load $pkg: $@"]
                    unless (eval { require $pkg_pm; 1 });
                my @cats;
                @cats = $pkg->categories if $pkg->can("categories");
                if (@cats) {
                    push @res, "$th/$_" for sort @cats;
                } else {
                    push @res, $th;
                }
            } else {
                push @res, $th;
            }
        }
        return [200, "OK", _shuffle_and_limit(\@res, \%args)];
    }

    my $theme;
    if ($args{theme}) {
        $theme = $args{theme};
    } elsif ($args{random_theme}) {
        my @themes = Acme::MetaSyntactic->new->themes;
        $theme = $themes[rand @themes];
    } else {
        $theme = 'foo';
    }
    my $cat = $theme =~ s{/(.+)\z}{} ? $1 : undef;

    my $pkg = "Acme::MetaSyntactic::$theme";
    (my $pkg_pm = "$pkg.pm") =~ s!::!/!g;
    return [500, "Can't load $pkg: $@"] unless (eval { require $pkg_pm; 1 });

    if ($args{categories}) {
        my @res;
        eval { @res = sort $pkg->categories };
        #warn if $@;
        return [200, "OK", _shuffle_and_limit(\@res, \%args)];
    }
    #my $meta = Acme::MetaSyntactic->new($theme);
    my @names;
    if (defined $cat) {
        @names = @{ ${"$pkg\::MultiList"}{$cat} // [] };
    } else {
        @names = @{"$pkg\::List"};
        unless (@names) {
            @names = map { @{ ${"$pkg\::MultiList"}{$_} } }
                sort keys %{"$pkg\::MultiList"};
        }
    }
    return [200, "OK", _shuffle_and_limit(\@names, \%args)];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

Use the included script L<metasyn>.
