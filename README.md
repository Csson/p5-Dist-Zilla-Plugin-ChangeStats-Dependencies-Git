# NAME

Dist::Zilla::Plugin::ChangeStats::Dependencies::Git - Add dependency changes to the changelog

![Requires Perl 5.10+](https://img.shields.io/badge/perl-5.10+-brightgreen.svg) [![Travis status](https://api.travis-ci.org/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git.svg?branch=master)](https://travis-ci.org/Csson/p5-Dist-Zilla-Plugin-ChangeStats-Dependencies-Git) ![coverage 88.9%](https://img.shields.io/badge/coverage-88.9%-orange.svg)

# VERSION

Version 0.0100, released 2016-02-12.

# SYNOPSIS

    ; in dist.ini
    [ChangeStats::Dependencies::Git]
    group = Dependency Changes

# DESCRIPTION

This plugin adds detailed information about changes in requirements to the changelog, possibly in a group.

     [Dependency Changes]
     - (runtime requires) Added Moose (any)
     - (runtime requires) Removed Acme::Resume
     - (develop requires) Changed List::Util 1.40 --> 1.42

For this to work the following must be true:

- The changelog must conform to [CPAN::Changes::Spec](https://metacpan.org/pod/CPAN::Changes::Spec).
- There must be a [`panfile`](https://metacpan.org/pod/panfile) (this is the source of current dependencies) in the distribution root.
- Git tag names must be identical to (or a superset of) the version numbers in the changelog.
- There must be a `META.json` commited in the git tags.
- The plugin should come before \[NextRelease\] or similar in dist.ini.

# ATTRIBUTES

## change\_file

Default: `Changes`

The name of the changelog file.

## group

Default: No group

The group (if any) under which to add the dependency changes. If the group already exists these changes will be appended to that group.

## format\_tag

Default: `%s`

Use this ff the Git tags are formatted differently to the versions in the changelog. `%s` gets replaced with the version.

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
