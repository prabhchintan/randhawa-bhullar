import CloudKit
import Foundation

/// Mirrors moments and memories into the user's private CloudKit database, so
/// the map and its memories survive a new phone and flow between devices.
///
/// The design leans on Apple's stack end to end:
/// - The user's Apple Account is the account. There is nothing to create,
///   no password, and no sign-in screen; if the device is signed into
///   iCloud, sync can work.
/// - Records live in the private database of the shared container
///   `iCloud.Prabhchintan.Randhawa`, which both Randhawa and Bhullar use, so
///   a memory made in one app reaches the other through the same zone.
/// - The private database is invisible to us. We run no servers, and CloudKit
///   gives us no way to read anyone's records. Storage counts against the
///   user's own iCloud space, and costs us nothing.
///
/// Sync is off until the user turns it on. Everything still works without it;
/// the app-group files remain the local source of truth, and this class only
/// mirrors them. CKSyncEngine (iOS 17) does the heavy lifting: batching,
/// retries, and scheduling. We fetch on every foreground and let the engine
/// send in the background whenever local changes queue up.
@MainActor
final class CloudSync: CKSyncEngineDelegate {
    static let containerIdentifier = "iCloud.Prabhchintan.Randhawa"
    static let zoneName = "SpaceTime"
    static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    private static let enabledKey = "cloudSyncEnabled"

    /// Both apps read the same switch, so turning sync on in one turns it on
    /// for the other.
    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: MomentPersistence.appGroupID) ?? .standard
    }

    /// Whether the user has answered the sync question at all. Until they
    /// have, the apps may offer it once.
    static var isDecided: Bool {
        sharedDefaults.object(forKey: enabledKey) != nil
    }

    static var isEnabled: Bool {
        sharedDefaults.bool(forKey: enabledKey)
    }

    private(set) static var shared: CloudSync?

    /// Call once at app start. A no-op unless the user has sync turned on.
    static func startIfEnabled() {
        guard shared == nil, isEnabled else { return }
        shared = CloudSync()
    }

    static func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled || isDecided == false else { return }
        sharedDefaults.set(enabled, forKey: enabledKey)
        if enabled {
            if shared == nil {
                shared = CloudSync()
            }
            shared?.uploadEverything()
            shared?.fetchNow()
        } else {
            shared = nil
            try? FileManager.default.removeItem(at: stateFileURL())
        }
    }

    /// Records the user's explicit "not now" so the offer is not repeated.
    static func declineOffer() {
        guard !isDecided else { return }
        sharedDefaults.set(false, forKey: enabledKey)
    }

    // MARK: - Engine

    private var engine: CKSyncEngine!

    /// Server-side versions of records we have seen, so re-saves carry the
    /// right change tag. Purely a warm cache: after a relaunch a re-save may
    /// conflict once, and the conflict handler repairs it.
    private var lastKnownRecords: [CKRecord.ID: CKRecord] = [:]

    private init() {
        var configuration = CKSyncEngine.Configuration(
            database: CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase,
            stateSerialization: Self.loadStateSerialization(),
            delegate: self
        )
        configuration.automaticallySync = true
        engine = CKSyncEngine(configuration)
    }

    // MARK: - Local intents

    func momentAppended(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(moment: id))])
    }

    /// Moments are otherwise append-only, but the trail can be forgotten on
    /// request, and a dot deleted here must not come back on the next fetch.
    func momentDeleted(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(Self.recordID(moment: id))])
    }

    func memoryChanged(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(memory: id))])
    }

    func memoryDeleted(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(Self.recordID(memory: id))])
    }

    /// The user erased their map: drop every queued change and delete the
    /// whole zone, moments and memories alike, from their iCloud.
    func eraseEverything() {
        engine.state.remove(pendingRecordZoneChanges: engine.state.pendingRecordZoneChanges)
        engine.state.add(pendingDatabaseChanges: [.deleteZone(Self.zoneID)])
        lastKnownRecords = [:]
    }

    /// Queues every local record for upload; used when sync first turns on
    /// and when an iCloud account signs in.
    func uploadEverything() {
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for moment in MomentSync.allMoments() {
            changes.append(.saveRecord(Self.recordID(moment: moment.id)))
        }
        for memory in MemoryPersistence.load() {
            changes.append(.saveRecord(Self.recordID(memory: memory.id)))
        }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Called on foreground. Cheap when nothing changed.
    func fetchNow() {
        Task {
            try? await engine.fetchChanges()
        }
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            Self.saveStateSerialization(stateUpdate.stateSerialization)

        case .accountChange(let accountChange):
            handleAccountChange(accountChange)

        case .fetchedDatabaseChanges(let changes):
            // Our zone deleted on the server means the user erased everything
            // from another device; mirror that here.
            for deletion in changes.deletions where deletion.zoneID == Self.zoneID {
                MomentSync.eraseAllLocal()
                MemoryStore.shared.eraseAll()
                lastKnownRecords = [:]
            }

        case .fetchedRecordZoneChanges(let changes):
            applyFetched(changes)

        case .sentRecordZoneChanges(let sent):
            handleSent(sent)

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        // Snapshot everything on the main actor; the record provider below
        // may run anywhere, so it touches only these immutable copies.
        let moments = Dictionary(uniqueKeysWithValues: MomentSync.allMoments().map { ($0.id, $0) })
        let memories = Dictionary(uniqueKeysWithValues: MemoryStore.shared.memories.map { ($0.id, $0) })
        let known = lastKnownRecords

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            switch Self.parse(recordID) {
            case .moment(let id):
                guard let moment = moments[id] else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    return nil
                }
                return Self.record(for: moment, recordID: recordID, base: known[recordID])
            case .memory(let id):
                guard let memory = memories[id] else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    return nil
                }
                return Self.record(for: memory, recordID: recordID, base: known[recordID])
            case nil:
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
        }
    }

    // MARK: - Event handling

    private func applyFetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var fetchedMoments: [Moment] = []
        for modification in changes.modifications {
            let record = modification.record
            lastKnownRecords[record.recordID] = record
            switch record.recordType {
            case RecordType.moment:
                if let moment = Self.moment(from: record) {
                    fetchedMoments.append(moment)
                }
            case RecordType.memory:
                if let (memory, photoSourceURL) = Self.memory(from: record) {
                    MemoryStore.shared.applyFetched(memory, photoSourceURL: photoSourceURL)
                }
            default:
                break
            }
        }
        if !fetchedMoments.isEmpty {
            MomentSync.upsert(fetchedMoments)
        }

        var momentDeletions: Set<UUID> = []
        var memoryDeletions: Set<UUID> = []
        for deletion in changes.deletions {
            lastKnownRecords[deletion.recordID] = nil
            switch Self.parse(deletion.recordID) {
            case .moment(let id): momentDeletions.insert(id)
            case .memory(let id): memoryDeletions.insert(id)
            case nil: break
            }
        }
        if !momentDeletions.isEmpty {
            MomentSync.remove(ids: momentDeletions)
        }
        if !memoryDeletions.isEmpty {
            MemoryStore.shared.removeFetched(ids: memoryDeletions)
        }
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        for record in sent.savedRecords {
            lastKnownRecords[record.recordID] = record
        }
        for recordID in sent.deletedRecordIDs {
            lastKnownRecords[recordID] = nil
        }
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Someone else wrote this record first. Take the server copy
                // as the new base and send our fields again on top of it.
                if let serverRecord = failure.error.serverRecord {
                    lastKnownRecords[recordID] = serverRecord
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                }
            case .zoneNotFound:
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .unknownItem:
                // The server lost track of it; save it fresh.
                lastKnownRecords[recordID] = nil
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            default:
                // Transient failures (network, throttling) are retried by the
                // engine on its own schedule.
                break
            }
        }
        for (recordID, _) in sent.failedRecordDeletes {
            lastKnownRecords[recordID] = nil
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            uploadEverything()
        case .switchAccounts:
            // The device's map belongs to the person holding the device;
            // offer it to the account that just arrived.
            lastKnownRecords = [:]
            uploadEverything()
        case .signOut:
            // Keep everything local; the engine idles until an account is back.
            lastKnownRecords = [:]
        @unknown default:
            break
        }
    }

    // MARK: - Records

    private enum RecordType {
        static let moment = "Moment"
        static let memory = "Memory"
    }

    private enum ParsedRecordID {
        case moment(UUID)
        case memory(UUID)
    }

    private static func recordID(moment id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "moment-" + id.uuidString, zoneID: zoneID)
    }

    private static func recordID(memory id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "memory-" + id.uuidString, zoneID: zoneID)
    }

    private nonisolated static func parse(_ recordID: CKRecord.ID) -> ParsedRecordID? {
        let name = recordID.recordName
        if name.hasPrefix("moment-"), let id = UUID(uuidString: String(name.dropFirst("moment-".count))) {
            return .moment(id)
        }
        if name.hasPrefix("memory-"), let id = UUID(uuidString: String(name.dropFirst("memory-".count))) {
            return .memory(id)
        }
        return nil
    }

    private nonisolated static func record(for moment: Moment, recordID: CKRecord.ID, base: CKRecord?) -> CKRecord {
        let record = base ?? CKRecord(recordType: RecordType.moment, recordID: recordID)
        record["latitude"] = moment.latitude
        record["longitude"] = moment.longitude
        record["date"] = moment.date
        return record
    }

    private nonisolated static func record(for memory: Memory, recordID: CKRecord.ID, base: CKRecord?) -> CKRecord {
        let record = base ?? CKRecord(recordType: RecordType.memory, recordID: recordID)
        record["date"] = memory.date
        record["latitude"] = memory.latitude
        record["longitude"] = memory.longitude
        record["placeName"] = memory.placeName
        record["text"] = memory.text
        if let fileName = memory.photoFileName,
           let url = MemoryPersistence.photoURL(fileName: fileName),
           FileManager.default.fileExists(atPath: url.path) {
            record["photo"] = CKAsset(fileURL: url)
        } else {
            record["photo"] = nil
        }
        return record
    }

    private static func moment(from record: CKRecord) -> Moment? {
        guard case .moment(let id) = parse(record.recordID),
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double,
              let date = record["date"] as? Date else { return nil }
        return Moment(id: id, latitude: latitude, longitude: longitude, date: date)
    }

    /// Returns the memory plus the downloaded asset's temporary URL, so the
    /// store can copy the photo into its own folder.
    private static func memory(from record: CKRecord) -> (Memory, URL?)? {
        guard case .memory(let id) = parse(record.recordID),
              let date = record["date"] as? Date,
              let text = record["text"] as? String else { return nil }
        let photoSourceURL = (record["photo"] as? CKAsset)?.fileURL
        let memory = Memory(
            id: id,
            date: date,
            latitude: record["latitude"] as? Double,
            longitude: record["longitude"] as? Double,
            placeName: record["placeName"] as? String,
            text: text,
            photoFileName: photoSourceURL == nil ? nil : id.uuidString + ".jpg"
        )
        return (memory, photoSourceURL)
    }

    // MARK: - Engine state persistence

    private static func stateFileURL() -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "app"
        let base = MomentPersistence.containerURL() ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("cloudsync-state-" + bundleID + ".json")
    }

    private static func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateFileURL()) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private static func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        try? data.write(to: stateFileURL(), options: .atomic)
    }
}
