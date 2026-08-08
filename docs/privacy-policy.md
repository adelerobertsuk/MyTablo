# Privacy Policy for Tablo

**Effective date: 8 August 2026**

Tablo is developed by Adele Roberts. This policy explains how Tablo handles information when you use the app.

## Information stored on your device

Tablo stores your book library, book details, cover images, table arrangements, decorations, and preferences locally on your device using Apple's SwiftData technology.

The main app and its widget share this information through an Apple App Group container on the same device. This is local storage, not a server or cloud-synchronisation service operated by Tablo.

Tablo also stores an internal migration flag in UserDefaults. This flag is used to safely move existing local app data into the shared App Group container. It is not used for advertising, analytics, or tracking.

## Book information and Open Library

When you scan a barcode or enter an ISBN, Tablo sends that ISBN to:

- `openlibrary.org`, to request book title and author information
- `covers.openlibrary.org`, to request available cover artwork

Tablo does not deliberately send your name, email address, account information, advertising identifier, or Tablo library to Open Library.

Like other internet services, Open Library may receive technical network information, including your IP address, when a request is made. Open Library is operated by the Internet Archive, and its handling of requests is governed by its own terms and privacy practices.

## Camera access

Tablo uses the camera to scan book barcodes. Barcode recognition uses Apple's VisionKit framework. Tablo does not upload camera images to a server operated by the developer.

## Photos and cover images

If you choose an image from your photo library as custom cover artwork, the selected image is stored locally as part of the book's record. Tablo does not upload that image to a server operated by the developer.

## Sharing

When you choose to share a Tablo image, the app creates the image locally and presents Apple's system share sheet. The destination you select may process the image according to that service's own privacy policy.

## Accounts, analytics, and advertising

Tablo does not require an account or login.

Tablo does not contain third-party advertising, analytics, or tracking SDKs. The developer does not use Tablo to track people across apps or websites.

## Support emails

If you contact support by email, the developer receives the information you choose to include, such as your email address, message, and attachments. This information is used to respond to your request and maintain necessary support records.

## Deleting your data

You can delete individual books from within Tablo. Removing the app will ordinarily remove its locally stored data in accordance with iOS behaviour and any device backup settings.

## Children's privacy

Tablo is not designed to request personal information from children and does not require an account. If you believe personal information has been sent through a support request, contact the developer.

## Changes to this policy

This policy may be updated when Tablo's features or data practices change. The current version will be published with its effective date.

## Contact

For privacy questions, email [info@adeleroberts.com](mailto:info@adeleroberts.com).

---

This draft must be reviewed before publication. Confirm the developer's legal identity and address requirements, applicable jurisdiction, and Open Library's data-retention practices.
