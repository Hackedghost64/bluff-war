# Bluff War

> A high-speed, local multiplayer card game built with Flutter and Google Nearby Connections — no internet required.

**Platform:** Android · iOS · Linux  
**Version:** 1.1.0  
**Stack:** Flutter 3 · Dart · Google Nearby Connections · audioplayers

---

## What Is It?

Bluff War is a local P2P multiplayer card game where players challenge each other over Bluetooth/Wi-Fi Direct using Google Nearby Connections. There is no server. No matchmaking service. No internet required. Two or more devices discover each other, one becomes the Host, and the game begins.

The core engineering challenge is keeping every player's game state perfectly synchronised across an unreliable, connectionless transport layer — and doing so without a central authority to resolve conflicts.

---

## Architecture

### Host-Authoritative State Machine

The entire game runs on a **Host-Authoritative** model to prevent state drift in a P2P environment.

```
[Guest Device]                          [Host Device]
     │                                       │
     │  ── play_card_intent ──────────────►  │
     │                                       ├─ _isValidTransition()
     │                                       ├─ mutate GameState
     │  ◄─────────────── state_sync ─────────┤
     │                                       │
  (UI re-renders from                  (Source of truth)
   validated state only)
```

**Rules:**
- Only the **Host** (Advertiser) owns the `GameState`. It is the single source of truth.
- **Guests** (Discoverers) never mutate local state directly. Every action — playing a card, making a challenge — emits an **Intent Packet** to the Host.
- The Host validates the intent against strict state machine rules (`_isValidTransition`), executes the mutation, then broadcasts the updated `GameState` to all connected peers via a `state_sync` packet.
- The Guest UI is purely reactive: it only updates when a validated `state_sync` arrives.

This means desync is structurally impossible — a Guest cannot enter an invalid state, because it never writes state on its own.

---

### Packet Deduplication

Google Nearby Connections can deliver duplicate payloads due to internal retry logic or network jitter. Without protection, the state machine could process the same action twice — e.g. applying damage twice for a single challenge — causing an immediate desync.

**Solution:**

- Every outgoing packet includes a unique 32-character ID.
- The `GameController` maintains a `Set<String>` of processed packet IDs. Lookup is **O(1)**.
- To prevent unbounded memory growth during long sessions, a **FIFO queue** bounds the tracking history to the last **100 packets**. Old IDs are evicted once capacity is reached.

```dart
// Simplified deduplication logic
final Set<String> _processedIds = {};
final Queue<String> _idQueue = Queue();
const int _maxHistory = 100;

bool _isDuplicate(String id) {
  if (_processedIds.contains(id)) return true;
  if (_idQueue.length >= _maxHistory) {
    _processedIds.remove(_idQueue.removeFirst());
  }
  _idQueue.add(id);
  _processedIds.add(id);
  return false;
}
```

---

### Packet Schema

All P2P messages follow a rigid JSON schema. Packets that fail validation are silently discarded with a warning log — the controller is never exposed to malformed data.

```json
{
  "version": 1,
  "type": "play_card_intent | state_sync | challenge_intent | ...",
  "id": "a8f3c2d1e4b7...",
  "timestamp": 1716912345678,
  "data": {}
}
```

Required fields: `version`, `type`, `id`, `timestamp`, `data`. Any packet missing these is dropped.

---

### Engineering Commitments

| Decision | Why |
|---|---|
| Host-authoritative model | Eliminates the possibility of state drift without needing a server |
| O(1) deduplication via `Set<String>` | Constant-time packet validation regardless of session length |
| FIFO eviction at 100 packets | Bounded memory — no leaks during extended play sessions |
| Rigid JSON schema with strict validation | Protects the state machine from malformed or injected payloads |
| No internet dependency | Bluetooth/Wi-Fi Direct via Nearby Connections — works entirely offline |

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.4`
- Android device with Bluetooth and Location permissions enabled (required by Nearby Connections)

### Run

```bash
flutter pub get
flutter run
```

### Verify

```bash
flutter analyze
flutter test
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `nearby_connections ^4.3.0` | P2P transport layer (Bluetooth / Wi-Fi Direct) |
| `audioplayers ^6.1.1` | In-game sound effects |
| `permission_handler ^11.3.1` | Runtime permission requests (Bluetooth, Location) |
| `package_info_plus ^8.0.0` | App version metadata |
| `http ^1.2.1` | Optional remote asset fetching |
| `url_launcher ^6.3.0` | External link handling |

---

## Project Structure

```
lib/
├── main.dart               # App entry point
├── game_controller.dart    # Host-authoritative state machine & deduplication
├── models/                 # GameState, Card, Player, Packet schemas
├── screens/                # Lobby, Game, Result screens
└── services/               # NearbyConnectionsService, PacketRouter
docs/                       # Architecture diagrams
```

---

## License

MIT — see `LICENSE` for details.
