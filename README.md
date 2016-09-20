# NAME

Dist::Zilla::Plugin::ChangeStats::Dependencies::Git - Add dependency changes to the changelog

<div>
    <p>
    <img src="https://img.shields.io/badge/perl-5.10+-blue.svg" alt="Requires Perl 5.10+" />
    <a href="https://travis-ci.org/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git"><img src="https://api.travis-ci.org/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git.svg?branch=master" alt="Travis status" /></a>
    <a href="http://cpants.cpanauthors.org/release/CSSON/Dist-Zilla-Plugin-ChangeStats-Dependencies-Git-0.0101"><img src="http://badgedepot.code301.com/badge/kwalitee/CSSON/Dist-Zilla-Plugin-ChangeStats-Dependencies-Git/0.0101" alt="Distribution kwalitee" /></a>
    <a href="http://matrix.cpantesters.org/?dist=Dist-Zilla-Plugin-ChangeStats-Dependencies-Git%200.0101"><img src="http://badgedepot.code301.com/badge/cpantesters/Dist-Zilla-Plugin-ChangeStats-Dependencies-Git/0.0101" alt="CPAN Testers result" /></a>
    <img src="https://img.shields.io/badge/coverage-20.5%-red.svg" alt="coverage 20.5%" />
    </p>
</div>

# VERSION

Version 0.0101, released 2016-09-20.

# SYNOPSIS

    ; in dist.ini
    [ChangeStats::Dependencies::Git]
    group = Dependency Changes

# DESCRIPTION

This plugin adds detailed information about changes in requirements to the changelog, possibly in a group. The
synopsis might add this:

     [Dependency Changes]
     - (run req) + Moose (any)
     - (run req) - No::Longer::Used
     - (test sug) + Something::Useful 0.82
     - (dev req) ~ List::Util 1.40 --> 1.42

For this to work the following must be true:

- The changelog must conform to [CPAN::Changes::Spec](https://metacpan.org/pod/CPAN::Changes::Spec).
- There must be a `META.json` in both the working directory and in the tags.
- Git tag names must be identical to (or a superset of) the version numbers in the changelog.
- This plugin should come before \[NextRelease\] or similar in dist.ini.

# ATTRIBUTES

## change\_file

Default: `Changes`

The name of the changelog file.

## group

Default: No group

The group (if any) under which to add the dependency changes. If the group already exists these changes will be appended to that group.

## format\_tag

Default: `%s`

Use this if the Git tags are formatted differently to the versions in the changelog. `%s` gets replaced with the version.

# SEE ALSO

- [Dist::Zilla::Plugin::ChangeStats::Git](https://metacpan.org/pod/Dist::Zilla::Plugin::ChangeStats::Git)

# SOURCE

[https://github.com/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git](https://github.com/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git)

# HOMEPAGE

[https://metacpan.org/release/Dist-Zilla-Plugin-ChangeStats-Dependencies-Git](https://metacpan.org/release/Dist-Zilla-Plugin-ChangeStats-Dependencies-Git)

# AUTHOR

Erik Carlsson <info@code301.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Erik Carlsson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
