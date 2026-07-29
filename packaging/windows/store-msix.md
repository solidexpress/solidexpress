# Microsoft Store (MSIX)

1. Produce a signed MSIX from the same files as the Inno install (Partner Center packaging tool or `makeappx`).
2. Map executable + DLLs; test GDExtension load paths inside MSIX container.
3. Partner Center → new app → upload MSIX → certification.

Not automated in CI until `AZURE_SIGNING` / store credentials exist in GitHub secrets.
