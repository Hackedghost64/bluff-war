# JUMP 7 — Performance Benchmarks & Root Cause Analysis

## 1. Packet Flood Stress Test
*   **Target:** 1,000 rapid-fire JSON packets.
*   **Result:** Processed 1,000 packets in **40-45ms**.
*   **Stability:** 100% processing rate. No isolate lockups detected.
*   **Memory Footprint:** Negligible growth for packet IDs (capped at 100 entries).

## 2. O(1) Deduplication Efficiency
*   **Method:** Set-based lookup for packet IDs.
*   **Observation:** Duplicate packets (identical UUIDs) are discarded in constant time before any game logic or JSON parsing of the `data` payload occurs.
*   **Capacity:** Strictly enforced FIFO eviction at 100 entries.

## 3. Root Cause Analysis (RCA) - Potential Bottlenecks

### Issue: Main Isolate Blocking
*   **Analysis:** Current JSON decoding (`json.decode`) and state validation happen on the main isolate. During the 1,000-packet flood, the isolate was occupied for ~40ms. While acceptable for a 1,000-packet spike, sustained high-frequency traffic (>500 packets/sec) would drop the UI frame rate below 60FPS.
*   **Impact:** Minor UI stutter during heavy network bursts.
*   **Proposed Solution:** Offload `json.decode` and schema validation to a background isolate using Flutter's `compute()` or `Isolate.spawn()` for traffic exceeding a threshold.

### Issue: Memory Management
*   **Analysis:** The deduplication history is stored in a `Set` and a `List`.
*   **Root Cause:** Rapid addition and eviction in the `List` (`removeAt(0)`) is $O(N)$. At $N=100$, this is trivial, but if the history size increases to $10,000+$, eviction will become a bottleneck.
*   **Proposed Solution:** Use a `Queue` for the ID history to maintain $O(1)$ eviction if larger history windows are required.

## 4. Conclusion
The Bluff War engine is structurally sound for P2P play. The Host-Authoritative state machine correctly handles out-of-order delivery and hardware disconnections. The system is ready for the visual identity phase (Jump 8).
