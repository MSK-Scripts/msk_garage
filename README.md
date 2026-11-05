<img width="1920" height="1080" alt="msk_garage-banner" src="https://github.com/user-attachments/assets/684c9e02-83e4-44d5-989d-975b46227b69" />

<div align="center">

[![Discord](https://img.shields.io/badge/Discord-MSK%20Scripts-5865F2?logo=discord&logoColor=white)](https://discord.gg/5hHSBRHvJE)
[![Documentation](https://img.shields.io/badge/Docs-docu.msk--scripts.de-00E676)](https://docu.msk-scripts.de/docs/msk_garage/)
[![Version](https://img.shields.io/badge/version-5.7.0-blue)](https://github.com/MSK-Scripts/msk_garage/releases)
[![License](https://img.shields.io/badge/license-LGPL--3.0-green)](LICENSE)

</div>

A garage and impound system for ESX, QBCore and Qbox, with a React UI and an in-game admin dashboard.

The server validates every action instead of trusting the client. Garages, impounds and settings live in the database and are managed in game. Private garages work with housing scripts, and the key handling plugs into MSK VehicleKeys, VehicleKeyChain or Jaksam Vehicle Keys.

MSK Garage used to be a paid script. It is free and open source since November 2026.

## Quick start

Requires [msk_core](https://github.com/MSK-Scripts/msk_core) 4.1.0+, [ox_lib](https://github.com/overextended/ox_lib) and [oxmysql](https://github.com/overextended/oxmysql). Download the latest [release](https://github.com/MSK-Scripts/msk_garage/releases), put `msk_garage` into your `resources` folder and start it after its dependencies:

```ini
ensure oxmysql
ensure ox_lib
ensure msk_core
ensure msk_garage
```

The tables are created on first start.

## Documentation

| Topic | Link |
|---|---|
| Installation | [docu.msk-scripts.de/docs/msk_garage/guides/installation](https://docu.msk-scripts.de/docs/msk_garage/guides/installation) |
| Configuration | [docu.msk-scripts.de/docs/msk_garage/config](https://docu.msk-scripts.de/docs/msk_garage/config) |
| Integrations | [docu.msk-scripts.de/docs/msk_garage/guides/integrations](https://docu.msk-scripts.de/docs/msk_garage/guides/integrations) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |

## Help and contributing

Ask in the public support channel on [Discord](https://discord.gg/5hHSBRHvJE) or open an issue. [GitHub Sponsors](https://github.com/sponsors/MSK-Scripts) get ticket support. Pull requests are welcome.

## License

[LGPL-3.0](LICENSE), see also [GPL-3.0.txt](GPL-3.0.txt).
