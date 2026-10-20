# Security policy

## Reporting a vulnerability

Please report security issues **privately** through GitHub:
[**Report a vulnerability**](https://github.com/adamtty/adobe-off/security/advisories/new).
Don't open a public issue for them.

Include what you found, how to reproduce it, and what an attacker could do with it. You'll get a
reply within a week. Once it's fixed, you'll be credited in the advisory unless you'd rather not be.

## Supported versions

Only the latest commit on `main` is supported; there are no release branches.

## Scope

In scope: the `adobe` script. Especially interesting: anything that makes it signal a process that
isn't part of Adobe's background stack (above all through `sudo`), run a different program than the
system's own `kill`, `launchctl` or `sudo`, or leave services in a state `adobe on` can't undo.

Out of scope: Adobe's own software (report that to Adobe), and attacks that need an attacker who can
already write to `/Library` or run code as you.
