# Contributing to PinRoutes

Contributions are welcome! Here's how to get started.

## Development Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/Positronico/pinroutes.git
   cd pinroutes
   ```

2. Build:
   ```bash
   swift build        # debug build
   make bundle        # release build + app bundle
   ```

3. Run:
   ```bash
   make run           # builds and opens PinRoutes.app
   ```

## Making Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Test locally — build, run, verify routes work
5. Commit your changes
6. Push to your fork and open a Pull Request

## Code Style

- Follow existing patterns in the codebase
- Keep the helper binary minimal — no shared dependencies
- Validate all inputs at system boundaries

## Reporting Issues

Open an issue on GitHub with:
- macOS version
- What you expected vs what happened
- Steps to reproduce

## Security

If you find a security vulnerability (especially related to the SUID helper), please report it privately via GitHub's security advisory feature rather than opening a public issue.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
