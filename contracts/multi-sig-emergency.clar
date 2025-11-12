(define-constant err-owner-only (err u300))
(define-constant err-not-approver (err u301))
(define-constant err-already-approved (err u302))
(define-constant err-insufficient-approvals (err u303))
(define-constant err-no-claim-pending (err u304))
(define-constant err-invalid-threshold (err u305))
(define-constant err-approver-exists (err u306))

(define-constant err-claim-expired (err u307))

(define-data-var claim-expiration-window uint u1008)

(define-data-var contract-owner principal tx-sender)
(define-data-var approval-threshold uint u2)
(define-data-var claim-nonce uint u0)

(define-map approvers principal bool)
(define-map approver-list uint principal)
(define-data-var approver-count uint u0)

(define-map claim-approvals
  uint
  {
    claimer: principal,
    amount: uint,
    created-block: uint,
    approval-count: uint,
    executed: bool
  })

(define-map claim-signatures
  { claim-id: uint, approver: principal }
  bool)

(define-read-only (get-approval-threshold)
  (var-get approval-threshold))

(define-read-only (get-approver-count)
  (var-get approver-count))

(define-read-only (is-approver (account principal))
  (default-to false (map-get? approvers account)))

(define-read-only (get-claim-details (claim-id uint))
  (map-get? claim-approvals claim-id))

(define-read-only (has-approved (claim-id uint) (approver principal))
  (default-to false (map-get? claim-signatures { claim-id: claim-id, approver: approver })))

(define-public (add-approver (approver principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (asserts! (not (is-approver approver)) err-approver-exists)
    (map-set approvers approver true)
    (let ((count (var-get approver-count)))
      (map-set approver-list count approver)
      (var-set approver-count (+ count u1)))
    (ok true)))

(define-public (remove-approver (approver principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (asserts! (is-approver approver) err-not-approver)
    (map-delete approvers approver)
    (ok true)))

(define-public (set-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (asserts! (and (> new-threshold u0) (<= new-threshold (var-get approver-count))) err-invalid-threshold)
    (var-set approval-threshold new-threshold)
    (ok true)))

(define-public (initiate-claim (amount uint))
  (let ((current-nonce (var-get claim-nonce)))
    (begin
      (map-set claim-approvals current-nonce
        {
          claimer: tx-sender,
          amount: amount,
          created-block: stacks-block-height,
          approval-count: u0,
          executed: false
        })
      (var-set claim-nonce (+ current-nonce u1))
      (ok current-nonce))))

(define-public (approve-claim (claim-id uint))
  (match (map-get? claim-approvals claim-id)
    claim
      (begin
        (asserts! (is-approver tx-sender) err-not-approver)
        (asserts! (not (has-approved claim-id tx-sender)) err-already-approved)
        (asserts! (not (get executed claim)) err-no-claim-pending)
        (map-set claim-signatures { claim-id: claim-id, approver: tx-sender } true)
        (map-set claim-approvals claim-id
          (merge claim { approval-count: (+ (get approval-count claim) u1) }))
        (ok true))
    err-no-claim-pending))

(define-public (execute-claim (claim-id uint))
  (match (map-get? claim-approvals claim-id)
    claim
      (begin
        (asserts! (is-eq tx-sender (get claimer claim)) err-owner-only)
        (asserts! (not (get executed claim)) err-no-claim-pending)
        (asserts! (>= (get approval-count claim) (var-get approval-threshold)) err-insufficient-approvals)
        (map-set claim-approvals claim-id (merge claim { executed: true }))
        (ok (get amount claim)))
    err-no-claim-pending))





(define-read-only (get-claim-expiration-window)
  (var-get claim-expiration-window))

(define-read-only (is-claim-expired (claim-id uint))
  (match (map-get? claim-approvals claim-id)
    claim
      (let ((current-height stacks-block-height)
            (claim-created (get created-block claim))
            (expiration-window (var-get claim-expiration-window))
            (expiration-block (+ claim-created expiration-window)))
        (>= current-height expiration-block))
    true))

(define-public (set-claim-expiration-window (new-window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (asserts! (> new-window u0) err-invalid-threshold)
    (var-set claim-expiration-window new-window)
    (ok true)))

(define-public (execute-claim-with-expiration (claim-id uint))
  (match (map-get? claim-approvals claim-id)
    claim
      (begin
        (asserts! (is-eq tx-sender (get claimer claim)) err-owner-only)
        (asserts! (not (get executed claim)) err-no-claim-pending)
        (asserts! (not (is-claim-expired claim-id)) err-claim-expired)
        (asserts! (>= (get approval-count claim) (var-get approval-threshold)) err-insufficient-approvals)
        (map-set claim-approvals claim-id (merge claim { executed: true }))
        (ok (get amount claim)))
    err-no-claim-pending))