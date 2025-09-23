(define-non-fungible-token story-nft uint)
(define-fungible-token governance-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-proposal (err u103))
(define-constant err-proposal-ended (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-insufficient-tokens (err u106))
(define-constant err-story-exists (err u107))
(define-constant err-invalid-branch (err u108))

(define-data-var story-id-nonce uint u0)
(define-data-var proposal-id-nonce uint u0)
(define-data-var nft-id-nonce uint u0)
(define-data-var min-proposal-threshold uint u1000000)
(define-data-var voting-period uint u1440)

(define-map stories
  uint
  {
    title: (string-ascii 100),
    author: principal,
    content: (string-utf8 1000),
    parent-id: (optional uint),
    created-at: uint,
    is-canonical: bool,
    vote-count: uint
  }
)

(define-map story-branches
  uint
  (list 10 uint)
)

(define-map proposals
  uint
  {
    proposer: principal,
    story-id: uint,
    branch-options: (list 5 uint),
    yes-votes: uint,
    no-votes: uint,
    end-block: uint,
    executed: bool,
    description: (string-utf8 500)
  }
)

(define-map user-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, amount: uint }
)

(define-map user-governance-balance
  principal
  uint
)

(define-map story-contributors
  uint
  (list 20 principal)
)

(define-private (get-governance-balance (user principal))
  (default-to u0 (map-get? user-governance-balance user))
)

(define-private (set-governance-balance (user principal) (amount uint))
  (map-set user-governance-balance user amount)
)

(define-private (mint-governance-tokens (recipient principal) (amount uint))
  (begin
    (try! (ft-mint? governance-token amount recipient))
    (set-governance-balance recipient (+ (get-governance-balance recipient) amount))
    (ok true)
  )
)

(define-private (burn-governance-tokens (sender principal) (amount uint))
  (let ((current-balance (get-governance-balance sender)))
    (asserts! (>= current-balance amount) err-insufficient-tokens)
    (try! (ft-burn? governance-token amount sender))
    (set-governance-balance sender (- current-balance amount))
    (ok true)
  )
)

(define-private (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (< stacks-block-height (get end-block proposal))
    false
  )
)

(define-private (has-user-voted (proposal-id uint) (user principal))
  (is-some (map-get? user-votes { proposal-id: proposal-id, voter: user }))
)

(define-private (add-story-contributor (story-id uint) (contributor principal))
  (let ((current-contributors (default-to (list) (map-get? story-contributors story-id))))
    (match (as-max-len? (append current-contributors contributor) u20)
      some-list (begin (map-set story-contributors story-id some-list) (ok true))
      (err u999)
    )
  )
)

(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (mint-governance-tokens contract-owner u10000000))
    (ok true)
  )
)

(define-public (create-story (title (string-ascii 100)) (content (string-utf8 1000)) (parent-id (optional uint)))
  (let ((new-story-id (+ (var-get story-id-nonce) u1)))
    (asserts! (> (get-governance-balance tx-sender) u0) err-insufficient-tokens)
    (match parent-id
      some-parent-id (asserts! (is-some (map-get? stories some-parent-id)) err-not-found)
      true
    )
    (map-set stories new-story-id {
      title: title,
      author: tx-sender,
      content: content,
      parent-id: parent-id,
      created-at: stacks-block-height,
      is-canonical: false,
      vote-count: u0
    })
    (try! (add-story-contributor new-story-id tx-sender))
    (try! (mint-governance-tokens tx-sender u100))
    (var-set story-id-nonce new-story-id)
    (ok new-story-id)
  )
)

(define-public (create-branch-proposal (story-id uint) (branch-options (list 5 uint)) (description (string-utf8 500)))
  (let ((new-proposal-id (+ (var-get proposal-id-nonce) u1))
        (user-balance (get-governance-balance tx-sender)))
    (asserts! (>= user-balance (var-get min-proposal-threshold)) err-insufficient-tokens)
    (asserts! (is-some (map-get? stories story-id)) err-not-found)
    (asserts! (> (len branch-options) u0) err-invalid-proposal)
    (map-set proposals new-proposal-id {
      proposer: tx-sender,
      story-id: story-id,
      branch-options: branch-options,
      yes-votes: u0,
      no-votes: u0,
      end-block: (+ stacks-block-height (var-get voting-period)),
      executed: false,
      description: description
    })
    (var-set proposal-id-nonce new-proposal-id)
    (ok new-proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool) (amount uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (user-balance (get-governance-balance tx-sender)))
    (asserts! (>= user-balance amount) err-insufficient-tokens)
    (asserts! (is-proposal-active proposal-id) err-proposal-ended)
    (asserts! (not (has-user-voted proposal-id tx-sender)) err-already-voted)
    (map-set user-votes { proposal-id: proposal-id, voter: tx-sender } { vote: vote, amount: amount })
    (if vote
      (map-set proposals proposal-id (merge proposal { yes-votes: (+ (get yes-votes proposal) amount) }))
      (map-set proposals proposal-id (merge proposal { no-votes: (+ (get no-votes proposal) amount) }))
    )
    (try! (burn-governance-tokens tx-sender amount))
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (story-id (get story-id proposal))
        (winning-branches (get branch-options proposal)))
    (asserts! (not (is-proposal-active proposal-id)) err-proposal-ended)
    (asserts! (not (get executed proposal)) err-invalid-proposal)
    (asserts! (> (get yes-votes proposal) (get no-votes proposal)) err-invalid-proposal)
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (map-set story-branches story-id winning-branches)
    (try! (mint-story-nft story-id (get proposer proposal)))
    (ok true)
  )
)

(define-public (mint-story-nft (story-id uint) (recipient principal))
  (let ((new-nft-id (+ (var-get nft-id-nonce) u1))
        (story (unwrap! (map-get? stories story-id) err-not-found)))
    (asserts! (or (is-eq tx-sender (get author story)) (is-eq tx-sender contract-owner)) err-unauthorized)
    (try! (nft-mint? story-nft new-nft-id recipient))
    (map-set stories story-id (merge story { is-canonical: true }))
    (var-set nft-id-nonce new-nft-id)
    (ok new-nft-id)
  )
)

(define-public (distribute-rewards (story-id uint))
  (let ((story (unwrap! (map-get? stories story-id) err-not-found))
        (contributors (default-to (list) (map-get? story-contributors story-id))))
    (asserts! (get is-canonical story) err-invalid-proposal)
    (begin
      (fold distribute-to-contributor contributors u0)
      (ok true)
    )
  )
)

(define-private (distribute-to-contributor (contributor principal) (counter uint))
  (begin
    (unwrap-panic (mint-governance-tokens contributor u500))
    (+ counter u1)
  )
)

(define-public (set-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set voting-period blocks)
    (ok true)
  )
)

(define-public (set-proposal-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-proposal-threshold threshold)
    (ok true)
  )
)

(define-read-only (get-story (story-id uint))
  (map-get? stories story-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-user-balance (user principal))
  (get-governance-balance user)
)

(define-read-only (get-story-branches (story-id uint))
  (map-get? story-branches story-id)
)

(define-read-only (get-story-contributors (story-id uint))
  (map-get? story-contributors story-id)
)

(define-read-only (get-contract-info)
  {
    total-stories: (var-get story-id-nonce),
    total-proposals: (var-get proposal-id-nonce),
    total-nfts: (var-get nft-id-nonce),
    voting-period: (var-get voting-period),
    proposal-threshold: (var-get min-proposal-threshold)
  }
)

