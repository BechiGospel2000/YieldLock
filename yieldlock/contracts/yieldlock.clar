;; Parametric Crop Insurance
;; Automatic payouts based on predefined weather triggers without requiring claims

;; Insurance policies
(define-map coverage-contracts
  { contract-id: uint }
  {
    customer: principal,
    region-id: (string-ascii 64),      ;; Geographic identifier
    plant-type: (string-ascii 32),        ;; Type of crop insured
    payout-amount: uint,               ;; Maximum payout amount
    fee-amount: uint,                  ;; Premium paid
    inception-date: uint,              ;; Block height when coverage begins
    expiration-date: uint,             ;; Block height when coverage ends
    is-active: bool,                   ;; Whether policy is currently active
    rain-min-threshold: int,           ;; Rainfall threshold in mm below which payout triggers
    rain-max-threshold: int,           ;; Rainfall threshold in mm above which payout triggers
    temp-min-threshold: int,           ;; Temperature threshold in Celsius below which payout triggers
    claim-processed: bool,             ;; Whether a payout has been executed
    data-provider: principal           ;; Weather data oracle
  }
)

;; Weather data records
(define-map climate-data
  { region-id: (string-ascii 64), block-time: uint }
  {
    precipitation-mm: int,       ;; Rainfall in millimeters
    temp-celsius: int,           ;; Temperature in Celsius
    moisture-percent: uint,      ;; Humidity percentage
    submitted-by: principal,     ;; Oracle that recorded data
    is-confirmed: bool           ;; Whether data is verified by multiple oracles
  }
)

;; Authorized weather oracles
(define-map verified-data-sources
  { provider: principal }
  {
    provider-name: (string-utf8 128),
    registration-date: uint,
    approved-by: principal,
    is-active: bool
  }
)

;; Risk pools for each crop type
(define-map coverage-pools
  { plant-type: (string-ascii 32) }
  {
    collected-fees: uint,        ;; Total premiums collected for this crop
    distributed-claims: uint,    ;; Total payouts made
    current-contracts: uint,     ;; Number of active policies
    safety-ratio: uint,          ;; Target reserve ratio (out of 10000)
    pool-balance: uint           ;; Current STX balance in the pool
  }
)

;; Next available policy ID
(define-data-var next-contract-id uint u0)

;; Protocol fees
(define-data-var admin-fee-rate uint u500)  ;; 5% of premiums
(define-data-var admin-wallet principal tx-sender)

;; Register an oracle provider
(define-public (register-oracle (provider-name (string-utf8 128)))
  (begin
    ;; In a real implementation, this would require governance approval
    ;; Simplified for this example
    
    (map-set verified-data-sources
      { provider: tx-sender }
      {
        provider-name: provider-name,
        registration-date: block-height,
        approved-by: tx-sender,
        is-active: true
      }
    )
    
    (ok true)
  )
)

;; Check if sender is an authorized oracle
(define-private (is-verified-provider (provider principal))
  (default-to 
    false 
    (get is-active (map-get? verified-data-sources { provider: provider }))
  )
)

;; Create a new insurance policy
(define-public (create-policy
                (region-id (string-ascii 64))
                (plant-type (string-ascii 32))
                (payout-amount uint)
                (fee-amount uint)
                (coverage-duration uint)
                (rain-min-threshold int)
                (rain-max-threshold int)
                (temp-min-threshold int)
                (data-provider principal))
  (let
    ((contract-id (var-get next-contract-id))
     (start-block block-height)
     (end-block (+ block-height coverage-duration))
     (admin-fee (/ (* fee-amount (var-get admin-fee-rate)) u10000))
     (pool-fee (- fee-amount admin-fee)))
    
    ;; Validate parameters
    (asserts! (> payout-amount u0) (err u"Coverage amount must be positive"))
    (asserts! (> fee-amount u0) (err u"Premium amount must be positive"))
    (asserts! (>= coverage-duration u1000) (err u"Coverage duration too short"))
    (asserts! (> rain-min-threshold (to-int u0)) (err u"Invalid drought threshold"))
    (asserts! (> rain-max-threshold rain-min-threshold) (err u"Invalid excess rain threshold"))
    (asserts! (< temp-min-threshold (to-int u30)) (err u"Invalid frost threshold"))
    (asserts! (is-verified-provider data-provider) (err u"Oracle provider not authorized"))
    
    ;; Transfer premium payment
    (asserts! (is-ok (stx-transfer? fee-amount tx-sender (as-contract tx-sender))) 
             (err u"Failed to transfer premium payment"))
    
    ;; Transfer protocol fee
    (asserts! (is-ok (as-contract (stx-transfer? admin-fee tx-sender (var-get admin-wallet))))
             (err u"Failed to transfer protocol fee"))
    
    ;; Create the policy
    (map-set coverage-contracts
      { contract-id: contract-id }
      {
        customer: tx-sender,
        region-id: region-id,
        plant-type: plant-type,
        payout-amount: payout-amount,
        fee-amount: fee-amount,
        inception-date: start-block,
        expiration-date: end-block,
        is-active: true,
        rain-min-threshold: rain-min-threshold,
        rain-max-threshold: rain-max-threshold,
        temp-min-threshold: temp-min-threshold,
        claim-processed: false,
        data-provider: data-provider
      }
    )
    
    ;; Set next policy ID now to avoid any race conditions
    (var-set next-contract-id (+ contract-id u1))
    
    ;; Update risk pool
    (match (map-get? coverage-pools { plant-type: plant-type })
      existing-pool (map-set coverage-pools
                      { plant-type: plant-type }
                      {
                        collected-fees: (+ (get collected-fees existing-pool) pool-fee),
                        distributed-claims: (get distributed-claims existing-pool),
                        current-contracts: (+ (get current-contracts existing-pool) u1),
                        safety-ratio: (get safety-ratio existing-pool),
                        pool-balance: (+ (get pool-balance existing-pool) pool-fee)
                      }
                    )
      ;; Create new pool if it doesn't exist
      (map-set coverage-pools
        { plant-type: plant-type }
        {
          collected-fees: pool-fee,
          distributed-claims: u0,
          current-contracts: u1,
          safety-ratio: u7000,  ;; Default 70% reserve ratio
          pool-balance: pool-fee
        }
      )
    )
    
    ;; Policy ID counter increment was moved above to avoid race conditions
    
    (ok contract-id)
  )
)

;; Submit weather data (oracle only)
(define-public (submit-weather-data
                (region-id (string-ascii 64))
                (precipitation-mm int)
                (temp-celsius int)
                (moisture-percent uint))
  (begin
    ;; Validate oracle authorization
    (asserts! (is-verified-provider tx-sender) (err u"Not authorized as oracle"))
    
    ;; Record weather data
    (map-set climate-data
      { region-id: region-id, block-time: block-height }
      {
        precipitation-mm: precipitation-mm,
        temp-celsius: temp-celsius,
        moisture-percent: moisture-percent,
        submitted-by: tx-sender,
        is-confirmed: false  ;; Would need verification from multiple oracles in production
      }
    )
    
    ;; Process any policies that might be triggered by this data
    (try! (process-weather-triggers region-id))
    
    (ok true)
  )
)

;; Process weather triggers for policies
(define-private (process-weather-triggers (region-id (string-ascii 64)))
  (begin
    ;; In a real implementation, this would iterate through all policies for the location
    ;; and check trigger conditions. Simplified for this example.
    
    ;; Return early if no policies match, to avoid any future issues
    
    ;; For demonstration, we'll process a dummy policy ID 0
    (let ((policy-opt (map-get? coverage-contracts { contract-id: u0 })))
      (if (is-some policy-opt)
        (let ((policy (unwrap-panic policy-opt)))
          (if (and (is-eq (get region-id policy) region-id)
                 (get is-active policy)
                 (not (get claim-processed policy))
                 (<= (get inception-date policy) block-height)
                 (>= (get expiration-date policy) block-height))
            ;; Policy matches criteria, check triggers
            (let ((trigger-result (check-policy-triggers u0 policy)))
              (if (is-ok trigger-result)
                (ok true)
                trigger-result))
            ;; Policy doesn't match criteria
            (ok true)))
        ;; No policy found
        (ok true)))
  )
)

;; Check if policy triggers are met
(define-private (check-policy-triggers (contract-id uint) (policy (tuple 
                                         (customer principal)
                                         (region-id (string-ascii 64))
                                         (plant-type (string-ascii 32))
                                         (payout-amount uint)
                                         (fee-amount uint)
                                         (inception-date uint)
                                         (expiration-date uint)
                                         (is-active bool)
                                         (rain-min-threshold int)
                                         (rain-max-threshold int)
                                         (temp-min-threshold int)
                                         (claim-processed bool)
                                         (data-provider principal))))
  (let
    ((weather (unwrap! (map-get? climate-data 
                       { region-id: (get region-id policy), block-time: block-height })
                      (err u"Weather data not found"))))
    
    ;; Check if any trigger conditions are met
    (if (or (< (get precipitation-mm weather) (get rain-min-threshold policy))
            (> (get precipitation-mm weather) (get rain-max-threshold policy))
            (< (get temp-celsius weather) (get temp-min-threshold policy)))
        ;; Trigger conditions met, execute payout
        (execute-policy-payout contract-id)
        (ok false)
    )
  )
)

;; Execute policy payout
(define-private (execute-policy-payout (contract-id uint))
  (let
    ((policy-opt (map-get? coverage-contracts { contract-id: contract-id })))
    
    ;; Check if policy exists
    (asserts! (is-some policy-opt) (err u"Policy not found"))
    (let ((policy (unwrap-panic policy-opt)))
      
      ;; Validate policy is active and payout not already executed
      (asserts! (get is-active policy) (err u"Policy not active"))
      (asserts! (not (get claim-processed policy)) (err u"Payout already executed"))
      
      ;; Update policy status
      (map-set coverage-contracts
        { contract-id: contract-id }
        (merge policy { claim-processed: true, is-active: false })
      )
      
      ;; Update risk pool
      (let ((risk-pool (map-get? coverage-pools { plant-type: (get plant-type policy) })))
        (asserts! (is-some risk-pool) (err u"Risk pool not found"))
        
        (let ((pool (unwrap-panic risk-pool)))
          (map-set coverage-pools
            { plant-type: (get plant-type policy) }
            {
              collected-fees: (get collected-fees pool),
              distributed-claims: (+ (get distributed-claims pool) (get payout-amount policy)),
              current-contracts: (- (get current-contracts pool) u1),
              safety-ratio: (get safety-ratio pool),
              pool-balance: (- (get pool-balance pool) (get payout-amount policy))
            }
          )
        )
      )
      
      ;; Transfer payout to policyholder
      (asserts! (is-ok (as-contract (stx-transfer? (get payout-amount policy) tx-sender (get customer policy))))
                (err u"Failed to transfer payout"))
      
      (ok true)
    )
  )
)

;; Allow a user to cancel policy before end date (partial refund)
(define-public (cancel-policy (contract-id uint))
  (let
    ((policy-opt (map-get? coverage-contracts { contract-id: contract-id })))
    
    ;; Validate policy exists
    (asserts! (is-some policy-opt) (err u"Policy not found"))
    (let ((policy (unwrap-panic policy-opt)))
      
      ;; Validate
      (asserts! (is-eq tx-sender (get customer policy)) (err u"Not the policyholder"))
      (asserts! (get is-active policy) (err u"Policy not active"))
      (asserts! (not (get claim-processed policy)) (err u"Payout already executed"))
      
      ;; Calculate refund based on time remaining
      (let
        ((total-duration (- (get expiration-date policy) (get inception-date policy)))
         (elapsed-duration (- block-height (get inception-date policy)))
         (remaining-duration (- total-duration elapsed-duration))
         (refund-percentage (/ (* remaining-duration u10000) total-duration))
         (refund-amount (/ (* (get fee-amount policy) refund-percentage) u10000)))
        
        ;; Update policy status
        (map-set coverage-contracts
          { contract-id: contract-id }
          (merge policy { is-active: false })
        )
        
        ;; Update risk pool
        (let ((risk-pool (map-get? coverage-pools { plant-type: (get plant-type policy) })))
          (asserts! (is-some risk-pool) (err u"Risk pool not found"))
          
          (let ((pool (unwrap-panic risk-pool)))
            (map-set coverage-pools
              { plant-type: (get plant-type policy) }
              {
                collected-fees: (get collected-fees pool),
                distributed-claims: (get distributed-claims pool),
                current-contracts: (- (get current-contracts pool) u1),
                safety-ratio: (get safety-ratio pool),
                pool-balance: (- (get pool-balance pool) refund-amount)
              }
            )
          )
        )
        
        ;; Transfer refund to policyholder
        (asserts! (is-ok (as-contract (stx-transfer? refund-amount tx-sender (get customer policy))))
                  (err u"Failed to transfer refund"))
        
        (ok refund-amount)
      )
    )
  )
)

;; Verify weather data (multiple oracles required)
(define-public (verify-weather-data
                (region-id (string-ascii 64))
                (block-time uint)
                (precipitation-mm int)
                (temp-celsius int)
                (moisture-percent uint))
  (let
    ((weather-record (unwrap! (map-get? climate-data 
                              { region-id: region-id, block-time: block-time })
                             (err u"Weather data not found"))))
    
    ;; Validate oracle authorization
    (asserts! (is-verified-provider tx-sender) (err u"Not authorized as oracle"))
    (asserts! (not (is-eq tx-sender (get submitted-by weather-record))) 
              (err u"Cannot verify own data"))
    
    ;; Check if data matches within acceptable margin of error
    (asserts! (< (abs (- precipitation-mm (get precipitation-mm weather-record))) (to-int u5)) 
              (err u"Rainfall data differs too much"))
    (asserts! (< (abs (- temp-celsius (get temp-celsius weather-record))) (to-int u2)) 
              (err u"Temperature data differs too much"))
    (asserts! (< (abs-uint moisture-percent (get moisture-percent weather-record)) u5) 
              (err u"Humidity data differs too much"))
    
    ;; Mark data as verified
    (map-set climate-data
      { region-id: region-id, block-time: block-time }
      (merge weather-record { is-confirmed: true })
    )
    
    (ok true)
  )
)

;; Manually trigger policy evaluation (for testing or backup)
(define-public (evaluate-policy (contract-id uint))
  (let
    ((policy (unwrap! (map-get? coverage-contracts { contract-id: contract-id }) 
                     (err u"Policy not found")))
     (latest-weather (get-latest-weather (get region-id policy))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get customer policy))
                 (is-eq tx-sender (get data-provider policy)))
              (err u"Not authorized"))
    (asserts! (get is-active policy) (err u"Policy not active"))
    (asserts! (not (get claim-processed policy)) (err u"Payout already executed"))
    (asserts! (is-some latest-weather) (err u"No weather data available"))
    
    ;; Check if any trigger conditions are met
    (let ((weather (unwrap-panic latest-weather)))
      (if (or (< (get precipitation-mm weather) (get rain-min-threshold policy))
              (> (get precipitation-mm weather) (get rain-max-threshold policy))
              (< (get temp-celsius weather) (get temp-min-threshold policy)))
          ;; Trigger conditions met, execute payout
          (execute-policy-payout contract-id)
          (ok false)
      )
    )
  )
)

;; Get latest weather data for a location
(define-private (get-latest-weather (region-id (string-ascii 64)))
  ;; In a real implementation, this would search for the most recent data
  ;; Simplified for this example
  (map-get? climate-data { region-id: region-id, block-time: block-height })
)

;; Utility function for absolute value (int)
(define-private (abs (x int))
  (if (< x (to-int u0)) (to-int (- u0 (to-uint x))) x)
)

;; Utility function for absolute value (uint)
(define-private (abs-uint (x uint) (y uint))
  (if (> x y) (- x y) (- y x))
)

;; Read-only functions

;; Get policy details
(define-read-only (get-policy (contract-id uint))
  (ok (unwrap! (map-get? coverage-contracts { contract-id: contract-id }) (err u"Policy not found")))
)

;; Get weather data
(define-read-only (get-weather-data (region-id (string-ascii 64)) (block-time uint))
  (ok (unwrap! (map-get? climate-data { region-id: region-id, block-time: block-time })
              (err u"Weather data not found")))
)

;; Get risk pool information
(define-read-only (get-risk-pool (plant-type (string-ascii 32)))
  (ok (unwrap! (map-get? coverage-pools { plant-type: plant-type }) (err u"Risk pool not found")))
)

;; Check if oracle is authorized
(define-read-only (check-oracle-authorization (provider principal))
  (ok (is-verified-provider provider))
)