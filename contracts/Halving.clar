;; title: Halving

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INVALID-ORACLE (err u101))
(define-constant ERR-INVALID-HEIGHT (err u102))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u103))
(define-constant ERR-HALVING-COMPLETE (err u104))

(define-constant BLOCKS-PER-HALVING u210000)
(define-constant SATOSHIS-PER-BTC u100000000)
(define-constant INITIAL-BLOCK-REWARD u5000000000)

(define-data-var bitcoin-block-height uint u840000)
(define-data-var last-update-block uint u0)
(define-data-var oracle-fee uint u1000000)
(define-data-var total-updates uint u0)

(define-map authorized-oracles principal bool)
(define-map halving-history uint {block-height: uint, reward: uint, timestamp: uint})
(define-map oracle-stats principal {updates: uint, last-update: uint, reputation: uint})

(define-read-only (get-contract-info)
  {
    bitcoin-height: (var-get bitcoin-block-height),
    last-update: (var-get last-update-block),
    oracle-fee: (var-get oracle-fee),
    total-updates: (var-get total-updates)
  }
)

(define-read-only (get-current-halving-epoch)
  (/ (var-get bitcoin-block-height) BLOCKS-PER-HALVING)
)

(define-read-only (get-next-halving-block)
  (let ((current-epoch (get-current-halving-epoch)))
    (* (+ current-epoch u1) BLOCKS-PER-HALVING)
  )
)

(define-read-only (get-blocks-until-halving)
  (let ((next-halving (get-next-halving-block))
        (current-height (var-get bitcoin-block-height)))
    (if (>= current-height next-halving)
        u0
        (- next-halving current-height)
    )
  )
)

(define-read-only (get-current-block-reward)
  (let ((epoch (get-current-halving-epoch)))
    (/ INITIAL-BLOCK-REWARD (pow u2 epoch))
  )
)

(define-read-only (get-next-block-reward)
  (let ((next-epoch (+ (get-current-halving-epoch) u1)))
    (/ INITIAL-BLOCK-REWARD (pow u2 next-epoch))
  )
)

(define-read-only (get-halving-progress)
  (let ((current-height (var-get bitcoin-block-height))
        (current-epoch (get-current-halving-epoch))
        (epoch-start (* current-epoch BLOCKS-PER-HALVING))
        (blocks-in-epoch (- current-height epoch-start)))
    {
      epoch: current-epoch,
      blocks-in-epoch: blocks-in-epoch,
      progress-percentage: (/ (* blocks-in-epoch u10000) BLOCKS-PER-HALVING),
      blocks-remaining: (get-blocks-until-halving)
    }
  )
)

(define-read-only (estimate-time-to-halving)
  (let ((blocks-remaining (get-blocks-until-halving)))
    {
      blocks-remaining: blocks-remaining,
      estimated-minutes: (* blocks-remaining u10),
      estimated-hours: (/ (* blocks-remaining u10) u60),
      estimated-days: (/ (* blocks-remaining u10) u1440)
    }
  )
)

(define-read-only (get-halving-history (epoch uint))
  (map-get? halving-history epoch)
)

(define-read-only (get-oracle-stats (oracle principal))
  (map-get? oracle-stats oracle)
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

(define-read-only (calculate-total-bitcoins-mined)
  (let ((current-epoch (get-current-halving-epoch))
        (current-height (var-get bitcoin-block-height)))
    (fold calculate-epoch-rewards (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
          {total: u0, remaining-blocks: current-height})
  )
)

(define-private (calculate-epoch-rewards (epoch uint) (acc {total: uint, remaining-blocks: uint}))
  (let ((blocks-this-epoch (if (> (get remaining-blocks acc) BLOCKS-PER-HALVING)
                              BLOCKS-PER-HALVING
                              (get remaining-blocks acc)))
        (reward-this-epoch (/ INITIAL-BLOCK-REWARD (pow u2 epoch)))
        (bitcoins-this-epoch (* blocks-this-epoch reward-this-epoch)))
    {
      total: (+ (get total acc) bitcoins-this-epoch),
      remaining-blocks: (if (> (get remaining-blocks acc) BLOCKS-PER-HALVING)
                           (- (get remaining-blocks acc) BLOCKS-PER-HALVING)
                           u0)
    }
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set authorized-oracles oracle true)
    (map-set oracle-stats oracle {updates: u0, last-update: u0, reputation: u100})
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-delete authorized-oracles oracle)
    (ok true)
  )
)

(define-public (set-oracle-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set oracle-fee new-fee)
    (ok true)
  )
)

(define-public (update-bitcoin-height (new-height uint))
  (let ((current-height (var-get bitcoin-block-height))
        (caller-stats (default-to {updates: u0, last-update: u0, reputation: u0} 
                                 (map-get? oracle-stats tx-sender))))
    (asserts! (is-oracle-authorized tx-sender) ERR-ORACLE-NOT-AUTHORIZED)
    (asserts! (> new-height current-height) ERR-INVALID-HEIGHT)
    
    (var-set bitcoin-block-height new-height)
    (var-set last-update-block stacks-block-height)
    (var-set total-updates (+ (var-get total-updates) u1))
    
    (map-set oracle-stats tx-sender {
      updates: (+ (get updates caller-stats) u1),
      last-update: stacks-block-height,
      reputation: (let ((new-rep (+ (get reputation caller-stats) u1)))
                    (if (> new-rep u1000) u1000 new-rep))
    })
    
    (let ((halving-result (record-halving-if-occurred current-height new-height)))
      (ok new-height))
  )
)

(define-private (record-halving-if-occurred (old-height uint) (new-height uint))
  (let ((old-epoch (/ old-height BLOCKS-PER-HALVING))
        (new-epoch (/ new-height BLOCKS-PER-HALVING)))
    (if (> new-epoch old-epoch)
        (begin
          (map-set halving-history new-epoch {
            block-height: (* new-epoch BLOCKS-PER-HALVING),
            reward: (get-current-block-reward),
            timestamp: stacks-block-height
          })
          (ok true)
        )
        (ok true)
    )
  )
)

(define-public (emergency-update-height (new-height uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set bitcoin-block-height new-height)
    (var-set last-update-block stacks-block-height)
    (ok true)
  )
)

(define-read-only (get-halving-countdown)
  (let ((blocks-remaining (get-blocks-until-halving))
        (current-reward (get-current-block-reward))
        (next-reward (get-next-block-reward))
        (progress (get-halving-progress))
        (time-estimate (estimate-time-to-halving)))
    {
      current-bitcoin-height: (var-get bitcoin-block-height),
      next-halving-block: (get-next-halving-block),
      blocks-remaining: blocks-remaining,
      current-reward: current-reward,
      next-reward: next-reward,
      halving-epoch: (get epoch progress),
      progress-percentage: (get progress-percentage progress),
      estimated-days: (get estimated-days time-estimate),
      is-halving-complete: (is-eq blocks-remaining u0)
    }
  )
)

(define-read-only (get-network-statistics)
  (let ((total-mined (calculate-total-bitcoins-mined))
        (current-epoch (get-current-halving-epoch)))
    {
      total-bitcoins-mined: (get total (calculate-total-bitcoins-mined)),
      current-halving-epoch: current-epoch,
      total-halvings-occurred: current-epoch,
      blocks-per-halving: BLOCKS-PER-HALVING,
      current-block-reward: (get-current-block-reward),
      max-supply: u2100000000000000
    }
  )
)

(define-public (batch-update-oracle-data (height uint) (fee-payment uint))
  (begin
    (asserts! (is-oracle-authorized tx-sender) ERR-ORACLE-NOT-AUTHORIZED)
    (asserts! (>= fee-payment (var-get oracle-fee)) ERR-INVALID-ORACLE)
    (try! (stx-transfer? fee-payment tx-sender CONTRACT-OWNER))
    (update-bitcoin-height height)
  )
)

(define-read-only (get-oracle-performance)
  (let ((total-oracles u0)
        (active-oracles u0))
    {
      total-updates: (var-get total-updates),
      last-update-block: (var-get last-update-block),
      blocks-since-update: (- stacks-block-height (var-get last-update-block)),
      oracle-fee: (var-get oracle-fee)
    }
  )
)
