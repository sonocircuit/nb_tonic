# nb_tonic

an eight voice supertonic port – big thanks to zack for [supertonic](https://github.com/schollz/supertonic/tree/main), which itself was inspired by magnus lidström's [microtonic](https://soniccharge.com/microtonic) drum synth. <br>
nb tonic makes the supertonic sound available for norns scripts that support nb, with some minor changes and additions:

* extends the number of voices to eight
* adds six choke groups (six voice polyphony)
* load and save kits and individual voices via menu
* kit and voice preview within the file select menu (turn E3 CW)
* replaces noise generators with a noise buffer (uses two playback heads for stereo noise)
* velocity modulation is handled differently (a value of 0% will no longer mute the signal)
* adds pan/balance to each voice
* distortion is handled differently (soft clip + post-distortion attenuation) → gets crunchy but not too loud

### documentation:

* Install and activate **nb_tonic** like other mods. Load a script that supports nb players and select **tonic**.
* **tonic** initializes with the default kit loaded. Complete kits can be loaded and saved under `tonic kits`. When a pset of the active script is saved, all parameters are saved as well, so saving kits isn't necessary but provides a way of backing up your favorite settings. When in the `>> load` menu, kits can be previewed by turning E3. Overwrite the default kit with your own setting to have your sounds of choice loaded at init.
* Under `settings`, the global parameters for `main level` and `base note` are accessed. The `base note` defines which note will trigger voice 1. The next seven subsequent semitones will trigger voices 2–8.
* Under `global lpf`, the cutoff frequency and resonance of the global low-pass filter are accessed.
* Under `voice` and subsequent sections, all parameters of the currently selected voice are accessed. `> load voice` and `< save voice` allow you to load and save the currently selected voice. When in the load menu, the voice can be previewed by turning E3.
