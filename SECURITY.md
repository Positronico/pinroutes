# Security Policy

## SUID Helper

PinRoutes includes a SUID-root helper binary (`pinroutes-helper`) that executes `/sbin/route` commands without requiring repeated password prompts. The helper:

- Only accepts `add` or `delete` as actions
- Validates network input as valid CIDR notation
- Validates gateway input as valid IPv4
- Only executes `/sbin/route` — no shell, no other binaries
- Rejects any other input

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately:

1. Go to the [Security Advisories](https://github.com/Positronico/pinroutes/security/advisories) page
2. Click "Report a vulnerability"
3. Describe the issue with steps to reproduce

Please do **not** open public issues for security vulnerabilities.

We will acknowledge your report within 48 hours and aim to release a fix promptly.
