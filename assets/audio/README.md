# MVP audio assets

All files are **44.1 kHz, mono, 16-bit PCM WAV**, normalized to 0.88 full scale
(about -1.1 dBFS) with a short de-click fade at the loop seam. Music stems are
16 beats (4 bars of 4/4) at **140 BPM = 6.857142 s = 302400 frames**, matching
the `BPM := 140.0` constant in `scripts/autoload/audio_manager.gd` so the
AudioManager beat/bar counters stay in phase with the loop.

## Looping

The three music stems carry a standard RIFF `smpl` chunk describing one
full-length **forward** loop (start frame 0, end frame 302400). Godot 4.3's WAV
importer defaults to "Detect From WAV", so imported stems become looping
`AudioStreamWAV` resources. As a second layer, `AudioManager.play_music()` (and
`play_vocals()`) set `loop_mode = LOOP_FORWARD`, `loop_begin = 0` and
`loop_end = frame_count` on the stream before playback, so music still loops if
the import preset is overridden to "Disabled". SFX are written without loop
metadata and played via the one-shot `play_sfx()` path.

| Plan slot | File | Origin |
|---|---|---|
| Base beat loop (instrumental) | `music/base_beat.wav` | synthesized: kick + snare + hats, bass, pad, arpeggio |
| Drum track stem | `music/drums.wav` | synthesized; phase-aligned with `base_beat.wav` |
| Vocal track stem | `music/vocals.wav` | **synthesized guide placeholder** — vowel-like_pad, no lyrics, not AI-generated |
| Laser fire SFX | `sfx/laser.wav` | synthesized descending saw/square sweep, 0.16 s |
| Missile fire SFX | `sfx/missile.wav` | synthesized rising filtered-noise whoosh, 0.42 s |
| Bomb fire SFX | `sfx/bomb.wav` | synthesized sub-bass boom + noise, 1.00 s |
| Enemy hit/destroyed — hit | `sfx/enemy_hit.wav` | synthesized short impact + metallic ping, 0.12 s |
| Enemy hit/destroyed — destroyed | `sfx/enemy_destroyed.wav` | synthesized crunch + falling tone, 0.38 s |
| Explosion SFX | `sfx/explosion.wav` | synthesized rumble + crackle layers, 1.20 s |

`enemy_hit.wav` and `enemy_destroyed.wav` are separate slots so the impact and
destruction cases from the plan's combined "enemy hit/destroyed" row can be
wired independently.

## Generate / validate

From the Godot project root:

```sh
python3 assets/audio/generate_audio.py          # regenerate every WAV
python3 assets/audio/generate_audio.py --check  # header/duration/peak/loop validation
```

The generator uses only the Python 3 standard library (`wave`, `array`, `math`,
`random`, `struct`, `io`) and fixed noise seeds, so re-running produces
byte-identical files. `--check` also verifies that music stems contain a
full-length forward `smpl` loop and that SFX contain no loop metadata.

A Sonic Pi score for this stage lives in the parent repository at
`docs/music/stage1.rb` (stage-name convention from `docs/music/readme.md`).
It was **authored but not executed** here — see "Deferred steps" below.

## Tool inventory (checked in this build environment, 2026-11-18)

| Tool | Status |
|---|---|
| `python3` 3.12.3 | available (stdlib only) |
| `node` / `npm` | available, not used |
| `sox`, `ffmpeg` | absent |
| Sonic Pi, `scsynth`, `ruby` | absent |
| Suno / Udio | no installed client, no credentials; no AI generation was attempted |
| Ultimate Vocal Remover (UVR), `demucs` | absent |
| Audacity | absent |

Nothing was installed: the repository's `AGENTS.md` forbids adding new
runtimes/apps to this environment.

## Deferred steps (to upgrade the placeholders)

1. **Suno/Udio base generation** — generate a 140 BPM retrowave instrumental
   with the stage-1 lyrics in Suno or Udio, export a WAV, then loop-trim it to
   16 beats at 44.1 kHz and replace `music/base_beat.wav`. No claim is made
   that any file here came from an AI music generator.
2. **UVR stem isolation** — on a machine with UVR and PyTorch installed, load
   the AI base WAV, run model `htdemucs_ft` (or the UVR karaoke model for the
   vocal pass), and export `drums.wav` / `vocals.wav` into `music/`. Replace
   both stems together so they stay phase-aligned with the base loop. The
   current stems are synthesized from the same score, not separated.
3. **Audacity loop cleanup** — open each replacement loop, apply a 5 ms Fade
   In at 0:00 and a 5 ms Fade Out at the end, verify with looped playback,
   then export as 16-bit PCM WAV at 44.1 kHz mono. The generated files already
   have these fades applied.
4. **Sonic Pi render** — open `docs/music/stage1.rb` in Sonic Pi 4.x, run each
   layer separately (mute the other `live_loop`s) and record the output to the
   corresponding `music/*.wav`. This gives the authoritative scored version of
   the base beat, drum stem and vocal guide once Sonic Pi is available.
