(define-constant err-schedule-not-found (err u200))
(define-constant err-insufficient-funds (err u201))
(define-constant err-schedule-exists (err u202))
(define-constant err-unauthorized-scheduler (err u203))
(define-constant err-invalid-interval (err u204))
(define-constant err-payment-not-due (err u205))

(define-map payment-schedules
  uint
  {
    recipient: principal,
    amount: uint,
    interval-blocks: uint,
    next-payment: uint,
    total-payments: uint,
    payments-made: uint,
    active: bool,
    creator: principal
  })

(define-map user-deposits principal uint)
(define-data-var next-schedule-id uint u1)
(define-data-var contract-balance uint u0)

(define-read-only (get-schedule (schedule-id uint))
  (map-get? payment-schedules schedule-id))

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-deposits user)))

(define-read-only (get-contract-balance)
  (var-get contract-balance))

(define-read-only (is-payment-due (schedule-id uint))
  (match (map-get? payment-schedules schedule-id)
    schedule (and (get active schedule)
                  (>= stacks-block-height (get next-payment schedule))
                  (< (get payments-made schedule) (get total-payments schedule)))
    false))

(define-public (deposit (amount uint))
  (let ((current-balance (get-user-balance tx-sender))
        (new-balance (+ current-balance amount)))
    (begin
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set user-deposits tx-sender new-balance)
      (var-set contract-balance (+ (var-get contract-balance) amount))
      (ok new-balance))))

(define-public (withdraw (amount uint))
  (let ((current-balance (get-user-balance tx-sender)))
    (begin
      (asserts! (>= current-balance amount) err-insufficient-funds)
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      (map-set user-deposits tx-sender (- current-balance amount))
      (var-set contract-balance (- (var-get contract-balance) amount))
      (ok (- current-balance amount)))))

(define-public (create-schedule (recipient principal) (amount uint) (interval-blocks uint) (total-payments uint))
  (let ((schedule-id (var-get next-schedule-id))
        (current-balance (get-user-balance tx-sender))
        (total-cost (* amount total-payments)))
    (begin
      (asserts! (> interval-blocks u0) err-invalid-interval)
      (asserts! (>= current-balance total-cost) err-insufficient-funds)
      (map-set payment-schedules schedule-id
        {
          recipient: recipient,
          amount: amount,
          interval-blocks: interval-blocks,
          next-payment: (+ stacks-block-height interval-blocks),
          total-payments: total-payments,
          payments-made: u0,
          active: true,
          creator: tx-sender
        })
      (var-set next-schedule-id (+ schedule-id u1))
      (ok schedule-id))))

(define-public (execute-payment (schedule-id uint))
  (match (map-get? payment-schedules schedule-id)
    schedule
      (let ((creator-balance (get-user-balance (get creator schedule))))
        (begin
          (asserts! (get active schedule) err-schedule-not-found)
          (asserts! (>= stacks-block-height (get next-payment schedule)) err-payment-not-due)
          (asserts! (< (get payments-made schedule) (get total-payments schedule)) err-schedule-not-found)
          (asserts! (>= creator-balance (get amount schedule)) err-insufficient-funds)
          (map-set user-deposits (get creator schedule) (- creator-balance (get amount schedule)))
          (try! (as-contract (stx-transfer? (get amount schedule) tx-sender (get recipient schedule))))
          (var-set contract-balance (- (var-get contract-balance) (get amount schedule)))
          (let ((new-payments-made (+ (get payments-made schedule) u1)))
            (map-set payment-schedules schedule-id
              (merge schedule {
                payments-made: new-payments-made,
                next-payment: (+ stacks-block-height (get interval-blocks schedule)),
                active: (< new-payments-made (get total-payments schedule))
              })))
          (ok true)))
    err-schedule-not-found))

(define-public (cancel-schedule (schedule-id uint))
  (match (map-get? payment-schedules schedule-id)
    schedule
      (begin
        (asserts! (is-eq tx-sender (get creator schedule)) err-unauthorized-scheduler)
        (asserts! (get active schedule) err-schedule-not-found)
        (map-set payment-schedules schedule-id (merge schedule { active: false }))
        (ok true))
    err-schedule-not-found))
