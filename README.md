# Sam's Apps: an Umbrel community app store

| App | What it is |
| --- | --- |
| **Prusa Connect** (`sam-prusa-connect`) | [Prusa Connect](https://github.com/prusa3d/prusa-connect), Prusa Research's self-hosted server for 3D printers: fleet overview, printing from the browser, accounts and permissions, REST API, MQTT and webhooks. No cloud. |

## Add the store to umbrelOS

1. Open the umbrelOS **App Store**.
2. Click **⋯** (top right) and choose **Community App Stores**.
3. Paste `https://github.com/sam-apostel/umbrel-app-store` and click **Add**.
4. Open **Sam's Apps** and install **Prusa Connect**.

## Prusa Connect

### First run

1. Open the app. It shows Prusa's setup wizard.
2. As the **setup code**, enter the password umbrelOS shows on the app's page. umbrelOS generates it
   per install, and the app writes it into the server's configuration as the setup code.
3. Choose that everybody signs in, and create your own administrator.
4. Keep the upload folder at **`/storage`** (the default). That folder is on a volume, so your print
   files survive updates; another folder would be lost on the next update.
5. Leave the port as it is. It is fixed to 8080 inside the container, and umbrelOS serves it on
   port **8580**.

### Add a printer

Open the app at your Umbrel's **IP address**, e.g. `http://192.168.1.20:8580`, before you go to
**Add a printer**. The page writes the address it was opened at into `prusa_printer_settings.ini`,
and a printer may not resolve `umbrel.local`. Then follow the page: put the file on a USB drive, load
it on the printer (**Settings → Network → Prusa Connect → Load Settings → Add Printer to Connect**)
and approve the code.

umbrelOS's own login is switched off for this app (`PROXY_AUTH_ADD: "false"`), because printers and
API clients cannot sign in to umbrelOS. Prusa Connect's accounts protect it instead.

### What does not work on Umbrel

- **Nearby printers** (mDNS discovery) needs host networking, which this app does not use. Add
  printers with the USB file instead.
- The **Updates** page in Prusa Connect prepares an update but cannot replace the binary inside the
  image. Updates come through umbrelOS (see below).
- Extensions that open their own ports (the Prusa printer logs extension's UDP ports, Fractal) are
  not reachable from outside the container.

### Updates

Prusa publishes no container image, so this repository builds one:

1. **`Update Prusa Connect`** (`.github/workflows/update.yml`) runs every day. When
   [prusa3d/prusa-connect](https://github.com/prusa3d/prusa-connect/releases) has a new release, it
   calls the build.
2. **`Build Prusa Connect image`** (`.github/workflows/build.yml`) checks out the unmodified upstream
   release tag, builds `ghcr.io/sam-apostel/prusa-connect:<version>` natively for `amd64` and
   `arm64`, and runs `.github/scripts/smoke.sh` on both. The smoke test starts the app from this
   repository's own `docker-compose.yml` the way umbrelOS does. It checks that the server becomes
   healthy, that umbrelOS's password is accepted as the setup code, and that a sign-in is required
   afterwards.
3. Only if all of that passes, the update workflow commits the new version and the image digest to
   `main`.

umbrelOS then shows an **Update** button on the app. Nothing changes on your Umbrel until you click
it. Prusa Connect is a beta: its releases can change the configuration and the database, so back up
first (the app's data is in `~/umbrel/app-data/sam-prusa-connect/data/`).

To build a specific release by hand, run **Update Prusa Connect** from the Actions tab and enter the
version.

### Data

| On the Umbrel | In the container | Holds |
| --- | --- | --- |
| `data/config/config.yaml` | `/config/config.yaml` | Written by the app at every start (setup code, trusted proxy, bundled extensions). Do not edit. |
| `data/config/config.d/` | `/config/config.d/` | The database (accounts, printers, permissions), the wizard's answers, history, installed extensions |
| `data/storage/` | `/storage` | Uploaded print files |

## Licence

The packaging in this repository (manifests, workflows, scripts) is mine. Prusa Connect itself is
**built on Prusa Connect by Prusa Research** and licensed under
[OCL v1.1 + Micro v1 + NoSaaS v1 + SWAtt v1](https://github.com/prusa3d/prusa-connect/blob/main/LICENSE).
It is free for non-commercial use, and a business with up to €1M yearly revenue may run it for
its own internal use. Offering it to others as a service is not allowed. The image is built from the
unmodified upstream source.
