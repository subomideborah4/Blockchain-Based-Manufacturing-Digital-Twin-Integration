;; Manufacturer Verification Contract
;; Validates and manages manufacturing companies on the blockchain

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MANUFACTURER_EXISTS (err u101))
(define-constant ERR_MANUFACTURER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Manufacturer status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map manufacturers
  { manufacturer-id: uint }
  {
    company-name: (string-ascii 100),
    contact-address: (string-ascii 200),
    verification-status: uint,
    registration-block: uint,
    last-updated: uint
  }
)

(define-map manufacturer-principals
  { principal: principal }
  { manufacturer-id: uint }
)

(define-data-var next-manufacturer-id uint u1)

;; Register a new manufacturer
(define-public (register-manufacturer (company-name (string-ascii 100)) (contact-address (string-ascii 200)))
  (let ((manufacturer-id (var-get next-manufacturer-id)))
    (asserts! (is-none (map-get? manufacturer-principals { principal: tx-sender })) ERR_MANUFACTURER_EXISTS)
    (map-set manufacturers
      { manufacturer-id: manufacturer-id }
      {
        company-name: company-name,
        contact-address: contact-address,
        verification-status: STATUS_PENDING,
        registration-block: block-height,
        last-updated: block-height
      }
    )
    (map-set manufacturer-principals
      { principal: tx-sender }
      { manufacturer-id: manufacturer-id }
    )
    (var-set next-manufacturer-id (+ manufacturer-id u1))
    (ok manufacturer-id)
  )
)

;; Verify a manufacturer (admin only)
(define-public (verify-manufacturer (manufacturer-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? manufacturers { manufacturer-id: manufacturer-id })
      manufacturer-data
      (begin
        (map-set manufacturers
          { manufacturer-id: manufacturer-id }
          (merge manufacturer-data { verification-status: STATUS_VERIFIED, last-updated: block-height })
        )
        (ok true)
      )
      ERR_MANUFACTURER_NOT_FOUND
    )
  )
)

;; Update manufacturer status
(define-public (update-manufacturer-status (manufacturer-id uint) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (match (map-get? manufacturers { manufacturer-id: manufacturer-id })
      manufacturer-data
      (begin
        (map-set manufacturers
          { manufacturer-id: manufacturer-id }
          (merge manufacturer-data { verification-status: new-status, last-updated: block-height })
        )
        (ok true)
      )
      ERR_MANUFACTURER_NOT_FOUND
    )
  )
)

;; Get manufacturer info
(define-read-only (get-manufacturer (manufacturer-id uint))
  (map-get? manufacturers { manufacturer-id: manufacturer-id })
)

;; Get manufacturer ID by principal
(define-read-only (get-manufacturer-id (principal-addr principal))
  (map-get? manufacturer-principals { principal: principal-addr })
)

;; Check if manufacturer is verified
(define-read-only (is-manufacturer-verified (manufacturer-id uint))
  (match (map-get? manufacturers { manufacturer-id: manufacturer-id })
    manufacturer-data
    (is-eq (get verification-status manufacturer-data) STATUS_VERIFIED)
    false
  )
)
