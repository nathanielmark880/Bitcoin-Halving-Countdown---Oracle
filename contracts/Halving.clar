;; title: Halving

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INVALID-ORACLE (err u101))
(define-constant ERR-INVALID-HEIGHT (err u102))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u103))
(define-constant ERR-HALVING-COMPLETE (err u104))
(define-constant ERR-EPOCH-RESOLVED (err u105))
(define-constant ERR-ALREADY-PREDICTED (err u106))
(define-constant ERR-INSUFFICIENT-STAKE (err u107))
(define-constant ERR-NOT-AUTHORIZED-RESOLVER (err u108))
(define-constant ERR-ALREADY-WITHDRAWN (err u109))

(define-constant BLOCKS-PER-HALVING u210000)
(define-constant SATOSHIS-PER-BTC u100000000)
(define-constant INITIAL-BLOCK-REWARD u5000000000)
(define-constant MIN-PREDICTION-STAKE u10000000)
(define-constant EARLY-BONUS-BLOCKS u30240)
(define-constant WITHDRAWAL-PENALTY-PCT u20)
(define-constant PREDICTION-TOLERANCE u10)

(define-data-var bitcoin-block-height uint u840000)
(define-data-var last-update-block uint u0)
(define-data-var oracle-fee uint u1000000)
(define-data-var total-updates uint u0)

(define-map authorized-oracles principal bool)
(define-map halving-history uint {block-height: uint, reward: uint, timestamp: uint})
(define-map oracle-stats principal {updates: uint, last-update: uint, reputation: uint})
(define-map epoch-predictions {epoch: uint, predictor: principal} {predicted-block: uint, stake: uint, withdrawn: bool, early-bonus: bool})
(define-map epoch-stakes uint uint)
(define-map epoch-resolved uint {resolved: bool, actual-block: uint})
(define-map prediction-treasury principal uint)
(define-map predictor-stats {epoch: uint, predictor: principal} {wins: uint, total: uint, accuracy: uint})
(define-map oracle-reputation principal {score: uint, last-quality-check: uint})
(define-map top-predictors uint principal)
(define-data-var leaderboard-size uint u0)

(define-public (update-predictor-stats (epoch uint) (predictor principal) (won bool))
  (let
    (
      (current-stats (default-to {wins: u0, total: u0, accuracy: u0}
        (map-get? predictor-stats {epoch: epoch, predictor: predictor})))
      (new-wins (if won (+ (get wins current-stats) u1) (get wins current-stats)))
      (new-total (+ (get total current-stats) u1))
      (new-accuracy (/ (* new-wins u10000) new-total))
    )
    (map-set predictor-stats
      {epoch: epoch, predictor: predictor}
      {wins: new-wins, total: new-total, accuracy: new-accuracy}
    )
    (ok {wins: new-wins, total: new-total, accuracy: new-accuracy})
  )
)

(define-public (adjust-oracle-reputation (oracle principal) (quality-score uint))
  (let
    (
      (current-rep (default-to {score: u500, last-quality-check: u0}
        (map-get? oracle-reputation oracle)))
      (current-score (get score current-rep))
      (adjustment (if (> quality-score u50)
        (let ((calc (/ quality-score u20))) (if (> calc u50) u50 calc))
        (let ((reduced (- current-score (/ (- u50 quality-score) u10)))) (if (< reduced u950) u950 reduced))))
      (adjusted-score (+ current-score adjustment))
      (capped-low (if (< adjusted-score u0) u0 adjusted-score))
      (new-score (if (> capped-low u1000) u1000 capped-low))
    )
    (map-set oracle-reputation
      oracle
      {score: new-score, last-quality-check: stacks-block-height}
    )
    (ok {score: new-score, last-quality-check: stacks-block-height})
  )
)

(define-public (update-leaderboard (predictor principal) (epoch uint))
  (let
    (
      (stats (unwrap! (map-get? predictor-stats {epoch: epoch, predictor: predictor})
        (err u404)))
      (current-size (var-get leaderboard-size))
    )
    (if (< current-size u100)
      (begin
        (map-set top-predictors current-size predictor)
        (var-set leaderboard-size (+ current-size u1))
        (ok true)
      )
      (ok true)
    )
  )
)

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

(define-public (predict-halving-block (epoch uint) (predicted-block uint))
  (let ((current-epoch (get-current-halving-epoch))
        (current-height (var-get bitcoin-block-height))
        (blocks-until-target (if (> epoch current-epoch)
                               (* (- epoch current-epoch) BLOCKS-PER-HALVING)
                               u0))
        (is-early (>= blocks-until-target EARLY-BONUS-BLOCKS))
        (existing-prediction (map-get? epoch-predictions {epoch: epoch, predictor: tx-sender}))
        (epoch-resolution (map-get? epoch-resolved epoch)))
    
    (asserts! (is-none existing-prediction) ERR-ALREADY-PREDICTED)
    (asserts! (or (is-none epoch-resolution) (not (get resolved (unwrap-panic epoch-resolution)))) ERR-EPOCH-RESOLVED)
    (asserts! (>= (stx-get-balance tx-sender) MIN-PREDICTION-STAKE) ERR-INSUFFICIENT-STAKE)
    
    (try! (stx-transfer? MIN-PREDICTION-STAKE tx-sender (as-contract tx-sender)))
    
    (map-set epoch-predictions {epoch: epoch, predictor: tx-sender} {
      predicted-block: predicted-block,
      stake: MIN-PREDICTION-STAKE,
      withdrawn: false,
      early-bonus: is-early
    })
    
    (map-set epoch-stakes epoch (+ (default-to u0 (map-get? epoch-stakes epoch)) MIN-PREDICTION-STAKE))
    
    (ok {epoch: epoch, predicted-block: predicted-block, stake: MIN-PREDICTION-STAKE, early-bonus: is-early})
  )
)

(define-public (withdraw-prediction (epoch uint))
  (let ((prediction (map-get? epoch-predictions {epoch: epoch, predictor: tx-sender}))
        (epoch-resolution (map-get? epoch-resolved epoch)))
    
    (asserts! (is-some prediction) ERR-INVALID-ORACLE)
    (asserts! (not (get withdrawn (unwrap-panic prediction))) ERR-ALREADY-WITHDRAWN)
    (asserts! (or (is-none epoch-resolution) (not (get resolved (unwrap-panic epoch-resolution)))) ERR-EPOCH-RESOLVED)
    
    (let ((stake-amount (get stake (unwrap-panic prediction)))
          (penalty (/ (* stake-amount WITHDRAWAL-PENALTY-PCT) u100))
          (refund-amount (- stake-amount penalty)))
      
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      (map-set prediction-treasury CONTRACT-OWNER (+ (default-to u0 (map-get? prediction-treasury CONTRACT-OWNER)) penalty))
      
      (map-set epoch-predictions {epoch: epoch, predictor: tx-sender} 
        (merge (unwrap-panic prediction) {withdrawn: true}))
      
      (map-set epoch-stakes epoch (- (default-to u0 (map-get? epoch-stakes epoch)) stake-amount))
      
      (ok {refund: refund-amount, penalty: penalty})
    )
  )
)

(define-public (resolve-epoch-predictions (epoch uint) (actual-block uint))
  (let ((epoch-resolution (map-get? epoch-resolved epoch)))
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-oracle-authorized tx-sender)) ERR-NOT-AUTHORIZED-RESOLVER)
    (asserts! (or (is-none epoch-resolution) (not (get resolved (unwrap-panic epoch-resolution)))) ERR-EPOCH-RESOLVED)
    
    (map-set epoch-resolved epoch {resolved: true, actual-block: actual-block})
    
    (ok {epoch: epoch, actual-block: actual-block})
  )
)

(define-public (claim-prediction-reward (epoch uint) (winner principal))
  (let ((prediction (map-get? epoch-predictions {epoch: epoch, predictor: winner}))
        (epoch-resolution (map-get? epoch-resolved epoch))
        (total-stake (default-to u0 (map-get? epoch-stakes epoch))))
    
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-some prediction) ERR-INVALID-ORACLE)
    (asserts! (is-some epoch-resolution) ERR-INVALID-ORACLE)
    (asserts! (get resolved (unwrap-panic epoch-resolution)) ERR-EPOCH-RESOLVED)
    
    (let ((pred-data (unwrap-panic prediction))
          (actual-block (get actual-block (unwrap-panic epoch-resolution)))
          (predicted-block (get predicted-block pred-data))
          (distance (if (> predicted-block actual-block)
                      (- predicted-block actual-block)
                      (- actual-block predicted-block)))
          (is-winner (<= distance PREDICTION-TOLERANCE)))
      
      (asserts! is-winner ERR-INVALID-HEIGHT)
      (asserts! (not (get withdrawn pred-data)) ERR-ALREADY-WITHDRAWN)
      
      (let ((base-reward (/ total-stake u2))
            (early-mult (if (get early-bonus pred-data) u15 u10))
            (early-reward (/ (* base-reward early-mult) u10))
            (accuracy-multiplier (calculate-reward-multiplier winner epoch))
            (final-reward (/ (* early-reward accuracy-multiplier) u100)))
        
        (unwrap! (update-predictor-stats epoch winner true) ERR-INVALID-ORACLE)
        (unwrap! (update-leaderboard winner epoch) ERR-INVALID-ORACLE)
        (try! (as-contract (stx-transfer? final-reward tx-sender winner)))
        
        (map-set epoch-predictions {epoch: epoch, predictor: winner}
          (merge pred-data {withdrawn: true}))
        
        (ok {winner: winner, reward: final-reward, distance: distance, multiplier: accuracy-multiplier})
      )
    )
  )
)

(define-read-only (get-prediction-stats (epoch uint))
  (let ((total-stake (default-to u0 (map-get? epoch-stakes epoch)))
        (resolution (map-get? epoch-resolved epoch)))
    {
      epoch: epoch,
      total-stake: total-stake,
      resolved: (if (is-some resolution) (get resolved (unwrap-panic resolution)) false),
      actual-block: (if (is-some resolution) (some (get actual-block (unwrap-panic resolution))) none)
    }
  )
)

(define-read-only (get-user-prediction (epoch uint) (user principal))
  (map-get? epoch-predictions {epoch: epoch, predictor: user})
)

(define-read-only (calculate-prediction-accuracy (epoch uint) (user principal))
  (let ((prediction (map-get? epoch-predictions {epoch: epoch, predictor: user}))
        (resolution (map-get? epoch-resolved epoch)))
    (if (and (is-some prediction) (is-some resolution))
      (let ((pred-block (get predicted-block (unwrap-panic prediction)))
            (actual-block (get actual-block (unwrap-panic resolution)))
            (distance (if (> pred-block actual-block)
                        (- pred-block actual-block)
                        (- actual-block pred-block))))
        (some {predicted: pred-block, actual: actual-block, distance: distance, within-tolerance: (<= distance PREDICTION-TOLERANCE)})
      )
      none
    )
  )
)

(define-read-only (calculate-reward-multiplier (predictor principal) (epoch uint))
  (let
    (
      (stats (map-get? predictor-stats {epoch: epoch, predictor: predictor}))
    )
    (match stats
      stats-data
        (let
          (
            (accuracy (get accuracy stats-data))
          )
          (if (>= accuracy u8000)
            u200
            (if (>= accuracy u5000)
              u150
              u100
            )
          )
        )
      u100
    )
  )
)

(define-read-only (get-predictor-stats (epoch uint) (predictor principal))
  (map-get? predictor-stats {epoch: epoch, predictor: predictor})
)

(define-read-only (get-oracle-reputation (oracle principal))
  (map-get? oracle-reputation oracle)
)

(define-read-only (get-leaderboard (start uint) (limit uint))
  (let
    (
      (calculated-end (+ start limit))
      (max-size (var-get leaderboard-size))
      (end (if (> calculated-end max-size) max-size calculated-end))
    )
    {
      start: start,
      end: end,
      total: max-size
    }
  )
)

(define-read-only (get-leaderboard-entry (position uint))
  (map-get? top-predictors position)
)
