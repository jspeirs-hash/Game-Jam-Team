# Game audio

The hideout, battle, snow, shadow and credits music, wind ambience and all synthetic game effects were composed/generated for this project with Python/NumPy. No external sample packs were used for those assets.

`SFX/rat_death_voice.wav` and `SFX/cat_spawn_voice.wav` are excerpts from the user-supplied "Return By Death FULL Sound Effect Re Zero – Starting Life In Another World.mp3". Requested cuts: 3–10 seconds for rat death, 0–2 seconds for cat emergence. Those two excerpts retain their source's ownership; they are not part of the original synthesized score.

Music loops and transitions are managed by the `GameAudio` autoload. Music and sound-effect volume settings are stored separately in `user://audio_settings.cfg`. F10 or the SOUND button opens the controls.

`SFX/dialogue_tick.wav` is an original low synth blip for the cat dialogue typewriter. Dialogue advances once per attack or skill action, with player turns after lines one and two and a single paw attack after line three.

Original feature-pass effects: footstep.wav, hideout_air.wav (air and distant bird-like synth chirps), scout_signal.wav, atom_signal.wav and smasher_signal.wav. These are generated for this project and follow the sound-effect volume setting.
