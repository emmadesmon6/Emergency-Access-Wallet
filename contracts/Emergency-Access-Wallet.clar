(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-emergency-not-active (err u104))
(define-constant err-emergency-still-active (err u105))

(define-data-var emergency-contact (optional principal) none)
(define-data-var emergency-timelock uint u144)
(define-data-var last-owner-activity uint u0)
(define-data-var contract-balance uint u0)

(define-map user-balances principal uint)

(define-read-only (get-emergency-contact)
  (var-get emergency-contact))

(define-read-only (get-emergency-timelock)
  (var-get emergency-timelock))

(define-read-only (get-last-owner-activity)
  (var-get last-owner-activity))

(define-read-only (get-contract-balance)
  (var-get contract-balance))

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user)))

(define-read-only (is-emergency-active)
  (let ((current-height stacks-block-height)
        (last-activity (var-get last-owner-activity))
        (timelock (var-get emergency-timelock)))
    (and (> current-height u0)
         (> current-height (+ last-activity timelock)))))

(define-read-only (blocks-until-emergency)
  (let ((current-height stacks-block-height)
        (last-activity (var-get last-owner-activity))
        (timelock (var-get emergency-timelock))
        (emergency-block (+ last-activity timelock)))
    (if (> current-height emergency-block)
        u0
        (- emergency-block current-height))))

(define-private (update-owner-activity)
  (var-set last-owner-activity stacks-block-height))

(define-public (set-emergency-contact (contact principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set emergency-contact (some contact))
    (update-owner-activity)
    (ok true)))

(define-public (set-emergency-timelock (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> blocks u0) (err u106))
    (var-set emergency-timelock blocks)
    (update-owner-activity)
    (ok true)))

(define-public (deposit (amount uint))
  (let ((sender-balance (get-user-balance tx-sender))
        (new-balance (+ sender-balance amount))
        (new-contract-balance (+ (var-get contract-balance) amount)))
    (begin
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set user-balances tx-sender new-balance)
      (var-set contract-balance new-contract-balance)
      (if (is-eq tx-sender contract-owner)
          (update-owner-activity)
          true)
      (ok new-balance))))

(define-public (withdraw (amount uint))
  (let ((sender-balance (get-user-balance tx-sender))
        (new-balance (- sender-balance amount))
        (new-contract-balance (- (var-get contract-balance) amount)))
    (begin
      (asserts! (>= sender-balance amount) err-insufficient-balance)
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      (map-set user-balances tx-sender new-balance)
      (var-set contract-balance new-contract-balance)
      (if (is-eq tx-sender contract-owner)
          (update-owner-activity)
          true)
      (ok new-balance))))

(define-public (owner-withdraw-all)
  (let ((owner-balance (get-user-balance contract-owner)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (if (> owner-balance u0)
          (withdraw owner-balance)
          (ok u0)))))

(define-public (emergency-claim)
  (let ((contact (var-get emergency-contact))
        (contract-bal (var-get contract-balance)))
    (begin
      (asserts! (is-some contact) err-not-found)
      (asserts! (is-eq tx-sender (unwrap-panic contact)) err-unauthorized)
      (asserts! (is-emergency-active) err-emergency-not-active)
      (asserts! (> contract-bal u0) err-insufficient-balance)
      (try! (as-contract (stx-transfer? contract-bal tx-sender tx-sender)))
      (var-set contract-balance u0)
      (map-set user-balances contract-owner u0)
      (ok contract-bal))))

(define-public (reset-emergency-timer)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (update-owner-activity)
    (ok stacks-block-height)))

(define-public (remove-emergency-contact)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set emergency-contact none)
    (update-owner-activity)
    (ok true)))

(define-public (get-emergency-status)
  (ok {
    contact: (var-get emergency-contact),
    timelock: (var-get emergency-timelock),
    last-activity: (var-get last-owner-activity),
    current-block: stacks-block-height,
    blocks-remaining: (blocks-until-emergency),
    emergency-active: (is-emergency-active),
    contract-balance: (var-get contract-balance)
  }))

(define-public (initialize (contact principal) (timelock-blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (var-get emergency-contact)) (err u107))
    (var-set emergency-contact (some contact))
    (var-set emergency-timelock timelock-blocks)
    (var-set last-owner-activity stacks-block-height)
    (ok true)))

(begin
  (var-set last-owner-activity stacks-block-height))


