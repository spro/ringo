React = require 'preact'
Redux = require 'redux'
Kefir = require 'kefir'
somata = require 'somata-socketio-client'

# Store
# ------------------------------------------------------------------------------

initial_state = {
    loading: true
    tab: 'board'
}

reducer = (state={}, action) ->
    switch action.type
        when 'setBoard'
            {board, alerts, winners, leaderboard} = action
            return Object.assign {}, state, {loading: false, board, alerts, winners, leaderboard}
        when 'changeTab'
            {tab} = action
            return Object.assign {}, state, {tab}
    return state

Store = Redux.createStore reducer, initial_state

# Dispatcher
# ------------------------------------------------------------------------------

Globals =
    user_id: window.location.hash.slice(1)
    game_id: null

promptForUsername = ->
    user_id = prompt "Set your username"
    if user_id?.trim().length
        window.location.hash = user_id.trim()
        Globals.user_id = user_id
    else
        promptForUsername()

if !Globals.user_id?.trim().length
    promptForUsername()

Dispatcher =
    getBoard: ->
        somata.remote$ 'bingo', 'getBoard', Globals.game_id, Globals.user_id

    claimSquare: (square_id) ->
        somata.remote$ 'bingo', 'claimSquare', Globals.game_id, square_id, Globals.user_id
            .log 'claimed'

    voteSquare: (square_id, vote) ->
        somata.remote$ 'bingo', 'voteSquare', Globals.game_id, square_id, Globals.user_id, vote
            .log 'voted'

    resetBoard: ->
        somata.remote$ 'bingo', 'resetBoard', Globals.game_id, Globals.user_id
            .onValue (new_game_id) ->
                refresh new_game_id

    setTab: (tab) ->
        Store.dispatch {type: 'changeTab', tab}

somata.connect()

refresh = (new_game_id) ->
    if new_game_id?
        somata.unsubscribe 'bingo', "updateBoard:#{Globals.game_id}:#{Globals.user_id}"
        Globals.game_id = new_game_id

    somata.subscribe$ 'bingo', "updateBoard:#{Globals.game_id}:#{Globals.user_id}"
        .onValue ({board, alerts, winners, leaderboard}) ->
            Store.dispatch {type: 'setBoard', board, alerts, winners, leaderboard}

    Dispatcher.getBoard Globals.game_id, Globals.user_id
        .onValue ({board, alerts, winners, leaderboard}) ->
            Store.dispatch {type: 'setBoard', board, alerts, winners, leaderboard}

somata.remote$ 'bingo', 'getGameId'
    .onValue (game_id) ->
        Globals.game_id = game_id
        refresh()

window.addEventListener "focus", ->
    refresh()

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
        {loading, tab, board, alerts, winners, leaderboard} = @state

        <div id='container'>
            <div id='header'>
                <img src='/images/logo.png' />
                <div id='navigation'>
                    <a onClick={Dispatcher.setTab.bind(null, 'board')} className={if tab == 'board' then 'selected'}>Board</a>
                    <a onClick={Dispatcher.setTab.bind(null, 'leaderboard')} className={if tab == 'leaderboard' then 'selected'}>Leaderboard</a>
                </div>
                <span className='username'>{Globals.user_id}</span>
            </div>

            {if loading
                <p>Loading...</p>
            else if tab == 'board'
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
            else if tab == 'leaderboard'
                <div id='leaderboard'>
                    {if leaderboard.length
                        leaderboard.map ([user_id, user_score]) ->
                            <div className='leader' key=user_id>
                                <span className='user_id'>{user_id}</span>
                                <span className='user_score'>{user_score}</span>
                            </div>
                    else
                        <p className='empty'>Nobody has won a game yet...</p>
                    }
                </div>
            }

            {if winners?.length
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
                        <a onClick=Dispatcher.resetBoard>Join new game</a>
                    </div>
                </div>
            else if alerts?.length
                <div className='alerts'>
                    {alerts.map (alert) ->
                        <div className='alert' key=alert.square.id>
                            <p className='message'><strong>{alert.user_id}</strong> claims <strong>{alert.square.text}</strong></p>
                            <div className='buttons'>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, 1)}>Confirm</a>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, -1)}>Deny</a>
                            </div>
                        </div>
                    }
                </div>
            }

            <span className='game_id'>{Globals.game_id}</span>
        </div>

React.render <App />, document.getElementById 'app'
