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
(define-constant err-invalid-rating (err u109))
(define-constant err-already-rated (err u110))
(define-constant err-self-rating (err u111))
(define-constant err-invalid-amount (err u112))
(define-constant err-already-invited (err u113))
(define-constant err-not-invited (err u114))
(define-constant err-invitation-expired (err u115))
(define-constant err-bounty-not-found (err u116))
(define-constant err-bounty-claimed (err u117))
(define-constant err-bounty-expired (err u118))
(define-constant err-bounty-not-expired (err u119))

(define-data-var story-id-nonce uint u0)
(define-data-var proposal-id-nonce uint u0)
(define-data-var nft-id-nonce uint u0)
(define-data-var min-proposal-threshold uint u1000000)
(define-data-var voting-period uint u1440)
(define-data-var invitation-validity uint u720)
(define-data-var bounty-id-nonce uint u0)
(define-data-var bounty-duration uint u4320)

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

(define-map story-ratings
  { story-id: uint, rater: principal }
  { rating: uint, timestamp: uint }
)

(define-map story-rating-summary
  uint
  { total-rating: uint, rating-count: uint, average-rating: uint }
)

(define-map author-reputation
  principal
  { total-score: uint, story-count: uint, reputation-score: uint }
)

(define-map story-tips
  uint
  { total-tips: uint, tip-count: uint }
)

(define-map collaboration-invitations
  { story-id: uint, invitee: principal }
  { inviter: principal, created-at: uint, accepted: bool }
)

(define-map story-collaborators
  uint
  (list 10 principal)
)

(define-map bounties
  uint
  {
    creator: principal,
    reward: uint,
    description: (string-utf8 500),
    parent-story-id: (optional uint),
    created-at: uint,
    deadline: uint,
    claimed: bool,
    claimed-story-id: (optional uint)
  }
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

(define-private (transfer-governance-tokens (sender principal) (recipient principal) (amount uint))
  (let ((sender-balance (get-governance-balance sender)))
    (asserts! (>= sender-balance amount) err-insufficient-tokens)
    (try! (ft-transfer? governance-token amount sender recipient))
    (set-governance-balance sender (- sender-balance amount))
    (set-governance-balance recipient (+ (get-governance-balance recipient) amount))
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

(define-private (update-author-reputation (author principal) (rating uint))
  (let ((current-rep (default-to { total-score: u0, story-count: u0, reputation-score: u0 } 
                                   (map-get? author-reputation author))))
    (let ((new-total-score (+ (get total-score current-rep) rating))
          (new-story-count (+ (get story-count current-rep) u1))
          (new-reputation-score (/ (* new-total-score u100) new-story-count)))
      (map-set author-reputation author {
        total-score: new-total-score,
        story-count: new-story-count,
        reputation-score: new-reputation-score
      })
      true
    )
  )
)

(define-private (has-user-rated (story-id uint) (user principal))
  (is-some (map-get? story-ratings { story-id: story-id, rater: user }))
)

(define-private (is-story-author-or-collaborator (story-id uint) (user principal))
  (let ((story (map-get? stories story-id)))
    (match story
      s (or 
          (is-eq user (get author s))
          (is-some (index-of (default-to (list) (map-get? story-collaborators story-id)) user)))
      false
    )
  )
)

(define-private (add-collaborator-to-story (story-id uint) (collaborator principal))
  (let ((current-collaborators (default-to (list) (map-get? story-collaborators story-id))))
    (match (as-max-len? (append current-collaborators collaborator) u10)
      some-list (begin (map-set story-collaborators story-id some-list) (ok true))
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

(define-public (rate-story (story-id uint) (rating uint))
  (let ((story (unwrap! (map-get? stories story-id) err-not-found))
        (story-author (get author story))
        (current-summary (default-to { total-rating: u0, rating-count: u0, average-rating: u0 }
                                       (map-get? story-rating-summary story-id))))
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (not (is-eq tx-sender story-author)) err-self-rating)
    (asserts! (not (has-user-rated story-id tx-sender)) err-already-rated)
    (asserts! (> (get-governance-balance tx-sender) u0) err-insufficient-tokens)
    (map-set story-ratings { story-id: story-id, rater: tx-sender } {
      rating: rating,
      timestamp: stacks-block-height
    })
    (let ((new-total-rating (+ (get total-rating current-summary) rating))
          (new-rating-count (+ (get rating-count current-summary) u1)))
      (let ((new-average-rating (/ (* new-total-rating u100) new-rating-count)))
        (map-set story-rating-summary story-id {
          total-rating: new-total-rating,
          rating-count: new-rating-count,
          average-rating: new-average-rating
        })
        (update-author-reputation story-author rating)
        (try! (mint-governance-tokens tx-sender u10))
        (ok true)
      )
    )
  )
)

(define-public (tip-story (story-id uint) (amount uint))
  (let ((story (unwrap! (map-get? stories story-id) err-not-found))
        (story-author (get author story))
        (tipper-balance (get-governance-balance tx-sender))
        (current-summary (default-to { total-tips: u0, tip-count: u0 }
                                       (map-get? story-tips story-id))))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= tipper-balance amount) err-insufficient-tokens)
    (asserts! (not (is-eq tx-sender story-author)) err-self-rating)
    (try! (transfer-governance-tokens tx-sender story-author amount))
    (let ((new-total-tips (+ (get total-tips current-summary) amount))
          (new-tip-count (+ (get tip-count current-summary) u1)))
      (map-set story-tips story-id {
        total-tips: new-total-tips,
        tip-count: new-tip-count
      })
      (ok true)
    )
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

(define-read-only (get-story-rating (story-id uint))
  (map-get? story-rating-summary story-id)
)

(define-read-only (get-user-story-rating (story-id uint) (user principal))
  (map-get? story-ratings { story-id: story-id, rater: user })
)

(define-read-only (get-author-reputation (author principal))
  (map-get? author-reputation author)
)

(define-read-only (get-story-tips (story-id uint))
  (map-get? story-tips story-id)
)

(define-public (invite-collaborator (story-id uint) (invitee principal))
  (let ((story (unwrap! (map-get? stories story-id) err-not-found)))
    (asserts! (is-eq tx-sender (get author story)) err-unauthorized)
    (asserts! (not (is-eq tx-sender invitee)) err-self-rating)
    (asserts! (is-none (map-get? collaboration-invitations { story-id: story-id, invitee: invitee })) err-already-invited)
    (map-set collaboration-invitations { story-id: story-id, invitee: invitee } {
      inviter: tx-sender,
      created-at: stacks-block-height,
      accepted: false
    })
    (ok true)
  )
)

(define-public (accept-collaboration (story-id uint))
  (let ((invitation (unwrap! (map-get? collaboration-invitations { story-id: story-id, invitee: tx-sender }) err-not-invited)))
    (asserts! (not (get accepted invitation)) err-already-invited)
    (asserts! (<= (- stacks-block-height (get created-at invitation)) (var-get invitation-validity)) err-invitation-expired)
    (map-set collaboration-invitations { story-id: story-id, invitee: tx-sender } 
      (merge invitation { accepted: true }))
    (try! (add-collaborator-to-story story-id tx-sender))
    (try! (add-story-contributor story-id tx-sender))
    (try! (mint-governance-tokens tx-sender u50))
    (ok true)
  )
)

(define-public (revoke-invitation (story-id uint) (invitee principal))
  (let ((story (unwrap! (map-get? stories story-id) err-not-found))
        (invitation (unwrap! (map-get? collaboration-invitations { story-id: story-id, invitee: invitee }) err-not-invited)))
    (asserts! (is-eq tx-sender (get author story)) err-unauthorized)
    (asserts! (not (get accepted invitation)) err-already-invited)
    (map-delete collaboration-invitations { story-id: story-id, invitee: invitee })
    (ok true)
  )
)

(define-read-only (get-collaboration-invitation (story-id uint) (invitee principal))
  (map-get? collaboration-invitations { story-id: story-id, invitee: invitee })
)

(define-read-only (get-story-collaborators (story-id uint))
  (map-get? story-collaborators story-id)
)

(define-read-only (is-collaborator (story-id uint) (user principal))
  (is-story-author-or-collaborator story-id user)
)

(define-public (create-bounty (reward uint) (description (string-utf8 500)) (parent-story-id (optional uint)))
  (let ((new-bounty-id (+ (var-get bounty-id-nonce) u1))
        (creator-balance (get-governance-balance tx-sender)))
    (asserts! (> reward u0) err-invalid-amount)
    (asserts! (>= creator-balance reward) err-insufficient-tokens)
    (match parent-story-id
      some-parent (asserts! (is-some (map-get? stories some-parent)) err-not-found)
      true
    )
    (try! (burn-governance-tokens tx-sender reward))
    (map-set bounties new-bounty-id {
      creator: tx-sender,
      reward: reward,
      description: description,
      parent-story-id: parent-story-id,
      created-at: stacks-block-height,
      deadline: (+ stacks-block-height (var-get bounty-duration)),
      claimed: false,
      claimed-story-id: none
    })
    (var-set bounty-id-nonce new-bounty-id)
    (ok new-bounty-id)
  )
)

(define-public (claim-bounty (bounty-id uint) (story-id uint))
  (let ((bounty (unwrap! (map-get? bounties bounty-id) err-bounty-not-found))
        (story (unwrap! (map-get? stories story-id) err-not-found)))
    (asserts! (not (get claimed bounty)) err-bounty-claimed)
    (asserts! (<= stacks-block-height (get deadline bounty)) err-bounty-expired)
    (asserts! (is-eq tx-sender (get author story)) err-unauthorized)
    (asserts! (not (is-eq tx-sender (get creator bounty))) err-self-rating)
    (map-set bounties bounty-id (merge bounty {
      claimed: true,
      claimed-story-id: (some story-id)
    }))
    (try! (mint-governance-tokens tx-sender (get reward bounty)))
    (ok true)
  )
)

(define-public (cancel-bounty (bounty-id uint))
  (let ((bounty (unwrap! (map-get? bounties bounty-id) err-bounty-not-found)))
    (asserts! (is-eq tx-sender (get creator bounty)) err-unauthorized)
    (asserts! (not (get claimed bounty)) err-bounty-claimed)
    (asserts! (> stacks-block-height (get deadline bounty)) err-bounty-not-expired)
    (try! (mint-governance-tokens tx-sender (get reward bounty)))
    (map-delete bounties bounty-id)
    (ok true)
  )
)

(define-read-only (get-bounty (bounty-id uint))
  (map-get? bounties bounty-id)
)

(define-read-only (get-contract-info)
  {
    total-stories: (var-get story-id-nonce),
    total-proposals: (var-get proposal-id-nonce),
    total-nfts: (var-get nft-id-nonce),
    voting-period: (var-get voting-period),
    proposal-threshold: (var-get min-proposal-threshold),
    total-bounties: (var-get bounty-id-nonce)
  }
)