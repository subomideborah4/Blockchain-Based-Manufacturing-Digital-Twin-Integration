;; Real-time Synchronization Contract
;; Synchronizes physical and digital manufacturing assets

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_TWIN_NOT_FOUND (err u301))
(define-constant ERR_SYNC_DATA_INVALID (err u302))
(define-constant ERR_SYNC_TOO_FREQUENT (err u303))

;; Minimum blocks between syncs
(define-constant MIN_SYNC_INTERVAL u10)

;; Data structures
(define-map sync-records
  { twin-id: uint, sync-id: uint }
  {
    timestamp: uint,
    data-hash: (buff 32),
    sensor-data: (string-ascii 500),
    sync-status: uint,
    block-height: uint
  }
)

(define-map twin-sync-counts
  { twin-id: uint }
  { count: uint }
)

(define-map twin-last-sync
  { twin-id: uint }
  { last-sync-block: uint }
)

;; Sync status types
(define-constant SYNC_STATUS_PENDING u0)
(define-constant SYNC_STATUS_COMPLETED u1)
(define-constant SYNC_STATUS_FAILED u2)

;; Synchronize twin data
(define-public (sync-twin-data
  (twin-id uint)
  (data-hash (buff 32))
  (sensor-data (string-ascii 500))
)
  (let (
    (sync-count (default-to u0 (get count (map-get? twin-sync-counts { twin-id: twin-id }))))
    (last-sync-block (default-to u0 (get last-sync-block (map-get? twin-last-sync { twin-id: twin-id }))))
  )
    ;; Check sync frequency
    (asserts! (>= (- block-height last-sync-block) MIN_SYNC_INTERVAL) ERR_SYNC_TOO_FREQUENT)

    ;; Create sync record
    (map-set sync-records
      { twin-id: twin-id, sync-id: sync-count }
      {
        timestamp: block-height,
        data-hash: data-hash,
        sensor-data: sensor-data,
        sync-status: SYNC_STATUS_COMPLETED,
        block-height: block-height
      }
    )

    ;; Update counters
    (map-set twin-sync-counts
      { twin-id: twin-id }
      { count: (+ sync-count u1) }
    )

    (map-set twin-last-sync
      { twin-id: twin-id }
      { last-sync-block: block-height }
    )

    (ok sync-count)
  )
)

;; Batch sync multiple twins
(define-public (batch-sync-twins
  (twin-ids (list 10 uint))
  (data-hashes (list 10 (buff 32)))
  (sensor-data-list (list 10 (string-ascii 500)))
)
  (let (
    (sync-results (map sync-single-twin twin-ids data-hashes sensor-data-list))
  )
    (ok sync-results)
  )
)

;; Helper function for batch sync
(define-private (sync-single-twin (twin-id uint) (data-hash (buff 32)) (sensor-data (string-ascii 500)))
  (match (sync-twin-data twin-id data-hash sensor-data)
    success success
    error u999999 ;; Error indicator
  )
)

;; Get sync record
(define-read-only (get-sync-record (twin-id uint) (sync-id uint))
  (map-get? sync-records { twin-id: twin-id, sync-id: sync-id })
)

;; Get twin sync count
(define-read-only (get-twin-sync-count (twin-id uint))
  (default-to u0 (get count (map-get? twin-sync-counts { twin-id: twin-id })))
)

;; Get last sync block
(define-read-only (get-last-sync-block (twin-id uint))
  (default-to u0 (get last-sync-block (map-get? twin-last-sync { twin-id: twin-id })))
)

;; Check if twin can sync
(define-read-only (can-sync-twin (twin-id uint))
  (let (
    (last-sync-block (get-last-sync-block twin-id))
  )
    (>= (- block-height last-sync-block) MIN_SYNC_INTERVAL)
  )
)
