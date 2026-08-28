# Port Authority

A macOS menu bar app that shows what your USB-C and MagSafe ports are actually
negotiating: the charger's advertised power profiles, the contract your Mac
settled on, and live wattage.

## What it reads

Three layers, in descending order of durability:

**IORegistry (`IOAccessory` plane).** Port enumeration, connection state, plug
orientation, active/passive cable, transports, liquid detection. No entitlement,
no root, fully supported API. This layer is the floor: if everything else breaks,
the app still works.

**`AppleSmartBattery`.** Live `AdapterPower` and `SystemPower` in watts, plus the
adapter's nameplate rating. Cheap enough to poll continuously.

**`/usr/bin/hpmdiagnose`.** The PD controller register file, which carries the
received source capabilities and the active contract. This is an undocumented
Apple tool and the register layout is neither published nor stable across models
or firmware. Everything downstream of it degrades gracefully to nil.

The app cannot talk to the PD driver directly: `AppleHPMUserClient` requires
`com.apple.USBCEntitlement`, which is Apple-private. Shelling out to their
signed binary is the only route.

## Register map

Established by differential capture on an M4 Pro (Mac16,8), then validated
against `AppleSmartBattery`'s independent `UsbHvcMenu` / `UsbHvcHvcIndex`
report — two unrelated sources agreeing.

| Register | Contents |
|----------|----------|
| `0x1A` | Status; bit 0 = plug present |
| `0x30` | Received source capabilities: count byte, then N little-endian PDOs |
| `0x35` | Active contract: RDO, followed by an echo of the PDO it selected |
| `0x36` | Sink request RDO |

PDO and RDO bit layouts are fixed by the USB PD specification, so that decoding
is spec-driven rather than reverse-engineered.

## Usage

```bash
portauth status              # human-readable summary
portauth json                # machine-readable snapshot
portauth dump                # controller inventory
portauth decode <capture>    # offline decode of a saved hpmdiagnose capture
```

## Building

Requires only the Command Line Tools — no Xcode.

```bash
swift build -c release
Scripts/make-app.sh
```

## Known gaps

- Cable e-marker VDOs are not yet located in the register map. The app infers
  e-marking from a contract above 3A rather than claiming to have read it.
- `ActiveCable` in the registry distinguishes active cables from passive ones.
  It is not an e-marker flag.

## License

MIT
