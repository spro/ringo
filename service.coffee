somata = require 'somata'

# Helpers
# ------------------------------------------------------------------------------

randomChoice = (l) ->
    l[Math.floor Math.random() * l.length]

randomSample = (l, n) ->
    [0...n].map -> randomChoice l

randomString = (len=8) ->
    s = ''
    while s.length < len
        s += Math.random().toString(36).slice(2, len-s.length+2)
    return s

shuffle = (array) ->
    shuffled = []
    copy = array.slice(0)

    n = copy.length
    # While there remain elements to shuffle…
    while n
        # Pick a remaining element…
        i = Math.floor(Math.random() * n--)
        # And move it to the new array.
        shuffled.push copy.splice(i, 1)[0]
    shuffled

# Data
# ------------------------------------------------------------------------------

# Keep track of all squares

free_text = "\"Cuck\" (FREE SPACE)"

squares = {}
[
    "Clark insults date"
    "Seth calls Erica \"woman\""
    "Dropping the N word over open mic"
    "Tunak Tunak plays"
    "Sorority sisters go woo"
    "Grumpy elder insults the help"
    "Carlos twerks on a wall"
    "Something about Ben's truck"
    "Amiria falls down"
    "Someone mis-pronounces Kirsten's name"
    "Jay takes off his shirt"
    "Ryan refers to himself as Andre"
    "\"Twerk\" by Lady plays"
    "Mention of Betty"
    "Kimia sits on Jay's lap"
    "Seth corrects Baker's grammar"
    "\"Beta\""
    "Amiria insults someone to their face"
    "Baker makes joke, no one laughs"
    "\"Did you know I biked to San Diego?\"- Ben Mayne"
    "Steven makes grand gesture"
    "Jay consumes supplements"
    "Jolt Sensor recommended"
    "Unsucessful shotgunning of beer"
    "Cody’s legal battle status update"
    "Baker criticizes Leah when she’s clearly right"
    "Did you try calling it?"
    "Ray turns red"
    "Someone sends a pisschat"
    "Reverse jaegerbombs are suggested"
    "Reverse jaegerbombs are consumed"
    "Bryn talks about bitcoin"
    "Random guest asks \"when are you going to get married?\""
    "Ben offers someone dip"
    "Clark changes the music to country"
    "Ben and Kirsten talk family planning"
    "Carrie and Lizzie ditch Sean and Clark"
    "Ashley relays a message through Javier"
].map (text) ->
    console.log text
    id = randomString()
    squares[id] = {id, text}

Object.values = (o) ->
    vs = []
    for k, v of o
        vs.push v
    return vs

# Keep track of confirmed square IDs
confirmed = {free: true}
randomSample Object.keys(squares), 3
    .map (id) -> confirmed[id] = true

# Keep track of pending square IDs, as an array of users who have
# claimed this square as pending. Once N_CONFIRM people have confirmed it,
# the square will be marked as confirmed
pending = {}
pending[Object.keys(squares)[0]] = {'jeff': 1}

ROWS = 5
COLS = 5
N_CONFIRM = 3

# Create a random board
randomBoard = ->
    shuffled_square_ids = shuffle Object.keys(squares)
    [0...ROWS].map (row) ->
        [0...COLS].map (col) ->
            if (row == Math.floor ROWS / 2) and (col == Math.floor COLS / 2)
                {id: 'free', text: free_text}
            else
                {id, text} = squares[shuffled_square_ids[row * ROWS + col]]
                {id, text}

# Set statuses on someone's board squares based on the confirmed
# and pending items
fillBoard = (board) ->
    board.map (row) ->
        row.map (square) ->
            {id, text} = square
            {
                id, text,
                confirmed: confirmed[id]
                pending: Object.values(pending[id]).filter (vote) -> vote == 1
            }

# Keep track of boards of every user
user_boards = {}

# Methods
# ------------------------------------------------------------------------------

# Create a new board for a user
createBoard = (user_id, cb) ->
    new_board = randomBoard()
    user_boards[user_id] = new_board
    cb null, fillBoard new_board

makeAlerts = (user_id) ->
    alerts = []
    for square_id, user_votes of pending
        if not user_votes[user_id]?
            alerts.push {
                square: squares[square_id]
                user_id: Object.keys(user_votes)[0]
            }
    return alerts

# Return a board for a user
getBoard = (user_id, cb) ->
    user_board = user_boards[user_id]
    if !user_board?
        user_board = randomBoard()
        user_boards[user_id] = user_board
    cb null, {
        board: fillBoard user_board
        alerts: makeAlerts user_id
        winners: checkWinners()
    }

# Claim square: Send an alert to participants asking for votes if this square is valid
claimSquare = (square_id, user_id, cb) ->
    if !confirmed[square_id]
        if !pending[square_id]?
            votes = {}
            votes[user_id] = 1
            pending[square_id] = votes
        else
            if not pending[square_id][user_id]
                pending[square_id][user_id] = 1
    cb null
    publishBoards()
    checkPending square_id
    publishClaim square_id, user_id

# Vote square: Participant responds yes or no on whether square is valid
# If > N yes votes, square is marked confirmed
voteSquare = (square_id, user_id, vote, cb) ->
    if !confirmed[square_id] and pending[square_id]?
        if not pending[square_id][user_id]?
            pending[square_id][user_id] = vote
    cb null
    checkPending square_id
    publishBoards()

add = (a, b) -> a + b
sum = (l) -> l.reduce add, 0

checkPending = (square_id) ->
    # If enough votes, emit confirm event
    if user_votes = pending[square_id]
        total = sum Object.values user_votes
        if total >= N_CONFIRM
            confirmSquare square_id
        else if total == -1
            delete pending[square_id]

# Confirm square: Square is set confirmed, all participants are notified.
# Checks participant boards to find a winner
confirmSquare = (square_id) ->
    delete pending[square_id]
    confirmed[square_id] = true
    publishBoards()

checkWinners = ->
    winners = []
    for user_id, user_board of user_boards
        if checkBoard user_board
            winners.push user_id
    return winners

winning_positions = []

flatten = (ls) ->
    flat = []
    for l in ls
        for i in l
            flat.push i
    return flat

# Rows
[0...ROWS].map (row) ->
    winning_positions.push [0...COLS].map (col) ->
        [row, col]

# Columns
[0...COLS].map (col) ->
    winning_positions.push [0...ROWS].map (row) ->
        [row, col]

# Diagonals
winning_positions.push [0...ROWS].map (row) ->
    [row, row]

winning_positions.push [0...ROWS].map (row) ->
    [row, ROWS - row - a-1]

console.log winning_positions

checkBoard = (user_board) ->
    for positions in winning_positions
        if checkPositions user_board, positions
            return true
    return false

checkPositions = (user_board, positions) ->
    for position in positions
        [y, x] = position
        console.log 'y', y, 'x', x
        if not confirmed[user_board[y][x].id]
            return false
    return true

# Publishing events
# ------------------------------------------------------------------------------

publishClaim = (square_id, user_id) ->
    if !confirmed[square_id]
        # Publish claim
        square = squares[square_id]
        service.publish 'claim', {user_id, square}

publishBoards = ->
    for user_id, user_board of user_boards
        service.publish 'updateBoard:' + user_id, {
            board: fillBoard user_board
            alerts: makeAlerts user_id
            winners: checkWinners()
        }

# ------------------------------------------------------------------------------

service = new somata.Service 'bingo', {
    createBoard
    getBoard
    claimSquare
    voteSquare
}
