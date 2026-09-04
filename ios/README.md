# Rey Lab for iPhone and iPad

A native SwiftUI edition of the projects in `rvmendillo/rvmendillo`, compatible with iOS 17+. This is the original Flask portfolio repository, not the newer Portfolio OS repository.

| Original feature | iOS behavior |
| --- | --- |
| Portfolio and contact | Native project directory, GitHub/LinkedIn/email links, archived original résumé and paper |
| Image to ASCII | Offline Photos, Files and HTTPS image import; configurable ramp, columns, inversion and color; PNG and text export |
| MIDI to relative scale | Offline standard MIDI 0/1 parser, duration-weighted Krumhansl key inference, optional mode override, diatonic relative-mode conversion, MIDI export/playback |
| Knapsack | Offline exact dynamic programming solver with editable items and capacity |
| Skirt sloper | Offline original line/curve formulas and centimeter measurements; full-size vector PDF export and preview |
| Python compiler | Native editor submits to `/api/python_compiler` on the HTTPS server configured in Settings |
| MBTI personality predictor | Opens the original `/project/mbti_personality_predictor` form on the configured server, using its real models |
| Realtime chat | Opens the original `/project/realtime_chat` page on the configured server |

The three connected tools require a running instance of the original Flask application with its database, trained model dependencies and routes. No server is preconfigured or deployed by this app. Inputs are sent only when submitted to that server. The app does not embed Python, MongoDB, model pickles or a fake local MBTI predictor. Its main screen and four offline tools work without a server or JIT.

## Build and install

Changes on `codex/ios-ipa` trigger **Build iPhone IPA**. The workflow builds with Xcode on macOS, tests on an iPhone simulator, launches the app, captures a screenshot and uploads `Rey-Lab-unsigned-IPA`. Download and unzip the artifact, then import `Rey-Lab-unsigned.ipa` into Feather and sign with your certificate/provisioning profile. The unsigned output is not directly installable. No signing secrets are embedded.

For local Xcode builds, copy `static/files/*.mid` and `static/files/*.pdf` into `ios/ReyLab/Resources` before running `xcodegen generate` in `ios`. GitHub Actions performs that step automatically. Both workflows preserve the original web/Python source.

## Port differences

- The native MIDI implementation preserves MIDI bytes, tracks, velocity, controllers and timing; channel 10 percussion is unchanged. It detects one global key and maps notes by two diatonic scale degrees. Accidentals are mapped to a nearest scale tone, so enharmonic/chromatic passages can differ from music21's notation-aware `GenericInterval`. Format 2 and SMPTE division are rejected with a message. It is not a claim of byte-for-byte music21 equivalence.
- Knapsack returns an exact solution instead of the original stochastic genetic search, so population/generation settings are not used.
- ASCII uses the original 7:10 cell aspect ratio and default `#Wo- ` ramp, with Menlo in place of the desktop bitmap font. Image sources are bounded to 50 MB and downsampled before rendering.
- Sloper exports a true-size PDF with centimeter grid and a labeled margin. Use actual-size printing and poster tiling/large-format printing; the PDF is not automatically tiled onto A4.
- Bundled résumé and research PDF are archived repository documents, not updated professional claims.

Tests cover exact knapsack selection/no duplicate items, MIDI melody and percussion preservation, malformed MIDI rejection, pattern geometry/PDF generation and HTTPS server validation. CI success does not substitute for testing signed builds on the user's physical iPhone, and server-backed features require their configured live service.
