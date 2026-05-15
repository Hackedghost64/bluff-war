# Bluff War (P2P Multiplayer)

A high-speed, local multiplayer card game built with Flutter and Google Nearby Connections.

## System Architecture (Jump 6)

### Host-Authoritative State Machine
To ensure synchronization and prevent "state drift" in a P2P environment, Bluff War utilizes a **Host-Authoritative** model:

1.  **State Ownership:** Only the **Host** device (Advertiser) owns the source of truth for the `GameState`.
2.  **Intent Flow (Guest -> Host):** When a **Guest** (Discoverer) performs an action (e.g., playing a card, challenging), it does *not* mutate its local state. Instead, it emits an **Intent Packet** (e.g., `play_card_intent`) to the Host.
3.  **Validation & Execution:** The Host receives the intent, validates it against the strict state machine rules (`_isValidTransition`), executes the mutation, and broadcasts the updated `GameState` to all connected peers via a `state_sync` packet.
4.  **Reactive UI:** The Guest UI is purely reactive; it only updates when a validated `state_sync` is received from the Host.

### Packet Deduplication Strategy
Google Nearby Connections can occasionally deliver duplicate payloads due to internal retry mechanisms or network jitter. 

**The "Why":** Without deduplication, the state machine could process the same action twice (e.g., applying damage twice for a single challenge), leading to immediate desync.

**The "How":**
*   **O(1) Lookup:** Every packet includes a unique 32-character ID. The `GameController` maintains a `Set<String>` of processed IDs for constant-time lookup.
*   **Memory Management:** To prevent memory leaks during long sessions, a FIFO (First-In-First-Out) queue limits the tracking history to the last **100 packets**. Old IDs are evicted once the capacity is reached.

### Strict Schema Validation
All P2P communication follows a rigid JSON schema:
```json
{ 
  "version": 1, 
  "type": "string", 
  "id": "pseudo-uuid-string", 
  "timestamp": 1234567890, 
  "data": {} 
}
```
Packets failing this validation are discarded with a warning, protecting the controller from malformed data.
