React = require 'preact'
Redux = require 'redux'
Kefir = require 'kefir'
somata = require 'somata-socketio-client'

# Store
# ------------------------------------------------------------------------------

initial_state = {
    loading: true
}

reducer = (state={}, action) ->
    switch action.type
        when 'setBoard'
            {board, alerts, winners} = action
            return Object.assign {}, state, {loading: false, board, alerts, winners}
    return state

Store = Redux.createStore reducer, initial_state

# Dispatcher
# ------------------------------------------------------------------------------

promptForUsername = ->
    user_id = prompt "Set your username"
    if user_id?.trim().length
        window.location.hash = user_id.trim()
    else
        promptForUsername()

user_id = window.location.hash.slice(1)

if !user_id?.trim().length
    promptForUsername()

Dispatcher =
    getBoard: ->
        somata.remote$ 'bingo', 'getBoard', user_id

    claimSquare: (square_id) ->
        somata.remote$ 'bingo', 'claimSquare', square_id, user_id
            .log 'claimed'

    voteSquare: (square_id, vote) ->
        somata.remote$ 'bingo', 'voteSquare', square_id, user_id, vote
            .log 'voted'

Dispatcher.getBoard user_id
    .onValue ({board, alerts, winners}) ->
        Store.dispatch {type: 'setBoard', board, alerts, winners}

somata.connect ->
    console.log '[connected]'

somata.subscribe$ 'bingo', 'updateBoard:' + user_id
    .onValue ({board, alerts, winners}) ->
        Store.dispatch {type: 'setBoard', board, alerts, winners}

# Components
# ------------------------------------------------------------------------------

double_touch_square = null
double_touch_count = 0
double_touch_timeout = null

claimOnDouble = (square_id, e) ->
    e.preventDefault()
    e.stopPropagation()
    clearTimeout double_touch_timeout
    if square_id != double_touch_square
        double_touch_count = 1
    else
        double_touch_count++
    double_touch_square = square_id
    if double_touch_count == 2
        console.log 'dubbd'
        Dispatcher.claimSquare square_id
        double_touch_count = 0
    else
        double_touch_timeout = setTimeout ->
            double_touch_count = 0
        , 500

class App extends React.Component
    constructor: ->
        @state = Store.getState()
        Store.subscribe =>
            @setState Store.getState()

    render: ->
        {loading, board, alerts, winners} = @state

        <div id='container'>
            <div id='header'>
                <img src='/images/logo.png' />
                <div id='navigation'>
                    <a className='selected'>Board</a>
                    <a className='unselected'>Leaderboard</a>
                </div>
                <span className='username'>{user_id}</span>
            </div>

            {if loading
                <p>Loading...</p>
            else
                [0...5].map (row) ->
                    <div className='row' key=row>
                        {[0...5].map (col) ->
                            square = board[row][col]
                            square_class = "square"
                            if square.pending?.length
                                square_class += ' pending'
                            if square.confirmed
                                square_class += ' confirmed'
                            <div className=square_class key=col onDblClick={Dispatcher.claimSquare.bind(null, square.id)} onTouchStart={claimOnDouble.bind(null, square.id)}>
                                {if square.pending?.length
                                    <span className='pending'>{square.pending.length}</span>
                                }
                                <span>{square.text}</span>
                            </div>
                        }
                    </div>
            }

            {if winners?.length
                console.log "WINNERS", winners
                <div className='overlay'>
                    <div className='winners'>
                        <img src='/images/logo.png' />
                        {if winners.length == 1
                            <p>We have a winner!</p>
                        else
                            <p>We have {winners.length} winners!</p>
                        }
                        {winners.map (user_id) ->
                            <div className='winner' key=user_id>
                                {user_id}
                            </div>
                        }
                        <p>The winner{if winners.length > 1 then 's'} may present this ticket for a free drink at the bar.</p>
                        <a>Reset board</a>
                    </div>
                </div>
            else if alerts?.length
                <div className='alerts'>
                    {alerts.map (alert) ->
                        <div className='alert' key=alert.square.id>
                            <p className='message'>{alert.user_id} claims <strong>{alert.square.text}</strong></p>
                            <div className='buttons'>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, 1)}>Confirm</a>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, -1)}>Deny</a>
                            </div>
                        </div>
                    }
                </div>
            }
        </div>

React.render <App />, document.getElementById 'app'
