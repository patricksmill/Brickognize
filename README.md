## Brickognize

Identify LEGO-style parts and sets from your iPhone camera. Brickognize is a SwiftUI iOS app that captures a photo, sends it to the Brickognize cloud service for visual recognition, and shows the most likely match with a quick scan history stored on-device.

Unlike most other brick recognition apps, Brickognize offers an unlimited amount of scans for free.

### Description
- **What it does**: Lets you point your camera at a brick/part/set, captures an image, and returns a likely name/ID and reference image.
- **How it works**: Uses the device camera (AVFoundation), sends the photo to `api.brickognize.com`, and displays the top recognition result. Recent scans are saved locally using SwiftData.
- **Tech**: SwiftUI, AVFoundation, SwiftData; network calls to the Brickognize API.


