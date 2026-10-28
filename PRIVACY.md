# Privacy

Taima is built so that what you record never leaves your iPhone unless you send it yourself.

## What stays on your iPhone

- **Your records:** bags, photos, sessions, notes, scores, tags, shops and settings.
- **Where they live:** Taima's own storage on the phone.
- **Photos:** stored without location or other metadata.
- **Label reading:** done on the phone with Apple's Vision framework.
- **No servers:** Taima has no account and no analytics, and doesn't use any server of its own or of anyone else.

## The only network use: the update check

Once a day, if **Check for updates** is on (it is by default), Taima downloads two public files from this GitHub repository:

- `sidestore/source.json`, the list of releases, to tell you when a new version is out.
- `catalog/v1/…`, the strain library, installed only if every file matches its published checksum.

The request carries no information about you or your collection. Like any download, GitHub sees your IP address. Turn it off under **Settings ▸ Updates**.

## Things you can choose to do

- **Share a label sample.** Off by default. When on, after you correct a new bag Taima shows you the sample first:
  - **What it contains:** the text it read and the fields you corrected, with product codes and barcodes removed. No photo, price, shop, note or date of yours is included.
  - **Where it goes:** you pick a GitHub issue (public) or the share sheet. Nothing is sent otherwise.
- **Look up a product code.** The **Look up product code online** button opens Potspot (a community website) in Safari with that one code, after asking.
- **Open links from a label.** Leaflet links read from a label open in Safari, after asking. Only https links are allowed.
- **Back up or export.**
  - **Backups:** encrypted with your passphrase unless you choose otherwise.
  - **Automatic backups:** go to the folder you pick. A folder in iCloud Drive is uploaded to Apple.
  - **CSV exports:** plain text.

## On your iPhone

- **Discreet mode:** a plain icon. Strain names, THC and photos stay off widgets, the Live Activity, notifications, Siri replies and Spotlight.
- **Face ID lock:** covers the whole app. With it on, Spotlight stays empty, Siri requires an unlocked iPhone and notifications stay neutral.
- **iCloud backups:** your iPhone's iCloud backup includes Taima's data unless you turn on **Leave out of iCloud backups**.
- **Delete all data:** in Settings, this removes everything Taima stored on the phone.
